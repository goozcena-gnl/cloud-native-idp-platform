#!/usr/bin/env bash

set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-demo-grpc:local}"
CHART_DIR="${CHART_DIR:-charts/demo-grpc}"
SERVICE_DIR="${SERVICE_DIR:-services/demo-grpc}"
RENDERED_FILE="${RENDERED_FILE:-/tmp/demo-grpc-rendered.yaml}"
BUILD_IMAGE_IF_MISSING="${BUILD_IMAGE_IF_MISSING:-true}"

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

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not in PATH."
  exit 1
fi

echo "Checking Docker daemon..."
docker info >/dev/null
echo "Docker daemon OK."
echo

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
echo "Checking whether Docker image exists locally..."
if docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Image already exists: ${IMAGE_NAME}"
else
  if [[ "${BUILD_IMAGE_IF_MISSING}" != "true" ]]; then
    echo "ERROR: image ${IMAGE_NAME} does not exist locally."
    echo "Build it with:"
    echo "  docker build -t ${IMAGE_NAME} ${SERVICE_DIR}"
    exit 1
  fi

  echo "Image not found. Building ${IMAGE_NAME} from ${SERVICE_DIR}..."
  docker build -t "${IMAGE_NAME}" "${SERVICE_DIR}"
fi

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
