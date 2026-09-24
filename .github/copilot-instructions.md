# GitHub Copilot Instructions

Read and follow `AGENTS.md` as the repository-wide engineering and trust contract.

For Copilot-specific work:
- keep each change scoped to the issue or pull-request objective;
- inspect existing architecture, tests, validation scripts, and CI before editing;
- prefer the smallest safe diff and preserve existing trust boundaries;
- do not weaken checks, policies, provenance controls, or GitOps ownership to make CI pass;
- report exact validation commands run and separate static checks from runtime evidence;
- leave merge, release, cluster mutation, and production/cloud actions to a human.
