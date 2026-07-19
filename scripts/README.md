# `scripts`

이 폴더는 더 이상 배포 진입점이 아닙니다. 기존 Docker 기반 관리 스크립트는 Kubernetes 전환과 함께 제거했습니다.

NCP NKS 배포는 [`infra/scripts`](../infra/scripts/README.md)의 다음 스크립트를 사용합니다.

```bash
./infra/scripts/bootstrap-argocd.sh
./infra/scripts/verify-dev.sh
```

Kubernetes 매니페스트는 [`k8s`](../k8s/README.md), Argo CD Application은 [`argocd`](../argocd/README.md)에서 관리합니다.
