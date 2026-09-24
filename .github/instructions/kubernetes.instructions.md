---
applyTo: "charts/**,k8s/**,manifests/**,deploy/**"
---

# Kubernetes and GitOps Instructions

- Preserve Argo CD/GitOps as the deployment authority.
- Keep workload security controls intact: non-root execution, resource bounds, probes, NetworkPolicy, Pod Security, and policy enforcement.
- Prefer immutable image references and do not replace provenance checks with mutable tags.
- Validate rendered manifests or Helm output before proposing changes.
- Do not treat rendered configuration or CI success as live-cluster evidence.
- Never introduce cluster credentials into CI solely to simplify deployment.
