# ADR 0002: GitOps as source of truth

## Status

Accepted

## Context

Manual cluster changes create drift and make the platform difficult to audit.

## Decision

After the initial bootstrap, platform state should be managed through Git and reconciled by ArgoCD.

## Consequences

Positive:
- Auditability.
- Drift detection.
- Repeatable deployments.

Trade-offs:
- Bootstrap still requires a small number of imperative commands.
- Git repository structure must be carefully designed.
