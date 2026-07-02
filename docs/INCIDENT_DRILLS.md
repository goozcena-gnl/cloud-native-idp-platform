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
