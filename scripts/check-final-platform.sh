#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-idp-local}"
FULL_VALIDATION="${FULL_VALIDATION:-false}"
REQUIRE_CLEAN_GIT="${REQUIRE_CLEAN_GIT:-true}"

echo "============================================================"
echo "Final platform validation"
echo "Context:            ${CONTEXT}"
echo "Full validation:    ${FULL_VALIDATION}"
echo "Require clean Git:  ${REQUIRE_CLEAN_GIT}"
echo "============================================================"

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${CONTEXT}" ]]; then
  echo "ERROR: expected Kubernetes context '${CONTEXT}', got '${CURRENT_CONTEXT}'."
  exit 1
fi

echo
echo "============================================================"
echo "1. Git state"
echo "============================================================"

git status --short

if [[ "${REQUIRE_CLEAN_GIT}" == "true" ]]; then
  if [[ -n "$(git status --short)" ]]; then
    echo "ERROR: working tree is not clean."
    echo
    echo "For the first validation before committing this script, run:"
    echo "REQUIRE_CLEAN_GIT=false ./scripts/check-final-platform.sh"
    exit 1
  fi

  echo "OK: Git working tree is clean."
else
  echo "WARN: Git clean check skipped because REQUIRE_CLEAN_GIT=false."
fi

echo
echo "============================================================"
echo "2. Recent CI runs"
echo "============================================================"

if command -v gh >/dev/null 2>&1; then
  gh run list --workflow CI --limit 5 || true
else
  echo "WARN: gh CLI not found, skipping GitHub Actions check."
fi

echo
echo "============================================================"
echo "3. ArgoCD applications"
echo "============================================================"

kubectl -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' \
  | sort

python - <<'PY'
import json
import subprocess
import sys

raw = subprocess.check_output(
    ["kubectl", "-n", "argocd", "get", "applications", "-o", "json"],
    text=True,
)

data = json.loads(raw)
bad = []

for item in data.get("items", []):
    name = item["metadata"]["name"]
    sync = item.get("status", {}).get("sync", {}).get("status")
    health = item.get("status", {}).get("health", {}).get("status")

    if sync != "Synced" or health != "Healthy":
        bad.append((name, sync, health))

if bad:
    print("ERROR: some ArgoCD applications are not Synced/Healthy:")
    for name, sync, health in bad:
        print(f"- {name}: sync={sync}, health={health}")
    sys.exit(1)

print("OK: all ArgoCD applications are Synced/Healthy.")
PY

echo
echo "============================================================"
echo "4. Portfolio package"
echo "============================================================"

./scripts/check-readme-portfolio.sh
./scripts/check-portfolio-package.sh

echo
echo "============================================================"
echo "5. Developer Experience"
echo "============================================================"

./scripts/check-developer-experience.sh
./scripts/check-production-readiness-scorecard.sh
./scripts/check-backstage-local-app.sh
./scripts/check-backstage-stack.sh
./scripts/check-backstage-software-template.sh

echo
echo "============================================================"
echo "6. Core platform quick checks"
echo "============================================================"

./scripts/check-vault-stack.sh

echo
echo "Reconciling Vault Kubernetes auth configuration..."
./scripts/configure-vault-kubernetes-auth.sh
./scripts/check-vault-kubernetes-auth.sh

echo
echo "============================================================"
echo "7. Optional full operational validation"
echo "============================================================"

if [[ "${FULL_VALIDATION}" == "true" ]]; then
  echo "Running full operational validation..."

  ./scripts/check-opencost-stack.sh
  ./scripts/check-falco-stack.sh
  ./scripts/check-velero-backup-restore.sh
  ./scripts/check-kyverno-stack.sh
  ./scripts/check-network-policies.sh
  ./scripts/check-platform-alerts.sh

  if [[ -x "./scripts/check-demo-grpc-log-trace-correlation.sh" ]]; then
    ./scripts/check-demo-grpc-log-trace-correlation.sh
  fi

  if [[ -x "./scripts/check-demo-grpc-security-baseline.sh" ]]; then
    ./scripts/check-demo-grpc-security-baseline.sh
  fi
else
  echo "Skipping full operational validation."
  echo
  echo "To run the complete validation suite:"
  echo "FULL_VALIDATION=true ./scripts/check-final-platform.sh"
fi

echo
echo "============================================================"
echo "Final platform validation completed successfully."
echo "============================================================"
