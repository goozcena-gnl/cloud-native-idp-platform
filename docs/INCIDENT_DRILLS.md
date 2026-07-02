# Incident Drills

This document records reliability drills executed on the local cloud-native IDP platform.

The goal is to validate that the observability and alerting pipeline works under realistic failure scenarios.

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
