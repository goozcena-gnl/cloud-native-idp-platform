#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-idp-local}"
IMAGE="${IMAGE:-backstage:local}"
APP_DIR="${APP_DIR:-developer-portal/backstage}"

echo "============================================================"
echo "Build Backstage image and load into kind"
echo "Cluster: ${CLUSTER_NAME}"
echo "Image:   ${IMAGE}"
echo "App dir: ${APP_DIR}"
echo "============================================================"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "ERROR: missing Backstage app directory: ${APP_DIR}"
  exit 1
fi

echo
echo "Checking kind cluster..."
kind get clusters | grep -qx "${CLUSTER_NAME}"

echo
echo "Building Backstage backend bundle..."
(
  cd "${APP_DIR}"
  corepack enable || true
  yarn install --immutable
  yarn tsc
  yarn build:backend
)

echo
echo "Building Docker image..."
docker build \
  -t "${IMAGE}" \
  -f "${APP_DIR}/packages/backend/Dockerfile" \
  "${APP_DIR}"

echo
echo "Loading image into kind..."
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"

echo
echo "Checking image inside kind nodes..."
for node in "${CLUSTER_NAME}-control-plane" "${CLUSTER_NAME}-worker"; do
  echo "--- ${node}"
  docker exec "${node}" crictl images | grep -E 'backstage|IMAGE' || true
done

echo
echo "============================================================"
echo "Backstage image built and loaded successfully."
echo "============================================================"
