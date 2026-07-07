# Secrets Management with Vault

## Goal

This document describes the secrets management layer implemented in the local cloud-native IDP platform.

The goal is to demonstrate how workloads can authenticate to Vault using Kubernetes identities and read only the secrets they are authorized to access.

## Implemented capabilities

The platform now includes:

- Vault deployed through ArgoCD;
- Vault Agent Injector deployed through the official Helm chart;
- Vault running in controlled dev mode for local portfolio validation;
- Kubernetes authentication enabled in Vault;
- Kubernetes ServiceAccount bound to a Vault role;
- Vault policy scoped to a demo application secret;
- automated validation script proving secret access through Kubernetes auth.

## Architecture

```text
Kubernetes ServiceAccount
  -> short-lived Kubernetes token
  -> Vault Kubernetes auth method
  -> Vault role demo-grpc
  -> Vault policy demo-grpc-read
  -> secret/demo-grpc/config
```

## GitOps applications

Vault is managed through ArgoCD:

```text
vault                   Synced   Healthy
vault-kubernetes-auth   Synced   Healthy
```

The `vault` application deploys the Vault server and injector.

The `vault-kubernetes-auth` application deploys the Kubernetes-side resources required for authentication:

- `ServiceAccount/vault-auth-smoke` in the `apps` namespace;
- `ClusterRoleBinding/vault-token-reviewer` for token review access.

## Vault configuration

The runtime Vault configuration is applied by:

```bash
./scripts/configure-vault-kubernetes-auth.sh
```

The script configures:

- Kubernetes auth method;
- Kubernetes auth backend configuration;
- demo secret;
- Vault policy;
- Vault role bound to Kubernetes ServiceAccounts.

Configured role:

```text
demo-grpc
```

Bound Kubernetes ServiceAccounts:

```text
demo-grpc
vault-auth-smoke
```

Bound namespace:

```text
apps
```

Policy:

```text
demo-grpc-read
```

Allowed secret path:

```text
secret/data/demo-grpc/config
```

## Validation

Run:

```bash
./scripts/check-vault-kubernetes-auth.sh
```

The validation proves that:

1. ArgoCD applications are Synced and Healthy.
2. A short-lived Kubernetes token is generated.
3. The token authenticates to Vault through the Kubernetes auth method.
4. Vault returns a scoped client token.
5. The client token can read the expected secret.

Successful output:

```text
Vault secret value: hello-from-vault
OK: Kubernetes-authenticated Vault token can read the expected secret.
Vault Kubernetes auth validated successfully.
```

## Security value

This demonstrates workload identity-based secret access.

Instead of putting static secrets directly into Kubernetes manifests, workloads can authenticate using their Kubernetes identity and receive access only to the Vault paths allowed by policy.

This complements:

- Kubernetes RBAC;
- Kyverno admission policies;
- Pod Security Admission;
- NetworkPolicies;
- CI/CD security scanning;
- runtime detection with Falco.

## Current limitations

Vault currently runs in dev mode with in-memory storage:

```text
Storage Type: inmem
```

This is suitable for local validation and portfolio demonstration, but not for production.

In production, Vault should use:

- persistent storage;
- TLS;
- real unseal strategy;
- external secrets backend or HA storage;
- no hardcoded root token;
- least-privilege policies;
- audit logging;
- backup and restore procedures.

Because this local Vault uses in-memory storage, the Kubernetes auth configuration is reapplied by the idempotent script after a Vault pod restart.

## Future improvements

Potential next steps:

- inject Vault secrets into `demo-grpc` using Vault Agent Injector;
- replace static Kubernetes demo env vars with Vault-provided values;
- add Vault audit logs to Loki;
- create Grafana panels for Vault health;
- add production-mode documentation with HA and persistent storage trade-offs.