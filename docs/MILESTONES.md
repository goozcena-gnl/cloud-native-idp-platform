# Project Milestones

This document records significant, verifiable milestones in the build-out of
the Internal Developer Platform. Each milestone captures what was achieved,
what remains manual, and the relevant security posture at that point in time.

The tone is intentionally factual: a milestone is only listed once it has been
validated against the running cluster.

---

## Milestone: GitOps Reconciliation of Platform Namespaces

**Date:** 2026-06-17
**Phase:** GitOps foundation
**Status:** Achieved and validated

### Summary

The platform now reconciles its namespaces through GitOps. ArgoCD reads the
desired state from the Git repository and continuously enforces it on the local
kind cluster, replacing the earlier manual `kubectl apply` bootstrap path for
namespaces.

### What was achieved

- A local `kind` cluster (`idp-local`) is running.
- ArgoCD is installed via the `argo/argo-cd` Helm chart in the `argocd`
  namespace, exposed locally only (ClusterIP + `kubectl port-forward`).
- ArgoCD authenticates to the **private** GitHub repository using read
  credentials supplied through a Kubernetes `Secret`. No credentials are
  committed to Git.
- An app-of-apps layout is live:
  - AppProject `idp-platform`
  - Root Application `idp-root` — **Synced** and **Healthy**
  - Child Application `platform-namespaces` — **Synced** and **Healthy**
- Platform namespaces are now reconciled through GitOps from
  `platform/namespaces`, driven by the root Application reading
  `platform/argocd/apps`.
- Git is now the source of truth for namespace state. Drift is automatically
  corrected by ArgoCD (`prune` and `selfHeal` enabled).

### Reconciliation flow

```text
ArgoCD repository credential Secret
  -> idp-root Application
  -> platform/argocd/apps
  -> platform-namespaces Application
  -> platform/namespaces
```


- `idp-root`: `Synced` / `Healthy`
- `platform-namespaces`: `Synced` / `Healthy`
- The five platform namespaces exist with their managed labels.

### What is still manual

These steps remain intentionally manual for the MVP and are candidates for
automation in later phases:

- Cluster creation (`./scripts/create-kind-cluster.sh`).
- ArgoCD installation via Helm (`./scripts/install-argocd.sh`).
- One-time creation of the ArgoCD repository credential Secret
  (`./scripts/configure-argocd-private-repo.sh`).
- One-time bootstrap of the root Application
  (`./scripts/bootstrap-argocd-apps.sh`).
- Rotating and eventually replacing the temporary Personal Access Token (PAT).

- ArgoCD is not publicly exposed (ClusterIP + port-forward only).
- The Git repository is private.
- The advanced target credential strategy is a **read-only deploy key**, a

See [security/GITHUB_TOKEN_STRATEGY.md](security/GITHUB_TOKEN_STRATEGY.md) for
the full credential strategy and migration path.

### Next steps

- Replace the PAT with a least-privilege, read-only credential
  (deploy key / GitHub App / Vault).
- Onboard the first real workload (Go gRPC reference service) as a GitOps
- a minimal Go gRPC service;
- a Dockerfile;
- a Helm chart;
- a GitOps ArgoCD Application for the service;

**Date:** 2026-06-17
**Phase:** Go gRPC reference workload
**Status:** Achieved and validated

### Summary

The `demo-grpc` Go gRPC service is now fully wired through the supply chain:

```text
Go source code
  -> Docker image (distroless, nonroot)
  -> GHCR package (ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:main)
  -> ArgoCD Application (platform/argocd/apps/demo-grpc-app.yaml)
  -> Helm chart (charts/demo-grpc)
  -> Kubernetes Deployment and Service (namespace: apps)
```

Current image:

```
ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:main
```

### Validated state

```text
idp-root              Synced   Healthy
platform-namespaces   Synced   Healthy
demo-grpc             Synced   Healthy
```

### Security posture at this milestone

- Image runs as `nonroot:nonroot` (UID 65532), distroless base.
- All restricted Pod Security Standard fields are set in the Helm chart.
- GHCR pull secret is stored only as a Kubernetes `docker-registry` Secret,
  never committed to Git.
- CI pipeline validates Go tests, Docker image, Helm chart, and Trivy security
  scans on every push to `main`.

### Known limitation

The deployment currently uses the mutable `main` tag. A future improvement
should deploy by immutable `sha-*` tag or image digest.

### Next steps

- Switch to immutable SHA tag or image digest.
- Add Prometheus metrics endpoint to `demo-grpc`.
- Add observability: structured logging, distributed tracing.
- Onboard Kyverno admission policies.

---

## Milestone: Observability foundation

**Date:** 2026-06-18
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- `kube-prometheus-stack` is deployed through ArgoCD.
- Prometheus Operator is running.
- Prometheus is running.
- Grafana is running.
- kube-state-metrics is running.
- node-exporter is running on the local kind nodes.
- Grafana is reachable through local port-forwarding.
- Grafana `/api/health` returns HTTP 200.
- Kubernetes dashboards are visible in Grafana.

### Current observability flow

```text
ArgoCD Application
  -> prometheus-community/kube-prometheus-stack Helm chart
  -> platform/helm-values/kube-prometheus-stack-values.yaml
  -> observability namespace
  -> Prometheus + Grafana + Kubernetes dashboards
```

### Local tuning

Grafana resources were increased for local kind stability because the default
MVP limits were too small for Grafana, dashboards, sidecars, and internal APIs.

### Known limitations

- Grafana uses local MVP credentials.
- Grafana has no persistent storage.
- Alertmanager is disabled.
- Application-level metrics for `demo-grpc` are not exposed yet.
- Logs and traces are not configured yet.

### Next steps

- Expose Prometheus metrics from `demo-grpc`.
- Create a ServiceMonitor for `demo-grpc`.
- Build a Grafana dashboard for `demo-grpc` gRPC request metrics.

---

## Milestone: Application metrics scraping

**Date:** 2026-06-18
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- `demo-grpc` exposes a Prometheus-compatible `/metrics` endpoint.
- The metrics endpoint runs on port `9090`.
- The Docker image exposes both gRPC and metrics ports.
- Local tests validate the gRPC healthcheck and `/metrics`.
- Container tests validate the gRPC healthcheck and `/metrics`.
- The Helm chart exposes a named `metrics` container port.
- The Kubernetes Service exposes port `9090`.
- A `ServiceMonitor` is deployed in the `apps` namespace.
- Prometheus discovers the `demo-grpc` scrape target.
- Prometheus `up` query confirms the target is scraped.

### Current metrics flow

```text
demo-grpc
  -> /metrics on port 9090
  -> Kubernetes Service metrics port
  -> ServiceMonitor apps/demo-grpc
  -> kube-prometheus-stack Prometheus
  -> Grafana / Prometheus queries
```

### Important lesson learned

The deployment currently uses the mutable GHCR tag `main`.

After publishing a new image, Kubernetes may still run an older cached image
until a rollout restart occurs. This validated the need for a future move to
immutable tags or image digests.

### Future improvements

- Deploy `demo-grpc` using `sha-*` tags or image digests.
- Add custom business metrics.
- Create a dedicated Grafana dashboard for `demo-grpc`.
- Define basic SLI/SLO panels.

---

## Milestone: Custom application metrics

**Date:** 2026-06-18
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- `demo-grpc` exposes custom Prometheus metrics.
- gRPC requests are instrumented through a unary server interceptor.
- The metrics endpoint includes build metadata.
- The metrics endpoint includes request counters.
- The metrics endpoint includes request duration histograms.
- Local tests validate custom metrics.
- Container tests validate custom metrics.
- Kubernetes Service validation confirms custom metrics are reachable.
- Prometheus successfully queries custom `demo_grpc_*` metrics.

### Custom metrics

```text
demo_grpc_build_info
demo_grpc_grpc_requests_total
demo_grpc_grpc_request_duration_seconds
```

### Current metrics flow

```text
gRPC request
  -> unary interceptor
  -> demo_grpc_* custom metrics
  -> /metrics endpoint
  -> ServiceMonitor
  -> Prometheus
  -> Grafana / PromQL
```

### Important lesson learned

The project now demonstrates both infrastructure observability and
application-level instrumentation.

### Future improvements

- Add business-level metrics.
- Create a Grafana dashboard for `demo-grpc`.
- Define basic SLI/SLO queries.
- Add latency percentile panels.
- Add request rate and error rate panels.

---

## Milestone: GitOps-provisioned Grafana dashboard

**Date:** 2026-06-18
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- A dedicated `demo-grpc` Grafana dashboard is stored in Git.
- The dashboard is deployed through an ArgoCD Application.
- The dashboard is provisioned as a Kubernetes ConfigMap.
- Grafana sidecar discovers the dashboard through the `grafana_dashboard=1` label.
- The dashboard is visible in Grafana.
- Grafana API confirms the dashboard is searchable.
- Grafana API confirms the dashboard is accessible by UID.

### Dashboard flow

```text
Git repository
  -> ArgoCD Application grafana-dashboards
  -> ConfigMap observability/demo-grpc-dashboard
  -> Grafana dashboard sidecar
  -> Grafana dashboard UID demo-grpc
```

### Dashboard panels

- Service information;
- Build info;
- Request rate;
- Error rate;
- Request latency (p95);
- Requests by method and code.

### Important local note

Grafana currently runs as an MVP local instance without persistent storage.
Manual UI changes, such as changing the admin password, are not part of GitOps
state and can create drift. Future secret handling should be moved to Vault or
External Secrets.

---

## Milestone: Immutable image tag deployment

**Date:** 2026-06-18
**Phase:** Supply chain / deployment discipline
**Status:** Achieved

### Summary

The `demo-grpc` ArgoCD Application no longer references the mutable `:main`
tag. It now pins to the exact SHA digest tag published by the CI workflow for
the last image-producing commit.

```yaml
image:
  tag: sha-1b1db1a      # immutable — maps to one specific image layer set
  pullPolicy: IfNotPresent
env:
  APP_VERSION: sha-1b1db1a
```

### What changed

| Field | Before | After |
|---|---|---|
| `image.tag` | `main` (mutable) | `sha-1b1db1a` (immutable) |
| `image.pullPolicy` | `Always` | `IfNotPresent` |
| `APP_VERSION` | `ghcr-main` | `sha-1b1db1a` |

### Why this matters

With a mutable tag ArgoCD cannot detect that a new image was pushed; the
manifest diff is empty and no rollout fires. The previous workaround was
`kubectl rollout restart`, which is error-prone and untracked.

With an immutable SHA tag:

- Every image upgrade is an explicit Git commit.
- ArgoCD detects the manifest diff and fires a real rollout automatically.
- The running image is fully traceable back to the triggering commit.
- `pullPolicy: IfNotPresent` is correct and efficient because the tag will
  never point to a different layer set.

### CI workflow

The `publish-demo-grpc.yml` workflow already publishes two tags on every
push to `main` that touches `services/demo-grpc/**` or `charts/demo-grpc/**`:

```yaml
tags: |
  type=raw,value=main           # mutable alias — kept for convenience
  type=sha,prefix=sha-,format=short   # immutable 7-char SHA tag
```

No changes were needed to the workflow itself.

### Deployment upgrade procedure

When a new version of `demo-grpc` is ready to deploy:

1. Push code changes to `main` (triggers the publish workflow).
2. Identify the short SHA of that commit: `git rev-parse --short=7 HEAD`.
3. Update `platform/argocd/apps/demo-grpc-app.yaml`:
   - `image.tag: sha-<new-sha>`
   - `env.APP_VERSION: sha-<new-sha>`
4. Commit and push the manifest change.
5. ArgoCD detects the diff and rolls out the new image automatically.

### Validation after cluster restart

```bash
# Confirm ArgoCD synced with the new tag
kubectl -n apps get deployment demo-grpc \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# Should print:
# ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:sha-1b1db1a

# Full metrics and dashboard validation
./scripts/check-demo-grpc-metrics.sh
./scripts/check-grafana-dashboard.sh
```

---

## Milestone 11 — Centralized Kubernetes logs with Loki and Alloy

**Date:** 2026-06-20
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- Loki is deployed through ArgoCD.
- Grafana Alloy is deployed through ArgoCD.
- Loki runs in local monolithic mode.
- Alloy collects Kubernetes pod logs through the Kubernetes API.
- Logs are forwarded from Alloy to Loki.
- Grafana has a Loki datasource provisioned through GitOps.
- Loki `/ready` returns `ready`.
- `demo-grpc` logs are queryable through Loki.
- `demo-grpc` logs are visible in Grafana Explore.
- Validation scripts confirm the Loki stack and application logs.

### Current logs flow

```text
Kubernetes pod logs
  -> Grafana Alloy
  -> Loki
  -> Grafana Loki datasource
  -> Grafana Explore
  -> LogQL queries
```

### Validated LogQL query

```logql
{namespace="apps", container="demo-grpc"}
```

### Example returned logs

```
starting service=demo-grpc version=sha-1b1db1a grpc_port=50051
starting metrics server port=9090 path=/metrics
```

### Important implementation choice

Promtail was intentionally not used. The project uses Grafana Alloy for log
collection because Alloy is the forward-looking Grafana telemetry collector
and is better aligned with the current Loki ecosystem.

### Local limitations

- Loki storage is ephemeral.
- Loki is not exposed publicly.
- No retention/persistence strategy is configured yet.
- No alerting rules are configured on logs yet.
- No structured JSON log parsing pipeline is configured yet.

### Future improvements

- Add structured log parsing.
- Add log-based dashboard panels.
- Add error log queries.
- Add log-derived metrics.
- Add Tempo and OpenTelemetry traces.

---

## Milestone 12 — Structured JSON application logs

**Date:** 2026-06-20
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- `demo-grpc` now emits structured JSON logs to stdout.
- Startup logs include explicit fields such as `service`, `version`, `grpc_port`, `metrics_port`, and `path`.
- Local tests validate structured JSON logs.
- Container tests validate structured JSON logs.
- The Docker image was rebuilt and published to GHCR.
- The deployment was pinned to the immutable image tag `sha-4398e39`.
- Kubernetes logs show JSON-formatted application logs.
- Loki contains the structured JSON logs.
- The validation script confirms that structured logs are queryable through Loki.
- CI is green.

### Example structured logs

```json
{"time":"2026-06-20T13:29:30.994701865Z","level":"INFO","msg":"starting service","service":"demo-grpc","version":"sha-4398e39","grpc_port":"50051"}
{"time":"2026-06-20T13:29:30.994858581Z","level":"INFO","msg":"starting metrics server","service":"demo-grpc","version":"sha-4398e39","metrics_port":"9090","path":"/metrics"}
```

### Current logs flow

```text
demo-grpc JSON stdout
  -> Kubernetes pod logs
  -> Grafana Alloy
  -> Loki
  -> Grafana Explore
  -> LogQL queries
```

### Important implementation detail

Older text logs can still appear in Loki for previous pods. The current
running pod emits structured JSON logs.

### Future improvements

- Add structured log parsing in Alloy or Loki queries.
- Add log-based dashboard panels.
- Add error-level log queries.
- Add log-derived metrics.
- Add trace IDs once OpenTelemetry tracing is introduced.

---

## Milestone 13 — GitOps-provisioned Grafana logs dashboard

**Date:** 2026-06-20
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- A dedicated Grafana dashboard for `demo-grpc` logs is provisioned through GitOps.
- The dashboard is stored as a Kubernetes ConfigMap.
- The ConfigMap is managed by the existing `grafana-dashboards` ArgoCD application.
- The dashboard uses the Loki datasource.
- The dashboard UID is `demo-grpc-logs`.
- Grafana API validation confirms that the dashboard is reachable.
- CI is green.

### Dashboard

```text
demo-grpc Logs
```

Dashboard UID:

```
demo-grpc-logs
```

Main LogQL query:

```logql
{namespace="apps", container="demo-grpc"}
```

### Panels

- Recent `demo-grpc` logs
- Startup logs
- Error logs
- Log rate
- INFO logs count
- ERROR logs count

### Validation command

```bash
./scripts/check-grafana-logs-dashboard.sh
```

Expected result:

```
Grafana health OK.
Loki datasource OK.
Grafana logs dashboard OK.
Grafana logs dashboard is provisioned and reachable.
```

### Current observability coverage

```text
Metrics dashboard:  demo-grpc -> Prometheus -> Grafana
Logs dashboard:     demo-grpc -> Alloy -> Loki -> Grafana
```

### Future improvements

- Add dashboard variables for namespace, pod, and container.
- Add log-level filters.
- Add JSON parsing-based panels.
- Add log-derived metrics.
- Add trace ID filters when OpenTelemetry tracing is introduced.

---

## Milestone 14 — Grafana logs dashboard variables

**Date:** 2026-06-20
**Phase:** Observability and security
**Status:** Achieved and validated

### Validated outcomes

- The `demo-grpc Logs` dashboard now includes Grafana variables.
- Variables allow filtering logs by namespace, pod, and container.
- The dashboard remains provisioned through GitOps.
- The dashboard is still managed by the `grafana-dashboards` ArgoCD application.
- The dashboard uses the Loki datasource.
- The validation script confirms that the dashboard and variables are reachable through the Grafana API.
- CI is green.

### Dashboard UID

```text
demo-grpc-logs
```

### Dashboard variables

```text
namespace
pod
container
```

### Default operational view

```text
namespace = apps
pod       = All
container = demo-grpc
```

### Main parameterized LogQL query

```logql
{namespace="$namespace", pod=~"$pod", container=~"$container"}
```

### Validation command

```bash
./scripts/check-grafana-logs-dashboard.sh
```

Expected result:

```
Grafana health OK.
Loki datasource OK.
Grafana logs dashboard OK.
Grafana logs dashboard variables OK.
Grafana logs dashboard is provisioned and reachable.
```

### Why this matters

The logs dashboard is no longer hardcoded to a single pod. It can follow new
`demo-grpc` pods after rollouts and can be reused more easily for troubleshooting.

---

## Milestone 15 — Grafana SRE summary dashboard

**Date:** 2026-06-21
**Phase:** Observability and SRE
**Status:** Achieved and validated

### Validated outcomes

- A dedicated Grafana SRE summary dashboard is provisioned through GitOps.
- The dashboard is stored as a Kubernetes ConfigMap.
- The ConfigMap is managed by the existing `grafana-dashboards` ArgoCD application.
- The dashboard uses both Prometheus and Loki datasources.
- The dashboard UID is `demo-grpc-sre`.
- Grafana API validation confirms that the dashboard is reachable.
- CI is green.

### Dashboard

```text
demo-grpc SRE Summary
```

Dashboard UID:

```
demo-grpc-sre
```

Prometheus datasource UID: `prometheus` — Loki datasource UID: `loki`

### Key Prometheus panels

- Service Up
- Current build info
- Request rate
- Error rate
- P95 latency
- gRPC request rate over time
- P95 latency over time

### Key Loki panels

- INFO logs count
- ERROR logs count
- Startup logs count
- Recent application logs

### Validated Prometheus queries

```promql
demo_grpc_build_info
```

```promql
sum(rate(demo_grpc_grpc_requests_total[5m]))
```

```promql
histogram_quantile(0.95, sum(rate(demo_grpc_grpc_request_duration_seconds_bucket[5m])) by (le))
```

### Validated Loki queries

```logql
sum(count_over_time({namespace="apps", container="demo-grpc"} | json | level="INFO" [24h])) or vector(0)
```

```logql
sum(count_over_time({namespace="apps", container="demo-grpc"} | json | level="ERROR" [24h])) or vector(0)
```

```logql
{namespace="apps", container="demo-grpc"}
```

### Current observability coverage

```text
Metrics:     demo-grpc -> ServiceMonitor -> Prometheus -> Grafana
Logs:        demo-grpc JSON stdout -> Alloy -> Loki -> Grafana
SRE summary: Prometheus + Loki -> Grafana SRE dashboard
```

### Validation command

```bash
./scripts/check-grafana-sre-dashboard.sh
```

Expected result:

```
Grafana health OK.
Prometheus datasource OK.
Loki datasource OK.
Grafana SRE dashboard OK.
Grafana SRE summary dashboard is provisioned and reachable.
```

### Future improvements

- Add dashboard variables for namespace, pod, and container.
- Add ArgoCD application health once ArgoCD metrics are scraped.
- Add Kubernetes pod restart panels.
- Add log-derived error rate.
- Add trace panels once OpenTelemetry and Tempo are introduced.

---

## Milestone 16 — ArgoCD metrics scraped by Prometheus

**Date:** 2026-06-21
**Phase:** Observability and GitOps
**Status:** Achieved and validated

### Validated outcomes

- Dedicated metrics Services were created for ArgoCD components.
- `argocd-application-controller` metrics are exposed on port 8082.
- `argocd-repo-server` metrics are exposed on port 8084.
- `argocd-server` metrics are exposed on port 8083.
- A dedicated `ServiceMonitor` named `argocd-metrics` was created.
- The `ServiceMonitor` is selected by `kube-prometheus-stack` through the `release: kube-prometheus-stack` label.
- The `argocd-monitoring` ArgoCD Application manages the monitoring manifests through GitOps.
- Prometheus successfully scrapes ArgoCD metrics.
- CI is green.

### GitOps application

```text
argocd-monitoring
```

### Created metrics Services

```text
argocd-application-controller-metrics
argocd-repo-server-metrics
argocd-server-metrics
```

### Created ServiceMonitor

```text
argocd-metrics
```

### Validated Prometheus metrics

```promql
argocd_app_info
```

```promql
argocd_info
```

```promql
argocd_git_request_duration_seconds_count
```

### Validation command

```bash
./scripts/check-argocd-metrics.sh
```

Expected result:

```
ArgoCD metrics are scraped by Prometheus.
```

### Why this matters

The platform can now observe GitOps health directly from Prometheus. This
enables future dashboards and alerts for ArgoCD application sync status,
health status, Git repository latency, reconciliation activity, and controller
health.

---

## Milestone 17 — SRE dashboard enriched with GitOps metrics

**Date:** 2026-06-21
**Phase:** Observability, SRE, and GitOps
**Status:** Achieved and validated

### Validated outcomes

- The `demo-grpc SRE Summary` dashboard now includes GitOps metrics.
- The dashboard combines application metrics, application logs, and ArgoCD metrics.
- ArgoCD application health and sync status are visible in Grafana.
- ArgoCD repository activity is visible through repo-server Git request metrics.
- The dashboard is provisioned through GitOps.
- The dashboard is managed by the `grafana-dashboards` ArgoCD application.
- Grafana API validation confirms that the dashboard is reachable.
- CI is green.

### Dashboard

```text
demo-grpc SRE Summary
```

Dashboard UID:

```
demo-grpc-sre
```

### GitOps panels added

```text
GitOps Apps Total
GitOps Apps Synced
GitOps Apps Healthy
OutOfSync Apps
Unhealthy Apps
ArgoCD version
Git request rate by type
Git request P95 by type
ArgoCD applications table
```

### Validated Prometheus queries

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
argocd_info
```

```promql
sum(rate(argocd_git_request_duration_seconds_count[30m])) by (request_type)
```

```promql
histogram_quantile(0.95, sum(rate(argocd_git_request_duration_seconds_bucket[30m])) by (le, request_type))
```

### Current SRE coverage

```text
Application metrics: demo-grpc -> Prometheus -> Grafana
Application logs:    demo-grpc -> Alloy -> Loki -> Grafana
GitOps metrics:      ArgoCD -> Prometheus -> Grafana
SRE summary:         Prometheus + Loki + ArgoCD metrics -> Grafana
```

### Validation command

```bash
./scripts/check-grafana-sre-dashboard.sh
```

Expected result:

```
Grafana health OK.
Prometheus datasource OK.
Loki datasource OK.
Grafana SRE dashboard OK.
Grafana SRE summary dashboard is provisioned and reachable.
```

### Why this matters

The platform now demonstrates an SRE-style operational view that connects
workload health, logs, deployment version, GitOps reconciliation state, and
Git repository activity in a single dashboard.

---

## Milestone 18 — Platform Prometheus alerts

**Date:** 2026-06-28
**Phase:** Observability, SRE, and Alerting
**Status:** Achieved and validated

### Validated outcomes

- A dedicated `PrometheusRule` named `platform-alerts` is provisioned through GitOps.
- The rule is selected by Prometheus through the `release: kube-prometheus-stack` label.
- The rule is managed by the `platform-alerts` ArgoCD Application.
- Prometheus successfully loads all platform alert rules.
- The alert expressions are validated against live Prometheus data.
- No platform alert is currently firing.
- CI is green.

### GitOps application

```text
platform-alerts
```

### PrometheusRule

```
platform-alerts
```

### Alert rules added

```text
DemoGrpcDown
GrafanaDown
ArgoCDAppOutOfSync
ArgoCDAppUnhealthy
ArgoCDApplicationControllerMetricsDown
ArgoCDRepoServerMetricsDown
ArgoCDServerMetricsDown
```

### Validated expressions

```promql
max(up{namespace="apps", service="demo-grpc"})
```

```promql
max(up{namespace="observability", service="kube-prometheus-stack-grafana"})
```

```promql
max(up{namespace="argocd", service="argocd-application-controller-metrics"})
```

```promql
max(up{namespace="argocd", service="argocd-repo-server-metrics"})
```

```promql
max(up{namespace="argocd", service="argocd-server-metrics"})
```

```promql
sum(argocd_app_info{project="idp-platform", sync_status!="Synced"}) or vector(0)
```

```promql
sum(argocd_app_info{project="idp-platform", health_status!="Healthy"}) or vector(0)
```

### Validation command

```bash
./scripts/check-platform-alerts.sh
```

Expected result:

```
All platform alert rules are loaded.
No platform alert is firing.
Platform Prometheus alerts are loaded and healthy.
```

### Notes

- Loki alerting is intentionally not included yet because Loki metrics are not currently scraped by Prometheus.
- Grafana dashboard validation is not included as a PrometheusRule yet because it requires either a synthetic exporter, blackbox exporter, or scheduled external check exposing metrics to Prometheus.
- Alertmanager notification routing is a future improvement. The current milestone validates Prometheus rule loading and alert expression health.

---

## Milestone 19 — Loki metrics and LokiDown alert

**Date:** 2026-06-28
**Phase:** Observability, SRE, and Alerting
**Status:** Achieved and validated

### Validated outcomes

- Loki exposes `/metrics` on the `http-metrics` port.
- A dedicated `ServiceMonitor` named `loki` is provisioned through GitOps.
- The `ServiceMonitor` is selected by Prometheus through the `release: kube-prometheus-stack` label.
- The `loki-monitoring` ArgoCD Application manages the Loki monitoring manifests.
- Prometheus successfully scrapes Loki metrics.
- Loki-owned `loki_*` metrics are available in Prometheus.
- The `LokiDown` alert was added to the platform `PrometheusRule`.
- The `platform-alerts` ArgoCD Application remains Synced and Healthy.
- No platform alert is currently firing.
- CI is green.

### GitOps application

```text
loki-monitoring
```

### ServiceMonitor

```
ServiceMonitor/loki
```

### Validated Loki target query

```promql
max(up{namespace="observability", service="loki"})
```

### Validated Loki metrics count query

```promql
count({__name__=~"loki_.*", namespace="observability", service="loki"})
```

### Validated alert

```
LokiDown
```

### Validation commands

```bash
./scripts/check-loki-metrics.sh
./scripts/check-platform-alerts.sh
```

Expected results:

```
Loki metrics are scraped by Prometheus.
Platform Prometheus alerts are loaded and healthy.
```

### Why this matters

The platform can now alert on the availability of the log storage backend
itself. This closes the monitoring loop for application logs: logs are
collected by Alloy, stored in Loki, queried in Grafana, scraped by Prometheus,
and protected by a Prometheus alert.

---

## Milestone 20 — SRE dashboard enriched with Loki metrics

**Date:** 2026-06-28
**Phase:** Observability, SRE, Logging, and Dashboards
**Status:** Achieved and validated

### Validated outcomes

- The `demo-grpc SRE Summary` dashboard now includes Loki backend metrics.
- The dashboard combines application metrics, application logs, GitOps metrics, and logging backend metrics.
- Loki availability is visible in Grafana.
- Loki metric cardinality is visible through the Loki metrics count panel.
- Loki request rate and P95 latency are visible by route.
- Loki ingestion throughput is visible through bytes/sec and lines/sec panels.
- Loki memory usage and ingester stream count are visible.
- The dashboard is provisioned through GitOps.
- The dashboard is managed by the `grafana-dashboards` ArgoCD Application.
- Grafana API validation confirms that the dashboard is reachable.
- Loki metrics validation confirms that Prometheus scrapes Loki successfully.
- CI is green.

### Dashboard

```text
demo-grpc SRE Summary
```

Dashboard UID:

```
demo-grpc-sre
```

### Logging backend panels added

```text
Logging backend overview
Loki backend up
Loki metrics count
Loki 5xx rate
Loki 4xx rate
Loki ingested bytes/sec
Loki ingested lines/sec
Loki ingester streams
Loki memory usage
Loki request rate by route/status
Loki request P95 by route
```

### Validated Prometheus queries

```promql
max(up{namespace="observability", service="loki"})
```

```promql
count({__name__=~"loki_.*", namespace="observability", service="loki"})
```

```promql
sum(rate(loki_request_duration_seconds_count{namespace="observability", service="loki"}[5m])) by (route, status_code)
```

```promql
histogram_quantile(0.95, sum(rate(loki_request_duration_seconds_bucket{namespace="observability", service="loki"}[5m])) by (le, route))
```

```promql
sum(rate(loki_distributor_bytes_received_total{namespace="observability", service="loki"}[5m]))
```

```promql
sum(rate(loki_distributor_lines_received_total{namespace="observability", service="loki"}[5m]))
```

```promql
sum(loki_ingester_memory_streams{namespace="observability", service="loki"})
```

```promql
process_resident_memory_bytes{namespace="observability", service="loki"}
```

### Validation commands

```bash
./scripts/check-grafana-sre-dashboard.sh
./scripts/check-loki-metrics.sh
```

Expected results:

```
Grafana SRE summary dashboard is provisioned and reachable.
Loki metrics are scraped by Prometheus.
```

### Why this matters

The platform now exposes a complete SRE view that connects workload health,
GitOps state, application logs, and logging backend health in a single
GitOps-managed Grafana dashboard.

---

## Milestone 21 - Alertmanager routing and alert runbooks

**Date:** 2026-06-28
**Phase:** Observability, SRE, Alerting, and Incident Response
**Status:** Achieved and validated

### Validated outcomes

- Alertmanager is enabled through the GitOps-managed `kube-prometheus-stack` Helm values.
- The `kube-prometheus-stack-alertmanager` Alertmanager custom resource is created.
- The Alertmanager pod is running and ready.
- Prometheus discovers an active Alertmanager target.
- Alertmanager exposes its readiness and alerts API.
- Alertmanager routing configuration is loaded.
- The following receivers are configured:
  - `local-null`
  - `platform-critical`
  - `platform-warning`
  - `gitops-alerts`
- Platform alerts include `runbook_url` annotations.
- The runbook validation confirms `8/8` platform alerts have runbook URLs.
- Platform alert expressions are still healthy.
- No platform alert is currently firing.
- CI is green.

### Validation commands

```bash
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Expected results:

```text
Alert runbook_url annotations OK (8/8).
Platform Prometheus alerts are loaded and healthy.
Alertmanager is enabled, reachable, and routing config is loaded.
```

Alertmanager routing path:

```text
PrometheusRule -> Prometheus -> Alertmanager -> route -> receiver
```

Runbook path:

```text
PrometheusRule annotation -> runbook_url -> docs/RUNBOOKS.md
```

### Why this matters

The platform now goes beyond simple alert definition. Alerts are discoverable by Prometheus,
routed through Alertmanager, associated with receivers, and linked to operational runbooks.
This creates a realistic incident-response foundation for the local platform.

---

## Milestone 22 — Distributed tracing with OpenTelemetry and Tempo

The platform now includes distributed tracing for the `demo-grpc` reference service.

Implemented capabilities:

- Tempo deployed through ArgoCD using the Grafana Helm chart.
- Tempo datasource provisioned in Grafana.
- `demo-grpc` instrumented with OpenTelemetry gRPC server instrumentation.
- Traces exported over OTLP gRPC to Tempo.
- Trace validation automated with `scripts/check-demo-grpc-traces.sh`.
- Grafana Explore can query `demo-grpc` traces by service name.
- Portfolio screenshots added for Tempo Explore, trace details, and Tempo API search.

Validation commands:

```bash
./scripts/check-tempo-stack.sh
./scripts/check-demo-grpc-traces.sh
```

---

## Milestone 23 — Tempo monitoring in the SRE dashboard

The SRE dashboard now includes Tempo tracing backend health panels.

Implemented capabilities:

- Tempo availability panel based on Prometheus `up`.
- Tempo metrics count panel.
- Tempo ingested spans rate panel.
- Tempo request 5xx rate panel.
- Tempo request duration p95 panel.
- Dashboard validation through `scripts/check-grafana-sre-dashboard.sh`.
- Portfolio screenshot added for the Tempo SRE dashboard section.

Validation commands:

```bash
./scripts/check-tempo-stack.sh
./scripts/check-grafana-sre-dashboard.sh
```

---

## Milestone 24 — SLO and error budget dashboard

The SRE dashboard now includes service-level objective panels for the
`demo-grpc` reference service.

Implemented capabilities:

- Availability target panel based on the 99.5% SLO.
- Success ratio panel based on Prometheus recording rules.
- Error ratio panel.
- Error budget burn-rate panel.
- Request rate panel.
- Latency p95 panel.
- Validation through `scripts/check-demo-grpc-slo.sh`.
- Dashboard validation through `scripts/check-grafana-sre-dashboard.sh`.
- Portfolio screenshot added for the SLO dashboard section.

Validation commands:

```bash
./scripts/check-demo-grpc-slo.sh
./scripts/check-grafana-sre-dashboard.sh
```

---

## Milestone 25 — Reliability drill: demo-grpc outage simulation

The platform now includes a controlled incident drill for the `demo-grpc` reference service.

Implemented capabilities:

- Automated outage simulation by scaling `demo-grpc` to zero replicas.
- Temporary ArgoCD automated sync suspension for controlled incident testing.
- Prometheus alert lifecycle validation:
  - `DemoGrpcDown` pending.
  - `DemoGrpcDown` firing.
  - `DemoGrpcDown` cleared after recovery.
- Alertmanager reception validation for the active critical alert.
- Automatic restoration of the workload replica count.
- Automatic restoration of ArgoCD automated sync.
- Post-drill platform validation through existing health-check scripts.
- Incident drill documentation in `docs/INCIDENT_DRILLS.md`.

Validation commands:

```bash
./scripts/drill-demo-grpc-down.sh
./scripts/check-demo-grpc-slo.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

---

## Milestone 26 — Reliability drill: Tempo outage simulation

The platform now includes a controlled incident drill for the Tempo tracing backend.

Implemented capabilities:

- Automated Tempo outage simulation by scaling the Tempo StatefulSet to zero replicas.
- Temporary ArgoCD automated sync suspension for controlled incident testing.
- Prometheus alert lifecycle validation:
  - `TempoDown` pending.
  - `TempoDown` firing.
  - `TempoDown` cleared after recovery.
- Alertmanager reception validation for the active critical alert.
- `TempoDown` routed to the `platform-critical` receiver.
- Automatic restoration of the Tempo StatefulSet replica count.
- Automatic restoration of ArgoCD automated sync.
- Post-drill validation through Tempo, platform alert, and Alertmanager health checks.
- Incident drill documentation in `docs/INCIDENT_DRILLS.md`.

Validation commands:

```bash
./scripts/drill-tempo-down.sh
./scripts/check-tempo-stack.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

---

## Milestone 27 — Reliability drill: Loki outage simulation

The platform now includes a controlled incident drill for the Loki logging backend.

Implemented capabilities:

- Automated Loki outage simulation by scaling the Loki StatefulSet to zero replicas.
- Temporary ArgoCD automated sync suspension for controlled incident testing.
- Prometheus alert lifecycle validation:
  - `LokiDown` pending.
  - `LokiDown` firing.
  - `LokiDown` cleared after recovery.
- Alertmanager reception validation for the active critical alert.
- `LokiDown` routed to the `platform-critical` receiver.
- Automatic restoration of the Loki StatefulSet replica count.
- Automatic restoration of ArgoCD automated sync.
- Post-drill validation through Loki metrics, platform alert, and Alertmanager health checks.
- Incident drill documentation in `docs/INCIDENT_DRILLS.md`.

Validation commands:

```bash
./scripts/drill-loki-down.sh
./scripts/check-loki-metrics.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

---

## Milestone 28 — Reliability drill: Grafana outage simulation

The platform now includes a controlled incident drill for the Grafana observability frontend.

Implemented capabilities:

- Automated Grafana outage simulation by scaling the Grafana Deployment to zero replicas.
- Temporary ArgoCD automated sync suspension for controlled incident testing.
- Prometheus alert lifecycle validation:
  - `GrafanaDown` pending.
  - `GrafanaDown` firing.
  - `GrafanaDown` cleared after recovery.
- Alertmanager reception validation for the active warning alert.
- `GrafanaDown` routed to the `platform-warning` receiver.
- Automatic restoration of the Grafana Deployment replica count.
- Automatic restoration of ArgoCD automated sync.
- Post-drill validation through Grafana dashboard, platform alert, and Alertmanager health checks.
- Incident drill documentation in `docs/INCIDENT_DRILLS.md`.

Validation commands:

```bash
./scripts/drill-grafana-down.sh
./scripts/check-grafana-sre-dashboard.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

---

## Milestone 29 — Reliability drill suite summary

The platform now includes a documented reliability drill suite covering application, tracing, logging, and observability frontend outages.

Implemented capabilities:

- Reliability drill matrix added to `docs/INCIDENT_DRILLS.md`.
- Portfolio evidence section added for the full drill suite.
- Four controlled incident drills documented:
  - `DemoGrpcDown` for application workload failure.
  - `TempoDown` for tracing backend failure.
  - `LokiDown` for logging backend failure.
  - `GrafanaDown` for observability frontend failure.
- Alertmanager routing expectations documented:
  - `platform-critical` for application, Tempo, and Loki failures.
  - `platform-warning` for Grafana frontend failure.
- Recovery validation commands documented for each layer.
- Incident lifecycle standardized across all drills:
  - failure injection;
  - Prometheus detection;
  - pending alert;
  - firing alert;
  - Alertmanager routing;
  - service recovery;
  - alert clearing;
  - post-incident validation.

Validation commands:

```bash
git diff --check
git status
```

---

## Milestone 30 — Logs and traces correlation

The platform now supports correlation between application logs in Loki and distributed traces in Tempo.

Implemented capabilities:

- Added gRPC request logging interceptor to `demo-grpc`.
- Added structured JSON logs for completed gRPC requests.
- Added OpenTelemetry trace context to logs:
  - `trace_id`;
  - `span_id`.
- Added gRPC request metadata to logs:
  - `grpc.method`;
  - `grpc.code`;
  - `duration_ms`.
- Published and deployed the trace-correlated `demo-grpc` image through GHCR and ArgoCD.
- Validated that the deployed GitOps image is:
  - `ghcr.io/goozdu12/cloud-native-idp-platform/demo-grpc:sha-1dba716`.
- Added automated correlation validation script:
  - `scripts/check-demo-grpc-log-trace-correlation.sh`.
- Validated that a `trace_id` from a Kubernetes log line is found in Loki.
- Validated that the same `trace_id` is found in Tempo.
- Validated that the Tempo trace contains:
  - `service.name=demo-grpc`;
  - `service.version=sha-1dba716`;
  - `grpc.health.v1.Health/Check`;
  - `rpc.response.status_code=OK`.

Validation command:

```bash
./scripts/check-demo-grpc-log-trace-correlation.sh
```

---

## Milestone 31 — Grafana Loki to Tempo trace links

Grafana now supports direct navigation from Loki log lines to Tempo traces.

Implemented capabilities:

- Added `derivedFields` to the Loki datasource.
- Extracted `trace_id` from structured JSON logs using a regex matcher.
- Linked the extracted `trace_id` to the Tempo datasource.
- Validated the datasource through:
  - GitOps ConfigMap;
  - Grafana provisioning file;
  - Grafana datasource API;
  - Grafana Explore UI.
- Validated that a `demo-grpc` log line in Loki exposes a `TraceID` link.
- Validated that clicking the link opens the matching Tempo trace.
- Validated that the trace contains the `grpc.health.v1.Health/Check` server span.

Validated workflow:

```text
demo-grpc request
  -> JSON log with trace_id
  -> Loki
  -> Grafana Explore
  -> TraceID derived field
  -> Tempo trace
```

---

## Milestone 32 — Security baseline validation

The platform now includes a repeatable security baseline validation for the `demo-grpc` workload.

Validated controls:

- non-root execution;
- fixed non-root UID/GID;
- RuntimeDefault seccomp profile;
- privilege escalation disabled;
- read-only root filesystem;
- Linux capabilities dropped;
- CPU and memory requests and limits;
- Pod Security Admission warn/audit labels.

Validation command:

```bash
./scripts/check-demo-grpc-security-baseline.sh
```

---

## Milestone 33 — Kyverno GitOps installation

Kyverno is now installed through ArgoCD and managed declaratively.

Validated components:

- Kyverno admission controller;
- Kyverno background controller;
- Kyverno cleanup controller;
- Kyverno reports controller;
- Kyverno CRDs;
- validating webhooks;
- mutating webhooks.

Validation command:

```bash
./scripts/check-kyverno-stack.sh
```

---

## Milestone 34 — Kyverno baseline policies in Audit mode

The platform now includes a baseline Kyverno `ClusterPolicy` for workloads in the `apps` namespace.

Policy:

```text
idp-apps-pod-security-baseline
```

Validated rules:

- require pod security context;
- disallow privilege escalation;
- require read-only root filesystem;
- require dropping all Linux capabilities;
- require CPU and memory requests and limits.

Validation command:

```bash
./scripts/check-kyverno-policies.sh
```

---

## Milestone 35 — Kyverno Audit mode proof

The platform now proves that Kyverno can detect non-compliant workloads without blocking them.

Validated behavior:

- an intentionally non-compliant pod is admitted;
- Pod Security Admission emits warnings;
- Kyverno records violations in a PolicyReport;
- five policy violations are detected;
- the test pod is cleaned up automatically.

Validation command:

```bash
./scripts/check-kyverno-audit-mode.sh
```

---

## Milestone 36 — NetworkPolicy baseline

The `apps` namespace now has ingress isolation through Kubernetes NetworkPolicies.

Implemented policies:

```text
apps-default-deny-ingress
demo-grpc-allow-ingress
```

Validated behavior:

- traffic from `apps` to `demo-grpc` metrics is allowed;
- traffic from `observability` to `demo-grpc` metrics is allowed;
- traffic from an unrelated namespace to `demo-grpc` metrics is blocked;
- observability checks continue to pass after isolation.

Validation command:

```bash
./scripts/check-network-policies.sh
```

---

## Milestone 37 — Security governance portfolio evidence

The security and governance phase now includes portfolio-ready visual evidence.

Added screenshots:

```text
01-demo-grpc-security-baseline.png
02-kyverno-stack-validation.png
03-kyverno-audit-mode-violations.png
04-network-policy-baseline-validation.png
05-argocd-security-apps-synced.png
```

The screenshots prove:

- hardened workload configuration;
- Kyverno installed and healthy;
- Kyverno Audit mode detects non-compliant workloads;
- NetworkPolicies allow expected traffic and block unrelated namespaces;
- security-related ArgoCD applications are Synced and Healthy.

Documentation:

```text
docs/SECURITY_GOVERNANCE.md
docs/assets/security-governance/
```
