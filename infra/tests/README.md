# `infra/tests`

Terraform과 Kubernetes 설정의 정적 회귀 검사입니다.

```bash
bash infra/tests/static.sh
```

검사 항목:

- 필수 Terraform/스크립트 파일 존재
- NCP Provider와 핵심 리소스 존재
- 하드코딩 인증키·state·kubeconfig 미추적
- 레거시 서비스 디스커버리/프록시 재도입 방지
- Kustomize 렌더 결과에서 GatewayClass는 cluster-scoped인지 확인
- namespaced 리소스는 `blue-bank`인지 확인
