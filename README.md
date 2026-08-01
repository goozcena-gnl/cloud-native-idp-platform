# Cloud Native IDP Platform

Local-first Internal Developer Platform built with Kubernetes, GitOps, observability, security, runtime operations and developer experience.

This project is a professional DevOps / Platform Engineering portfolio project. It demonstrates how to build and operate a cloud-native platform progressively, with real validation scripts, GitOps delivery and documented evidence.

## What this project demonstrates

This repository demonstrates practical skills around:

- Kubernetes platform engineering;
- GitOps with ArgoCD;
- Go gRPC service delivery;
- CI/CD with GitHub Actions;
- observability with Prometheus, Grafana, Loki, Tempo and OpenTelemetry;
- SRE practices with alerts, SLOs and incident drills;
- Kubernetes security governance with Kyverno and NetworkPolicies;
- runtime security with Falco;
- cost visibility with OpenCost;
- backup and restore with Velero and MinIO;
- secrets management with Vault and Kubernetes authentication;
- developer experience with Backstage;
- production readiness documentation and scorecards.

## Target roles

This project is relevant for:

- DevOps Engineer;
- Cloud Engineer;
- Platform Engineer;
- Site Reliability Engineer;
- DevSecOps Engineer;
- Kubernetes / GitOps Engineer.

## Architecture overview

```text
Developer
  -> GitHub repository
  -> GitHub Actions CI
  -> ArgoCD app-of-apps
  -> kind Kubernetes cluster
      -> demo-grpc service
      -> observability stack
      -> security governance
      -> runtime operations
      -> Backstage developer portal
```

Core platform layers:

```text
GitOps             ArgoCD
Workload           Go gRPC demo service
Packaging          Docker + Helm
Observability      Prometheus, Grafana, Loki, Tempo, OpenTelemetry
Security           Kyverno, NetworkPolicies, Pod Security Admission
Runtime Security   Falco
Cost Visibility    OpenCost
Backup / DR        Velero + MinIO
Secrets            Vault + Kubernetes Auth
Developer Portal   Backstage
```

## Current platform capabilities

### GitOps

- ArgoCD AppProject;
- app-of-apps pattern;
- automated sync;
- prune and self-heal;
- all platform applications managed declaratively.

### Demo service

The reference service is `demo-grpc`, a Go gRPC service used to validate the full platform lifecycle.

It includes:

- Docker image;
- Helm chart;
- Kubernetes deployment;
- gRPC health checks;
- Prometheus metrics;
- OpenTelemetry traces;
- structured logs;
- log-to-trace correlation;
- hardened security context.

### Observability and SRE

The observability layer includes:

- Prometheus metrics;
- Grafana dashboards;
- Loki logs;
- Tempo traces;
- OpenTelemetry instrumentation;
- alerting rules;
- SLO documentation;
- incident drills.

Documentation:

- [Observability and SRE](docs/PORTFOLIO_OBSERVABILITY_SRE.md)
- [Incident drills](docs/INCIDENT_DRILLS.md)

### Security governance

The security layer includes:

- Pod Security Admission labels;
- hardened workload baseline;
- Kyverno policies;
- Kyverno audit-mode validation;
- NetworkPolicy default-deny model;
- security validation scripts.

Documentation:

- [Security governance](docs/SECURITY_GOVERNANCE.md)
- [DevSecOps and CI/CD supply-chain security](docs/DEVSECOPS.md)

The dedicated `Plumber CI/CD Security` workflow analyzes every GitHub Actions
workflow and local composite action on pull requests, pushes to `main`, and
manual runs. It enforces a minimum Plumber score of `A`, publishes SARIF to
GitHub Code Scanning, and retains JSON, SARIF, PBOM, and CycloneDX reports as
short-lived workflow artifacts. Plumber score publication to the external badge
service is intentionally disabled.

### Runtime operations

The runtime operations layer includes:

- OpenCost for cost visibility;
- Falco for runtime threat detection;
- Velero and MinIO for backup and restore;
- Vault for secrets management;
- Vault Kubernetes auth validation.

Documentation:

- [Runtime operations summary](docs/PHASE_7_RUNTIME_OPERATIONS.md)
- [Cost visibility](docs/COST_VISIBILITY.md)
- [Runtime security](docs/RUNTIME_SECURITY.md)
- [Backup and disaster recovery](docs/BACKUP_AND_DISASTER_RECOVERY.md)
- [Secrets management](docs/SECRETS_MANAGEMENT.md)

### Developer Experience

The developer experience layer includes:

- Backstage service catalog;
- Backstage developer portal;
- `Component/demo-grpc`;
- `API/demo-grpc-api`;
- `Group/platform-team`;
- Developer Golden Path;
- Production Readiness Scorecard;
- Go gRPC Backstage software template.

Documentation:

- [Platform Engineering and Developer Experience](docs/PHASE_8_PLATFORM_ENGINEERING_DEVELOPER_EXPERIENCE.md)
- [Developer Golden Path](docs/DEVELOPER_GOLDEN_PATH.md)
- [Production Readiness Scorecard](docs/PRODUCTION_READINESS_SCORECARD.md)
- [Developer Portal with Backstage](docs/DEVELOPER_PORTAL_BACKSTAGE.md)

## Validation model

This project is validated through three evidence layers:

1. **GitOps state**

ArgoCD applications must be `Synced` and `Healthy`.
2. **Executable validation scripts**

Each important platform capability has a validation script under `scripts/`.
3. **Visual evidence**

Screenshots are stored under `docs/assets/`.

## Key validation scripts

```text
./scripts/check-portfolio-package.sh
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

## Documentation index

Start here:

- [Portfolio project overview](docs/PORTFOLIO_PROJECT_OVERVIEW.md)
- [Documentation index](docs/DOCUMENTATION_INDEX.md)
- [Milestones](docs/MILESTONES.md)

## Evidence assets

Screenshots and visual proof are stored under:

```text
docs/assets/
```

Main evidence folders:

```text
docs/assets/observability-sre/
docs/assets/security-governance/
docs/assets/backup-disaster-recovery/
docs/assets/secrets-management/
docs/assets/developer-portal/
```

## Repository structure

```text
.
├── catalog-info.yaml
├── charts/
├── developer-portal/
│   └── backstage/
├── docs/
│   ├── assets/
│   └── *.md
├── platform/
│   ├── argocd/
│   ├── backup/
│   ├── developer-portal/
│   ├── grafana/
│   ├── namespaces/
│   ├── observability/
│   └── security/
├── scripts/
└── services/
    └── demo-grpc/
```

## Local-first design

This project is intentionally local-first.

It uses:

- kind for Kubernetes;
- local Docker images;
- local MinIO for Velero;
- Vault dev mode for secrets validation;
- local Backstage image;
- simplified local authentication.

These choices make the platform reproducible on a local workstation while still demonstrating real DevOps, SRE, GitOps and platform engineering concepts.

## Production note

This is not presented as a production deployment.

Production improvements would include:

- managed Kubernetes;
- real ingress and TLS;
- external DNS;
- production-grade Vault storage and unseal;
- persistent PostgreSQL for Backstage;
- external object storage for Velero;
- production authentication and RBAC;
- hardened supply chain and image signing;
- cloud billing integration;
- high availability and disaster recovery across failure domains.

## Portfolio outcome

This project demonstrates the ability to:

- design a platform roadmap;
- deliver Kubernetes workloads through GitOps;
- build observability and SRE evidence;
- enforce security governance;
- validate backup and restore;
- integrate workload identity with Vault;
- build a Backstage developer portal;
- expose a self-service software template;
- document trade-offs and limitations clearly.

The repository is intended to support technical discussions for DevOps, Cloud, Platform Engineering, SRE and DevSecOps roles.
