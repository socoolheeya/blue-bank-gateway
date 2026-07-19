# Blue Bank Gateway

Spring Cloud Gateway 기반 Blue Bank API Gateway입니다. 현재 배포 아키텍처는 Naver Cloud Platform NKS, Kubernetes Service/DNS, Envoy Gateway, Argo CD, Redis입니다.

## 아키텍처

```text
Internet
  -> NCP Public Load Balancer
  -> Envoy Gateway
  -> blue-bank-gateway Service
  -> Spring Cloud Gateway
  -> account/deposit/loan/card Kubernetes Service DNS
```

Spring Cloud Gateway는 JWT 인증, 업무별 라우팅 필터, Redis Rate Limit, Circuit Breaker와 Fallback을 담당합니다. 서비스 검색은 Kubernetes Service/DNS로 처리합니다.

## 폴더 안내

- [`infra/`](infra/README.md): NCP VPC/NKS Terraform과 부트스트랩
- [`k8s/`](k8s/README.md): Kubernetes Base와 Dev/Prod Overlay
- [`argocd/`](argocd/README.md): Argo CD Application
- [`docs/`](docs/README.md): 설계·배포·운영 문서
- [`docker/`](docker/README.md): 이미지 빌드 설정
- [`test-utils/`](test-utils/README.md): 테스트 보조 도구

## 로컬 애플리케이션 빌드

```bash
./gradlew clean test build
```

## NCP 개발 환경 배포

전체 절차는 [NCP NKS Terraform 배포 가이드](docs/NCP_TERRAFORM_DEPLOYMENT.md)를 따릅니다.

```bash
cd infra/environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

NCP 인증키, 실제 backend 설정, `terraform.tfvars`, kubeconfig, Kubernetes Secret은 Git에 저장하지 않습니다.

## Kubernetes 매니페스트 확인

```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/prod
```

클러스터가 생성된 뒤:

```bash
./infra/scripts/bootstrap-argocd.sh
./infra/scripts/verify-dev.sh
```

## 이미지 빌드와 NCR Push

```bash
export NCR_ENDPOINT="registry.kr.ncr.ntruss.com"
export IMAGE_TAG="dev-$(git rev-parse --short HEAD)"

docker build -t "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG" .
docker push "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG"
```

이후 `k8s/overlays/dev/kustomization.yaml`의 이미지 태그를 갱신해 Git에 Push하면 Argo CD가 배포합니다.

## 검증

```bash
bash infra/tests/static.sh
terraform fmt -check -recursive infra
./gradlew clean test build
```

실제 클러스터 검증은 `infra/scripts/verify-dev.sh`가 노드, Argo CD, Envoy Gateway, Gateway, Redis와 외부 HTTP 응답을 확인합니다.
