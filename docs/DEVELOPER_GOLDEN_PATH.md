# Developer Golden Path

## Goal

This document describes the recommended path for adding a new service to the cloud-native IDP platform.

The objective is to provide a clear, repeatable and production-oriented developer experience.

A developer should be able to understand:

- where to place service code;
- how to containerize the service;
- how to expose it through Helm;
- how to deploy it with ArgoCD;
- how to add observability;
- how to meet security requirements;
- how to document ownership, runbooks and readiness.

## Reference implementation

The current reference service is:

```text
demo-grpc
```

It demonstrates the expected platform integration model:

- Go service;
- Docker image;
- Helm chart;
- ArgoCD application;
- CI pipeline;
- Kubernetes security context;
- Prometheus metrics;
- OpenTelemetry traces;
- structured logs with trace correlation;
- NetworkPolicy;
- Kyverno policy compatibility;
- Vault Kubernetes auth compatibility;
- observability and SRE documentation.

## Golden Path overview

A new service should follow this path:

```text
1. Create service source code
2. Add container image build
3. Add Helm chart
4. Add GitOps application
5. Add CI validation
6. Add observability
7. Add security baseline
8. Add runtime operations integration
9. Add service catalog metadata
10. Add runbook and ownership documentation
```

## 1. Service source code

Recommended location:

```text
services/<service-name>/
```

Expected minimum content:

```text
services/<service-name>/
  README.md
  Dockerfile
  go.mod / package.json / pyproject.toml / equivalent
  src or cmd directory
  tests
```

The service should expose:

- a health endpoint or gRPC health service;
- application metrics;
- structured logs;
- clear configuration through environment variables.

## 2. Container image

Each service must provide a reproducible container build.

Expected requirements:

- small runtime image;
- non-root runtime user;
- no unnecessary build tools in the final image;
- explicit exposed ports;
- healthcheck binary or endpoint if relevant.

Reference:

```text
services/demo-grpc/Dockerfile
```

## 3. Helm chart

Recommended location:

```text
charts/<service-name>/
```

The Helm chart should define:

- Deployment;
- Service;
- ServiceMonitor if metrics are exposed;
- labels compatible with ArgoCD and Backstage;
- resource requests and limits;
- hardened pod and container security contexts;
- configurable image repository and tag.

Reference:

```text
charts/demo-grpc/
```

## 4. GitOps application

Recommended location:

```text
platform/argocd/apps/<service-name>-app.yaml
```

Each service should be deployed through ArgoCD.

Expected requirements:

- project: `idp-platform`;
- target namespace: usually `apps`;
- automated sync;
- self-heal enabled;
- prune enabled;
- clear labels.

Reference:

```text
platform/argocd/apps/demo-grpc-app.yaml
```

## 5. CI validation

A service should include CI validation before being deployed.

Expected checks:

- formatting;
- tests;
- build;
- container build if relevant;
- Helm template validation;
- security scan where relevant.

Reference:

```text
.github/workflows/ci.yml
.github/workflows/publish-demo-grpc.yml
```

## 6. Observability

Each service should provide the three pillars of observability.

### Metrics

Expected:

- `/metrics` endpoint or equivalent;
- Prometheus-compatible metrics;
- ServiceMonitor;
- dashboard or dashboard section.

### Logs

Expected:

- structured logs;
- useful operational fields;
- trace correlation fields when tracing is enabled.

Recommended fields:

```text
service
version
level
message
trace_id
span_id
duration_ms
```

### Traces

Expected:

- OpenTelemetry instrumentation;
- Tempo-compatible traces;
- trace IDs correlated with logs.

Reference validation:

```text
./scripts/check-demo-grpc-log-trace-correlation.sh
```

## 7. Security baseline

Every workload should meet the platform security baseline.

Expected Kubernetes security requirements:

- run as non-root;
- drop Linux capabilities;
- disable privilege escalation;
- read-only root filesystem where possible;
- define CPU and memory requests;
- define CPU and memory limits;
- use RuntimeDefault seccomp profile.

Reference validation:

```text
./scripts/check-demo-grpc-security-baseline.sh
./scripts/check-kyverno-audit-mode.sh
```

## 8. Runtime operations integration

A production-oriented service should integrate with platform runtime capabilities.

Expected integrations:

- NetworkPolicy;
- Prometheus monitoring;
- alerting rules if relevant;
- runbook;
- backup considerations if it owns persistent data;
- secret access through Vault if it needs secrets.

Vault reference:

```text
./scripts/configure-vault-kubernetes-auth.sh
./scripts/check-vault-kubernetes-auth.sh
```

## 9. Service catalog metadata

Each service should be represented in the platform catalog.

Reference file:

```text
catalog-info.yaml
```

A service should declare:

- owner;
- lifecycle;
- system;
- provided APIs;
- dependencies;
- links to documentation;
- ArgoCD application annotation;
- Kubernetes identifier annotation.

## 10. Runbook and ownership

Each service should include operational documentation.

Recommended location:

```text
docs/runbooks/<service-name>.md
```

The runbook should include:

- service purpose;
- owner;
- dependencies;
- dashboards;
- alerts;
- common failure modes;
- restart procedure;
- rollback procedure;
- troubleshooting commands.

## Definition of Ready

A new service is ready to be onboarded when it has:

- source code;
- Dockerfile;
- Helm chart;
- local test command;
- basic README;
- declared ports;
- health endpoint;
- clear configuration model.

## Definition of Done

A new service is considered platform-ready when it has:

- ArgoCD application Synced and Healthy;
- CI green;
- metrics visible in Prometheus;
- logs visible in Loki;
- traces visible in Tempo if applicable;
- security baseline validated;
- NetworkPolicy applied;
- service catalog entry added;
- runbook created;
- documentation linked from the catalog.

## Example onboarding checklist

```text
[ ] Service code added under services/<service-name>
[ ] Dockerfile added
[ ] Helm chart added under charts/<service-name>
[ ] ArgoCD application added
[ ] CI validation added
[ ] Metrics exposed
[ ] Logs structured
[ ] Tracing configured
[ ] Security context hardened
[ ] Resource requests and limits defined
[ ] NetworkPolicy added
[ ] Vault role/policy added if secrets are needed
[ ] catalog-info.yaml updated
[ ] Runbook added
[ ] Validation screenshots added if relevant
```

## Platform value

This golden path turns the repository into a real Internal Developer Platform foundation.

It provides developers with a repeatable onboarding model instead of requiring them to understand every Kubernetes, GitOps, security and observability detail from scratch.