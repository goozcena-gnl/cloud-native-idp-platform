#!/usr/bin/env bash
# test-demo-grpc.sh — build-check, start, healthcheck, and stop demo-grpc.
# Run from the repository root.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_DIR="${REPO_ROOT}/services/demo-grpc"
LOG_FILE="/tmp/demo-grpc.log"
GRPC_PORT="${GRPC_PORT:-50051}"
METRICS_PORT="${METRICS_PORT:-9090}"
ADDR="localhost:${GRPC_PORT}"

echo "============================================================"
echo "demo-grpc local integration test"
echo "============================================================"
echo "service dir  : ${SERVICE_DIR}"
echo "gRPC port    : ${GRPC_PORT}"
echo "metrics port : ${METRICS_PORT}"

# ── build check (validates compilation) ──────────────────────────────────────
echo
echo "Checking build..."
(cd "${SERVICE_DIR}" && go build ./cmd/server ./cmd/healthcheck)
# Clean up the built binaries immediately; we use go run below.
EXT=""
[ "$(go env GOOS)" = "windows" ] && EXT=".exe"
rm -f "${SERVICE_DIR}/server${EXT}" "${SERVICE_DIR}/healthcheck${EXT}"
echo "Build OK."

# ── start server in background via go run ────────────────────────────────────
echo
echo "Starting server (log -> ${LOG_FILE})..."
# exec replaces the subshell so $! captures the go run process PID.
(cd "${SERVICE_DIR}" && GRPC_PORT="${GRPC_PORT}" METRICS_PORT="${METRICS_PORT}" exec go run ./cmd/server) > "${LOG_FILE}" 2>&1 &
SERVER_PID=$!

cleanup() {
  if kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ── wait for server to be ready ───────────────────────────────────────────────
RETRIES=15
until (cd "${SERVICE_DIR}" && go run ./cmd/healthcheck -addr "${ADDR}" -timeout 2s) >/dev/null 2>&1; do
  RETRIES=$((RETRIES - 1))
  if [ "${RETRIES}" -eq 0 ]; then
    echo "ERROR: server did not become healthy. Log:"
    cat "${LOG_FILE}"
    exit 1
  fi
  sleep 1
done

# ── run healthcheck ──────────────────────────────────────────────────────────
echo
echo "Running gRPC healthcheck client..."
(cd "${SERVICE_DIR}" && go run ./cmd/healthcheck -addr "${ADDR}")

# ── check metrics endpoint ───────────────────────────────────────────────────
echo
echo "Checking Prometheus metrics endpoint..."
curl -fsS "http://localhost:${METRICS_PORT}/metrics" \
  | grep -E "go_goroutines|process_cpu_seconds_total" >/dev/null
echo "Metrics endpoint OK."

# ── server log excerpt ───────────────────────────────────────────────────────
echo
echo "Server log excerpt:"
cat "${LOG_FILE}"

echo
echo "============================================================"
echo "demo-grpc local test passed."
echo "============================================================"

