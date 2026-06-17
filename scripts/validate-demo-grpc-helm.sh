#!/usr/bin/env bash
# validate-demo-grpc-helm.sh — lint, template, and server-side dry-run the
# demo-grpc Helm chart against the live kind cluster.
# Run from the repository root.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${REPO_ROOT}/charts/demo-grpc"
NAMESPACE="${NAMESPACE:-apps}"
RELEASE="${RELEASE:-demo-grpc}"
EXPECTED_CONTEXT="kind-idp-local"

echo "============================================================"
echo "demo-grpc Helm chart validation"
echo "============================================================"
echo "chart      : ${CHART_DIR}"
echo "namespace  : ${NAMESPACE}"
echo "release    : ${RELEASE}"

# ── pre-flight checks ────────────────────────────────────────────────────────
if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm is not installed or not in PATH."
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]; then
  echo "ERROR: kubectl context is '${CURRENT_CONTEXT}', expected '${EXPECTED_CONTEXT}'."
  echo "       Run: kubectl config use-context ${EXPECTED_CONTEXT}"
  exit 1
fi

echo
echo "Checking namespace '${NAMESPACE}'..."
kubectl get namespace "${NAMESPACE}" >/dev/null
echo "Namespace OK."

# ── helm lint ────────────────────────────────────────────────────────────────
echo
echo "Running helm lint..."
helm lint "${CHART_DIR}"
echo "Lint OK."

# ── helm template ────────────────────────────────────────────────────────────
RENDERED_FILE="$(mktemp)"
trap 'rm -f "${RENDERED_FILE}"' EXIT

echo
echo "Rendering chart (helm template)..."
helm template "${RELEASE}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  > "${RENDERED_FILE}"
echo "Rendered resources:"
grep -E '^kind:|^  name:' "${RENDERED_FILE}" | sed 's/^/  /' || true
echo "Template OK."

# ── client-side dry-run ──────────────────────────────────────────────────────
echo
echo "Running client-side dry-run..."
kubectl apply --namespace "${NAMESPACE}" --dry-run=client -f "${RENDERED_FILE}"
echo "Client dry-run OK."

# ── server-side dry-run ──────────────────────────────────────────────────────
echo
echo "Running server-side dry-run against ${EXPECTED_CONTEXT}..."
kubectl apply \
  --namespace "${NAMESPACE}" \
  --dry-run=server \
  --context "${EXPECTED_CONTEXT}" \
  -f "${RENDERED_FILE}"
echo "Server dry-run OK."

# ── rendered security assertions ─────────────────────────────────────────────
echo
echo "Checking rendered security context..."
assert_rendered() {
  if grep -qE -- "$1" "${RENDERED_FILE}"; then
    echo "  OK: $2"
  else
    echo "  ERROR: missing $2"
    exit 1
  fi
}
assert_rendered "runAsNonRoot: true"              "runAsNonRoot: true"
assert_rendered "allowPrivilegeEscalation: false" "allowPrivilegeEscalation: false"
assert_rendered "readOnlyRootFilesystem: true"    "readOnlyRootFilesystem: true"
assert_rendered "type: RuntimeDefault"            "seccompProfile RuntimeDefault"
assert_rendered "^ +- ALL$"                       "capabilities drop ALL"

# ── rendered probe assertions ────────────────────────────────────────────────
echo
echo "Checking rendered gRPC probes..."
assert_rendered "livenessProbe:"  "livenessProbe present"
assert_rendered "readinessProbe:" "readinessProbe present"
assert_rendered "grpc:"           "native gRPC probe present"

echo
echo "============================================================"
echo "demo-grpc Helm chart validation passed."
echo "============================================================"
