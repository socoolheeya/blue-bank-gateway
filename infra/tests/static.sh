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

rendered_dev="$(mktemp)"
trap 'rm -f "$rendered_dev"' EXIT
kubectl kustomize k8s/overlays/dev >"$rendered_dev"

if awk 'BEGIN { RS="---" } /kind: GatewayClass/ && /namespace:/ { found=1 } END { exit found ? 0 : 1 }' "$rendered_dev"; then
  echo "GatewayClass must remain cluster-scoped without metadata.namespace" >&2
  exit 1
fi

for kind in ConfigMap Service Deployment StatefulSet PodDisruptionBudget HorizontalPodAutoscaler Gateway HTTPRoute; do
  awk -v expected_kind="$kind" '
    BEGIN { RS="---"; found=0 }
    $0 ~ "kind: " expected_kind "([[:space:]]|$)" {
      found=1
      if ($0 !~ /namespace: blue-bank/) exit 2
    }
    END { if (!found) exit 1 }
  ' "$rendered_dev" || {
    echo "$kind must render in namespace blue-bank" >&2
    exit 1
  }
done

echo "Terraform static checks passed"
