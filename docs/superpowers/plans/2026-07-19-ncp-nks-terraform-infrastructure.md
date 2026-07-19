# NCP NKS Terraform 인프라 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**목표:** NCP 한국 리전에 개발용 VPC, Subnet, NAT Gateway, NKS 1.34 클러스터와 노드 풀을 Terraform으로 생성하고 기존 Argo CD·Envoy Gateway·Spring Cloud Gateway 배포를 부트스트랩한다.

**아키텍처:** `infra/modules/network`와 `infra/modules/nks`를 독립 모듈로 만들고 `infra/environments/dev` Root Module이 이를 조합한다. Terraform은 클라우드 인프라까지만 관리하며 Kubernetes 리소스는 Argo CD가 Git에서 동기화한다. Terraform state 버킷과 NCR은 콘솔에서 먼저 만들고 실제 인증키·backend 설정·환경 변수 파일은 Git에서 제외한다.

**기술 스택:** Terraform 1.10 이상, NaverCloudPlatform/ncloud Provider 4.0.5, NCP VPC/NAT Gateway/NKS 1.34/NCR/Object Storage, Kubernetes, Helm 3, Argo CD, Envoy Gateway 1.8.2, Bash

## 전역 제약 조건

- 리전은 `KR`, 기본 Zone은 `KR-1`, 개발 클러스터는 Single Zone이다.
- VPC는 `10.0.0.0/16`이다.
- 워커 Subnet은 `10.0.10.0/24`, Private LB Subnet은 `10.0.20.0/24`, Public LB Subnet은 `10.0.30.0/24`, NAT Gateway Subnet은 `10.0.40.0/24`이다.
- NKS는 KVM, Kubernetes 1.34, Cilium을 사용한다.
- 노드 풀은 2 vCPU, 8 GB, 100 GB 노드 2대이며 오토스케일링은 비활성화한다.
- NKS API ACL 기본 동작은 `deny`이고 `allowed_api_cidrs`는 비어 있을 수 없으며 `0.0.0.0/0`을 금지한다.
- NKS 워커 노드에는 Public IP를 부여하지 않는다.
- NCP 인증키, backend 실제 설정, Terraform state/plan, kubeconfig, Kubernetes Secret은 Git에 저장하지 않는다.
- Eureka와 Nginx를 다시 추가하지 않는다.
- 애플리케이션은 Terraform이 아니라 Argo CD가 관리한다.
- 모든 작업 완료 전 `./gradlew clean test build`가 성공해야 한다.

---

## 파일 구조와 책임

```text
infra/
  modules/
    network/
      main.tf                 # VPC, NACL, Subnet, NAT, Route 리소스
      variables.tf            # 네트워크 입력과 CIDR 검증
      outputs.tf              # NKS 모듈이 소비할 VPC/Subnet 번호
    nks/
      main.tf                 # NKS 조회 Data Source, 클러스터, 노드 풀
      variables.tf            # 클러스터/노드/API ACL 입력 검증
      outputs.tf              # UUID, Endpoint, 노드 풀 정보
  environments/
    dev/
      backend.tf              # 비어 있는 S3 backend 선언
      providers.tf            # Terraform/ncloud 버전과 Provider 구성
      main.tf                 # network/nks 모듈 조합
      variables.tf            # Dev Root 입력
      outputs.tf              # 운영자가 사용할 최종 출력
      backend.hcl.example     # NCP Object Storage backend 예시
      terraform.tfvars.example # CIDR/API/NCR 비밀 없는 예시
  scripts/
    bootstrap-argocd.sh       # 명시한 context에 Argo CD 및 Applications 설치
    verify-dev.sh             # NKS/Argo/Envoy/Gateway/Redis 검증
  tests/
    static.sh                 # 비밀·필수 리소스·위험 설정 정적 검사
docs/
  NCP_TERRAFORM_DEPLOYMENT.md # 콘솔 준비부터 배포/검증/삭제까지 실행 안내
```

---

### Task 1: Terraform 안전장치와 정적 검증 기반

**Files:**
- Modify: `.gitignore`
- Create: `infra/tests/static.sh`

**Interfaces:**
- Consumes: 전역 제약 조건과 향후 생성될 `infra/` 구조
- Produces: `bash infra/tests/static.sh` 검증 명령과 비밀 파일 Git 제외 규칙

- [ ] **Step 1: 현재 상태와 도구 버전을 확인한다**

Run:

```bash
git status --short
terraform version
kubectl version --client
helm version --short
```

Expected:

- 사용자 변경이 있으면 목록을 기록하고 덮어쓰지 않는다.
- Terraform은 1.10 이상이어야 한다.
- `kubectl`과 Helm 3가 실행 가능해야 한다.

- [ ] **Step 2: 실제 Terraform 파일이 아직 없어 정적 검사가 실패하는 테스트를 작성한다**

Create `infra/tests/static.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

required_files=(
  infra/modules/network/main.tf
  infra/modules/network/variables.tf
  infra/modules/network/outputs.tf
  infra/modules/nks/main.tf
  infra/modules/nks/variables.tf
  infra/modules/nks/outputs.tf
  infra/environments/dev/backend.tf
  infra/environments/dev/providers.tf
  infra/environments/dev/main.tf
  infra/environments/dev/variables.tf
  infra/environments/dev/outputs.tf
  infra/environments/dev/backend.hcl.example
  infra/environments/dev/terraform.tfvars.example
  infra/scripts/bootstrap-argocd.sh
  infra/scripts/verify-dev.sh
)

for file in "${required_files[@]}"; do
  test -f "$file" || { echo "missing required file: $file" >&2; exit 1; }
done

rg -q 'resource "ncloud_vpc"' infra/modules/network/main.tf
rg -q 'resource "ncloud_nat_gateway"' infra/modules/network/main.tf
rg -q 'resource "ncloud_route"' infra/modules/network/main.tf
rg -q 'resource "ncloud_nks_cluster"' infra/modules/nks/main.tf
rg -q 'resource "ncloud_nks_node_pool"' infra/modules/nks/main.tf
rg -q 'ip_acl_default_action[[:space:]]*=[[:space:]]*"deny"' infra/modules/nks/main.tf

if rg -n '(NCLOUD_ACCESS_KEY|NCLOUD_SECRET_KEY)[[:space:]]*=[[:space:]]*"[^"$]+' infra; then
  echo "hard-coded NCP credential detected" >&2
  exit 1
fi

if git ls-files | rg '(^|/)(backend\.hcl|terraform\.tfvars|[^/]+\.tfstate(\..*)?|[^/]+\.tfplan|kubeconfig)$'; then
  echo "sensitive Terraform or kubeconfig file is tracked" >&2
  exit 1
fi

if rg -n -i 'eureka|nginx' infra; then
  echo "Eureka or Nginx must not be part of the NKS infrastructure" >&2
  exit 1
fi

echo "Terraform static checks passed"
```

- [ ] **Step 3: 테스트가 예상대로 실패하는지 확인한다**

Run:

```bash
bash infra/tests/static.sh
```

Expected: `missing required file: infra/modules/network/main.tf`로 FAIL.

- [ ] **Step 4: Terraform 비밀·상태 파일 제외 규칙을 추가한다**

Append to `.gitignore`:

```gitignore

### Terraform ###
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
**/backend.hcl
**/terraform.tfvars
**/kubeconfig
```

- [ ] **Step 5: Shell 문법을 확인한다**

Run:

```bash
bash -n infra/tests/static.sh
```

Expected: 출력 없이 exit code 0.

- [ ] **Step 6: 안전장치만 먼저 커밋한다**

```bash
git add .gitignore infra/tests/static.sh
git commit -m "test: add Terraform infrastructure safety checks"
```

---

### Task 2: VPC, Subnet, NACL, NAT Gateway, Route 구현

**Files:**
- Create: `infra/modules/network/variables.tf`
- Create: `infra/modules/network/main.tf`
- Create: `infra/modules/network/outputs.tf`

**Interfaces:**
- Consumes: `name_prefix`, `zone`, VPC/Subnet CIDR 5개
- Produces: `vpc_no`, `worker_subnet_no`, `lb_private_subnet_no`, `lb_public_subnet_no`, `nat_gateway_no`, `nat_public_ip`

- [ ] **Step 1: Network Module 입력과 검증을 작성한다**

Create `infra/modules/network/variables.tf`:

```hcl
variable "name_prefix" {
  description = "모든 네트워크 리소스 이름의 접두사"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "name_prefix는 영문 소문자로 시작하는 3~20자의 소문자, 숫자, 하이픈이어야 합니다."
  }
}

variable "zone" {
  description = "Single Zone NKS를 생성할 Zone"
  type        = string
  default     = "KR-1"
  validation {
    condition     = can(regex("^KR-[1-3]$", var.zone))
    error_message = "zone은 KR-1, KR-2, KR-3 중 하나여야 합니다."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "worker_subnet_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "lb_private_subnet_cidr" {
  type    = string
  default = "10.0.20.0/24"
}

variable "lb_public_subnet_cidr" {
  type    = string
  default = "10.0.30.0/24"
}

variable "nat_subnet_cidr" {
  type    = string
  default = "10.0.40.0/24"
}
```

- [ ] **Step 2: VPC와 전용 Network ACL을 구현한다**

Start `infra/modules/network/main.tf` with:

```hcl
resource "ncloud_vpc" "this" {
  name            = "${var.name_prefix}-vpc"
  ipv4_cidr_block = var.vpc_cidr
}

resource "ncloud_network_acl" "nks" {
  vpc_no      = ncloud_vpc.this.id
  name        = "${var.name_prefix}-nks-nacl"
  description = "NACL for Blue Bank NKS subnets"
}

resource "ncloud_network_acl_rule" "nks" {
  network_acl_no = ncloud_network_acl.nks.id

  inbound {
    priority    = 100
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
    port_range  = "1-65535"
  }
  inbound {
    priority    = 110
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
    port_range  = "1-65535"
  }
  inbound {
    priority    = 120
    protocol    = "ICMP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
  }
  inbound {
    priority    = 130
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "80"
  }
  inbound {
    priority    = 140
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1024-65535"
  }
  inbound {
    priority    = 150
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1024-65535"
  }

  outbound {
    priority    = 100
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1-65535"
  }
  outbound {
    priority    = 110
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1-65535"
  }
  outbound {
    priority    = 120
    protocol    = "ICMP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
  }
}
```

NCP Provider는 한 NACL에 여러 `ncloud_network_acl_rule` 리소스를 만들면 마지막 규칙이 앞 규칙을 덮을 수 있으므로 반드시 단일 리소스 안에 모든 규칙을 둔다.

- [ ] **Step 3: 목적별 Subnet 4개를 구현한다**

Append to `infra/modules/network/main.tf`:

```hcl
resource "ncloud_subnet" "worker" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.worker_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PRIVATE"
  name           = "${var.name_prefix}-worker-sbn"
  usage_type     = "GEN"
}

resource "ncloud_subnet" "lb_private" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.lb_private_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PRIVATE"
  name           = "${var.name_prefix}-lb-private-sbn"
  usage_type     = "LOADB"
}

resource "ncloud_subnet" "lb_public" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.lb_public_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PUBLIC"
  name           = "${var.name_prefix}-lb-public-sbn"
  usage_type     = "LOADB"
}

resource "ncloud_subnet" "nat" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.nat_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PUBLIC"
  name           = "${var.name_prefix}-nat-sbn"
  usage_type     = "NATGW"
}
```

- [ ] **Step 4: NAT Gateway와 워커 Route Table을 구현한다**

Append to `infra/modules/network/main.tf`:

```hcl
resource "ncloud_nat_gateway" "this" {
  vpc_no      = ncloud_vpc.this.id
  subnet_no   = ncloud_subnet.nat.id
  zone        = var.zone
  name        = "${var.name_prefix}-natgw"
  description = "Outbound internet for private NKS workers"
}

resource "ncloud_route_table" "worker" {
  vpc_no                = ncloud_vpc.this.id
  supported_subnet_type = "PRIVATE"
  name                   = "${var.name_prefix}-worker-rt"
  description            = "Private NKS worker routes"
}

resource "ncloud_route_table_association" "worker" {
  route_table_no = ncloud_route_table.worker.id
  subnet_no      = ncloud_subnet.worker.id
}

resource "ncloud_route" "worker_default" {
  route_table_no         = ncloud_route_table.worker.id
  destination_cidr_block = "0.0.0.0/0"
  target_type            = "NATGW"
  target_name            = ncloud_nat_gateway.this.name
  target_no              = ncloud_nat_gateway.this.id
}
```

- [ ] **Step 5: Network Module 출력을 작성한다**

Create `infra/modules/network/outputs.tf`:

```hcl
output "vpc_no" {
  value = ncloud_vpc.this.id
}

output "worker_subnet_no" {
  value = ncloud_subnet.worker.id
}

output "lb_private_subnet_no" {
  value = ncloud_subnet.lb_private.id
}

output "lb_public_subnet_no" {
  value = ncloud_subnet.lb_public.id
}

output "nat_gateway_no" {
  value = ncloud_nat_gateway.this.id
}

output "nat_public_ip" {
  value = ncloud_nat_gateway.this.public_ip
}
```

- [ ] **Step 6: 포맷과 모듈 초기화를 검증한다**

Run:

```bash
terraform fmt -recursive infra/modules/network
terraform -chdir=infra/modules/network init -backend=false
terraform -chdir=infra/modules/network validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 7: 네트워크 모듈을 커밋한다**

```bash
git add infra/modules/network
git commit -m "feat: provision NCP development network"
```

---

### Task 3: NKS 1.34 클러스터와 노드 풀 구현

**Files:**
- Create: `infra/modules/nks/variables.tf`
- Create: `infra/modules/nks/main.tf`
- Create: `infra/modules/nks/outputs.tf`

**Interfaces:**
- Consumes: Task 2의 VPC/Subnet 번호, Zone, API CIDR, 노드 사양
- Produces: `cluster_uuid`, `cluster_endpoint`, `node_pool_name`, `node_instance_numbers`

- [ ] **Step 1: NKS 입력 변수와 보안 검증을 작성한다**

Create `infra/modules/nks/variables.tf`:

```hcl
variable "name_prefix" {
  type = string
}
variable "zone" {
  type = string
}
variable "vpc_no" {
  type = string
}
variable "worker_subnet_no" {
  type = string
}
variable "lb_private_subnet_no" {
  type = string
}
variable "lb_public_subnet_no" {
  type = string
}

variable "allowed_api_cidrs" {
  description = "NKS Public API 접근 허용 CIDR"
  type        = set(string)
  validation {
    condition = (
      length(var.allowed_api_cidrs) > 0 &&
      !contains(var.allowed_api_cidrs, "0.0.0.0/0") &&
      alltrue([for cidr in var.allowed_api_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "allowed_api_cidrs에는 유효한 CIDR을 하나 이상 입력해야 하며 0.0.0.0/0은 금지됩니다."
  }
}

variable "node_count" {
  type    = number
  default = 2
  validation {
    condition     = var.node_count >= 2 && var.node_count <= 5
    error_message = "개발 노드 수는 2~5 사이여야 합니다."
  }
}

variable "node_storage_size" {
  type    = number
  default = 100
  validation {
    condition     = var.node_storage_size >= 100 && var.node_storage_size <= 2000
    error_message = "노드 스토리지는 100~2000GB 사이여야 합니다."
  }
}

variable "return_protection" {
  type    = bool
  default = true
}
```

- [ ] **Step 2: NKS 버전·이미지·서버 사양 Data Source를 구현한다**

Start `infra/modules/nks/main.tf` with:

```hcl
data "ncloud_nks_versions" "selected" {
  hypervisor_code = "KVM"
  filter {
    name   = "value"
    values = ["1.34"]
    regex  = true
  }
}

data "ncloud_nks_server_images" "ubuntu" {
  hypervisor_code = "KVM"
  filter {
    name   = "label"
    values = ["ubuntu-22.04"]
    regex  = true
  }
}

data "ncloud_nks_server_products" "standard_2c_8g" {
  software_code = data.ncloud_nks_server_images.ubuntu.images[0].value
  zone          = var.zone

  filter {
    name   = "product_type"
    values = ["STAND"]
  }
  filter {
    name   = "cpu_count"
    values = ["2"]
  }
  filter {
    name   = "memory_size"
    values = ["8GB"]
  }
}

resource "ncloud_login_key" "nks" {
  key_name = "${var.name_prefix}-nks-key"
}
```

- [ ] **Step 3: 기본 차단 API ACL을 포함한 NKS 클러스터를 구현한다**

Append to `infra/modules/nks/main.tf`:

```hcl
resource "ncloud_nks_cluster" "this" {
  hypervisor_code      = "KVM"
  cluster_type         = "SVR.VNKS.STAND.C004.M016.G003"
  k8s_version          = data.ncloud_nks_versions.selected.versions[0].value
  login_key_name       = ncloud_login_key.nks.key_name
  name                 = "${var.name_prefix}-nks"
  zone                 = var.zone
  vpc_no               = var.vpc_no
  subnet_no_list       = [var.worker_subnet_no]
  lb_private_subnet_no = var.lb_private_subnet_no
  lb_public_subnet_no  = var.lb_public_subnet_no
  public_network       = false
  kube_network_plugin  = "cilium"
  return_protection    = var.return_protection

  ip_acl_default_action = "deny"
  dynamic "ip_acl" {
    for_each = var.allowed_api_cidrs
    content {
      action  = "allow"
      address = ip_acl.value
      comment = "Terraform-managed NKS API access"
    }
  }

  lifecycle {
    precondition {
      condition     = length(data.ncloud_nks_versions.selected.versions) == 1
      error_message = "KVM용 Kubernetes 1.34 버전을 정확히 하나 조회해야 합니다."
    }
  }
}
```

`public_network = false`는 워커 노드를 Private Network에 생성한다. API Public Endpoint 통제는 `ip_acl_default_action`과 `ip_acl`이 담당한다.

- [ ] **Step 4: 고정 크기 노드 풀을 구현한다**

Append to `infra/modules/nks/main.tf`:

```hcl
resource "ncloud_nks_node_pool" "default" {
  cluster_uuid     = ncloud_nks_cluster.this.uuid
  node_pool_name   = "${var.name_prefix}-default"
  node_count       = var.node_count
  software_code    = data.ncloud_nks_server_images.ubuntu.images[0].value
  server_spec_code = data.ncloud_nks_server_products.standard_2c_8g.products[0].value
  storage_size     = var.node_storage_size
  subnet_no_list   = [var.worker_subnet_no]

  autoscale {
    enabled = false
    min     = var.node_count
    max     = var.node_count
  }

  lifecycle {
    precondition {
      condition     = length(data.ncloud_nks_server_products.standard_2c_8g.products) > 0
      error_message = "선택 Zone에서 2 vCPU/8GB NKS 서버 상품을 찾지 못했습니다."
    }
  }
}
```

- [ ] **Step 5: NKS 출력을 작성한다**

Create `infra/modules/nks/outputs.tf`:

```hcl
output "cluster_uuid" {
  value = ncloud_nks_cluster.this.uuid
}

output "cluster_endpoint" {
  value = ncloud_nks_cluster.this.endpoint
}

output "node_pool_name" {
  value = ncloud_nks_node_pool.default.node_pool_name
}

output "node_instance_numbers" {
  value = ncloud_nks_node_pool.default.instance_no
}
```

- [ ] **Step 6: 모듈 포맷과 구성을 검증한다**

Run:

```bash
terraform fmt -recursive infra/modules/nks
terraform -chdir=infra/modules/nks init -backend=false
terraform -chdir=infra/modules/nks validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 7: NKS 모듈을 커밋한다**

```bash
git add infra/modules/nks
git commit -m "feat: provision protected NKS development cluster"
```

---

### Task 4: Dev Root Module과 Object Storage backend 연결

**Files:**
- Create: `infra/environments/dev/backend.tf`
- Create: `infra/environments/dev/providers.tf`
- Create: `infra/environments/dev/variables.tf`
- Create: `infra/environments/dev/main.tf`
- Create: `infra/environments/dev/outputs.tf`
- Create: `infra/environments/dev/backend.hcl.example`
- Create: `infra/environments/dev/terraform.tfvars.example`

**Interfaces:**
- Consumes: 환경변수 `NCLOUD_ACCESS_KEY`, `NCLOUD_SECRET_KEY`, `NCLOUD_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`; 콘솔에서 만든 state 버킷과 NCR Endpoint
- Produces: 한 번의 `terraform plan/apply`로 Dev network와 NKS 생성, 운영자용 output

- [ ] **Step 1: Terraform과 Provider 버전을 고정한다**

Create `infra/environments/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {}
}
```

Create `infra/environments/dev/providers.tf`:

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = "4.0.5"
    }
  }
}

provider "ncloud" {
  region      = var.region
  site        = "public"
  support_vpc = true
}
```

- [ ] **Step 2: Dev Root 입력과 교차 변수 검증을 작성한다**

Create `infra/environments/dev/variables.tf`:

```hcl
variable "region" {
  type    = string
  default = "KR"
  validation {
    condition     = var.region == "KR"
    error_message = "현재 개발 인프라는 KR 리전만 지원합니다."
  }
}

variable "zone" {
  type    = string
  default = "KR-1"
}

variable "name_prefix" {
  type    = string
  default = "blue-bank-dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "worker_subnet_cidr" {
  type    = string
  default = "10.0.10.0/24"
}
variable "lb_private_subnet_cidr" {
  type    = string
  default = "10.0.20.0/24"
}
variable "lb_public_subnet_cidr" {
  type    = string
  default = "10.0.30.0/24"
}
variable "nat_subnet_cidr" {
  type    = string
  default = "10.0.40.0/24"
}

variable "allowed_api_cidrs" {
  type        = set(string)
  description = "Terraform 실행 PC/CI의 공인 CIDR 목록. 단일 IP는 /32 사용"
}

variable "ncr_endpoint" {
  type        = string
  description = "콘솔에서 생성한 NCR Public Endpoint"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}\\.kr\\.ncr\\.ntruss\\.com$", var.ncr_endpoint))
    error_message = "ncr_endpoint는 <registry>.kr.ncr.ntruss.com 형식이어야 합니다."
  }
}

variable "return_protection" {
  type    = bool
  default = true
}
```

- [ ] **Step 3: Network와 NKS 모듈을 조합한다**

Create `infra/environments/dev/main.tf`:

```hcl
module "network" {
  source = "../../modules/network"

  name_prefix           = var.name_prefix
  zone                  = var.zone
  vpc_cidr              = var.vpc_cidr
  worker_subnet_cidr    = var.worker_subnet_cidr
  lb_private_subnet_cidr = var.lb_private_subnet_cidr
  lb_public_subnet_cidr = var.lb_public_subnet_cidr
  nat_subnet_cidr       = var.nat_subnet_cidr
}

module "nks" {
  source = "../../modules/nks"

  name_prefix             = var.name_prefix
  zone                    = var.zone
  vpc_no                  = module.network.vpc_no
  worker_subnet_no        = module.network.worker_subnet_no
  lb_private_subnet_no    = module.network.lb_private_subnet_no
  lb_public_subnet_no     = module.network.lb_public_subnet_no
  allowed_api_cidrs       = var.allowed_api_cidrs
  node_count              = 2
  node_storage_size       = 100
  return_protection       = var.return_protection
}
```

- [ ] **Step 4: 운영자가 사용할 Root 출력을 작성한다**

Create `infra/environments/dev/outputs.tf`:

```hcl
output "vpc_no" { value = module.network.vpc_no }
output "worker_subnet_no" { value = module.network.worker_subnet_no }
output "nat_public_ip" { value = module.network.nat_public_ip }
output "cluster_uuid" { value = module.nks.cluster_uuid }
output "cluster_endpoint" { value = module.nks.cluster_endpoint }
output "node_pool_name" { value = module.nks.node_pool_name }
output "ncr_endpoint" { value = var.ncr_endpoint }
```

- [ ] **Step 5: 실제 값이 없는 backend 예제 파일을 작성한다**

Create `infra/environments/dev/backend.hcl.example`:

```hcl
bucket = "blue-bank-tfstate-account-id"
key    = "blue-bank/dev/terraform.tfstate"
region = "kr-standard"

endpoints = {
  s3 = "https://kr.object.ncloudstorage.com"
}

use_path_style              = true
skip_credentials_validation = true
skip_region_validation      = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
skip_s3_checksum            = true
```

NCP Object Storage는 S3 호환 Endpoint를 사용하지만 AWS STS/IAM API가 아니므로 검증 생략 옵션이 필요하다. NCP Object Storage에서 S3 lockfile 조건부 쓰기 호환성을 확인하기 전까지 `use_lockfile`을 켜지 않고 한 번에 한 명/한 Pipeline만 Apply한다.

- [ ] **Step 6: Dev 변수 예제를 작성한다**

Create `infra/environments/dev/terraform.tfvars.example`:

```hcl
region      = "KR"
zone        = "KR-1"
name_prefix = "blue-bank-dev"

vpc_cidr               = "10.0.0.0/16"
worker_subnet_cidr     = "10.0.10.0/24"
lb_private_subnet_cidr = "10.0.20.0/24"
lb_public_subnet_cidr  = "10.0.30.0/24"
nat_subnet_cidr        = "10.0.40.0/24"

allowed_api_cidrs = ["203.0.113.10/32"]
ncr_endpoint       = "blue-bank-dev.kr.ncr.ntruss.com"
return_protection  = true
```

`203.0.113.10/32`는 문서용 주소이므로 사용자가 자신의 실제 공인 IP `/32`로 바꿔야 한다.

- [ ] **Step 7: Local backend로 전체 구성을 먼저 검증한다**

Run:

```bash
terraform fmt -recursive infra
terraform -chdir=infra/environments/dev init -backend=false
terraform -chdir=infra/environments/dev validate
bash infra/tests/static.sh
```

Expected:

- `Success! The configuration is valid.`
- `Terraform static checks passed`

- [ ] **Step 8: Dev Root Module을 커밋한다**

```bash
git add infra/environments/dev
git commit -m "feat: compose NCP development Terraform environment"
```

---

### Task 5: Argo CD 부트스트랩과 배포 검증 스크립트

**Files:**
- Create: `infra/scripts/bootstrap-argocd.sh`
- Create: `infra/scripts/verify-dev.sh`
- Modify: `argocd/blue-bank-gateway-dev-application.yaml`

**Interfaces:**
- Consumes: `KUBECONFIG`, `KUBE_CONTEXT`, `GIT_REPOSITORY_URL`, 기존 `argocd/*.yaml`
- Produces: Argo CD 설치/Applications 적용, 배포 상태와 External IP 검증

- [ ] **Step 1: Application의 명시적 토큰이 없으면 현재 bootstrap이 불가능함을 확인한다**

Run:

```bash
rg -n 'GIT_REPOSITORY_URL' argocd/blue-bank-gateway-dev-application.yaml
```

Expected: 치환해야 할 토큰 한 건 출력.

- [ ] **Step 2: 안전한 Argo CD bootstrap 스크립트를 작성한다**

Create `infra/scripts/bootstrap-argocd.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG 경로를 설정하세요}"
: "${KUBE_CONTEXT:?KUBE_CONTEXT를 설정하세요}"
: "${GIT_REPOSITORY_URL:?GIT_REPOSITORY_URL을 설정하세요}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" cluster-info >/dev/null
kubectl --kubeconfig "$KUBECONFIG" config get-contexts -o name | grep -Fxq "$KUBE_CONTEXT" || {
  echo "kubeconfig에 요청한 context가 없습니다: $KUBE_CONTEXT" >&2
  exit 1
}

helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --namespace argocd \
  --create-namespace \
  --version 10.1.3 \
  --kubeconfig "$KUBECONFIG" \
  --kube-context "$KUBE_CONTEXT" \
  --wait \
  --timeout 10m

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  apply -f "$repo_root/argocd/envoy-gateway-application.yaml"

sed "s|GIT_REPOSITORY_URL|${GIT_REPOSITORY_URL}|g" \
  "$repo_root/argocd/blue-bank-gateway-dev-application.yaml" |
  kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" apply -f -

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  wait --for=condition=Available deployment/argocd-server -n argocd --timeout=10m

echo "Argo CD bootstrap completed"
```

Argo CD Chart는 2026-07-09 공개된 `10.1.3`으로 고정하며, 이 Chart가 설치하는 Argo CD 애플리케이션 버전은 `v3.4.5`이다.

- [ ] **Step 3: 클러스터 검증 스크립트를 작성한다**

Create `infra/scripts/verify-dev.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG 경로를 설정하세요}"
: "${KUBE_CONTEXT:?KUBE_CONTEXT를 설정하세요}"

kc=(kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT")

"${kc[@]}" cluster-info >/dev/null
ready_nodes="$("${kc[@]}" get nodes --no-headers | awk '$2 == "Ready" {count++} END {print count+0}')"
test "$ready_nodes" -eq 2 || {
  echo "Ready 노드는 2대여야 하지만 ${ready_nodes}대입니다." >&2
  exit 1
}

"${kc[@]}" wait --for=condition=Available deployment/argocd-server -n argocd --timeout=10m
"${kc[@]}" wait --for=condition=Available deployment/envoy-gateway -n envoy-gateway-system --timeout=10m
"${kc[@]}" rollout status deployment/blue-bank-gateway -n blue-bank --timeout=10m
"${kc[@]}" rollout status statefulset/redis -n blue-bank --timeout=10m

"${kc[@]}" wait --for=condition=Programmed gateway/blue-bank-gateway -n blue-bank --timeout=10m

external_ip="$("${kc[@]}" get gateway blue-bank-gateway -n blue-bank \
  -o jsonpath='{.status.addresses[0].value}')"

test -n "$external_ip" || {
  echo "Envoy Gateway Load Balancer External IP가 없습니다." >&2
  exit 1
}

curl --fail --show-error --silent --max-time 10 "http://${external_ip}/actuator/health" >/dev/null
echo "Development NKS verification passed: http://${external_ip}"
```

- [ ] **Step 4: Shell 문법과 정적 검사를 실행한다**

Run:

```bash
bash -n infra/scripts/bootstrap-argocd.sh
bash -n infra/scripts/verify-dev.sh
bash infra/tests/static.sh
```

Expected: 두 문법 검사 exit code 0, `Terraform static checks passed`.

- [ ] **Step 5: 스크립트를 실행 가능하게 만들고 커밋한다**

```bash
chmod +x infra/scripts/bootstrap-argocd.sh infra/scripts/verify-dev.sh infra/tests/static.sh
git add infra/scripts infra/tests/static.sh
git commit -m "feat: bootstrap and verify NKS GitOps deployment"
```

---

### Task 6: 그대로 따라 하는 NCP 배포 가이드 작성

**Files:**
- Create: `docs/NCP_TERRAFORM_DEPLOYMENT.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Task 1~5의 파일과 출력
- Produces: 콘솔 사전 준비, VPC부터 배포·검증·삭제까지 단일 실행 문서

- [ ] **Step 1: 배포 문서에 사전 도구와 비용 발생 리소스를 명시한다**

Create `docs/NCP_TERRAFORM_DEPLOYMENT.md` with these exact top-level sections:

```markdown
# NCP NKS 개발 인프라 배포

## 1. 생성되는 유료 리소스
## 2. 로컬 도구 설치 확인
## 3. NCP Sub Account와 API 인증키 생성
## 4. Terraform state Object Storage 버킷 생성
## 5. NCR 이미지 버킷과 Container Registry 생성
## 6. 현재 공인 IP 확인
## 7. backend.hcl과 terraform.tfvars 작성
## 8. VPC/NAT/NKS Terraform Plan 검토
## 9. Terraform Apply
## 10. NCP 콘솔에서 VPC부터 생성 결과 확인
## 11. kubeconfig 발급
## 12. NCR 로그인과 Gateway 이미지 Push
## 13. Kubernetes Secret 생성
## 14. Argo CD/Envoy Gateway 부트스트랩
## 15. 전체 배포 검증
## 16. 장애별 확인 명령
## 17. 비용을 멈추는 안전한 삭제 순서
```

유료 리소스에는 NAT Gateway, NKS Control Plane 정책에 따른 비용, 워커 서버 2대/스토리지, Load Balancer, Object Storage 사용량, Public IP/트래픽을 명시한다. 실제 가격은 고정 금액으로 쓰지 않고 NCP 요금 페이지를 확인하도록 안내한다.

- [ ] **Step 2: 환경변수와 backend 초기화 명령을 문서에 넣는다**

Use:

```bash
export NCLOUD_ACCESS_KEY="발급받은-access-key"
export NCLOUD_SECRET_KEY="발급받은-secret-key"
export NCLOUD_REGION="KR"

# Terraform S3 backend가 동일한 NCP Object Storage 인증키를 사용한다.
export AWS_ACCESS_KEY_ID="$NCLOUD_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$NCLOUD_SECRET_KEY"

cd infra/environments/dev
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

`backend.hcl`의 버킷 이름과 `terraform.tfvars`의 공인 IP/NCR Endpoint를 실제 값으로 바꾸라고 바로 아래에 설명한다.

- [ ] **Step 3: VPC부터 Apply하는 명령과 성공 기준을 문서에 넣는다**

Use:

```bash
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive ../../
terraform validate
terraform plan -out=dev.tfplan
terraform show dev.tfplan
terraform apply dev.tfplan
terraform output
```

Plan 검토 체크리스트:

- VPC CIDR `10.0.0.0/16`
- Subnet 4개와 각 `usage_type`
- 워커 Subnet만 Private Route Table에 연결
- `0.0.0.0/0` Route 대상이 NAT Gateway
- NKS `public_network = false`
- NKS API 기본 `deny`
- 허용 IP가 본인/CI의 `/32`
- 노드 2대, 2 vCPU/8 GB, 100 GB
- 삭제/반납 보호 활성화
- 예상하지 않은 기존 리소스 삭제가 0개

- [ ] **Step 4: NCP 콘솔 확인 순서를 문서에 넣는다**

콘솔 메뉴와 성공 기준을 다음 순서로 작성한다.

1. **Services > Networking > VPC > VPC Management**: `blue-bank-dev-vpc`, `10.0.0.0/16`
2. **Subnet Management**: 워커/Private LB/Public LB/NAT Subnet 4개와 Zone 확인
3. **NAT Gateway**: `blue-bank-dev-natgw`와 Public IP 확인
4. **Route Table**: 워커 Route Table의 `0.0.0.0/0 -> NATGW` 확인
5. **Containers > Ncloud Kubernetes Service**: NKS 1.34, Cilium, Single Zone, Running
6. **Node Pool**: Ready 노드 2대와 Private IP 확인
7. **Load Balancer**: Argo CD 배포 후 Kubernetes가 생성한 LB 확인

콘솔에서 Terraform 관리 리소스를 수정하지 말고 코드 변경 후 다시 `plan/apply`하도록 경고한다.

- [ ] **Step 5: kubeconfig, NCR, Secret, Argo CD 실행 명령을 문서에 넣는다**

IAM 인증 kubeconfig는 `ncp-iam-authenticator`로 생성한다. Terraform output의 UUID를 사용해 다음 명령을 실행한다.

```bash
repo_root="$(git rev-parse --show-toplevel)"
mkdir -p "$repo_root/.kube"
cluster_uuid="$(terraform -chdir=infra/environments/dev output -raw cluster_uuid)"
ncp-iam-authenticator create-kubeconfig \
  --region KR \
  --clusterUuid "$cluster_uuid" \
  --output "$repo_root/.kube/blue-bank-dev.yaml"

export KUBECONFIG="$repo_root/.kube/blue-bank-dev.yaml"
export KUBE_CONTEXT="$(kubectl --kubeconfig "$KUBECONFIG" config current-context)"
export GIT_REPOSITORY_URL="https://github.com/조직/blue-bank-gateway.git"

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" get nodes

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  create namespace blue-bank --dry-run=client -o yaml | \
  kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" apply -f -

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" \
  create secret generic blue-bank-gateway-secret \
  --namespace blue-bank \
  --from-literal=JWT_SECRET='안전한-실제-JWT-secret' \
  --from-literal=REDIS_PASSWORD='안전한-실제-Redis-password'

./infra/scripts/bootstrap-argocd.sh
./infra/scripts/verify-dev.sh
```

Shell history에 Secret이 남는 문제를 경고하고 실제 사용 문서에서는 `read -s` 또는 Secret Manager 연동을 권장한다.

- [ ] **Step 6: 안전한 삭제 순서를 문서에 넣는다**

다음 순서를 정확히 문서화한다.

1. 삭제 대상 context를 재확인한다.
2. Argo CD Application을 삭제해 Kubernetes 생성 Load Balancer와 PVC를 먼저 정리한다.
3. NCP 콘솔에서 Kubernetes 연동 Load Balancer가 사라졌는지 확인한다.
4. `return_protection = false`로 변경하고 `terraform plan/apply`한다.
5. `terraform plan -destroy -out=destroy.tfplan`을 검토한다.
6. `terraform apply destroy.tfplan`을 실행한다.
7. NKS, NAT Gateway, Subnet, VPC가 제거됐는지 확인한다.
8. state 버킷과 NCR은 기본적으로 보존하며 정말 필요할 때만 콘솔에서 별도 삭제한다.

- [ ] **Step 7: README에 배포 문서 링크를 추가한다**

Add under the Kubernetes deployment section of `README.md`:

```markdown
- [NCP NKS Terraform 인프라 생성 및 배포](docs/NCP_TERRAFORM_DEPLOYMENT.md)
```

- [ ] **Step 8: 문서 명령과 링크를 검증하고 커밋한다**

Run:

```bash
rg -n '^## ([1-9]|1[0-7])\.' docs/NCP_TERRAFORM_DEPLOYMENT.md
rg -n 'NCP_TERRAFORM_DEPLOYMENT.md' README.md
bash -n infra/scripts/bootstrap-argocd.sh infra/scripts/verify-dev.sh
```

Expected: 17개 순서 섹션, README 링크 1개, Shell 문법 exit code 0.

Commit:

```bash
git add README.md docs/NCP_TERRAFORM_DEPLOYMENT.md
git commit -m "docs: add step-by-step NCP NKS deployment guide"
```

---

### Task 7: 전체 검증과 실제 Plan 준비

**Files:**
- Modify only if verification finds an issue: `infra/**`, `docs/NCP_TERRAFORM_DEPLOYMENT.md`, `.gitignore`

**Interfaces:**
- Consumes: Task 1~6 전체 결과
- Produces: 컴파일 성공, Terraform validate 성공, 비밀 미추적, 사용자가 실제 NCP Plan을 실행할 준비가 된 상태

- [ ] **Step 1: 모든 Terraform 파일을 포맷한다**

Run:

```bash
terraform fmt -recursive infra
git diff --check
```

Expected: 두 명령 모두 exit code 0.

- [ ] **Step 2: Provider를 초기화하고 전체 Root Module을 검증한다**

Run:

```bash
terraform -chdir=infra/environments/dev init -backend=false -upgrade
terraform -chdir=infra/environments/dev validate
```

Expected: `Success! The configuration is valid.`와 `.terraform.lock.hcl` 생성. Lock file은 커밋한다.

- [ ] **Step 3: 정적·Shell·비밀정보 검사를 실행한다**

Run:

```bash
bash infra/tests/static.sh
bash -n infra/tests/static.sh
bash -n infra/scripts/bootstrap-argocd.sh
bash -n infra/scripts/verify-dev.sh
git ls-files | rg '(backend\.hcl|terraform\.tfvars|\.tfstate|\.tfplan|kubeconfig)' && exit 1 || true
```

Expected: `Terraform static checks passed`, 나머지는 exit code 0.

- [ ] **Step 4: Kubernetes Overlay와 Argo CD 매니페스트를 검증한다**

Run:

```bash
kubectl kustomize k8s/overlays/dev >/tmp/blue-bank-dev-rendered.yaml
kubectl apply --dry-run=client -f argocd/envoy-gateway-application.yaml
sed 's|GIT_REPOSITORY_URL|https://github.com/example/blue-bank-gateway.git|g' \
  argocd/blue-bank-gateway-dev-application.yaml |
  kubectl apply --dry-run=client -f -
```

Expected: Kustomize render 성공, 두 Application 모두 dry-run 성공.

- [ ] **Step 5: Gateway 프로젝트 전체 컴파일과 테스트를 실행한다**

Run:

```bash
./gradlew clean test build
```

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: 실제 인증정보가 있는 환경에서 원격 backend와 Plan을 검증한다**

Run after copying the example files and exporting credentials:

```bash
export AWS_ACCESS_KEY_ID="$NCLOUD_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$NCLOUD_SECRET_KEY"

terraform -chdir=infra/environments/dev init \
  -reconfigure \
  -backend-config=backend.hcl
terraform -chdir=infra/environments/dev plan -out=dev.tfplan
terraform -chdir=infra/environments/dev show dev.tfplan
```

Expected:

- Object Storage backend 초기화 성공
- 기존 NCP 리소스 삭제 0개
- 이 계획에서 정의한 VPC/Network/NKS 리소스만 생성
- 사용자의 `/32` API 허용 CIDR 표시
- 인증키나 Secret 값이 Plan 출력에 없음

`terraform apply`는 사용자가 Plan을 직접 확인하고 승인한 다음에만 실행한다.

- [ ] **Step 7: 검증 결과와 Provider Lock file을 커밋한다**

```bash
git add infra/environments/dev/.terraform.lock.hcl
git status --short
git commit -m "chore: lock verified NCP Terraform provider"
```

- [ ] **Step 8: 완료 직전 학습을 기록하고 최종 상태를 확인한다**

Run after fresh verification:

```bash
/ce-compound mode:headless "NCP NKS Terraform 구현: VPC/NAT/NKS, Object Storage backend, Argo CD bootstrap, 검증에서 발견한 실수와 예방 체크"
git status --short
```

Expected: 재사용 가능한 교훈이 있으면 프로젝트 학습 문서에 기록되고, 없으면 재사용 가능한 교훈이 없다고 명시한다. 작업 범위 밖 사용자 변경은 보존한다.

---

## 실제 사용자가 따라갈 최종 실행 순서 요약

구현이 끝난 뒤 사용자는 아래 순서만 수행하면 된다.

1. NCP 콘솔에서 Terraform용 Sub Account/API Key를 만든다.
2. Object Storage에 state 전용 버킷과 NCR 이미지 전용 버킷을 각각 만든다.
3. 이미지 버킷을 연결해 Container Registry를 만든다.
4. 자신의 공인 IP를 `/32`로 확인한다.
5. `backend.hcl.example`, `terraform.tfvars.example`을 복사해 실제 환경값을 넣는다.
6. NCP와 S3 backend 인증 환경변수를 설정한다.
7. `terraform init`, `fmt -check`, `validate`, `plan`을 실행한다.
8. Plan에서 VPC/Subnet/NAT/NKS 구성과 삭제 0개를 확인한다.
9. `terraform apply dev.tfplan`을 실행한다.
10. NCP 콘솔에서 VPC → Subnet → NAT/Route → NKS → Node Pool 순으로 확인한다.
11. kubeconfig를 발급하고 Ready 노드 2대를 확인한다.
12. Gateway 이미지를 NCR에 Push하고 Kubernetes Secret을 만든다.
13. `bootstrap-argocd.sh`를 실행한다.
14. `verify-dev.sh`로 Envoy Gateway External IP와 HTTP 응답까지 확인한다.
