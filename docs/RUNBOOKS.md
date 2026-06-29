# Platform Alert Runbooks

This document provides investigation steps for the platform alerts defined in
`platform/observability/alerts/platform-alerts.yaml`.

## DemoGrpcDown

### Meaning

Prometheus cannot scrape the `demo-grpc` metrics target in the `apps` namespace.

### Impact

The demo application may be down, unreachable, or its metrics endpoint may be broken.

### Investigation

```bash
kubectl -n apps get pods -l app.kubernetes.io/name=demo-grpc -o wide
kubectl -n apps get svc demo-grpc -o wide
kubectl -n apps get endpoints demo-grpc
kubectl -n apps logs deploy/demo-grpc --tail=100
./scripts/check-demo-grpc-metrics.sh
```

### Common causes

- Pod not running.
- Service selector mismatch.
- Metrics port not exposed.
- ServiceMonitor selector mismatch.
- Application crash or failed rollout.

### Recovery

```bash
kubectl -n argocd get application demo-grpc
kubectl -n apps rollout status deploy/demo-grpc
```

If the application is out of sync, refresh or sync it through ArgoCD.

## GrafanaDown

### Meaning

Prometheus cannot scrape the Grafana target in the `observability` namespace.

### Impact

Dashboards may be unavailable or Grafana may not be healthy.

### Investigation

```bash
kubectl -n observability get pods -l app.kubernetes.io/name=grafana -o wide
kubectl -n observability get svc kube-prometheus-stack-grafana
kubectl -n observability logs deploy/kube-prometheus-stack-grafana --tail=100
./scripts/check-grafana-sre-dashboard.sh
```

### Common causes

- Grafana pod not running.
- Service unavailable.
- Datasource provisioning issue.
- Resource pressure on the local kind cluster.

### Recovery

```bash
kubectl -n argocd get application kube-prometheus-stack
kubectl -n argocd get application grafana-dashboards
kubectl -n observability rollout status deploy/kube-prometheus-stack-grafana
```

## LokiDown

### Meaning

Prometheus cannot scrape the Loki metrics target in the `observability` namespace.

### Impact

The logging backend may be unavailable, and logs may not be queryable from Grafana.

### Investigation

```bash
kubectl -n observability get pods -l app.kubernetes.io/name=loki -o wide
kubectl -n observability get svc loki -o wide
kubectl -n observability get servicemonitor loki
kubectl -n observability logs statefulset/loki --tail=100
./scripts/check-loki-metrics.sh
```

### Common causes

- Loki pod not running.
- Loki service unavailable.
- ServiceMonitor missing or not selected by Prometheus.
- Loki `/metrics` endpoint unavailable.
- Local cluster resource pressure.

### Recovery

```bash
kubectl -n argocd get application loki
kubectl -n argocd get application loki-monitoring
kubectl -n observability rollout status statefulset/loki
```

## TempoDown

### Meaning

Tempo is unavailable or Prometheus cannot scrape the Tempo metrics endpoint.

This impacts distributed tracing visibility. Application traffic may still work,
but traces may not be searchable in Grafana Explore.

### Impact

- `demo-grpc` traces may no longer be stored or queryable.
- Grafana Tempo Explore may return empty results or errors.
- Trace-based troubleshooting becomes unavailable.

### Investigation

```bash
kubectl -n argocd get application tempo
kubectl -n observability get pods | grep -i tempo
kubectl -n observability get svc tempo
kubectl -n observability get servicemonitor tempo
```

Check Tempo readiness:

```bash
kubectl -n observability port-forward svc/tempo 19098:3200 &
curl -fsS http://127.0.0.1:19098/ready
curl -fsS http://127.0.0.1:19098/metrics | grep tempo_
```

Check Prometheus scraping:

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 19099:9090 &
curl -G -fsS "http://127.0.0.1:19099/api/v1/query" \
  --data-urlencode 'query=up{namespace="observability", service="tempo"}' \
  | python -m json.tool
```

### Common causes

- Tempo pod is not running.
- Tempo service is missing or has changed labels.
- Tempo ServiceMonitor is missing the `release=kube-prometheus-stack` label.
- Prometheus has not discovered the Tempo target yet.
- Tempo is up but its `/metrics` endpoint is not reachable.

### Remediation

Restart or resync Tempo:

```bash
kubectl -n argocd annotate application tempo \
  argocd.argoproj.io/refresh=hard \
  --overwrite
kubectl -n observability rollout restart statefulset/tempo
kubectl -n observability rollout status statefulset/tempo
```

Validate the full tracing stack:

```bash
./scripts/check-tempo-stack.sh
./scripts/check-demo-grpc-traces.sh
```

## ArgoCDAppOutOfSync

### Meaning

At least one ArgoCD application in project `idp-platform` is not synced.

### Impact

The live Kubernetes state does not match the desired Git state.

### Investigation

```bash
kubectl -n argocd get applications
kubectl -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
```

Find the out-of-sync application:

```bash
kubectl -n argocd get applications \
  -o jsonpath='{range .items[*]}{.metadata.name}{" sync="}{.status.sync.status}{" health="}{.status.health.status}{"\n"}{end}'
```

### Common causes

- Git commit not yet reconciled.
- Manual change in the cluster.
- Invalid manifest.
- Helm rendering issue.
- Missing CRD during dry-run.

### Recovery

Refresh the root app:

```bash
kubectl -n argocd annotate application idp-root \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

Then check application status again.

## ArgoCDAppUnhealthy

### Meaning

At least one ArgoCD application in project `idp-platform` is not healthy.

### Impact

One or more platform components may be degraded or unavailable.

### Investigation

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application <application-name>
kubectl get pods -A
```

### Common causes

- Pod crash loop.
- StatefulSet not ready.
- Service dependency unavailable.
- Helm release rendered but workload cannot start.
- Insufficient local cluster resources.

### Recovery

Inspect the unhealthy application and its workload:

```bash
kubectl -n argocd describe application <application-name>
kubectl -n <namespace> get pods -o wide
kubectl -n <namespace> logs <pod-name> --tail=100
```

## ArgoCDApplicationControllerMetricsDown

### Meaning

Prometheus cannot scrape ArgoCD application-controller metrics.

### Investigation

```bash
kubectl -n argocd get pods | grep application-controller
kubectl -n argocd get svc argocd-application-controller-metrics
kubectl -n argocd get servicemonitor argocd-metrics
./scripts/check-argocd-metrics.sh
```

### Recovery

```bash
kubectl -n argocd get application argocd-monitoring
kubectl -n argocd annotate application argocd-monitoring \
  argocd.argoproj.io/refresh=hard \
  --overwrite
```

## ArgoCDRepoServerMetricsDown

### Meaning

Prometheus cannot scrape ArgoCD repo-server metrics.

### Investigation

```bash
kubectl -n argocd get pods | grep repo-server
kubectl -n argocd get svc argocd-repo-server-metrics
./scripts/check-argocd-metrics.sh
```

### Recovery

```bash
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd logs deploy/argocd-repo-server --tail=100
```

## ArgoCDServerMetricsDown

### Meaning

Prometheus cannot scrape ArgoCD server metrics.

### Investigation

```bash
kubectl -n argocd get pods | grep argocd-server
kubectl -n argocd get svc argocd-server-metrics
./scripts/check-argocd-metrics.sh
```

### Recovery

```bash
kubectl -n argocd rollout status deploy/argocd-server
kubectl -n argocd logs deploy/argocd-server --tail=100
```
