# Network Module

개발 VPC 네트워크를 생성합니다.

생성 리소스:

- VPC `10.0.0.0/16`
- 워커 Private Subnet `10.0.10.0/24`
- Private/Public Load Balancer Subnet
- NAT Gateway Subnet
- 워커용 NAT 기본 경로
- 단일 Network ACL 규칙 묶음

독립 검증:

```bash
terraform -chdir=infra/modules/network init -backend=false
terraform -chdir=infra/modules/network validate
```

실제 생성은 이 모듈에서 직접 하지 말고 `infra/environments/dev`에서 수행합니다.
