# GitOps Repository Access Model

ArgoCD will reconcile platform manifests from this Git repository. Before
creating ArgoCD `Application` resources, confirm which repository URL ArgoCD
should use and whether the repository is public or private.

This step is read-only. It does not configure ArgoCD repository credentials.

## Check the repository

Run from the repository root:

```bash
./scripts/check-gitops-repo.sh
```

The script checks `git remote origin`, normalizes common GitHub SSH remotes to
HTTPS, and prints the recommended ArgoCD `repoURL`.

It prints:

- The current Git remote
- The recommended ArgoCD `repoURL`
- The current branch
- The latest commit
- GitHub CLI authentication status
- GitHub repository metadata and visibility, if available

Example recommended shape:

```text
https://github.com/goozdu12/cloud-native-idp-platform.git
```

If GitHub CLI is installed and authenticated, the script also runs
`gh repo view` and prints repository visibility when available.

## Why normalize GitHub SSH to HTTPS?

ArgoCD can use either SSH or HTTPS repository URLs, but HTTPS is simpler for
the local MVP because public repositories need no credentials and private
repository credentials can be added later without changing the `repoURL` shape.

Common normalizations:

| Git remote | Recommended ArgoCD `repoURL` |
|---|---|
| `git@github.com:OWNER/REPO.git` | `https://github.com/OWNER/REPO.git` |
| `ssh://git@github.com/OWNER/REPO.git` | `https://github.com/OWNER/REPO.git` |
| `https://github.com/OWNER/REPO` | `https://github.com/OWNER/REPO.git` |
| `https://github.com/OWNER/REPO.git` | `https://github.com/OWNER/REPO.git` |

The script redacts embedded HTTP credentials if a remote URL contains them.
Do not use credential-bearing Git URLs in ArgoCD `Application` manifests.

## Public repository implication

If the repository is public, ArgoCD can read it without repository credentials.
The first ArgoCD `Application` can reference the recommended `repoURL` directly.

Public repository access is the simplest path for a portfolio MVP, but still
do not commit secrets, kubeconfig files, tokens, or generated credentials.

## Private repository implication

If the repository is private, ArgoCD needs Git credentials configured in the
cluster before it can reconcile Applications from the repo.

Do not commit any of the following:

- GitHub personal access tokens
- GitHub fine-grained tokens
- Deploy private keys
- Repository credential Secrets
- ArgoCD repo credential manifests containing secret material
- Kubeconfig files or cloud credentials

Credential setup is intentionally deferred. For a later task, choose a secure
local approach such as an ArgoCD CLI repo add command, a manually created
Kubernetes Secret excluded from Git, or an encrypted secret workflow such as
SOPS once secret management is part of the platform.

## MVP decision

The preferred MVP model is:

```text
Public GitHub repository + HTTPS repoURL + no ArgoCD credentials
```

If the repository must remain private during development, credentials will be
added later through a documented local-only secret process.

## Security implications

A public repository must not contain:

- Cloud credentials
- Kubeconfig files
- `.env` files
- Terraform state
- Vault tokens
- Private keys
- Passwords
- Generated Kubernetes Secrets

The `.gitignore` and documentation must support this rule.

## Unknown visibility

If `gh` is not authenticated, the script cannot reliably determine visibility.
Authenticate GitHub CLI if you want the check to print visibility:

```bash
gh auth login
./scripts/check-gitops-repo.sh
```

If you do not authenticate `gh`, confirm visibility in GitHub before creating
ArgoCD `Application` resources.

## Next decision before Applications

Use this rule before writing ArgoCD Applications:

- Public repo: use the recommended `repoURL` directly.
- Private repo: configure ArgoCD credentials outside Git first, then create
  Applications that reference the recommended `repoURL`.

In both cases, Git should become the source of truth for desired Kubernetes
manifests after ArgoCD starts reconciling them.