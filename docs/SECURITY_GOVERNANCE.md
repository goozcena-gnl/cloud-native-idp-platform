# Security and Governance

This document describes the Kubernetes security and governance baseline implemented in the local
cloud-native IDP platform.

The goal of this phase is to demonstrate defense-in-depth without breaking developer velocity or
platform observability.

## Implemented security capabilities

The platform now includes:

- hardened `demo-grpc` workload manifests;
- non-root container execution;
- read-only root filesystem;
- dropped Linux capabilities;
- RuntimeDefault seccomp profile;
- CPU and memory requests and limits;
- Pod Security Admission warnings and audit labels;
- Kyverno admission controller deployed through ArgoCD;
- Kyverno baseline policies in Audit mode;
- Kyverno PolicyReport validation;
- NetworkPolicy ingress isolation for the `apps` namespace;
- explicit allowed ingress for `demo-grpc`;
- validation scripts for repeatable security checks.

## Workload hardening

The `demo-grpc` Helm chart defines pod-level and container-level security controls.

Pod security context:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  seccompProfile:
    type: RuntimeDefault
```

Container security context:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

The workload also defines CPU and memory requests and limits.

Validation script:

```bash
./scripts/check-demo-grpc-security-baseline.sh
```

## Pod Security Admission

The `apps` namespace uses Pod Security Admission in warning and audit mode:

```text
pod-security.kubernetes.io/warn=restricted
pod-security.kubernetes.io/audit=restricted
```

This allows the platform to surface violations without immediately blocking workloads during the
learning and validation phase.

## Kyverno

Kyverno is deployed through ArgoCD as a GitOps-managed platform application.

Validated components:

- admission controller;
- background controller;
- cleanup controller;
- reports controller;
- Kyverno CRDs;
- validating webhooks;
- mutating webhooks.

Validation script:

```bash
./scripts/check-kyverno-stack.sh
```

## Kyverno baseline policies

The platform includes a baseline `ClusterPolicy` for workloads in the `apps` namespace:

```text
idp-apps-pod-security-baseline
```

The policy currently runs in `Audit` mode.

Rules:

- require pod security context;
- disallow privilege escalation;
- require read-only root filesystem;
- require dropping all Linux capabilities;
- require CPU and memory requests and limits.

Validation script:

```bash
./scripts/check-kyverno-policies.sh
```

## Kyverno Audit mode proof

The platform includes a validation script that creates an intentionally non-compliant pod in the
`apps` namespace.

Expected behavior:

- the pod is admitted because the policy runs in `Audit` mode;
- Pod Security Admission emits warnings;
- Kyverno records violations in a `PolicyReport`;
- the test pod is removed automatically.

Validation script:

```bash
./scripts/check-kyverno-audit-mode.sh
```

Validated violations:

```text
disallow-privilege-escalation
require-drop-all-capabilities
require-pod-security-context
require-read-only-root-filesystem
require-resource-requests-and-limits
```

## NetworkPolicy baseline

The `apps` namespace has a default deny ingress policy:

```text
apps-default-deny-ingress
```

The `demo-grpc` workload has an explicit allow policy:

```text
demo-grpc-allow-ingress
```

Allowed ingress:

- traffic from the `apps` namespace to `demo-grpc` on ports `50051` and `9090`;
- traffic from the `observability` namespace to `demo-grpc` on port `9090`.

Blocked ingress:

- traffic from unrelated namespaces to `demo-grpc`.

Validation script:

```bash
./scripts/check-network-policies.sh
```

## GitOps applications

Security applications managed by ArgoCD:

```text
kyverno
kyverno-policies
network-policies
```

Expected state:

```text
kyverno            Synced   Healthy
kyverno-policies   Synced   Healthy
network-policies   Synced   Healthy
```

## Validation checklist

Run the following commands to validate the security baseline:

```bash
./scripts/check-demo-grpc-security-baseline.sh
./scripts/check-kyverno-stack.sh
./scripts/check-kyverno-policies.sh
./scripts/check-kyverno-audit-mode.sh
./scripts/check-network-policies.sh
```

Then verify the full GitOps state:

```bash
kubectl -n argocd get applications \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' \
  | sort
```

## Current security posture

The platform currently demonstrates:

- secure workload defaults;
- admission control readiness;
- policy audit reporting;
- namespace-level ingress isolation;
- observability compatibility after network isolation;
- GitOps-managed security controls.

## Future improvements

Potential next improvements:

- promote selected Kyverno rules from `Audit` to `Enforce`;
- add egress NetworkPolicies;
- add image registry allowlist policies;
- add signed image verification;
- add Falco runtime detection;
- add Vault Kubernetes authentication;
- add security dashboards for Kyverno policy reports.
