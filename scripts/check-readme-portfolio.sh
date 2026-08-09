#!/usr/bin/env bash
set -euo pipefail

README="${README:-README.md}"

echo "============================================================"
echo "Check portfolio README"
echo "README: ${README}"
echo "============================================================"

if [[ ! -f "${README}" ]]; then
  echo "ERROR: README not found: ${README}"
  exit 1
fi

required_sections=(
  "# Cloud-Native Internal Developer Platform"
  "## Architecture and technical navigation"
  "## Capabilities and boundaries"
  "## Validation model"
  "## Key validation scripts"
  "## Documentation index"
  "## Evidence assets"
  "## Repository structure"
  "## Local-first design"
  "## Production note"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${README}"; then
    echo "ERROR: README missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

required_navigation=(
  "[Architecture and Capabilities Summary](docs/ARCHITECTURE_AND_CAPABILITIES.md)"
  "[Architecture Overview](docs/ARCHITECTURE.md)"
  "[ADR 0001: Local-first platform strategy](docs/adr/0001-local-first-platform-strategy.md)"
  "[ADR 0002: GitOps as source of truth](docs/adr/0002-gitops-as-source-of-truth.md)"
  "[ADR 0003: Hybrid repository strategy](docs/adr/0003-hybrid-repository-strategy.md)"
  "[ADR 0004: Local execution strategy](docs/adr/0004-local-execution-strategy.md)"
)

echo
echo "Checking architecture navigation..."

for link in "${required_navigation[@]}"; do
  if ! grep -qF "${link}" "${README}"; then
    echo "ERROR: README missing architecture navigation: ${link}"
    exit 1
  fi

  echo "OK: ${link}"
done

required_terms=(
  "Kubernetes"
  "ArgoCD"
  "GitOps"
  "Prometheus"
  "Grafana"
  "Loki"
  "Tempo"
  "OpenTelemetry"
  "Kyverno"
  "NetworkPolicy"
  "Falco"
  "OpenCost"
  "Velero"
  "Vault"
  "Backstage"
  "Production Readiness Scorecard"
  "Developer Golden Path"
)

echo
echo "Checking key platform terms..."

for term in "${required_terms[@]}"; do
  if ! grep -qF "${term}" "${README}"; then
    echo "ERROR: README missing term: ${term}"
    exit 1
  fi

  echo "OK: ${term}"
done

echo
echo "============================================================"
echo "Portfolio README validated successfully."
echo "============================================================"
