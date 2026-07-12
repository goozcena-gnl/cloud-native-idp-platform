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

check_heading() {
  local heading="$1"

  if grep -Eiq "^##[[:space:]]+([0-9]+\\.[[:space:]]+)?${heading}$" "${DOC}"; then
    echo "OK: ## ${heading}"
  else
    echo "ERROR: missing section: ## ${heading}"
    echo
    echo "Existing headings:"
    grep -n "^##" "${DOC}" || true
    exit 1
  fi
}

if ! grep -qiF "# Final Release Checklist" "${DOC}"; then
  echo "ERROR: missing section: # Final Release Checklist"
  exit 1
fi
echo "OK: # Final Release Checklist"

check_heading "Goal"
check_heading "Git and CI Readiness"
check_heading "GitOps Readiness"
check_heading "Portfolio Documentation Readiness"
check_heading "Platform Capability Readiness"
check_heading "Full Operational Validation"
check_heading "Evidence Readiness"
check_heading "Interview Readiness"
check_heading "Known Local-First Limitations"
check_heading "Final Release Criteria"
check_heading "Final Status"

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
