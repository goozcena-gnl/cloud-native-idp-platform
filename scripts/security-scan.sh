#!/usr/bin/env bash

set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-grpc:local}"
CHART_DIR="${CHART_DIR:-charts/demo-grpc}"
RENDERED_FILE="${RENDERED_FILE:-/tmp/demo-grpc-rendered.yaml}"

echo "============================================================"
echo "Security scan: demo-grpc"
echo "Image:  ${IMAGE_NAME}"
echo "Chart:  ${CHART_DIR}"
echo "============================================================"
echo

if ! command -v trivy >/dev/null 2>&1; then
  echo "ERROR: trivy is not installed or not in PATH."
  echo "Install Trivy locally or run this inside GitHub Actions."
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is not installed or not in PATH."
  exit 1
fi

echo "Trivy version:"
trivy --version

echo
echo "Filesystem scan: vulnerabilities, secrets, misconfigurations"
trivy fs \
  --scanners vuln,secret,misconfig \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  .

echo
echo "Rendering Helm chart for config scan..."
helm template demo-grpc "${CHART_DIR}" \
  --namespace apps \
  > "${RENDERED_FILE}"

echo
echo "Kubernetes manifest scan"
trivy config \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  "${RENDERED_FILE}"

echo
echo "Docker image scan"
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  "${IMAGE_NAME}"

echo
echo "============================================================"
echo "Security scan passed."
echo "============================================================"
