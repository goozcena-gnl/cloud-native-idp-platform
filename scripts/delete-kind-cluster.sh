#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-idp-local}"

echo "============================================================"
echo "Deleting local kind cluster"
echo "Cluster name: ${CLUSTER_NAME}"
echo "============================================================"
echo

if ! command -v kind >/dev/null 2>&1; then
  echo "ERROR: kind is not installed or not in PATH."
  exit 1
fi

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Cluster '${CLUSTER_NAME}' deleted."
else
  echo "Cluster '${CLUSTER_NAME}' does not exist. Nothing to delete."
fi
