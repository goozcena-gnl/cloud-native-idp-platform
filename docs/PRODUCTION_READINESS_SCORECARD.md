# Production Readiness Scorecard

## Goal

This scorecard defines the minimum production-readiness expectations for services running on the cloud-native IDP platform.

It helps platform engineers, SREs and developers assess whether a service is ready to be operated reliably.

The scorecard is intentionally practical and aligned with the platform capabilities already implemented in this repository.

## Scoring model

Each category can be rated from 0 to 3:

```text
0 = Not implemented
1 = Partially implemented
2 = Implemented
3 = Implemented, validated and documented
```

A service is considered platform-ready when:

```text
Total score >= 28 / 36
No critical category is scored 0
Observability, Security, GitOps and Ownership are at least 2
```

## Categories

### 1. Ownership and catalog

Expected:

- service owner is defined;
- lifecycle is defined;
- system relationship is declared;
- service is present in `catalog-info.yaml`;
- links to documentation are available.

Score:

```text
0 = no ownership metadata
1 = partial ownership metadata
2 = catalog entry exists
3 = catalog entry includes owner, lifecycle, system, API and documentation links
```

### 2. GitOps deployment

Expected:

- service is deployed through ArgoCD;
- application is `Synced`;
- application is `Healthy`;
- auto-sync, prune and self-heal are configured where appropriate.

Score:

```text
0 = manual deployment only
1 = manifests exist but are not GitOps-managed
2 = ArgoCD application exists
3 = ArgoCD application is Synced/Healthy and documented
```

### 3. CI/CD

Expected:

- formatting checks;
- unit tests;
- build validation;
- container image workflow if applicable;
- CI is green before deployment.

Score:

```text
0 = no CI
1 = partial CI
2 = CI validates build and tests
3 = CI validates build/tests and deployment-related assets
```

### 4. Container and runtime baseline

Expected:

- minimal runtime image;
- non-root user;
- no unnecessary tooling in final image;
- explicit ports;
- healthcheck or equivalent runtime probe.

Score:

```text
0 = no container baseline
1 = container exists but weak runtime baseline
2 = hardened image and runtime configuration
3 = hardened image documented and validated
```

### 5. Kubernetes reliability

Expected:

- readiness probe;
- liveness probe;
- resource requests;
- resource limits;
- graceful shutdown where applicable.

Score:

```text
0 = no reliability settings
1 = partial probes or resources
2 = probes and resources configured
3 = probes, resources and shutdown behavior validated
```

### 6. Observability

Expected:

- metrics exposed;
- logs are structured;
- traces are implemented where relevant;
- logs and traces can be correlated;
- dashboards or documentation exist.

Score:

```text
0 = no observability
1 = only logs or basic metrics
2 = metrics/logs/traces implemented
3 = metrics/logs/traces validated with correlation evidence
```

### 7. Security governance

Expected:

- non-root container;
- read-only root filesystem where possible;
- privilege escalation disabled;
- Linux capabilities dropped;
- seccomp profile configured;
- Kyverno policy compatibility.

Score:

```text
0 = no security baseline
1 = partial security context
2 = hardened security context
3 = hardened baseline validated by scripts and policy reports
```

### 8. Network security

Expected:

- default deny model where applicable;
- explicit NetworkPolicy;
- allowed traffic documented;
- denied traffic validated.

Score:

```text
0 = no network policy
1 = partial network rules
2 = NetworkPolicy exists
3 = allowed and denied traffic paths validated
```

### 9. Secrets management

Expected:

- no hardcoded secrets in manifests;
- Kubernetes ServiceAccount identity is used where possible;
- Vault policy limits access to required paths;
- secret access is validated.

Score:

```text
0 = secrets hardcoded or unmanaged
1 = Kubernetes Secret only
2 = Vault integration designed
3 = Vault Kubernetes auth validated
```

### 10. Runtime operations

Expected:

- runtime security coverage;
- backup/recovery considerations;
- cost visibility where relevant;
- operational validation scripts.

Score:

```text
0 = no runtime operations coverage
1 = partial operational coverage
2 = runtime capabilities integrated
3 = runtime security, cost and recovery documented
```

### 11. Runbooks and troubleshooting

Expected:

- service runbook exists;
- dashboards are referenced;
- alert response is documented;
- rollback procedure is described;
- common failure modes are listed.

Score:

```text
0 = no runbook
1 = partial notes
2 = runbook exists
3 = runbook includes alerts, dashboards, rollback and troubleshooting
```

### 12. Documentation and evidence

Expected:

- service documentation exists;
- validation commands are documented;
- screenshots or command outputs prove the implementation;
- limitations are clearly stated.

Score:

```text
0 = no documentation
1 = partial documentation
2 = documentation exists
3 = documentation includes validation evidence and limitations
```

## Demo service assessment

Reference service:

```text
demo-grpc
```

| Category | Score | Evidence |
|---|---|---|
| Ownership and catalog | 3 | `catalog-info.yaml` |
| GitOps deployment | 3 | `demo-grpc` ArgoCD app Synced/Healthy |
| CI/CD | 3 | GitHub Actions CI and publish workflow |
| Container and runtime baseline | 3 | hardened Dockerfile and runtime config |
| Kubernetes reliability | 3 | probes, resources, graceful shutdown |
| Observability | 3 | Prometheus, Loki, Tempo, OpenTelemetry |
| Security governance | 3 | security baseline and Kyverno validation |
| Network security | 3 | NetworkPolicy validation |
| Secrets management | 2 | Vault Kubernetes auth foundation available |
| Runtime operations | 3 | Falco, OpenCost, Velero platform capabilities |
| Runbooks and troubleshooting | 2 | incident drills and SRE docs exist |
| Documentation and evidence | 3 | screenshots and validation docs |

Total:

```text
34 / 36
```

## Interpretation

The `demo-grpc` service is platform-ready for a local production-like portfolio environment.

It demonstrates:

- GitOps delivery;
- CI validation;
- hardened Kubernetes deployment;
- observability with metrics, logs and traces;
- security governance;
- network restrictions;
- secrets management foundation;
- runtime operations integration;
- documented operational evidence.

## Current gaps

The remaining gaps are expected for a local-first portfolio platform:

- Vault is still running in dev mode;
- no production HA database or persistent app data yet;
- no real cloud billing integration;
- no production ingress or external DNS integration yet;
- no full Backstage portal deployment yet.

## Usage

When adding a new service, use this scorecard before considering the service platform-ready.

Recommended workflow:

```text
1. Follow the Developer Golden Path.
2. Add the service to catalog-info.yaml.
3. Deploy through ArgoCD.
4. Validate CI, security and observability.
5. Fill the scorecard.
6. Add runbook and evidence.
```