# `infra`

Naver Cloud Platform 개발 인프라를 Terraform으로 생성하는 영역입니다.

> 현재 개발 클러스터는 NCP Console에서 이미 생성되어 있으므로 이 디렉터리의 Terraform을 바로 `apply`하지 않습니다. 기존 리소스를 import하거나 별도 환경을 Terraform으로 새로 만들 때만 사용합니다.

## 구성

- `modules/`: 재사용 가능한 Network/NKS 모듈
- `environments/dev/`: 개발 환경 Root Module과 backend 예제
- `scripts/`: Argo CD 부트스트랩과 클러스터 검증
- `tests/`: Terraform/Kustomize 정적 안전장치

## 사용 순서 (Terraform을 선택한 경우)

1. 기존 콘솔 리소스를 사용한다면 먼저 Terraform import 계획을 세웁니다.
2. 새 환경을 Terraform으로 생성하는 경우에만 NCP state 버킷, NCR, API 인증키를 준비합니다.
3. `environments/dev/backend.hcl`과 `terraform.tfvars`를 생성합니다.
4. `terraform init`, `validate`, `plan` 후 삭제/중복 생성이 없는지 검토한 Plan만 `apply`합니다.
5. kubeconfig를 발급한 뒤 `scripts/bootstrap-argocd.sh`와 `verify-dev.sh`를 실행합니다.

전체 절차는 [`docs/NCP_TERRAFORM_DEPLOYMENT.md`](../docs/NCP_TERRAFORM_DEPLOYMENT.md)를 참고하세요.
