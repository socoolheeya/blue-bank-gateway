# `k8s`

Argo CD가 동기화하는 Kubernetes 매니페스트입니다.

- `base/`: 공통 Gateway, Redis, Gateway API 리소스
- `overlays/dev/`: 개발 NCR 이미지, in-cluster Redis, HTTP
- `overlays/prod/`: 운영 리소스 크기와 외부 Redis 설정

렌더링:

```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/prod
```

운영 적용은 직접 `kubectl apply`하기보다 Argo CD Application을 통해 수행합니다. GatewayClass는 cluster-scoped이므로 Namespace를 지정하지 않습니다.
