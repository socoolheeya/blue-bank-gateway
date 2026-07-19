#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG 경로를 설정하세요}"
: "${KUBE_CONTEXT:?KUBE_CONTEXT를 설정하세요}"
: "${GIT_REPOSITORY_URL:?GIT_REPOSITORY_URL을 설정하세요}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

test -f "$KUBECONFIG" || {
  echo "kubeconfig 파일이 없습니다: $KUBECONFIG" >&2
  exit 1
}

kubectl --kubeconfig "$KUBECONFIG" config get-contexts -o name | grep -Fxq "$KUBE_CONTEXT" || {
  echo "kubeconfig에 요청한 context가 없습니다: $KUBE_CONTEXT" >&2
  exit 1
}

kubectl --kubeconfig "$KUBECONFIG" --context "$KUBE_CONTEXT" cluster-info >/dev/null

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
