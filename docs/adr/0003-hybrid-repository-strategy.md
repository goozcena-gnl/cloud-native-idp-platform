# ADR 0003: Hybrid repository strategy

## Status

Accepted

## Context

The target architecture separates platform infrastructure from application services.

## Decision

The portfolio will start as one repository for simplicity, but the documentation will describe the target hybrid model:

- one platform infrastructure repository;
- separate application repositories generated later by Backstage.

## Consequences

Positive:
- Simple MVP.
- Clear migration path to a realistic enterprise model.

Trade-offs:
- The first version is not a perfect representation of the final multi-repo architecture.
