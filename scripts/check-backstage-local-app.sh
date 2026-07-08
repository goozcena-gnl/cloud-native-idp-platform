#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-developer-portal/backstage}"

echo "============================================================"
echo "Check Backstage local app"
echo "App dir: ${APP_DIR}"
echo "============================================================"

required_files=(
  "${APP_DIR}/package.json"
  "${APP_DIR}/app-config.yaml"
  "${APP_DIR}/app-config.production.yaml"
  "${APP_DIR}/catalog/platform-catalog-info.yaml"
  "${APP_DIR}/packages/app/package.json"
  "${APP_DIR}/packages/backend/package.json"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: missing required file: ${file}"
    exit 1
  fi

  echo "OK: ${file}"
done

echo
echo "Checking catalog location references..."

for file in "${APP_DIR}/app-config.yaml" "${APP_DIR}/app-config.production.yaml"; do
  if ! grep -q "./catalog/platform-catalog-info.yaml" "${file}"; then
    echo "ERROR: ${file} does not reference platform catalog."
    exit 1
  fi

  echo "OK: ${file} references platform catalog."
done

echo
echo "Checking platform catalog entities..."

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
  if ! grep -q "${pattern}" "${APP_DIR}/catalog/platform-catalog-info.yaml"; then
    echo "ERROR: platform catalog does not contain: ${pattern}"
    exit 1
  fi

  echo "OK: platform catalog contains '${pattern}'"
done

echo
echo "Checking generated Backstage app with Yarn..."

(
  cd "${APP_DIR}"
  yarn --version
  yarn tsc
)

echo
echo "============================================================"
echo "Backstage local app validated successfully."
echo "============================================================"
