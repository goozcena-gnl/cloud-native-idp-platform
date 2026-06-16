# Project Charter

## Project name

Cloud-Native Internal Developer Platform

## Objective

Create a professional portfolio project that demonstrates DevOps, Platform Engineering, Kubernetes, GitOps, SRE, and cloud-native security skills.

## MVP scope

The MVP proves the core delivery loop:

Developer code change -> CI -> image build and scan -> GitOps manifest update -> ArgoCD deployment -> observable Kubernetes workload.

## Advanced scope

The advanced version adds:

- Backstage developer portal
- Crossplane infrastructure abstractions
- Vault secrets management
- Falco runtime security
- OpenCost cost visibility
- Velero backup and recovery
- advanced Cilium network policies
- production-grade documentation and demo

## Constraints

- Prefer local-first resources.
- Avoid unnecessary cloud costs.
- Avoid vendor lock-in where possible.
- Use GitOps as the source of truth.
- Never skip validation, security, documentation, or Git commits.

## Success criteria

The project is successful when a recruiter or senior engineer can understand:

- what business problem the platform solves;
- how the platform is deployed;
- how applications are delivered;
- how security is enforced;
- how reliability is measured;
- how developers benefit from the platform.
