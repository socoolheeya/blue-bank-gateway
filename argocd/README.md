# `argocd`

Argo CD가 관리할 Application 선언입니다.

- `envoy-gateway-application.yaml`: Envoy Gateway Helm Chart 1.8.2
- `blue-bank-gateway-dev-application.yaml`: `k8s/overlays/dev` 동기화

`blue-bank-gateway-dev-application.yaml`의 `GIT_REPOSITORY_URL`은 bootstrap 스크립트가 실행 시 치환합니다. 실제 Secret과 private repository 인증정보는 YAML에 넣지 않습니다.

```bash
kubectl apply -f argocd/envoy-gateway-application.yaml
kubectl apply -f argocd/blue-bank-gateway-dev-application.yaml
```

일반적으로는 `infra/scripts/bootstrap-argocd.sh`를 사용하세요.
