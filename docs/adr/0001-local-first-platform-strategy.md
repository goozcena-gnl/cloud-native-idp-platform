# ADR 0001: Local-first platform strategy

## Status

Accepted

## Context

The project should be reproducible without requiring paid cloud infrastructure.

## Decision

The MVP will run locally first, using a local Kubernetes cluster. Cloud deployment will be optional and documented later.

## Consequences

Positive:
- Lower cost.
- Easier reproduction.
- Better for portfolio reviewers.

Trade-offs:
- Some features such as ExternalDNS, public TLS, cloud load balancers, and Velero object storage are more realistic in a cloud environment.
