#!/usr/bin/env bash
set -euo pipefail

: "${KUBECONFIG:?KUBECONFIG 경로를 설정하세요}"
: "${KUBE_CONTEXT:?KUBE_CONTEXT를 설정하세요}"

test -f "$KUBECONFIG" || {
  echo "kubeconfig 파일이 없습니다: $KUBECONFIG" >&2
  exit 1
}

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
"${kc[@]}" wait --for=condition=Programmed gateway/blue-bank -n blue-bank --timeout=10m

external_ip="$("${kc[@]}" get gateway blue-bank -n blue-bank \
  -o jsonpath='{.status.addresses[0].value}')"

test -n "$external_ip" || {
  echo "Envoy Gateway Load Balancer External IP가 없습니다." >&2
  exit 1
}

curl --fail --show-error --silent --max-time 10 \
  "http://${external_ip}/actuator/health" >/dev/null

echo "Development NKS verification passed: http://${external_ip}"
