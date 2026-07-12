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

check_term() {
  local term="$1"

  if grep -qiF "${term}" "${DOC}"; then
    echo "OK: ${term}"
  else
    echo "ERROR: missing term: ${term}"
    exit 1
  fi
}

check_term_any() {
  local label="$1"
  shift

  for term in "$@"; do
    if grep -qiF "${term}" "${DOC}"; then
      echo "OK: ${label}"
      return 0
    fi
  done

  echo "ERROR: missing term variant for: ${label}"
  echo "Accepted variants:"
  for term in "$@"; do
    echo "- ${term}"
  done
  exit 1
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

echo
echo "Checking release checklist terms..."

check_term "GitHub Actions CI"
check_term_any "ArgoCD / Argo CD" "ArgoCD" "Argo CD"
check_term "Synced"
check_term "Healthy"
check_term "FULL_VALIDATION=true ./scripts/check-final-platform.sh"
check_term "docs/ARCHITECTURE_AND_CAPABILITIES.md"
check_term "docs/assets/observability-sre/"
check_term "docs/assets/security-governance/"
check_term "docs/assets/backup-disaster-recovery/"
check_term "docs/assets/secrets-management/"
check_term "docs/assets/developer-portal/"
check_term "Vault dev mode"
check_term "Backstage Kubernetes plugin disabled"

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
