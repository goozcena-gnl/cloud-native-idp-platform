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
  "# Cloud Native IDP Platform"
  "## What this project demonstrates"
  "## Target roles"
  "## Architecture overview"
  "## Current platform capabilities"
  "## Validation model"
  "## Key validation scripts"
  "## Documentation index"
  "## Evidence assets"
  "## Repository structure"
  "## Local-first design"
  "## Production note"
  "## Portfolio outcome"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${README}"; then
    echo "ERROR: README missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
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