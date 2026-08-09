# Phase 7 — Runtime Operations, Security and Resilience

## Goal

Phase 7 adds operational capabilities around cost visibility, runtime security, disaster recovery, and secrets management.

The objective is to move the platform beyond deployment and observability by validating local workflows for operational concerns relevant to production design.

## Delivered capabilities

### 1. Cost visibility with OpenCost

OpenCost provides Kubernetes cost allocation visibility for the local platform.

Delivered:

- OpenCost deployed through Argo CD;
- Prometheus integration;
- allocation API validation;
- GitOps-managed application;
- documentation and screenshots.

Documentation:

- [OpenCost cost visibility](COST_VISIBILITY.md)

### 2. Runtime security with Falco

Falco provides runtime detection for suspicious activity inside Kubernetes workloads.

Delivered:

- Falco deployed through Argo CD;
- privileged runtime security namespace documented;
- ServiceMonitor integration;
- runtime detection test using `/etc/shadow`;
- validation script and evidence.

Documentation:

- [Runtime security with Falco](RUNTIME_SECURITY.md)

### 3. Backup and disaster recovery with Velero

Velero provides backup and restore capabilities for Kubernetes resources.

Delivered:

- Velero deployed through Argo CD;
- local MinIO object storage backend;
- BackupStorageLocation validation;
- real backup and restore drill;
- namespace deletion and restore proof;
- validation script and screenshots.

Documentation:

- [Backup and disaster recovery](BACKUP_AND_DISASTER_RECOVERY.md)

### 4. Secrets management with Vault

Vault provides workload identity-based secrets access through Kubernetes authentication.

Delivered:

- Vault deployed through Argo CD;
- Vault Agent Injector deployed;
- Kubernetes auth configured;
- ServiceAccount-bound Vault role;
- least-privilege Vault policy;
- short-lived Kubernetes token validation;
- secret read through Vault Kubernetes auth.

Documentation:

- [Secrets management with Vault](SECRETS_MANAGEMENT.md)

## Validation scripts

The phase is validated through executable scripts:

```bash
./scripts/check-opencost-stack.sh
./scripts/check-falco-stack.sh
./scripts/check-velero-backup-restore.sh
./scripts/check-vault-stack.sh
./scripts/configure-vault-kubernetes-auth.sh
./scripts/check-vault-kubernetes-auth.sh
```

## GitOps applications

The following Argo CD applications are part of this phase:

```text
opencost
falco
velero
velero-minio
vault
vault-kubernetes-auth
```

Expected state:

```text
Synced / Healthy
```

## Portfolio value

This phase demonstrates that the platform is not limited to deploying workloads.

It also covers:

- cost awareness;
- runtime security detection;
- backup and restore procedures;
- workload identity-based secret access;
- GitOps-managed operations tooling;
- repeatable validation;
- production trade-off documentation.

## Current limitations

This is a local-first portfolio platform.

Known limitations:

- Vault runs in dev mode with in-memory storage;
- MinIO is deployed locally for Velero validation;
- cost data is local cluster data, not cloud billing data;
- Falco runs with privileged access because runtime security requires host-level visibility;
- production-grade TLS, HA, external object storage and persistent Vault storage are documented as future improvements.

## Outcome

Phase 7 proves that the platform can support essential Day-2 operations:

```text
Observe cost
Detect runtime threats
Backup and restore resources
Authenticate workloads to secrets
Validate everything through scripts
Deliver everything through GitOps
```
