#!/usr/bin/env bash
set -euo pipefail

envoy_gateway_version="${ENVOY_GATEWAY_VERSION:-v1.8.2}"

helm upgrade --install eg \
  oci://docker.io/envoyproxy/gateway-helm \
  --version "$envoy_gateway_version" \
  --namespace envoy-gateway-system \
  --create-namespace \
  --wait \
  --timeout 5m

kubectl wait \
  --timeout=5m \
  --namespace envoy-gateway-system \
  deployment/envoy-gateway \
  --for=condition=Available

kubectl get pods -n envoy-gateway-system
