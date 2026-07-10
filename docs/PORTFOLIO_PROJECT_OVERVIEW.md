# Cloud Native IDP Platform — Portfolio Overview

## Executive summary

This project is a local-first cloud-native Internal Developer Platform built to demonstrate practical DevOps, Platform Engineering, SRE, GitOps, security and developer experience skills.

The platform is designed as a professional portfolio project, not as a toy deployment. It shows how a cloud-native platform can be built progressively with:

- Kubernetes;
- GitOps with ArgoCD;
- Go gRPC service delivery;
- CI/CD;
- observability;
- security governance;
- runtime operations;
- backup and disaster recovery;
- secrets management;
- developer experience with Backstage.

## Target roles demonstrated

This project is relevant for roles such as:

- DevOps Engineer;
- Cloud Engineer;
- Platform Engineer;
- Site Reliability Engineer;
- DevSecOps Engineer;
- Kubernetes / GitOps Engineer.

## Platform capabilities

### 1. Kubernetes foundation

The platform runs on a local kind Kubernetes cluster.

Delivered:

- local Kubernetes cluster;
- platform namespaces;
- namespace labeling;
- Pod Security Admission labels;
- GitOps-ready structure.

### 2. GitOps delivery with ArgoCD

ArgoCD manages the platform applications.

Delivered:

- AppProject;
- app-of-apps root application;
- automated sync;
- prune and self-heal;
- platform applications managed declaratively.

### 3. Demo gRPC service

The reference workload is a Go gRPC service.

Delivered:

- Go gRPC server;
- Docker image;
- Helm chart;
- Kubernetes deployment;
- readiness and liveness probes;
- Prometheus metrics;
- OpenTelemetry traces;
- structured logs;
- log-to-trace correlation.

### 4. CI/CD and supply chain foundation

The repository includes GitHub Actions workflows.

Delivered:

- Go test and build;
- Docker build;
- Helm validation;
- Trivy scanning;
- lightweight secret scanning;
- CI-relevant change detection.

### 5. Observability and SRE

The platform includes a full observability stack.

Delivered:

- Prometheus;
- Grafana;
- Loki;
- Tempo;
- Alloy;
- OpenTelemetry;
- dashboards;
- alerts;
- SLO documentation;
- incident drills;
- log and trace correlation.

Documentation:

- [Observability and SRE](PORTFOLIO_OBSERVABILITY_SRE.md)
- [Incident drills](INCIDENT_DRILLS.md)

### 6. Security governance

The platform includes Kubernetes security controls.

Delivered:

- hardened workload security context;
- Kyverno;
- audit-mode policies;
- PolicyReport validation;
- NetworkPolicy baseline;
- security validation scripts.

Documentation:

- [Security governance](SECURITY_GOVERNANCE.md)

### 7. Runtime operations

The platform includes Day-2 operational capabilities.

Delivered:

- OpenCost for cost visibility;
- Falco for runtime security detection;
- Velero and MinIO for backup and restore;
- Vault for secrets management;
- Vault Kubernetes auth validation.

Documentation:

- [Runtime operations summary](PHASE_7_RUNTIME_OPERATIONS.md)
- [Cost visibility](COST_VISIBILITY.md)
- [Runtime security](RUNTIME_SECURITY.md)
- [Backup and disaster recovery](BACKUP_AND_DISASTER_RECOVERY.md)
- [Secrets management](SECRETS_MANAGEMENT.md)

### 8. Platform Engineering and Developer Experience

The platform includes developer-facing capabilities.

Delivered:

- Backstage service catalog;
- Backstage developer portal;
- `demo-grpc` service catalog entity;
- platform team ownership entity;
- production readiness scorecard;
- developer golden path;
- Go gRPC software template.

Documentation:

- [Platform Engineering and Developer Experience](PHASE_8_PLATFORM_ENGINEERING_DEVELOPER_EXPERIENCE.md)
- [Developer Golden Path](DEVELOPER_GOLDEN_PATH.md)
- [Production Readiness Scorecard](PRODUCTION_READINESS_SCORECARD.md)
- [Developer Portal with Backstage](DEVELOPER_PORTAL_BACKSTAGE.md)

## Key validation scripts

The platform includes executable validation scripts.

Examples:

```bash
./scripts/check-argocd-apps.sh
./scripts/check-demo-grpc-security-baseline.sh
./scripts/check-demo-grpc-log-trace-correlation.sh
./scripts/check-platform-alerts.sh
./scripts/check-kyverno-stack.sh
./scripts/check-network-policies.sh
./scripts/check-opencost-stack.sh
./scripts/check-falco-stack.sh
./scripts/check-velero-backup-restore.sh
./scripts/check-vault-kubernetes-auth.sh
./scripts/check-backstage-stack.sh
./scripts/check-backstage-software-template.sh
```

## Evidence model

The project uses three kinds of proof:

1. GitOps state:

- ArgoCD applications are `Synced` and `Healthy`.
2. Executable validation:

- scripts validate each platform capability.
3. Visual evidence:

- screenshots are stored under `docs/assets/`.

## Current platform state

Expected final platform state:

```text
All ArgoCD applications: Synced / Healthy
GitHub Actions CI: green
Git working tree: clean
```

Core applications:

```text
argocd-monitoring
backstage
demo-grpc
falco
grafana-dashboards
kube-prometheus-stack
kyverno
kyverno-policies
loki
network-policies
opencost
platform-alerts
platform-slo
tempo
vault
vault-kubernetes-auth
velero
velero-minio
```

## Production-readiness note

This is a local-first portfolio platform.

It intentionally uses local-friendly components such as:

- kind;
- local Docker images;
- local MinIO;
- Vault dev mode;
- Backstage local image;
- simplified authentication.

The project documents these limitations and explains what would change in a production-grade deployment.

## Main portfolio value

This project demonstrates the ability to:

- design a platform roadmap;
- deliver Kubernetes applications through GitOps;
- instrument services with metrics, logs and traces;
- build SRE evidence through dashboards, alerts and drills;
- apply Kubernetes security governance;
- validate runtime detection and disaster recovery;
- integrate secrets management with workload identity;
- build developer experience with Backstage;
- document and prove the platform through repeatable scripts.

## Outcome

The repository is a practical DevOps / Platform Engineering portfolio project showing both implementation and operational maturity.

It is suitable for technical discussion around:

- Kubernetes;
- GitOps;
- CI/CD;
- observability;
- DevSecOps;
- SRE;
- runtime operations;
- developer platforms;
- Backstage;
- production-readiness practices.