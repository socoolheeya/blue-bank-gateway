# Dev Overlay

개발 Kubernetes 배포입니다.

```bash
kubectl kustomize k8s/overlays/dev
```

NCR Endpoint와 immutable image tag를 `kustomization.yaml`에 설정한 뒤 Git에 Push하면 Argo CD가 동기화합니다. 배포 전 `blue-bank-gateway-secret`에 `JWT_SECRET`, `REDIS_PASSWORD`가 있어야 합니다.
