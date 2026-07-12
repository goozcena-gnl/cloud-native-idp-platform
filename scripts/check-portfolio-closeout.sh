#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check portfolio closeout"
echo "============================================================"

DOC="docs/PORTFOLIO_CLOSEOUT.md"

if [[ ! -f "${DOC}" ]]; then
  echo "ERROR: missing ${DOC}"
  exit 1
fi

required_sections=(
  "# Portfolio Closeout"
  "## Final status"
  "## Final validation commands"
  "## What to show first"
  "## Strongest portfolio proof points"
  "## Interview narrative"
  "## Technical discussion topics"
  "## Known local-first limitations"
  "## Production evolution"
  "## Final outcome"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${DOC}"; then
    echo "ERROR: missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

required_terms=(
  "ArgoCD"
  "GitHub Actions CI"
  "demo-grpc"
  "Prometheus"
  "Grafana"
  "Loki"
  "Tempo"
  "OpenTelemetry"
  "Kyverno"
  "NetworkPolicies"
  "Falco"
  "OpenCost"
  "Velero"
  "Vault"
  "Backstage"
  "Go gRPC software template"
  "FULL_VALIDATION=true ./scripts/check-final-platform.sh"
)

echo
echo "Checking closeout terms..."

for term in "${required_terms[@]}"; do
  if ! grep -qF "${term}" "${DOC}"; then
    echo "ERROR: missing term: ${term}"
    exit 1
  fi

  echo "OK: ${term}"
done

echo
echo "============================================================"
echo "Portfolio closeout validated successfully."
echo "============================================================"
