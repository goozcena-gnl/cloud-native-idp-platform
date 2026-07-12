#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check final release readiness"
echo "============================================================"

DOC="docs/FINAL_RELEASE_CHECKLIST.md"

if [[ ! -f "${DOC}" ]]; then
  echo "ERROR: missing ${DOC}"
  exit 1
fi

required_sections=(
  "# Final Release Checklist"
  "## Goal"
  "## 1. Git and CI readiness"
  "## 2. GitOps readiness"
  "## 3. Portfolio documentation readiness"
  "## 4. Platform capability readiness"
  "## 5. Full operational validation"
  "## 6. Evidence readiness"
  "## 7. Interview readiness"
  "## 8. Known local-first limitations"
  "## 9. Final release criteria"
  "## Final status"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${DOC}"; then
    echo "ERROR: missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

required_terms=(
  "GitHub Actions CI"
  "ArgoCD"
  "Synced"
  "Healthy"
  "FULL_VALIDATION=true ./scripts/check-final-platform.sh"
  "docs/ARCHITECTURE_AND_CAPABILITIES.md"
  "docs/assets/observability-sre/"
  "docs/assets/security-governance/"
  "docs/assets/backup-disaster-recovery/"
  "docs/assets/secrets-management/"
  "docs/assets/developer-portal/"
  "Vault dev mode"
  "Backstage Kubernetes plugin disabled"
)

echo
echo "Checking release checklist terms..."

for term in "${required_terms[@]}"; do
  if ! grep -qF "${term}" "${DOC}"; then
    echo "ERROR: missing term: ${term}"
    exit 1
  fi

  echo "OK: ${term}"
done

echo
echo "Checking documentation validation scripts..."

./scripts/check-readme-portfolio.sh
./scripts/check-evidence-index.sh
./scripts/check-architecture-summary.sh
./scripts/check-portfolio-package.sh

echo
echo "============================================================"
echo "Final release readiness validated successfully."
echo "============================================================"
