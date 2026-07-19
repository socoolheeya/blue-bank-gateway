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

### 전체 아키텍처

```mermaid
flowchart TB
    user[Client / Internet]

    subgraph ncp[Naver Cloud Platform - KR]
        lb[Public Load Balancer]

        subgraph nks[NKS Kubernetes Cluster - Single Zone]
            eg[Envoy Gateway\nGateway API]

            subgraph ns[Namespace: blue-bank]
                gw[Spring Cloud Gateway\nDeployment: 2 replicas]
                redis[(Redis StatefulSet\nPVC)]

                account[account Service\nKubernetes DNS]
                deposit[deposit Service\nKubernetes DNS]
                loan[loan Service\nKubernetes DNS]
                card[card Service\nKubernetes DNS]
            end
        end

        nat[NAT Gateway]
        worker[Private Worker Subnet]
    end

    user -->|HTTP :80| lb
    lb --> eg
    eg -->|Gateway / HTTPRoute| gw

    gw -->|JWT / Rate Limit| redis
    gw -->|/api/accounts| account
    gw -->|/api/deposits| deposit
    gw -->|/api/loans| loan
    gw -->|/api/cards| card

    worker -. outbound image pulls .-> nat
    nat -.-> ncp

    argocd[Argo CD\nGitOps Controller] -. sync .-> nks
    git[Git Repository\nKustomize + Applications] --> argocd

    classDef edge fill:#dbeafe,stroke:#2563eb,color:#111827
    classDef app fill:#dcfce7,stroke:#16a34a,color:#111827
    classDef data fill:#fef3c7,stroke:#d97706,color:#111827
    classDef ops fill:#f3e8ff,stroke:#9333ea,color:#111827

    class user,lb,eg edge
    class gw,account,deposit,loan,card app
    class redis data
    class argocd,git ops
```

### 요청 흐름

1. Client가 NCP Public Load Balancer의 HTTP 포트로 요청합니다.
2. Envoy Gateway가 Gateway API `HTTPRoute`에 따라 Spring Cloud Gateway로 전달합니다.
3. Spring Cloud Gateway가 JWT 인증, Rate Limit, Circuit Breaker와 업무별 필터를 적용합니다.
4. 업무 요청은 Eureka 없이 Kubernetes Service DNS로 `account`, `deposit`, `loan`, `card`에 전달됩니다.
5. Rate Limit 상태와 Gateway 세션 데이터는 Redis Service를 사용합니다.

### 배포 흐름

```mermaid
flowchart LR
    tf[Terraform] --> ncp[NCP VPC / NAT / NKS]
    ncp --> kube[kubeconfig]
    kube --> argo[Argo CD]
    repo[Git: k8s + argocd] --> argo
    argo --> envoy[Envoy Gateway]
    argo --> app[Gateway + Redis]
    ci[CI: Docker Build / NCR Push] --> registry[Naver Container Registry]
    registry --> app
```

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
