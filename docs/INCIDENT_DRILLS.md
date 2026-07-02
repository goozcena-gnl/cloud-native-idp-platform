# Incident Drills

This document records reliability drills executed on the local cloud-native IDP platform.

The goal is to validate that the observability and alerting pipeline works under realistic failure scenarios.

## Reliability Drill Suite Summary

This project includes a controlled reliability drill suite for validating incident detection, alert routing, recovery, and post-incident health checks.

| Drill | Component | Failure simulated | Alert | Severity | Alertmanager receiver | Recovery validation |
|---|---|---|---|---|---|---|
| Drill 1 | Application workload | `demo-grpc` scaled to zero replicas | `DemoGrpcDown` | critical | `platform-critical` | SLO, platform alerts, Alertmanager |
| Drill 2 | Tracing backend | `Tempo` scaled to zero replicas | `TempoDown` | critical | `platform-critical` | Tempo stack, platform alerts, Alertmanager |
| Drill 3 | Logging backend | `Loki` scaled to zero replicas | `LokiDown` | critical | `platform-critical` | Loki metrics, platform alerts, Alertmanager |
| Drill 4 | Observability frontend | `Grafana` scaled to zero replicas | `GrafanaDown` | warning | `platform-warning` | Grafana dashboard, platform alerts, Alertmanager |

Validated incident lifecycle pattern:

```text
failure injection
  -> Prometheus detects the failure
  -> alert enters pending state
  -> alert enters firing state
  -> Alertmanager receives the alert
  -> alert is routed to the expected receiver
  -> workload is restored
  -> alert clears
  -> post-incident health checks pass
```

Reliability drill scripts:

```bash
./scripts/drill-demo-grpc-down.sh
./scripts/drill-tempo-down.sh
./scripts/drill-loki-down.sh
./scripts/drill-grafana-down.sh
```

Post-drill validation scripts:

```bash
./scripts/check-demo-grpc-slo.sh
./scripts/check-tempo-stack.sh
./scripts/check-loki-metrics.sh
./scripts/check-grafana-sre-dashboard.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Pipeline validated by the drills:

```text
Failure simulation
  -> Prometheus detection
  -> alert pending
  -> alert firing
  -> Alertmanager routing
  -> runbook-driven recovery
  -> alert clears
  -> platform returns healthy
```

---

## Drill 1 — demo-grpc outage simulation

### Objective

Validate that the platform detects a `demo-grpc` outage and routes the `DemoGrpcDown` alert to Alertmanager.

### Scenario

The `demo-grpc` deployment is temporarily scaled down to zero replicas.

Expected behavior:

```text
demo-grpc replicas = 0
  -> Prometheus target becomes down or absent
  -> DemoGrpcDown becomes pending
  -> DemoGrpcDown becomes firing
  -> Alertmanager receives DemoGrpcDown
  -> demo-grpc is restored
  -> DemoGrpcDown clears
```

### Drill command

```bash
./scripts/drill-demo-grpc-down.sh
```

### Evidence

The drill validated the complete incident lifecycle:

```
OK: DemoGrpcDown is pending in Prometheus.
OK: DemoGrpcDown is firing in Prometheus.
OK: Alertmanager has active alert DemoGrpcDown.
OK: DemoGrpcDown cleared from Prometheus.
Reliability drill DemoGrpcDown completed successfully.
```

### Recovery validation

After restoration, the following checks passed:

```bash
./scripts/check-demo-grpc-slo.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Validated final state:

```text
demo-grpc               Synced / Healthy
idp-root                Synced / Healthy
platform-alerts         Synced / Healthy
kube-prometheus-stack   Synced / Healthy
demo-grpc deployment    1/1 available
No platform alert firing
```

### What this proves

This drill proves that the platform can detect and route a real workload outage through the SRE alerting pipeline.

Validated capabilities:

- Failure injection through Kubernetes scaling.
- Temporary GitOps self-heal suspension for controlled testing.
- Prometheus alert state transition from pending to firing.
- Alertmanager reception of the critical workload alert.
- Automated recovery cleanup in the drill script.
- Post-incident validation through platform health checks.
- SLO and alert validation after recovery.

---

## Drill 2 — Tempo outage simulation

### Objective

Validate that the platform detects a Tempo tracing backend outage and routes the `TempoDown` alert to the critical platform receiver.

### Scenario

The Tempo StatefulSet is temporarily scaled down to zero replicas.

Expected behavior:

```text
tempo replicas = 0
  -> Prometheus target becomes down or absent
  -> TempoDown becomes pending
  -> TempoDown becomes firing
  -> Alertmanager receives TempoDown
  -> TempoDown is routed to platform-critical
  -> Tempo is restored
  -> TempoDown clears
```

### Drill command

```bash
./scripts/drill-tempo-down.sh
```

### Evidence

The drill validated the complete incident lifecycle:

```
OK: TempoDown is pending in Prometheus.
OK: TempoDown is firing in Prometheus.
OK: Alertmanager has active alert TempoDown.
Reliability drill TempoDown completed successfully.
```

The alert was routed to the expected critical receiver:

```
receivers:
  - platform-critical
```

### Recovery validation

After restoration, the following checks passed:

```bash
./scripts/check-tempo-stack.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Validated final state:

```text
tempo                   Synced / Healthy
platform-alerts         Synced / Healthy
kube-prometheus-stack   Synced / Healthy
Tempo pod               1/1 Running
Tempo Prometheus up     1
No platform alert firing
```

### What this proves

This drill proves that the tracing backend is monitored by the platform itself.

Validated capabilities:

- Failure injection on a stateful observability backend.
- Prometheus alert lifecycle validation for `TempoDown`.
- Critical routing through Alertmanager.
- Runbook-linked alerting for tracing backend failure.
- Automatic restoration of Tempo.
- Post-incident validation of Tempo, platform alerts, and Alertmanager.

---

## Drill 3 — Loki outage simulation

### Objective

Validate that the platform detects a Loki logging backend outage and routes the `LokiDown` alert to the critical platform receiver.

### Scenario

The Loki StatefulSet is temporarily scaled down to zero replicas.

Expected behavior:

```text
loki replicas = 0
  -> Prometheus target becomes down or absent
  -> LokiDown becomes pending
  -> LokiDown becomes firing
  -> Alertmanager receives LokiDown
  -> LokiDown is routed to platform-critical
  -> Loki is restored
  -> LokiDown clears
```

### Drill command

```bash
./scripts/drill-loki-down.sh
```

### Evidence

The drill validated the complete incident lifecycle:

```
OK: LokiDown is pending in Prometheus.
OK: LokiDown is firing in Prometheus.
OK: Alertmanager has active alert LokiDown.
Reliability drill LokiDown completed successfully.
```

The alert was routed to the expected critical receiver:

```
receivers:
  - platform-critical
```

### Recovery validation

After restoration, the following checks passed:

```bash
./scripts/check-loki-metrics.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Validated final state:

```text
loki                    Synced / Healthy
loki-monitoring         Synced / Healthy
platform-alerts         Synced / Healthy
kube-prometheus-stack   Synced / Healthy
Loki pod                2/2 Running
Loki Prometheus up      1
No platform alert firing
```

### What this proves

This drill proves that the logging backend is monitored by the platform itself.

Validated capabilities:

- Failure injection on the Loki logging backend.
- Prometheus alert lifecycle validation for `LokiDown`.
- Critical routing through Alertmanager.
- Runbook-linked alerting for logging backend failure.
- Automatic restoration of Loki.
- Post-incident validation of Loki metrics, platform alerts, and Alertmanager.

---

## Drill 4 — Grafana outage simulation

### Objective

Validate that the platform detects a Grafana outage and routes the `GrafanaDown` alert to the warning platform receiver.

### Scenario

The Grafana Deployment from `kube-prometheus-stack` is temporarily scaled down to zero replicas.

Expected behavior:

```text
grafana replicas = 0
  -> Prometheus target becomes down or absent
  -> GrafanaDown becomes pending
  -> GrafanaDown becomes firing
  -> Alertmanager receives GrafanaDown
  -> GrafanaDown is routed to platform-warning
  -> Grafana is restored
  -> GrafanaDown clears
```

### Drill command

```bash
./scripts/drill-grafana-down.sh
```

### Evidence

The drill validated the complete incident lifecycle:

```
OK: GrafanaDown is pending in Prometheus.
OK: GrafanaDown is firing in Prometheus.
OK: Alertmanager has active alert GrafanaDown.
Reliability drill GrafanaDown completed successfully.
```

The alert was routed to the expected warning receiver:

```
receivers:
  - platform-warning
```

### Recovery validation

After restoration, the following checks passed:

```bash
./scripts/check-grafana-sre-dashboard.sh
./scripts/check-platform-alerts.sh
./scripts/check-alertmanager.sh
```

Validated final state:

```text
kube-prometheus-stack   Synced / Healthy
grafana-dashboards      Synced / Healthy
platform-alerts         Synced / Healthy
Grafana deployment      1/1 available
Grafana dashboard       reachable
No platform alert firing
```

### What this proves

This drill proves that the observability frontend is monitored without depending on itself.

Validated capabilities:

- Failure injection on the Grafana UI layer.
- Prometheus alert lifecycle validation for `GrafanaDown`.
- Warning routing through Alertmanager.
- Runbook-linked alerting for Grafana failure.
- Automatic restoration of Grafana.
- Post-incident validation of dashboard provisioning, platform alerts, and Alertmanager.
