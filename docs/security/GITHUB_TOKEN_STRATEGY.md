# GitHub Token Strategy for GitOps

This document describes how ArgoCD authenticates to the **private** GitHub
repository, the security implications of the current approach, and the target
credential strategy. It exists to make the trade-offs explicit and to define a
clear migration path away from the MVP shortcut.

---

## Current state (MVP)

ArgoCD reads the private repository using a **GitHub Personal Access Token
(PAT)**. The token is provided to ArgoCD as a Kubernetes `Secret` of type
`repository`, created out-of-band with:

```bash
./scripts/configure-argocd-private-repo.sh
```

The Secret structure can be validated without revealing the token:

```bash
./scripts/check-argocd-repo-secret.sh
```

### Why a PAT for the MVP

- It is the fastest way to grant ArgoCD read access to a private repository.
- It requires no GitHub organization-level configuration.
- It keeps the local-first bootstrap simple and reproducible.

A PAT is acceptable **only** as a temporary bootstrap mechanism. It is not the
intended long-term credential.

---

## Security implications of using a PAT

A PAT carries real risk and must be treated as a sensitive secret:

- **Broad blast radius.** Classic PATs are tied to a user account and can be
  over-scoped. A leaked PAT may expose more than a single repository.
- **User-bound.** A PAT inherits the access of the human who created it. If
  that user's access changes or is revoked, GitOps can silently break.
- **Long-lived by default.** Tokens without an explicit expiry remain valid
  indefinitely, increasing exposure if leaked.
- **Hard to attribute.** Automation acting as a user makes audit trails less
  meaningful than a dedicated machine identity.
- **Leakage surface.** Tokens can leak through logs, shell history, screenshots,
  or accidental commits.

### Mandatory controls

These rules are non-negotiable for this project:

- **Never commit a token to Git.** No PAT, deploy key, or generated Secret YAML
  containing secret material is committed. The repository `.gitignore` and
  review discipline enforce this. Specifically, never commit:
  - GitHub tokens;
  - ArgoCD repository Secret manifests containing credentials;
  - SSH private keys;
  - kubeconfig files;
  - `.env` files;
  - cloud credentials;
  - Vault tokens.
- **The current PAT must be short-lived.** Set the shortest practical expiry
  and rotate it. Do not create non-expiring tokens.
- **Least privilege.** Grant only repository **read** access:
  - Fine-grained PAT: select only this repository, with
    *Contents: Read-only* (Metadata read is included automatically).
  - Classic PAT: limit to the `repo` scope and remove it after migration.
- **Store only in the Kubernetes Secret.** The token lives in the ArgoCD
  `repository` Secret and nowhere else (no `.env`, no notes, no chat).
- **Rotate on suspicion.** Any suspected exposure means immediate revocation
  and rotation.

### Rotating or revoking the PAT

```bash
# Re-run after issuing a fresh, short-lived token (paste it at the prompt;
# never share the token in chat or commit it):
./scripts/configure-argocd-private-repo.sh

# Force ArgoCD to re-read with the new credential:
kubectl -n argocd rollout restart deploy/argocd-repo-server
kubectl -n argocd annotate application idp-root \
  argocd.argoproj.io/refresh=hard --overwrite
```

Then revoke the old token in GitHub.

> Note: ArgoCD only needs to **read** the repository. GitHub may report
> `Write access to repository not granted` when a credential cannot **read** a
> private repo. That message indicates a missing read permission or an expired
> token, not a need for write access.

---

## Advanced target credential strategy

The PAT is a temporary measure. The intended long-term options, in increasing
order of operational maturity, are:

### 1. Read-only deploy key (per-repository)

- An SSH key pair scoped to a **single repository**, added as a
  **read-only** deploy key on GitHub.
- The private key is stored as an ArgoCD `repository` Secret (SSH type).
- **Pros:** narrow blast radius (one repo), not tied to a human user.
- **Cons:** per-repository management; key rotation is manual.

### 2. GitHub App installation

- A GitHub App installed on the repository/organization, granting ArgoCD a
  dedicated machine identity with **read-only Contents** permission.
- ArgoCD exchanges the App credentials for short-lived installation tokens.
- **Pros:** least-privilege, auditable as a distinct identity,
  short-lived tokens, scalable across many repositories.
- **Cons:** more initial setup (App registration, private key handling).

### 3. Vault-managed credential

- HashiCorp Vault issues and rotates the Git credential, delivered to the
  cluster via an integration such as the External Secrets Operator or the
  Vault Agent / CSI provider.
- **Pros:** centralized secret lifecycle, automatic rotation, strong audit,
  no static long-lived secret in the cluster.
- **Cons:** requires Vault to be deployed and operated (a later platform
  phase).

### Recommended progression

```text
PAT (MVP, short-lived)
      -> Read-only deploy key  (narrow blast radius, quick win)
      -> GitHub App            (machine identity, short-lived tokens)
      -> Vault-managed         (centralized rotation and audit)
```

---

## Summary

| Aspect | Current (MVP) | Target |
|---|---|---|
| Credential | Personal Access Token | Deploy key / GitHub App / Vault |
| Identity | Human user | Machine / per-repo identity |
| Scope | Repository read | Repository read (least privilege) |
| Lifetime | Short-lived, rotated | Short-lived / auto-rotated |
| Storage | Kubernetes Secret only | Kubernetes Secret / Vault-issued |
| Committed to Git | Never | Never |

The single most important invariant across every stage: **no token is ever
committed to Git, and credentials are always least-privilege and rotated.**
</content>
