# `infra/modules`

환경에 종속되지 않는 Terraform 모듈입니다. 인증키나 실제 환경값을 이 폴더에 넣지 않습니다.

- `network/`: VPC, Subnet, Network ACL, NAT Gateway, Route Table
- `nks/`: NKS 1.34 클러스터, 로그인 키, 고정 노드 풀

각 모듈은 `versions.tf`에 `NaverCloudPlatform/ncloud` Provider를 직접 선언하므로 독립적으로 `terraform validate`할 수 있습니다.
