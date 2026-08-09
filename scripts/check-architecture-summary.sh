#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check architecture and capabilities summary"
echo "============================================================"

DOC="docs/ARCHITECTURE_AND_CAPABILITIES.md"

if [[ ! -f "${DOC}" ]]; then
  echo "ERROR: missing ${DOC}"
  exit 1
fi

required_sections=(
  "# Architecture and Capabilities Summary"
  "## Purpose"
  "## High-level architecture"
  "## Platform layers"
  "## GitOps model"
  "## Reference workload"
  "## Observability capabilities"
  "## Security capabilities"
  "## Runtime operations capabilities"
  "## Developer Experience capabilities"
  "## Validation strategy"
  "## Local-first design choices"
  "## Production-grade improvements"
  "## Architecture review guide"
  "## Capability boundary"
)

for section in "${required_sections[@]}"; do
  if ! grep -qF "${section}" "${DOC}"; then
    echo "ERROR: missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

required_terms=(
  "Kubernetes"
  "Argo CD"
  "GitOps"
  "GitHub Actions"
  "demo-grpc"
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
  "MinIO"
  "Vault"
  "Backstage"
  "Developer Golden Path"
  "Production Readiness Scorecard"
)

echo
echo "Checking key architecture terms..."

for term in "${required_terms[@]}"; do
  if ! grep -qF "${term}" "${DOC}"; then
    echo "ERROR: missing term: ${term}"
    exit 1
  fi

  echo "OK: ${term}"
done

if ! grep -qF "[Architecture and capabilities summary](ARCHITECTURE_AND_CAPABILITIES.md)" docs/DOCUMENTATION_INDEX.md; then
  echo "ERROR: documentation index does not reference architecture summary."
  exit 1
fi

echo
echo "OK: documentation index references architecture summary."

if ! grep -qF "**Canonical architecture reference.**" "${DOC}"; then
  echo "ERROR: architecture summary is not identified as canonical."
  exit 1
fi

if ! grep -qF "[Architecture and Capabilities Summary](ARCHITECTURE_AND_CAPABILITIES.md)" docs/ARCHITECTURE.md; then
  echo "ERROR: architecture overview does not reference the canonical summary."
  exit 1
fi

adr_count="$(grep -cF "adr/000" docs/DOCUMENTATION_INDEX.md)"

if [[ "${adr_count}" != "4" ]]; then
  echo "ERROR: documentation index must reference exactly four ADRs; found ${adr_count}."
  exit 1
fi

echo "OK: canonical architecture marker, overview link, and four ADR routes are present."

echo
echo "============================================================"
echo "Architecture and capabilities summary validated successfully."
echo "============================================================"
