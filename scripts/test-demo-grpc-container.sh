#!/usr/bin/env bash
# test-demo-grpc-container.sh — build the demo-grpc image, run it, healthcheck,
# inspect, and clean up. Run from the repository root.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_DIR="${REPO_ROOT}/services/demo-grpc"

IMAGE="demo-grpc:local"
CONTAINER="demo-grpc-test"
HOST_PORT="${HOST_PORT:-50052}"
CONTAINER_PORT="50051"
ADDR="localhost:${HOST_PORT}"

echo "============================================================"
echo "demo-grpc container test"
echo "============================================================"
echo "image      : ${IMAGE}"
echo "host port  : ${HOST_PORT} -> container ${CONTAINER_PORT}"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not installed or not in PATH."
  exit 1
fi
if ! command -v go >/dev/null 2>&1; then
  echo "ERROR: go is not installed or not in PATH."
  exit 1
fi
echo
echo "Checking Docker daemon..."
docker info >/dev/null
echo "Docker daemon OK."

cleanup() {
  echo
  echo "Cleaning up..."
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
  docker image rm "${IMAGE}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo
echo "Removing any previous test container..."
docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true

# ── build image ──────────────────────────────────────────────────────────────
echo
echo "Building image..."
docker build --pull -t "${IMAGE}" "${SERVICE_DIR}"
echo "Build OK."

echo
echo "Inspecting image user (must be non-root)..."
IMAGE_USER="$(docker image inspect "${IMAGE}" --format '{{.Config.User}}')"
echo "  Image.Config.User = ${IMAGE_USER:-<empty>}"
if [ -z "${IMAGE_USER}" ] || [ "${IMAGE_USER%%:*}" = "0" ] || [ "${IMAGE_USER%%:*}" = "root" ]; then
  echo "ERROR: image must not run as root."
  exit 1
fi

# ── run container ────────────────────────────────────────────────────────────
echo
echo "Starting container..."
docker run -d \
  --name "${CONTAINER}" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  -e SERVICE_NAME=demo-grpc \
  -e APP_VERSION=container-local \
  -e GRPC_PORT="${CONTAINER_PORT}" \
  "${IMAGE}" >/dev/null

echo
echo "Container status:"
docker ps --filter "name=${CONTAINER}" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# ── wait for the gRPC server to be ready ─────────────────────────────────────
echo
echo "Waiting for gRPC server..."
RETRIES=15
until (cd "${SERVICE_DIR}" && go run ./cmd/healthcheck -addr "${ADDR}" -timeout 2s) >/dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [ "${RETRIES}" -eq 0 ]; then
    echo "ERROR: server did not become healthy. Container logs:"
    docker logs "${CONTAINER}" || true
    exit 1
  fi
  sleep 1
done

# ── healthcheck from host ────────────────────────────────────────────────────
echo
echo "Running gRPC healthcheck client against the container..."
(cd "${SERVICE_DIR}" && go run ./cmd/healthcheck -addr "${ADDR}")

# ── inspect image and container ──────────────────────────────────────────────
echo
echo "Waiting for Docker HEALTHCHECK..."
HEALTH_STATUS="starting"
for i in $(seq 1 12); do
  HEALTH_STATUS="$(docker inspect "${CONTAINER}" \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}')"
  echo "  attempt ${i}: ${HEALTH_STATUS}"
  [ "${HEALTH_STATUS}" = "healthy" ] && break
  sleep 2
done

if [ "${HEALTH_STATUS}" != "healthy" ]; then
  echo "ERROR: container did not become healthy."
  echo
  echo "Container logs:"
  docker logs "${CONTAINER}" || true
  exit 1
fi

echo
echo "Exposed ports:"
docker inspect -f '{{range $p, $_ := .Config.ExposedPorts}}  {{$p}}{{end}}' "${CONTAINER}"; echo

echo
echo "Container logs:"
docker logs "${CONTAINER}" 2>&1 | sed 's/^/  /'

echo
echo "Image size:"
docker image ls "${IMAGE}" --format '  {{.Repository}}:{{.Tag}}  {{.Size}}'

echo
echo "============================================================"
echo "demo-grpc container test passed."
echo "============================================================"
