# Dev Terraform Environment

한국 리전에 개발용 VPC와 NKS를 생성하는 Root Module입니다.

## 준비

```bash
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

실제 state 버킷, 공인 IP `/32`, NCR Endpoint를 입력하고 다음 환경변수를 설정합니다.

```bash
export NCLOUD_ACCESS_KEY="..."
export NCLOUD_SECRET_KEY="..."
export NCLOUD_REGION="KR"
export AWS_ACCESS_KEY_ID="$NCLOUD_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$NCLOUD_SECRET_KEY"
```

## 실행

```bash
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out=dev.tfplan
terraform show dev.tfplan
terraform apply dev.tfplan
```

실제 `backend.hcl`, `terraform.tfvars`, state, Plan, kubeconfig는 Git에 커밋하지 않습니다.
