#!/usr/bin/env bash

set -euo pipefail

EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-idp-local}"
NAMESPACE="${NAMESPACE:-observability}"

echo "============================================================"
echo "Check observability stack"
echo "Context:   ${EXPECTED_CONTEXT}"
echo "Namespace: ${NAMESPACE}"
echo "============================================================"
echo

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl is not installed or not in PATH."
  exit 1
fi

CURRENT_CONTEXT="$(kubectl config current-context)"
if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: kubectl context mismatch."
  echo "Current:  ${CURRENT_CONTEXT}"
  echo "Expected: ${EXPECTED_CONTEXT}"
  exit 1
fi

echo "ArgoCD application:"
kubectl -n argocd get application kube-prometheus-stack || true

echo
echo "Pods:"
kubectl -n "${NAMESPACE}" get pods -o wide

echo
echo "Services:"
kubectl -n "${NAMESPACE}" get svc

echo
echo "Deployments:"
kubectl -n "${NAMESPACE}" get deploy

echo
echo "StatefulSets:"
kubectl -n "${NAMESPACE}" get sts

echo
echo "Waiting for Grafana deployment..."
kubectl -n "${NAMESPACE}" rollout status deployment/kube-prometheus-stack-grafana --timeout=300s

echo
echo "Waiting for Prometheus Operator deployment..."
kubectl -n "${NAMESPACE}" rollout status deployment/kube-prometheus-stack-operator --timeout=300s

echo
echo "Prometheus CRs:"
kubectl -n "${NAMESPACE}" get prometheus || true

echo
echo "ServiceMonitors:"
kubectl -n "${NAMESPACE}" get servicemonitor | head -n 20 || true

echo
echo "============================================================"
echo "Observability stack check complete."
echo "Run ./scripts/grafana-port-forward.sh to access Grafana."
echo "============================================================"
