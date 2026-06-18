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
