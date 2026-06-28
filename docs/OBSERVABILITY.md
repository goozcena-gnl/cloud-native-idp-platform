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

## Centralized logs with Loki and Alloy

The platform now includes centralized Kubernetes logging.

### Components

```text
Loki
Grafana Alloy
Grafana Loki datasource
```

### Log collection flow

```text
Kubernetes pod logs
  -> Alloy
  -> Loki
  -> Grafana Explore
```

### Validation commands

```bash
./scripts/check-loki-stack.sh
./scripts/check-demo-grpc-logs.sh
```

Expected result:

```
Loki ready endpoint OK.
Loki + Alloy logs stack is healthy.
demo-grpc logs found in Loki.
demo-grpc logs are collected by Alloy and queryable in Loki.
```

### Example LogQL queries

```logql
{namespace="apps", container="demo-grpc"}
```

```logql
{namespace="apps", container="demo-grpc"} |= "starting"
```

The current setup uses ephemeral local Loki storage and is intended for local
portfolio validation. A production setup would require persistent/object
storage, retention policy, and stronger access controls.

## Structured JSON application logs

`demo-grpc` writes structured JSON logs to stdout.

The logs are collected through the existing pipeline:

```text
demo-grpc stdout
  -> Kubernetes pod logs
  -> Grafana Alloy
  -> Loki
  -> Grafana Explore
```

This improves filtering, parsing, and future log-derived metrics.

Example LogQL queries:

```logql
{namespace="apps", container="demo-grpc"} |= `"msg":"starting service"`
```

```logql
{namespace="apps", container="demo-grpc"} |= `"service":"demo-grpc"`
```

## Structured JSON logs validation

`demo-grpc` now emits structured JSON logs.

Example:

```json
{"time":"2026-06-20T13:29:30.994701865Z","level":"INFO","msg":"starting service","service":"demo-grpc","version":"sha-4398e39","grpc_port":"50051"}
```

The logs are collected through the existing pipeline:

```text
demo-grpc stdout
  -> Kubernetes pod logs
  -> Grafana Alloy
  -> Loki
  -> Grafana Explore
```

Validation command:

```bash
./scripts/check-demo-grpc-logs.sh
```

Expected result:

```
demo-grpc logs found in Loki.
Structured JSON startup logs found in Loki.
demo-grpc structured JSON logs are collected by Alloy and queryable in Loki.
```

Example LogQL queries:

```logql
{namespace="apps", container="demo-grpc"} |= `"msg":"starting service"`
```

```logql
{namespace="apps", container="demo-grpc"} |= `"service":"demo-grpc"`
```

```logql
{namespace="apps", container="demo-grpc"} |= `"version":"sha-4398e39"`
```

## Grafana logs dashboard

A dedicated Grafana dashboard is provisioned for `demo-grpc` logs.

Dashboard:

```text
demo-grpc Logs
```

Dashboard UID:

```
demo-grpc-logs
```

Main query:

```logql
{namespace="apps", container="demo-grpc"}
```

The dashboard is provisioned by the `grafana-dashboards` ArgoCD application from:

```text
platform/grafana/dashboards/demo-grpc-logs-dashboard.yaml
```

Validation command:

```bash
./scripts/check-grafana-logs-dashboard.sh
```

## Grafana logs dashboard variables

The `demo-grpc Logs` dashboard includes variables for interactive filtering.

Variables:

```text
namespace
pod
container
```

Main query pattern:

```logql
{namespace="$namespace", pod=~"$pod", container=~"$container"}
```

Default intended view:

```text
namespace = apps
pod       = All
container = demo-grpc
```

This makes the dashboard more useful after Kubernetes rollouts, because pod
names change every time a new ReplicaSet is created.

Validation command:

```bash
./scripts/check-grafana-logs-dashboard.sh
```

## Grafana SRE summary dashboard

The platform includes a GitOps-provisioned SRE summary dashboard for `demo-grpc`.

Dashboard:

```text
demo-grpc SRE Summary
```

Dashboard UID:

```
demo-grpc-sre
```

The dashboard combines Prometheus metrics and Loki logs.

### Main Prometheus signals

- Service Up
- Build info / version
- Request rate
- Error rate
- P95 latency

### Main Loki signals

- INFO logs count
- ERROR logs count
- Startup logs count
- Recent application logs

Validation command:

```bash
./scripts/check-grafana-sre-dashboard.sh
```

## Loki metrics

Loki metrics are scraped by Prometheus through a dedicated `ServiceMonitor`.

GitOps application:

```text
loki-monitoring
```

ServiceMonitor:

```
ServiceMonitor/loki
```

Useful PromQL queries:

```promql
max(up{namespace="observability", service="loki"})
```

```promql
count({__name__=~"loki_.*", namespace="observability", service="loki"})
```

Validation command:

```bash
./scripts/check-loki-metrics.sh
```

## LokiDown alert

The platform alert rules include a `LokiDown` alert.

The alert fires when Prometheus cannot scrape the Loki metrics target:

```promql
(max(up{namespace="observability", service="loki"}) == 0) or absent(up{namespace="observability", service="loki"})
```

Validation command:

```bash
./scripts/check-platform-alerts.sh
```

## Platform Prometheus alerts

The platform includes a GitOps-managed `PrometheusRule` for first-level SRE alerting.

PrometheusRule:

```text
platform-alerts
```

Managed by:

```text
Application/platform-alerts
```

Current alerts:

```text
DemoGrpcDown
GrafanaDown
ArgoCDAppOutOfSync
ArgoCDAppUnhealthy
ArgoCDApplicationControllerMetricsDown
ArgoCDRepoServerMetricsDown
ArgoCDServerMetricsDown
```

Validation command:

```bash
./scripts/check-platform-alerts.sh
```

Current limitations:

```text
LokiDown is not enabled yet because Loki metrics are not scraped by Prometheus.
Grafana dashboard validation requires a future synthetic check exporter or blackbox probe.
Alertmanager notification routing is a future improvement.
```

The dashboard is provisioned by the `grafana-dashboards` ArgoCD application from:

```text
platform/grafana/dashboards/demo-grpc-sre-dashboard.yaml
```

## ArgoCD metrics

The platform scrapes ArgoCD metrics with Prometheus.

The following ArgoCD components expose metrics through dedicated Services:

```text
argocd-application-controller-metrics : 8082
argocd-repo-server-metrics            : 8084
argocd-server-metrics                 : 8083
```

The metrics are discovered by Prometheus through:

```text
ServiceMonitor/argocd-metrics
```

The monitoring manifests are managed by:

```text
Application/argocd-monitoring
```

Useful Prometheus queries:

```promql
argocd_app_info
```

```promql
argocd_info
```

```promql
argocd_git_request_duration_seconds_count
```

Validation command:

```bash
./scripts/check-argocd-metrics.sh
```

## SRE dashboard with GitOps metrics

The `demo-grpc SRE Summary` dashboard includes application, logs, and GitOps signals.

Dashboard UID:

```text
demo-grpc-sre
```

The dashboard combines:

- Prometheus application metrics
- Loki application logs
- ArgoCD GitOps metrics

### GitOps signals

```text
Total ArgoCD applications
Synced ArgoCD applications
Healthy ArgoCD applications
OutOfSync applications
Unhealthy applications
ArgoCD version
Git request rate
Git request P95 latency
ArgoCD applications table
```

### Useful PromQL queries

```promql
sum(argocd_app_info{project="idp-platform"})
```

```promql
sum(argocd_app_info{project="idp-platform",sync_status="Synced"})
```

```promql
sum(argocd_app_info{project="idp-platform",health_status="Healthy"})
```

```promql
sum(argocd_app_info{project="idp-platform",sync_status!="Synced"}) or vector(0)
```

```promql
sum(argocd_app_info{project="idp-platform",health_status!="Healthy"}) or vector(0)
```

```promql
histogram_quantile(0.95, sum(rate(argocd_git_request_duration_seconds_bucket[30m])) by (le, request_type))
```

Validation command:

```bash
./scripts/check-grafana-sre-dashboard.sh
```
