#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-idp-local}"
IMAGE_NAME="${IMAGE_NAME:-demo-grpc:local}"
SERVICE_DIR="${SERVICE_DIR:-services/demo-grpc}"

echo "============================================================"
echo "Build and load demo-grpc image into kind"
echo "Cluster: ${CLUSTER_NAME}"
echo "Image:   ${IMAGE_NAME}"
echo "Service: ${SERVICE_DIR}"
echo "============================================================"
echo

docker info >/dev/null

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  echo "ERROR: kind cluster '${CLUSTER_NAME}' not found."
  exit 1
fi

echo "Building image..."
docker build -t "${IMAGE_NAME}" "${SERVICE_DIR}"

echo
echo "Loading image into kind..."
kind load docker-image "${IMAGE_NAME}" --name "${CLUSTER_NAME}"

echo
echo "Validating image inside kind nodes..."
docker exec "${CLUSTER_NAME}-control-plane" crictl images | grep demo-grpc || true
docker exec "${CLUSTER_NAME}-worker" crictl images | grep demo-grpc || true

echo
echo "============================================================"
echo "Image loaded into kind."
echo "============================================================"
