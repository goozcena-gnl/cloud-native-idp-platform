#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "Check Developer Experience foundation"
echo "============================================================"

required_files=(
  "catalog-info.yaml"
  "docs/PLATFORM_ENGINEERING_DEVELOPER_EXPERIENCE.md"
  "docs/DEVELOPER_GOLDEN_PATH.md"
  "services/demo-grpc/Dockerfile"
  "charts/demo-grpc/Chart.yaml"
  "platform/argocd/apps/demo-grpc-app.yaml"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: missing required file: ${file}"
    exit 1
  fi

  echo "OK: ${file}"
done

echo
echo "Checking catalog entities..."

required_catalog_patterns=(
  "kind: System"
  "name: cloud-native-idp-platform"
  "kind: Component"
  "name: demo-grpc"
  "kind: API"
  "name: demo-grpc-api"
  "kind: Resource"
  "name: observability-stack"
  "name: secrets-management-stack"
)

for pattern in "${required_catalog_patterns[@]}"; do
  if ! grep -Fq "${pattern}" catalog-info.yaml; then
    echo "ERROR: catalog-info.yaml does not contain: ${pattern}"
    exit 1
  fi

  echo "OK: catalog contains '${pattern}'"
done

echo
echo "Checking golden path key sections..."

required_doc_sections=(
  "## Golden Path overview"
  "## Definition of Ready"
  "## Definition of Done"
  "## Example onboarding checklist"
)

for section in "${required_doc_sections[@]}"; do
  if ! grep -Fq "${section}" docs/DEVELOPER_GOLDEN_PATH.md; then
    echo "ERROR: golden path documentation missing section: ${section}"
    exit 1
  fi

  echo "OK: ${section}"
done

echo
echo "============================================================"
echo "Developer Experience foundation validated successfully."
echo "============================================================"