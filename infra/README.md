# `infra`

Naver Cloud Platform 개발 인프라를 Terraform으로 생성하는 영역입니다.

## 구성

- `modules/`: 재사용 가능한 Network/NKS 모듈
- `environments/dev/`: 개발 환경 Root Module과 backend 예제
- `scripts/`: Argo CD 부트스트랩과 클러스터 검증
- `tests/`: Terraform/Kustomize 정적 안전장치

## 사용 순서

1. NCP 콘솔에서 state 버킷, NCR, API 인증키를 준비합니다.
2. `environments/dev/backend.hcl`과 `terraform.tfvars`를 생성합니다.
3. `terraform init`, `validate`, `plan` 후 승인한 Plan만 `apply`합니다.
4. kubeconfig를 발급한 뒤 `scripts/bootstrap-argocd.sh`와 `verify-dev.sh`를 실행합니다.

전체 절차는 [`docs/NCP_TERRAFORM_DEPLOYMENT.md`](../docs/NCP_TERRAFORM_DEPLOYMENT.md)를 참고하세요.
