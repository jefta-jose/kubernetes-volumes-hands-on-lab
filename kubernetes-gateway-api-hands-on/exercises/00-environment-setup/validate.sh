#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

context="$(kubectl config current-context 2>/dev/null)"
[[ -n "$context" ]] || fail "kubectl has no current context."

kubectl cluster-info >/dev/null 2>&1 || fail "cannot reach the Kubernetes cluster for context '$context'."

node_count="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
not_ready_count="$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" { count++ } END { print count+0 }')"
[[ "$node_count" -gt 0 ]] || fail "the cluster has no nodes."
[[ "$not_ready_count" -eq 0 ]] || fail "$not_ready_count node(s) are not Ready."

kubectl wait --for=condition=Available deployment/envoy-gateway \
  -n envoy-gateway-system --timeout=30s >/dev/null 2>&1 || \
  fail "Envoy Gateway is not installed or its Deployment is not Available."

required_crds=(
  gatewayclasses.gateway.networking.k8s.io
  gateways.gateway.networking.k8s.io
  httproutes.gateway.networking.k8s.io
  referencegrants.gateway.networking.k8s.io
)
for crd in "${required_crds[@]}"; do
  kubectl get crd "$crd" >/dev/null 2>&1 || fail "required CRD '$crd' is missing."
done

for namespace in gateway-lab infra team-a shared-services; do
  kubectl get namespace "$namespace" >/dev/null 2>&1 || fail "namespace '$namespace' is missing."
done

for namespace in gateway-lab shared-services; do
  deployment_count="$(kubectl get deployment -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  service_count="$(kubectl get service -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$deployment_count" -gt 0 ]] || fail "no backend Deployments exist in namespace '$namespace'."
  [[ "$service_count" -gt 0 ]] || fail "no backend Services exist in namespace '$namespace'."
  kubectl wait --for=condition=Available deployment --all \
    -n "$namespace" --timeout=30s >/dev/null 2>&1 || \
    fail "not all Deployments in namespace '$namespace' are Available."
done

echo "PASS: context '$context' is ready for Exercise 1 ($node_count Ready node(s))."
