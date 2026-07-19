# `infra/scripts`

NKS 생성 이후 Kubernetes GitOps를 부트스트랩하고 상태를 검증하는 Shell Script입니다.

## Argo CD 설치

필수 환경변수:

```bash
export KUBECONFIG=/secure/path/blue-bank-dev.yaml
export KUBE_CONTEXT="nks_KR_blue-bank-dev"
export GIT_REPOSITORY_URL="https://github.com/org/blue-bank-gateway.git"
./infra/scripts/bootstrap-argocd.sh
```

스크립트는 Argo CD Helm Chart, Envoy Gateway Application, Gateway Application을 적용합니다.

## 검증

```bash
./infra/scripts/verify-dev.sh
```

노드 2대, Argo CD, Envoy Gateway, Gateway, Redis, Public Load Balancer IP, HTTP health 응답을 검사합니다.
