#!/usr/bin/env bash
set -euo pipefail

SCORECARD="${SCORECARD:-docs/PRODUCTION_READINESS_SCORECARD.md}"

echo "============================================================"
echo "Check Production Readiness Scorecard"
echo "Scorecard: ${SCORECARD}"
echo "============================================================"

if [[ ! -f "${SCORECARD}" ]]; then
  echo "ERROR: missing scorecard: ${SCORECARD}"
  exit 1
fi

required_sections=(
  "# Production Readiness Scorecard"
  "## Scoring model"
  "## Categories"
  "### 1. Ownership and catalog"
  "### 2. GitOps deployment"
  "### 3. CI/CD"
  "### 4. Container and runtime baseline"
  "### 5. Kubernetes reliability"
  "### 6. Observability"
  "### 7. Security governance"
  "### 8. Network security"
  "### 9. Secrets management"
  "### 10. Runtime operations"
  "### 11. Runbooks and troubleshooting"
  "### 12. Documentation and evidence"
  "## Demo service assessment"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq "${section}" "${SCORECARD}"; then
    echo "ERROR: missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

echo
echo "Checking scorecard references..."

required_references=(
  "catalog-info.yaml"
  "demo-grpc"
  "ArgoCD"
  "GitHub Actions"
  "Prometheus"
  "Loki"
  "Tempo"
  "OpenTelemetry"
  "Kyverno"
  "NetworkPolicy"
  "Vault"
  "Falco"
  "OpenCost"
  "Velero"
)

for reference in "${required_references[@]}"; do
  if ! grep -Fq "${reference}" "${SCORECARD}"; then
    echo "ERROR: missing reference: ${reference}"
    exit 1
  fi

  echo "OK: ${reference}"
done

echo
echo "============================================================"
echo "Production Readiness Scorecard validated successfully."
echo "============================================================"