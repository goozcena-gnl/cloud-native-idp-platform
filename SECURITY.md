# Security Policy

## Security principles

This project follows a defense-in-depth approach:

- no secrets committed to Git;
- least privilege by default;
- container images scanned before deployment;
- workloads should run as non-root;
- Kubernetes manifests should define resource requests and limits;
- GitOps should be used to reduce configuration drift.

## Reporting issues

Report suspected vulnerabilities privately to the maintainers through a channel
already established with them. If you do not have a private channel, open a
public issue requesting one without including vulnerability details. Never put
exploit steps, credentials, tokens, or other sensitive information in a public
issue. General security improvements without sensitive details may be discussed
in public issues.
