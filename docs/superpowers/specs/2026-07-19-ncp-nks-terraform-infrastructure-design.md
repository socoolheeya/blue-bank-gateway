# NCP NKS Terraform 인프라 설계

## 목표

Blue Bank 개발 환경을 네이버클라우드 플랫폼에 반복 가능하고 안전하게 생성한다. Terraform으로 NKS 기반 인프라를 관리하고, 기존 Envoy Gateway·Argo CD·Spring Cloud Gateway·Redis 배포 구조를 연결한다. Eureka와 Nginx는 다시 도입하지 않는다.

## 확정 사항

- 클라우드/리전: 네이버클라우드 플랫폼 한국 리전(`KR`)
- 대상 환경: 이번 구현은 개발 환경만 생성하며 운영 환경은 추후 공용 모듈을 재사용
- 가용성: 개발 환경은 Single Zone
- Kubernetes: KVM 기반 NKS 1.34, Cilium
- 워커 네트워크: Private Subnet, NAT Gateway를 통한 외부 통신
- 노드 풀: 2 vCPU, 8 GB 메모리, 100 GB 기본 스토리지 노드 2대
- 오토스케일링: 개발 환경에서는 비활성화
- Kubernetes API: Public Endpoint, 기본 차단 후 명시한 `/32` CIDR만 허용
- 이미지 저장소: Naver Container Registry(NCR)
- Terraform 상태: NCP Object Storage 원격 backend
- 애플리케이션 배포: Argo CD GitOps
- 개발 환경 외부 진입: 도메인과 TLS 도입 전까지 Public Load Balancer IP와 HTTP 사용

## 관리 범위

Terraform은 다음 NCP 인프라를 관리한다.

- VPC, Subnet, Route Table, Route, NAT Gateway, Network ACL 규칙
- NKS 클러스터와 노드 풀
- 운영자와 배포 도구가 사용할 클러스터·네트워크 정보 출력

다음 항목은 NCP 콘솔에서 최초 한 번 생성한다.

- Terraform 상태 전용 Object Storage 버킷
- 컨테이너 이미지 전용 Object Storage 버킷
- 이미지 버킷과 연결된 Container Registry
- Terraform 실행용 Sub Account와 API 인증키

Argo CD는 클러스터가 생성된 다음 Kubernetes 리소스를 관리한다.

- Envoy Gateway v1.8.2 및 Gateway API 리소스
- Spring Cloud Gateway
- 개발용 Redis StatefulSet과 영구 볼륨
- 향후 account, deposit, loan, card 업무 서비스

NCP 인증키, kubeconfig, Kubernetes Secret, 애플리케이션 인증정보는 Terraform 코드와 Git에 저장하지 않는다.

## 저장소 구조

```text
infra/
  modules/
    network/
    nks/
  environments/
    dev/
      backend.tf
      main.tf
      providers.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
      backend.hcl.example
  scripts/
    bootstrap-argocd.sh
    verify-dev.sh
```

공용 모듈에는 환경별 인증정보를 넣지 않는다. `dev` Root Module이 개발 환경 CIDR, 노드 사양, 이름, API 허용 대역과 콘솔에서 만든 NCR Endpoint를 조합한다. 향후 `prod` Root Module을 추가해도 리소스 정의를 복사하지 않는다.

## 네트워크 설계

| 용도 | 종류 | CIDR |
| --- | --- | --- |
| VPC | 사설 주소 공간 | `10.0.0.0/16` |
| NKS 워커 노드 | Private 일반 Subnet | `10.0.10.0/24` |
| 내부 Load Balancer | Private LB 전용 Subnet | `10.0.20.0/24` |
| 외부 Load Balancer | Public LB 전용 Subnet | `10.0.30.0/24` |
| NAT Gateway | Public 일반 Subnet | `10.0.40.0/24` |

워커 Subnet의 `0.0.0.0/0` 경로는 NAT Gateway를 향한다. 워커 노드에는 Public IP를 부여하지 않는다. Envoy Gateway가 Public LB Subnet에 외부 Load Balancer를 생성한다. Network ACL은 VPC 내부 통신, 응답 트래픽, DNS, 필요한 외부 HTTPS 통신을 허용하되 워커 노드에 대한 무제한 외부 인바운드는 허용하지 않는다.

NKS용 일반 Subnet과 LB 전용 Subnet은 공식 제약인 `/17`~`/26` 범위에 포함되어야 하며 `172.17.0.0/16`은 사용하지 않는다.

## NKS 설계

NKS 클러스터는 KVM, Kubernetes 1.34, Cilium, Private 워커 Subnet, Public/Private LB 전용 Subnet을 사용한다. Control Plane API의 기본 ACL 동작은 `deny`로 설정한다. `allowed_api_cidrs`에는 최소 하나 이상의 CIDR을 반드시 입력하며 개발자 PC나 CI의 공인 IP는 `/32`로 등록한다.

개발 노드 풀은 2 vCPU/8 GB 노드 2대와 노드당 100 GB 기본 스토리지를 사용한다. 노드 2대로 Rolling Update와 기본적인 노드 장애를 검증하면서 개발 비용을 제한한다. 오토스케일링은 비용 예측을 위해 비활성화한다. NKS 반납 보호는 활성화하고 삭제할 때는 변수를 명시적으로 변경한 후 진행한다.

## Container Registry 설계

Container Registry는 NCP 콘솔에서 이미지 전용 Object Storage 버킷과 연결해 생성한다. Terraform Root Module에는 Registry 이름 또는 Endpoint만 입력하며 새 Registry를 암묵적으로 만들지 않는다.

CI는 Gateway 이미지를 빌드하고 변경 불가능한 태그로 NCR에 Push한 다음 Kustomize 이미지 태그를 변경해 Git에 반영한다. Argo CD는 이미지를 빌드하지 않는다. NKS에서 Private NCR 이미지를 Pull할 때 필요한 인증정보는 Kubernetes Secret으로 별도 생성하며 Git에 저장하지 않는다.

## NCP 콘솔 사전 생성 절차

### 1. 한국 리전과 VPC 플랫폼 선택

1. NCP 콘솔에 로그인한다.
2. 우측 상단 **리전 & 플랫폼**에서 리전은 **한국**, 플랫폼은 **VPC**를 선택한다.
3. 이후 생성하는 Object Storage, Container Registry, Sub Account가 동일 계정인지 확인한다.

VPC, Subnet, NAT Gateway, Route Table, NKS는 콘솔에서 직접 만들지 않는다. 해당 리소스는 Terraform이 생성해야 상태 불일치가 발생하지 않는다.

### 2. Terraform 실행용 Sub Account와 API 인증키 생성

1. **Services > Management & Governance > Sub Account**로 이동한다.
2. Terraform 전용 Sub Account를 생성한다.
3. 접근 유형에서 **API Gateway Access**를 활성화한다.
4. Terraform이 관리할 VPC, Server, NKS, Load Balancer 관련 권한과 Object Storage state 접근에 필요한 최소 권한을 부여한다.
5. 생성한 계정의 **Access Key** 탭에서 Access Key와 Secret Key를 생성한다.
6. Secret Key는 발급 직후 비밀 저장소에 보관하고 Git, 문서, 메신저, `terraform.tfvars`에 입력하지 않는다.

실행 터미널에서만 다음 환경변수를 설정한다.

```bash
export NCLOUD_ACCESS_KEY="발급받은-access-key"
export NCLOUD_SECRET_KEY="발급받은-secret-key"
export NCLOUD_REGION="KR"
```

### 3. Terraform 상태 전용 Object Storage 버킷 생성

1. **Services > Storage > Object Storage**로 이동한다.
2. 처음 사용하는 경우 **이용 신청**을 완료한다.
3. **Bucket Management > 버킷 생성**을 선택한다.
4. 전역에서 고유한 이름을 입력한다. 예: `blue-bank-tfstate-계정식별자`.
5. Terraform state 갱신을 방해할 수 있으므로 WORM 객체 잠금은 사용하지 않는다.
6. 외부 공개를 허용하지 않고 Terraform 전용 Sub Account만 읽기·쓰기할 수 있도록 권한을 제한한다.
7. backend 설정에 사용할 버킷 이름을 기록한다.

이 버킷에는 Terraform state만 저장한다. Container Registry 이미지 버킷과 공유하지 않는다. State 버킷은 자신을 사용하는 Terraform state에서 관리하지 않는다.

### 4. Container Registry 이미지 전용 버킷 생성

1. **Services > Storage > Object Storage > Bucket Management**로 이동한다.
2. 별도 버킷을 생성한다. 예: `blue-bank-ncr-계정식별자`.
3. WORM, Lifecycle Management, ACL을 활성화하면 NCR 사용에 제약이 생길 수 있으므로 초기에는 사용하지 않는다.
4. Terraform state 파일을 이 버킷에 저장하지 않는다.

### 5. Container Registry 생성

1. **Services > Containers > Container Registry**로 이동한다.
2. **레지스트리 생성**을 선택한다.
3. 영어 소문자, 숫자, 하이픈으로 3~30자 이름을 입력한다. 예: `blue-bank-dev`.
4. 스토리지 타입으로 **Object Storage**를 선택한다.
5. 앞에서 생성한 이미지 전용 버킷을 선택한다.
6. 생성 후 Public Endpoint를 기록한다. 형식은 `<registry-name>.kr.ncr.ntruss.com`이다.
7. Endpoint를 `terraform.tfvars`와 Kustomize 이미지 설정에 사용하되 인증정보는 함께 저장하지 않는다.

### 6. API 접근용 현재 공인 IP 확인

1. Terraform을 실행할 개발자 PC 또는 CI Runner의 공인 IPv4를 확인한다.
2. 단일 IP는 `x.x.x.x/32` 형식으로 기록한다.
3. 동적 IP가 변경되면 Terraform 실행 전에 `allowed_api_cidrs`를 갱신한다.
4. 편의를 이유로 `0.0.0.0/0`을 입력하지 않는다.

## Terraform 생성 절차

콘솔 사전 준비 후 Terraform이 다음 순서의 의존성을 계산해 생성한다.

1. VPC와 기본 Network ACL
2. 워커, Private LB, Public LB, NAT Gateway Subnet
3. NAT Gateway
4. 워커 전용 Route Table과 NAT 기본 경로
5. NKS 로그인 키
6. NKS 1.34 Single Zone 클러스터
7. 2 vCPU/8 GB 노드 2대의 노드 풀

실행 순서는 다음과 같다.

```bash
cd infra/environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../../
terraform validate
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

`backend.hcl`에는 state 버킷 이름, 객체 Key, 한국 리전용 S3 호환 Endpoint 등 backend 연결값을 넣는다. `terraform.tfvars`에는 API 허용 CIDR과 NCR Endpoint 같은 비밀이 아닌 환경값만 넣는다. 두 실제 설정 파일과 Plan 파일은 Git에서 제외한다.

## NKS 생성 후 GitOps 배포 순서

1. Terraform output에서 NKS UUID와 NCR Endpoint를 확인한다.
2. NCP CLI로 해당 NKS의 kubeconfig를 발급한다.
3. 명시적인 kubeconfig와 context로 클러스터 연결을 확인한다.
4. Argo CD bootstrap 스크립트를 실행한다.
5. 기존 Envoy Gateway Application과 Blue Bank Gateway Application을 적용한다.
6. Argo CD가 Envoy Gateway와 `k8s/overlays/dev`를 동기화한다.
7. Envoy Gateway가 NCP Public Load Balancer를 생성한다.
8. 할당된 External IP로 HTTP 요청을 보내 정상 응답을 확인한다.

Spring Cloud Gateway는 Kubernetes Service/DNS로 업무 서비스에 접근하며 JWT 인증, Redis Rate Limit, Circuit Breaker, Fallback, 업무별 Filter를 유지한다. 이 흐름에 Eureka Server, Eureka Client, Nginx는 포함되지 않는다.

Kubernetes가 생성한 Load Balancer는 콘솔에서 직접 수정하지 않는다. Load Balancer 속성 변경은 Kubernetes Service 또는 Envoy 관련 리소스에서 수행해 상태 동기화 문제를 방지한다.

## 상태와 비밀정보 관리

다음 파일은 반드시 Git에서 제외한다.

- `terraform.tfvars`
- `backend.hcl`
- `.terraform/`
- `*.tfstate`, `*.tfstate.*`
- `*.tfplan`
- kubeconfig

NCP Provider 인증은 `NCLOUD_ACCESS_KEY`, `NCLOUD_SECRET_KEY`, `NCLOUD_REGION` 환경변수로만 전달한다. 예제 파일에는 실제 값 대신 설명용 값만 둔다. Terraform state에는 인프라 정보가 포함되므로 비밀정보와 동일한 수준으로 접근을 제한한다.

## 장애 대응과 안전장치

- 변수 검증으로 잘못된 CIDR, 빈 API 허용 목록, 허용하지 않은 노드 수와 스토리지 크기를 Apply 전에 거부한다.
- NKS 버전, 노드 이미지, 서버 상품은 가능한 한 Provider Data Source로 조회해 변동 가능한 상품 코드를 하드코딩하지 않는다.
- 스크립트는 명시적인 kubeconfig/context를 요구해 다른 클러스터를 잘못 변경하지 않도록 한다.
- NAT 경로 이상은 Argo CD 배포 성공을 판단하기 전에 노드와 Pod의 외부 이미지 Pull로 검증한다.
- Kubernetes Secret이 없으면 안전하지 않은 기본값을 넣지 않고 Pod가 Ready가 되지 않도록 한다.
- NKS 반납 보호와 원격 state를 통해 우발적인 삭제 가능성을 줄인다.
- Terraform 장애는 인프라 계층에서, Argo CD 동기화 장애는 Kubernetes 계층에서 각각 진단한다.

## 검증

인프라 Apply 전 다음 검증이 모두 성공해야 한다.

- `terraform fmt -check -recursive infra`
- `terraform init -backend=false`
- `terraform validate`
- bootstrap/검증 Shell Script 문법 검사
- 인증키, state, plan, kubeconfig, 실제 `terraform.tfvars`가 Git에 포함되지 않았는지 검사
- `./gradlew clean test build`

Apply 후 다음 항목을 확인한다.

- 원격 state 저장 및 Terraform output
- 허용한 IP에서 NKS Control Plane 접근
- Private IP를 사용하는 Ready 노드 2대
- NAT Gateway를 통한 외부 이미지 Pull
- Argo CD, Envoy Gateway, Gateway API, Spring Gateway, Redis 상태
- Public Load Balancer External IP 할당
- Envoy Gateway를 경유한 HTTP 응답

## 제외 및 추후 작업

- Multi Zone 운영 클러스터와 운영 노드 사양
- 운영용 Terraform Root Module과 별도 state Key
- 도메인, DNS, 인증서, HTTPS Listener
- 운영용 Managed/HA Redis
- 특정 CI 제품에 종속된 NCR Build/Push Pipeline
- 중앙 관측성, 백업, 재해 복구 자동화
- VPN 또는 Bastion을 통한 Private Kubernetes API

## 공식 참고 문서

- [NKS 사용 준비](https://guide.ncloud-docs.com/docs/k8s-k8sprep)
- [NKS 시작](https://guide.ncloud-docs.com/docs/k8s-k8sstart)
- [NKS Load Balancer 연동](https://guide.ncloud-docs.com/docs/k8s-k8suse-loadbalancer)
- [Object Storage 버킷 사용](https://guide.ncloud-docs.com/docs/objectstorage-use-bucket)
- [Container Registry 시작](https://guide.ncloud-docs.com/docs/containerregistry-start)
- [Ncloud Terraform Provider 인증](https://registry.terraform.io/providers/NaverCloudPlatform/ncloud/latest/docs)

