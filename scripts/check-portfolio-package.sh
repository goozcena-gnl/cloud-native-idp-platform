#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check final portfolio package"
echo "============================================================"

required_docs=(
  "README.md"
  "docs/PORTFOLIO_PROJECT_OVERVIEW.md"
  "docs/DOCUMENTATION_INDEX.md"
  "docs/MILESTONES.md"
  "docs/PORTFOLIO_OBSERVABILITY_SRE.md"
  "docs/INCIDENT_DRILLS.md"
  "docs/SECURITY_GOVERNANCE.md"
  "docs/PHASE_7_RUNTIME_OPERATIONS.md"
  "docs/COST_VISIBILITY.md"
  "docs/RUNTIME_SECURITY.md"
  "docs/BACKUP_AND_DISASTER_RECOVERY.md"
  "docs/SECRETS_MANAGEMENT.md"
  "docs/PHASE_8_PLATFORM_ENGINEERING_DEVELOPER_EXPERIENCE.md"
  "docs/DEVELOPER_GOLDEN_PATH.md"
  "docs/PRODUCTION_READINESS_SCORECARD.md"
  "docs/DEVELOPER_PORTAL_BACKSTAGE.md"
  "docs/ARCHITECTURE_AND_CAPABILITIES.md"
  "docs/EVIDENCE_INDEX.md"
  "docs/FINAL_RELEASE_CHECKLIST.md"
  "catalog-info.yaml"
)

echo
echo "Checking required documentation files..."

for file in "${required_docs[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: missing required documentation file: ${file}"
    exit 1
  fi

  echo "OK: ${file}"
done

required_scripts=(
  "scripts/check-developer-experience.sh"
  "scripts/check-production-readiness-scorecard.sh"
  "scripts/check-backstage-local-app.sh"
  "scripts/check-backstage-stack.sh"
  "scripts/check-backstage-software-template.sh"
  "scripts/check-vault-stack.sh"
  "scripts/check-vault-kubernetes-auth.sh"
  "scripts/check-velero-backup-restore.sh"
  "scripts/check-falco-stack.sh"
  "scripts/check-opencost-stack.sh"
  "scripts/check-network-policies.sh"
  "scripts/check-kyverno-stack.sh"
  "scripts/check-platform-alerts.sh"
  "scripts/check-architecture-summary.sh"
  "scripts/check-evidence-index.sh"
  "scripts/check-final-platform.sh"
  "scripts/check-readme-portfolio.sh"
  "scripts/check-release-readiness.sh"
)

echo
echo "Checking required validation scripts..."

for file in "${required_scripts[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: missing required script: ${file}"
    exit 1
  fi

  if [[ ! -x "${file}" ]]; then
    echo "ERROR: script is not executable: ${file}"
    exit 1
  fi

  echo "OK: ${file}"
done

required_asset_dirs=(
  "docs/assets/observability-sre"
  "docs/assets/security-governance"
  "docs/assets/backup-disaster-recovery"
  "docs/assets/secrets-management"
  "docs/assets/developer-portal"
)

if command -v python >/dev/null 2>&1; then
  PYTHON_BIN=(python)
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN=(python3)
elif command -v py >/dev/null 2>&1; then
  PYTHON_BIN=(py -3)
else
  echo "ERROR: python, python3, or py -3 is required for catalog validation"
  exit 1
fi

echo
echo "Checking evidence asset directories..."

for dir in "${required_asset_dirs[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    echo "ERROR: missing evidence directory: ${dir}"
    exit 1
  fi

  count="$(find "${dir}" -type f | wc -l | tr -d ' ')"

  if [[ "${count}" == "0" ]]; then
    echo "ERROR: evidence directory is empty: ${dir}"
    exit 1
  fi

  echo "OK: ${dir} (${count} files)"
done

echo
echo "Checking Backstage catalog entities..."

"${PYTHON_BIN[@]}" - <<'PY'
from pathlib import Path
import yaml

path = Path("catalog-info.yaml")
docs = [doc for doc in yaml.safe_load_all(path.read_text(encoding="utf-8")) if doc]

required = {
    ("System", "cloud-native-idp-platform"),
    ("Group", "platform-team"),
    ("Component", "demo-grpc"),
    ("API", "demo-grpc-api"),
    ("Resource", "idp-local-kind-cluster"),
    ("Resource", "observability-stack"),
    ("Resource", "secrets-management-stack"),
}

seen = {
    (doc.get("kind"), doc.get("metadata", {}).get("name"))
    for doc in docs
}

missing = required - seen

if missing:
    raise SystemExit(f"Missing catalog entities: {sorted(missing)}")

for kind, name in sorted(seen):
    print(f"OK: {kind}/{name}")

print(f"Validated {len(docs)} catalog entities.")
PY

echo
echo "============================================================"
echo "Final portfolio package validated successfully."
echo "============================================================"