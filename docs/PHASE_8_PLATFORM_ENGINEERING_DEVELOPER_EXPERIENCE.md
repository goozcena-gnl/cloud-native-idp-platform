# Phase 8 — Platform Engineering and Developer Experience

## Goal

Phase 8 turns the platform from a Kubernetes/SRE technical stack into a developer-facing Internal Developer Platform foundation.

The objective is to improve service discoverability, onboarding, ownership, readiness assessment and self-service capabilities.

## Delivered capabilities

### 1. Backstage service catalog foundation

The platform now includes a Backstage-compatible catalog:

```text
catalog-info.yaml
```

Catalog entities include:

- `System/cloud-native-idp-platform`;
- `Group/platform-team`;
- `Component/demo-grpc`;
- `API/demo-grpc-api`;
- `Resource/idp-local-kind-cluster`;
- `Resource/observability-stack`;
- `Resource/secrets-management-stack`.

### 2. Developer Golden Path

The repository includes a documented onboarding path for new services:

```text
docs/DEVELOPER_GOLDEN_PATH.md
```

It explains how a developer should add a new service with:

- service source code;
- Dockerfile;
- Helm chart;
- ArgoCD application;
- CI validation;
- observability;
- security baseline;
- NetworkPolicy;
- Vault integration if needed;
- service catalog metadata;
- runbook and ownership documentation.

### 3. Production Readiness Scorecard

The platform includes a service readiness model:

```text
docs/PRODUCTION_READINESS_SCORECARD.md
```

It covers:

- ownership;
- GitOps;
- CI/CD;
- container baseline;
- Kubernetes reliability;
- observability;
- security governance;
- network security;
- secrets management;
- runtime operations;
- runbooks;
- documentation and evidence.

### 4. Backstage Developer Portal

Backstage is deployed locally through GitOps:

```text
platform/argocd/apps/backstage.yaml
platform/developer-portal/backstage/
```

It runs with:

- `Deployment/backstage`;
- `Deployment/backstage-postgresql`;
- `Service/backstage`;
- `Service/backstage-postgresql`;
- local image `backstage:local`;
- platform catalog imported into Backstage.

Validation:

```text
./scripts/check-backstage-stack.sh
```

### 5. Backstage Software Template

The developer portal exposes a self-service template:

```text
Go gRPC Service
```

Template location:

```text
developer-portal/backstage/templates/go-grpc-service/template.yaml
```

Validation:

```text
./scripts/check-backstage-software-template.sh
```

The template provides a starting point for generating a service aligned with the platform golden path.

## Validation scripts

Phase 8 is validated through:

```text
./scripts/check-developer-experience.sh
./scripts/check-production-readiness-scorecard.sh
./scripts/check-backstage-local-app.sh
./scripts/build-backstage-kind-image.sh
./scripts/configure-backstage-secrets.sh
./scripts/check-backstage-stack.sh
./scripts/check-backstage-software-template.sh
```

## ArgoCD applications

Phase 8 introduced:

```text
backstage
```

Expected state:

```text
backstage   Synced   Healthy
```

## Evidence

Backstage evidence is documented in:

```text
docs/DEVELOPER_PORTAL_BACKSTAGE.md
```

It includes:

- ArgoCD Backstage application synced and healthy;
- Backstage stack validation;
- Backstage UI;
- `demo-grpc` service catalog entity;
- ArgoCD resource tree;
- software template validation;
- Go gRPC Service template in the Create page.

## Current limitations

This is a local-first developer portal deployment.

Known limitations:

- Backstage image is built locally as `backstage:local`;
- PostgreSQL uses local in-cluster storage;
- authentication is simplified for local validation;
- permissions are disabled for the local portfolio deployment;
- Kubernetes backend plugin is disabled until proper cluster locator configuration is added;
- TechDocs is not configured yet;
- no public ingress or TLS endpoint is configured yet.

## Future improvements

Potential next improvements:

- publish Backstage image to GHCR;
- configure GitHub authentication;
- enable Backstage Kubernetes plugin properly;
- enable TechDocs;
- add ArgoCD plugin integration;
- add service scorecards directly in Backstage;
- add more software templates;
- expose Backstage through ingress and TLS.

## Outcome

Phase 8 demonstrates a real platform engineering foundation:

```text
Discover services
Understand ownership
Follow a golden path
Assess production readiness
Use a developer portal
Start self-service scaffolding
```

This moves the project closer to an Internal Developer Platform rather than only a Kubernetes infrastructure repository.