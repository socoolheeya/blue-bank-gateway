# NCP NKS 개발 인프라 배포

이 문서는 빈 NCP 계정 상태에서 개발용 Blue Bank NKS 인프라를 만들고 Gateway를 외부 HTTP로 확인하는 순서를 설명합니다. 명령은 저장소 루트에서 실행하는 것을 기준으로 합니다.

## 1. 생성되는 유료 리소스

Terraform과 Kubernetes 배포 후 다음 항목에 비용이 발생할 수 있습니다.

- NAT Gateway와 외부 통신량
- NKS Control Plane 이용료 정책
- 2 vCPU/8GB 워커 서버 2대와 노드당 100GB 스토리지
- Envoy Gateway가 생성하는 Public Load Balancer와 Public IP
- Terraform state 및 NCR 이미지용 Object Storage
- Container Registry 저장량과 네트워크 전송량
- Redis PVC용 Block Storage

가격은 변경될 수 있으므로 Apply 전에 NCP 상품별 최신 요금을 확인합니다.

## 2. 로컬 도구 설치 확인

다음 명령이 모두 실행되어야 합니다.

```bash
terraform version  # 1.10 이상
kubectl version --client
helm version --short
kustomize version
docker version
ncp-iam-authenticator version
```

Terraform Provider는 Root Module의 `.terraform.lock.hcl`에 `NaverCloudPlatform/ncloud` 4.0.5로 고정되어 있습니다.

## 3. NCP Sub Account와 API 인증키 생성

1. NCP 콘솔에서 리전 **한국**, 플랫폼 **VPC**를 선택합니다.
2. **Services > Management & Governance > Sub Account**로 이동합니다.
3. Terraform 전용 Sub Account를 생성합니다.
4. 접근 유형의 **API Gateway Access**를 활성화합니다.
5. VPC, NAT Gateway, Route Table, NKS, Server/Login Key, Load Balancer 조회·생성·변경 권한을 부여합니다.
6. Object Storage state 버킷을 읽고 쓸 권한을 부여합니다.
7. Sub Account의 **Access Key** 탭에서 Access Key와 Secret Key를 발급합니다.
8. Secret Key는 비밀 저장소에 보관하며 Git이나 `terraform.tfvars`에 기록하지 않습니다.

터미널에 인증정보를 설정합니다.

```bash
export NCLOUD_ACCESS_KEY="발급받은-access-key"
export NCLOUD_SECRET_KEY="발급받은-secret-key"
export NCLOUD_REGION="KR"

# Terraform S3 backend가 동일한 NCP Object Storage 인증키를 사용합니다.
export AWS_ACCESS_KEY_ID="$NCLOUD_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$NCLOUD_SECRET_KEY"
```

## 4. Terraform state Object Storage 버킷 생성

1. **Services > Storage > Object Storage**로 이동합니다.
2. 처음 사용한다면 **이용 신청**을 완료합니다.
3. **Bucket Management > 버킷 생성**을 선택합니다.
4. 전역에서 고유한 이름을 입력합니다. 예: `blue-bank-tfstate-계정식별자`.
5. Terraform state 갱신을 막을 수 있으므로 WORM 객체 잠금을 사용하지 않습니다.
6. 외부 공개를 차단하고 Terraform Sub Account에만 필요한 읽기·쓰기 권한을 부여합니다.

이 버킷은 자신이 보관하는 Terraform state로 관리하지 않으며 NCR 이미지 저장에 사용하지 않습니다.

## 5. NCR 이미지 버킷과 Container Registry 생성

1. **Services > Storage > Object Storage > Bucket Management**에서 별도 이미지 버킷을 만듭니다.
2. 예시 이름은 `blue-bank-ncr-계정식별자`입니다.
3. 초기에는 WORM, Lifecycle Management, ACL을 활성화하지 않습니다.
4. **Services > Containers > Container Registry**로 이동합니다.
5. **레지스트리 생성**을 선택합니다.
6. `blue-bank-dev`처럼 영어 소문자로 시작하는 3~30자의 소문자·숫자·하이픈 이름을 입력합니다.
7. 스토리지 타입은 **Object Storage**를 선택하고 이미지 버킷을 연결합니다.
8. 생성 후 `<registry-name>.kr.ncr.ntruss.com` 형식의 Public Endpoint를 기록합니다.

## 6. 현재 공인 IP 확인

Terraform을 실행할 PC 또는 CI Runner의 공인 IPv4를 확인합니다.

```bash
curl -4 https://ifconfig.me
```

출력이 `203.0.113.20`이라면 `allowed_api_cidrs`에는 `203.0.113.20/32`를 사용합니다. `0.0.0.0/0`은 변수 검증에서 거부됩니다. 동적 IP가 바뀌면 다시 Plan/Apply하여 허용 목록을 변경합니다.

## 7. backend.hcl과 terraform.tfvars 작성

```bash
cd "$(git rev-parse --show-toplevel)/infra/environments/dev"
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

`backend.hcl`에서 버킷 이름을 4단계에서 만든 이름으로 바꿉니다.

```hcl
bucket = "실제-state-버킷-이름"
key    = "blue-bank/dev/terraform.tfstate"
region = "kr-standard"
```

`terraform.tfvars`에서 다음 두 값을 반드시 바꿉니다.

```hcl
allowed_api_cidrs = ["실제-공인-IP/32"]
ncr_endpoint       = "실제-registry-name.kr.ncr.ntruss.com"
```

두 실제 파일은 `.gitignore`에 포함되어 있으므로 커밋하지 않습니다.

## 8. VPC/NAT/NKS Terraform Plan 검토

```bash
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../../
terraform validate
terraform plan -out=dev.tfplan
terraform show dev.tfplan
```

Plan에서 다음을 확인합니다.

- VPC CIDR: `10.0.0.0/16`
- 워커 Private Subnet: `10.0.10.0/24`, `usage_type = GEN`
- Private LB Subnet: `10.0.20.0/24`, `usage_type = LOADB`
- Public LB Subnet: `10.0.30.0/24`, `usage_type = LOADB`
- NAT Public Subnet: `10.0.40.0/24`, `usage_type = NATGW`
- 워커 Route Table의 `0.0.0.0/0` 대상: NAT Gateway
- NKS: KVM, Kubernetes 1.34, Cilium, `public_network = false`
- API ACL: 기본 `deny`, 실제 PC/CI `/32`만 `allow`
- 노드 풀: 2 vCPU/8GB, 100GB, 2대, Autoscale 비활성화
- `return_protection = true`
- 예상하지 않은 기존 리소스 변경·삭제: 0개

삭제가 표시되거나 CIDR/허용 IP가 다르면 Apply하지 말고 `terraform.tfvars` 또는 코드를 수정한 후 Plan을 다시 만듭니다.

## 9. Terraform Apply

Plan 검토가 끝난 경우에만 저장된 Plan을 적용합니다.

```bash
terraform apply dev.tfplan
terraform output
```

생성에는 시간이 걸릴 수 있습니다. 실행이 중단돼도 바로 재실행하지 말고 NCP 콘솔과 `terraform plan`으로 실제 상태를 먼저 확인합니다.

## 10. NCP 콘솔에서 VPC부터 생성 결과 확인

다음 순서대로 확인합니다. Terraform 관리 리소스를 콘솔에서 직접 수정하지 않습니다.

1. **Services > Networking > VPC > VPC Management**
   - `blue-bank-dev-vpc`
   - `10.0.0.0/16`
2. **Subnet Management**
   - 워커/Private LB/Public LB/NAT Subnet 4개
   - 모두 동일한 선택 Zone
3. **NAT Gateway**
   - `blue-bank-dev-natgw`
   - Public IP 할당
4. **Route Table**
   - `blue-bank-dev-worker-rt`
   - 워커 Subnet 연결
   - `0.0.0.0/0 -> NATGW`
5. **Services > Containers > Ncloud Kubernetes Service**
   - Kubernetes 1.34, KVM, Cilium, Single Zone
   - 클러스터 상태 Running
6. **Node Pool**
   - `blue-bank-dev-default`
   - 노드 2대와 Private IP
7. **Load Balancer**
   - Argo CD 배포 전에는 애플리케이션 LB가 없어도 정상
   - Envoy 배포 후 Kubernetes가 생성한 Public LB 확인

## 11. kubeconfig 발급

NCP의 IAM 인증 방식을 사용합니다.

```bash
cd "$(git rev-parse --show-toplevel)"
repo_root="$PWD"
mkdir -p "$repo_root/.kube"

cluster_uuid="$(terraform -chdir=infra/environments/dev output -raw cluster_uuid)"
ncp-iam-authenticator create-kubeconfig \
  --region KR \
  --clusterUuid "$cluster_uuid" \
  --output "$repo_root/.kube/blue-bank-dev.yaml"

export KUBECONFIG="$repo_root/.kube/blue-bank-dev.yaml"
export KUBE_CONTEXT="$(kubectl --kubeconfig "$KUBECONFIG" config current-context)"

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get nodes -o wide
```

Ready 노드가 정확히 2대이고 Public IP가 없어야 합니다. `.kube/` 파일을 커밋하지 않습니다.

## 12. NCR 로그인과 Gateway 이미지 Push

```bash
cd "$(git rev-parse --show-toplevel)"
NCR_ENDPOINT="실제-registry-name.kr.ncr.ntruss.com"
IMAGE_TAG="dev-$(git rev-parse --short HEAD)"

printf '%s' "$NCLOUD_SECRET_KEY" | \
  docker login "$NCR_ENDPOINT" --username "$NCLOUD_ACCESS_KEY" --password-stdin

docker build -t "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG" .
docker push "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG"
```

Kustomize의 Registry 토큰과 태그를 실제 값으로 변경합니다.

```bash
cd k8s/overlays/dev
kustomize edit set image \
  "blue-bank-gateway=$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG"
cd ../../..

git diff -- k8s/overlays/dev/kustomization.yaml
git add k8s/overlays/dev/kustomization.yaml
git commit -m "deploy: select Gateway image $IMAGE_TAG"
git push origin HEAD
```

Argo CD는 원격 Git 저장소를 읽으므로 이미지 변경 커밋을 Push해야 합니다.

## 13. Kubernetes Secret 생성

Secret을 Shell 명령행 인자로 직접 쓰면 history에 남을 수 있으므로 숨김 입력을 사용합니다.

```bash
read -r -s -p "JWT secret: " JWT_SECRET_VALUE
echo
read -r -s -p "Redis password: " REDIS_PASSWORD_VALUE
echo

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  create namespace blue-bank --dry-run=client -o yaml |
  kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" apply -f -

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  create secret generic blue-bank-gateway-secret \
  --namespace blue-bank \
  --from-literal=JWT_SECRET="$JWT_SECRET_VALUE" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD_VALUE" \
  --dry-run=client -o yaml |
  kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" apply -f -

unset JWT_SECRET_VALUE REDIS_PASSWORD_VALUE
```

운영 환경에서는 수동 Secret 대신 NCP Secret Manager와 External Secrets 같은 연동을 별도로 설계합니다.

## 14. Argo CD/Envoy Gateway 부트스트랩

원격 Git 저장소 URL을 설정합니다.

```bash
cd "$(git rev-parse --show-toplevel)"
export GIT_REPOSITORY_URL="https://github.com/조직/blue-bank-gateway.git"

./infra/scripts/bootstrap-argocd.sh
```

Private Git 저장소라면 Argo CD Repository Credential을 먼저 등록해야 합니다. 인증정보는 Application YAML에 넣지 않습니다.

확인 명령:

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get applications -n argocd
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get pods -n argocd
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get pods -n envoy-gateway-system
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get pods -n blue-bank
```

## 15. 전체 배포 검증

```bash
cd "$(git rev-parse --show-toplevel)"
./infra/scripts/verify-dev.sh
```

성공하면 다음 형식이 출력됩니다.

```text
Development NKS verification passed: http://외부-IP
```

직접 상태를 확인하려면 다음 명령을 사용합니다.

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  get gateway blue-bank -n blue-bank

EXTERNAL_IP="$(kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  get gateway blue-bank -n blue-bank -o jsonpath='{.status.addresses[0].value}')"

curl --fail --show-error "http://${EXTERNAL_IP}/actuator/health"
```

## 16. 장애별 확인 명령

### Terraform Provider 또는 문법 오류

```bash
terraform -chdir=infra/environments/dev init -backend=false -reconfigure
terraform -chdir=infra/environments/dev validate
```

### NKS 노드가 NotReady

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get nodes -o wide
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" describe node 노드이름
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get pods -n kube-system
```

NCP 콘솔에서 NAT Gateway와 워커 Route Table의 기본 경로도 확인합니다.

### Argo CD Application이 OutOfSync 또는 Degraded

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  describe application blue-bank-gateway-dev -n argocd
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  describe application envoy-gateway -n argocd
```

### Gateway에 External IP가 없음

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get gateway -n blue-bank -o yaml
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get gatewayclass
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get svc -n envoy-gateway-system
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" logs \
  deployment/envoy-gateway -n envoy-gateway-system
```

Kubernetes가 생성한 Load Balancer는 NCP 콘솔에서 직접 수정하지 않습니다. Service 또는 Envoy Gateway 리소스를 수정합니다.

### Gateway 또는 Redis Pod가 시작하지 않음

```bash
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get events -n blue-bank --sort-by=.lastTimestamp
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" describe pod -n blue-bank -l app.kubernetes.io/name=blue-bank-gateway
kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" logs -n blue-bank deployment/blue-bank-gateway
```

`ImagePullBackOff`이면 NCR 이미지 이름·태그·인증을, Secret 오류이면 `blue-bank-gateway-secret`의 키 이름을 확인합니다.

## 17. 비용을 멈추는 안전한 삭제 순서

삭제는 복구가 어려우므로 대상 context와 Terraform Plan을 반드시 직접 확인합니다.

1. 대상 클러스터를 확인합니다.

   ```bash
   kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" cluster-info
   kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get nodes
   ```

2. Argo CD Application을 삭제하여 Kubernetes 생성 LB와 workload를 먼저 정리합니다.

   ```bash
   kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
     delete application blue-bank-gateway-dev envoy-gateway -n argocd
   ```

3. NCP 콘솔에서 Kubernetes 연동 Load Balancer가 삭제됐는지 확인합니다.
4. `terraform.tfvars`의 `return_protection`을 `false`로 바꿉니다.
5. 반납 보호 해제만 먼저 적용합니다.

   ```bash
   terraform -chdir=infra/environments/dev plan -out=disable-protection.tfplan
   terraform -chdir=infra/environments/dev apply disable-protection.tfplan
   ```

6. 전체 삭제 Plan을 만들고 리소스 범위를 검토합니다.

   ```bash
   terraform -chdir=infra/environments/dev plan -destroy -out=destroy.tfplan
   terraform -chdir=infra/environments/dev show destroy.tfplan
   ```

7. 검토한 Plan만 적용합니다.

   ```bash
   terraform -chdir=infra/environments/dev apply destroy.tfplan
   ```

8. NKS → NAT Gateway → Route/Subnet → VPC가 제거됐는지 NCP 콘솔에서 확인합니다.
9. Terraform state 버킷과 NCR/이미지 버킷은 기본적으로 보존합니다. 정말 필요할 때만 내용과 복구 가능성을 확인한 후 콘솔에서 별도 삭제합니다.
