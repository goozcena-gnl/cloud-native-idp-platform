# Observability

## Purpose

Observability provides visibility into platform and workload health. The first
observability milestone installs the `kube-prometheus-stack`, which provides:

- Prometheus Operator;
- Prometheus;
- Grafana;
- kube-state-metrics;
- prometheus-node-exporter;
- default Kubernetes dashboards and alerting rules.

## Current stack

```text
kube-prometheus-stack v86.2.2
```

The chart is deployed by ArgoCD using the multi-source pattern:

```text
platform/argocd/apps/kube-prometheus-stack-app.yaml
```

The chart comes from the Prometheus Community Helm registry. Values are stored
in the GitOps repository and referenced via the ArgoCD `$values` source:

```text
platform/helm-values/kube-prometheus-stack-values.yaml
```

## Access Grafana

```bash
./scripts/grafana-port-forward.sh
```

Then open:

```
http://localhost:3000
```

Local MVP credentials:

```
admin / admin
```

## Validate

```bash
./scripts/check-observability-stack.sh
```

## Multi-source ArgoCD Application

The `kube-prometheus-stack-app.yaml` uses the ArgoCD multi-source feature
(`sources:`) to combine:

1. The chart from the external Helm registry (`prometheus-community.github.io`).
2. The values file from the GitOps repository (`ref: values`).

This keeps the chart version and the custom values in Git without bundling a
third-party chart in the repository.

## Security notes

The local MVP uses a simple Grafana admin password (`admin/admin`) for
convenience. Grafana is `ClusterIP` only and accessible exclusively through
`kubectl port-forward` — it is not reachable from outside the local machine.

This is **not production-grade**.

Future improvements:

- store Grafana credentials in a Kubernetes Secret managed by Vault or
  External Secrets;
- restrict access with ingress authentication or SSO;
- enable persistent storage;
- define SLO dashboards;
- add OpenTelemetry metrics from `demo-grpc`;
- add Loki for logs;
- add Tempo for traces.

## AppProject permission note

`kube-prometheus-stack` requires cluster-scoped Kubernetes resources such as
CRDs, ClusterRoles, ClusterRoleBindings, and webhooks.

For the local MVP, the `idp-platform` AppProject temporarily allows all
cluster-scoped resources:

```yaml
clusterResourceWhitelist:
  - group: '*'
    kind: '*'
```

This is acceptable for a controlled local portfolio environment.

Future hardening should replace this wildcard with an explicit allowlist for
only the required observability resources.

## Validated observability milestone

The observability foundation is now validated.

Current state:

```text
kube-prometheus-stack   Synced / Healthy
Grafana                 Running
Prometheus              Running
Grafana /api/health     HTTP 200 OK
```

Grafana dashboards are available under **Dashboards** in the Grafana UI. The
installation includes Kubernetes dashboards such as:

- Kubernetes API server;
- Kubernetes compute resources;
- Kubernetes networking;
- kubelet;
- node exporter;
- Prometheus overview.

## Local Grafana stabilization

The initial Grafana resource limits were too small for the local kind
environment. Grafana was stabilized by increasing CPU and memory limits and
making probes more tolerant. This is a pragmatic local-first adjustment.

## Next observability step

The next step is application observability:

```text
demo-grpc metrics  -> ServiceMonitor  -> Prometheus scrape  -> Grafana dashboard
```

`demo-grpc` now exposes a Prometheus-compatible `/metrics` endpoint on port
`9090`. This endpoint is validated locally (via `test-demo-grpc.sh`) and in the
container image (via `test-demo-grpc-container.sh`) before Kubernetes scrape
configuration is enabled. The next step is to expose this port in the Helm chart
and add a `ServiceMonitor`.

## demo-grpc Prometheus scraping

`demo-grpc` exposes Prometheus metrics on port `9090`.

Kubernetes exposure:

```text
Service port:    metrics / 9090
ServiceMonitor:  apps/demo-grpc
Prometheus:      kube-prometheus-stack
```

Validate:

```bash
./scripts/check-demo-grpc-metrics.sh
```

Expected result:

```
Service /metrics endpoint OK.
Prometheus target discovery OK.
Prometheus scrape query OK.
```

## Validated demo-grpc metrics scraping

`demo-grpc` is now scraped by Prometheus.

Validated Kubernetes objects:

```text
Service:        apps/demo-grpc
Service port:   metrics / 9090
ServiceMonitor: apps/demo-grpc
Prometheus:     observability/kube-prometheus-stack-prometheus
```

Validated checks:

```
Service /metrics endpoint OK.
Prometheus target discovery OK.
Prometheus scrape query OK.
```

Manual Prometheus query example:

```
up{namespace="apps"}
```

Expected result:

```
demo-grpc target present and up
```

### Important note

The current deployment uses the mutable image tag `main`.

If a newly published image is not immediately used by Kubernetes, force a rollout:

```bash
kubectl -n apps rollout restart deployment/demo-grpc
kubectl -n apps rollout status deployment/demo-grpc --timeout=180s
```

This will be improved later by deploying immutable image tags or digests.

## demo-grpc custom metrics

`demo-grpc` now exposes custom application metrics:

```text
demo_grpc_build_info
demo_grpc_grpc_requests_total
demo_grpc_grpc_request_duration_seconds
```

These metrics complement the default Go/process metrics and demonstrate
application-level instrumentation.

The gRPC request metrics are collected through a unary gRPC server interceptor.

## Validated custom application metrics

`demo-grpc` now exposes custom Prometheus metrics in addition to standard Go
and process metrics.

Validated metrics:

```text
demo_grpc_build_info
demo_grpc_grpc_requests_total
demo_grpc_grpc_request_duration_seconds
```

The gRPC request metrics are collected through a unary gRPC server interceptor.

Validated checks:

```
Custom Kubernetes metrics endpoint OK.
Custom Prometheus metric query OK.
```

Example PromQL queries:

```promql
demo_grpc_build_info
```

```promql
rate(demo_grpc_grpc_requests_total[5m])
```

```promql
histogram_quantile(0.95, rate(demo_grpc_grpc_request_duration_seconds_bucket[5m]))
```

Next step: create a dedicated Grafana dashboard for `demo-grpc` with request
rate, error rate, latency, and service build/version information.

## demo-grpc Grafana dashboard

A Grafana dashboard for `demo-grpc` is provisioned via a Kubernetes ConfigMap
labelled `grafana_dashboard: "1"`. The Grafana sidecar in `kube-prometheus-stack`
automatically loads it.

GitOps path:

```text
platform/grafana/dashboards/demo-grpc-dashboard.yaml
  -> ConfigMap observability/demo-grpc-dashboard
  -> Grafana sidecar
  -> Dashboard uid: demo-grpc
```

Dashboard panels:

| Panel | Type | Query |
|---|---|---|
| Service Info | Stat | `demo_grpc_build_info` |
| Goroutines | Stat | `go_goroutines` |
| Total Requests | Stat | `sum(demo_grpc_grpc_requests_total)` |
| Error Rate (5m) | Stat | `rate(...code!="OK"...)` |
| Request Rate | Time series | `rate(demo_grpc_grpc_requests_total[5m])` by method/code |
| Request Latency | Time series | p50 + p95 histogram_quantile |

Validate:

```bash
./scripts/check-grafana-dashboard.sh
```

Access:

```bash
./scripts/grafana-port-forward.sh
# then open http://localhost:3000/d/demo-grpc
```

## Validated Grafana dashboard provisioning

A dedicated `demo-grpc` Grafana dashboard is now provisioned through GitOps.

Validated resources:

```text
ArgoCD Application: grafana-dashboards
ConfigMap:          observability/demo-grpc-dashboard
Grafana dashboard:  demo-grpc
Dashboard UID:      demo-grpc
```

Validation command:

```bash
./scripts/check-grafana-dashboard.sh
```

Expected result:

```
Dashboard found in Grafana.
Dashboard UID lookup OK.
Grafana demo-grpc dashboard is provisioned and accessible.
```

The dashboard includes panels for service information, request rate, error rate,
latency, and runtime/application metrics.

### Important note

Grafana credentials should remain aligned with Kubernetes Secret state in this
local MVP. Manual password changes through the UI can cause validation scripts
and dashboard reload hooks to fail with `401 Unauthorized`.
