#!/usr/bin/env bash
set -euo pipefail
provider="${1:-kind}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$repo_root/scripts/check-prereqs.sh" "$provider"
"$repo_root/scripts/create-cluster.sh" "$provider"
"$repo_root/scripts/install-envoy-gateway.sh"
"$repo_root/scripts/deploy-lab-apps.sh"

cat <<'EOF'

Setup complete.

Begin with:
  cd exercises/00-environment-setup
  cat README.md
EOF
