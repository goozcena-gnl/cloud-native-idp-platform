#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-idp-local}"
CONFIG_PATH="${KIND_CONFIG_PATH:-platform/bootstrap/kind-config.yaml}"

echo "============================================================"
echo "Creating local kind cluster"
echo "Cluster name: ${CLUSTER_NAME}"
echo "Config path:  ${CONFIG_PATH}"
echo "============================================================"
echo

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not in PATH."
  exit 1
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "ERROR: kind is not installed or not in PATH."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

echo "Checking Docker daemon..."
docker info >/dev/null
echo "Docker daemon is reachable."
echo

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  echo "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${CONFIG_PATH}"
fi

echo
echo "Switching kubectl context..."
kubectl config use-context "kind-${CLUSTER_NAME}"

echo
echo "Cluster info:"
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo
echo "Waiting for all nodes to become Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo
echo "Nodes:"
kubectl get nodes -o wide

echo
echo "System pods:"
kubectl get pods -A

echo
echo "============================================================"
echo "Local kind cluster is ready."
echo "============================================================"
