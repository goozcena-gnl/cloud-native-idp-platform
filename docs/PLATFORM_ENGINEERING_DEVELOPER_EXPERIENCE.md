# Platform Engineering and Developer Experience

## Goal

This document describes the developer experience layer of the cloud-native IDP platform.

The goal is to make the platform understandable, discoverable and usable by developers through a service catalog, golden paths, operational documentation and eventually a developer portal.

## Phase scope

This phase focuses on:

- service catalog metadata;
- Backstage-compatible entity definitions;
- developer onboarding;
- golden path documentation;
- production readiness checks;
- future Backstage deployment;
- future software templates.

## Service Catalog

The repository now includes a Backstage-compatible catalog file:

```text
catalog-info.yaml
```

It defines the main platform entities:

- `System/cloud-native-idp-platform`;
- `Component/demo-grpc`;
- `API/demo-grpc-api`;
- `Resource/idp-local-kind-cluster`;
- `Resource/observability-stack`;
- `Resource/secrets-management-stack`.

## Why this matters

A service catalog helps platform teams and developers answer key questions:

- What services exist?
- Who owns them?
- Which system do they belong to?
- What APIs do they expose?
- What infrastructure do they depend on?
- Where are the dashboards, runbooks and documentation?
- What is the operational maturity of the service?

## Demo service catalog entry

The `demo-grpc` service is documented as a Backstage component.

It links the service to:

- the GitHub repository;
- the ArgoCD application;
- Kubernetes workload metadata;
- observability documentation;
- security governance documentation;
- backup and disaster recovery documentation;
- secrets management documentation.

## Developer Experience value

This is the first step toward an Internal Developer Platform.

Instead of only providing Kubernetes manifests and scripts, the platform starts exposing a product-oriented interface for developers and reviewers.

## Current status

Implemented:

- Backstage-compatible `catalog-info.yaml`;
- system metadata;
- service metadata;
- API metadata;
- platform resource metadata;
- documentation links.

Next improvements:

- deploy Backstage locally through GitOps;
- import the catalog into Backstage;
- add TechDocs;
- add software templates;
- add production readiness scorecards;
- add golden path onboarding documentation.