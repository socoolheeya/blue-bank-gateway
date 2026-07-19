#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

required_files=(
  infra/modules/network/main.tf
  infra/modules/network/variables.tf
  infra/modules/network/outputs.tf
  infra/modules/network/versions.tf
  infra/modules/nks/main.tf
  infra/modules/nks/variables.tf
  infra/modules/nks/outputs.tf
  infra/modules/nks/versions.tf
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
  test -f "$file" || {
    echo "missing required file: $file" >&2
    exit 1
  }
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

if rg -n -i 'eureka|nginx' infra/modules infra/environments infra/scripts; then
  echo "Eureka or Nginx must not be part of the NKS infrastructure" >&2
  exit 1
fi

echo "Terraform static checks passed"
