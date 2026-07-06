# Runtime Security with Falco

This document describes the runtime security layer implemented in the local cloud-native IDP platform.

The goal is to demonstrate runtime threat detection for Kubernetes workloads using a GitOps-managed Falco deployment.

## Implemented capabilities

The platform now includes:

- Falco deployed through ArgoCD;
- Falco running as a DaemonSet on all Kubernetes nodes;
- syscall runtime event monitoring;
- Falco metrics service;
- ServiceMonitor for Prometheus scraping;
- runtime detection validation script;
- test workload that triggers a known Falco rule.

## Architecture

```text
Kubernetes nodes
  -> Falco DaemonSet
  -> syscall event source
  -> Falco rules
  -> runtime security events
  -> logs / metrics
```

## GitOps application

Falco is deployed as an ArgoCD application:

```text
falco
```

Expected state:

```text
falco   Synced   Healthy
```

The Falco namespace is intentionally labeled with privileged Pod Security Admission warning and audit levels because Falco requires privileged runtime access to observe host-level events:

```text
pod-security.kubernetes.io/warn=privileged
pod-security.kubernetes.io/audit=privileged
```

## Runtime components

Validated resources:

- Falco DaemonSet;
- Falco pods on the kind nodes;
- Falco metrics service;
- Falco ServiceMonitor.

Validation command:

```bash
kubectl -n falco get daemonset,pods,svc,servicemonitor -o wide
```

## Runtime detection proof

A temporary test workload is created in the `falco-test` namespace.

The validation triggers a Falco rule by reading `/etc/shadow` from inside a container:

```bash
kubectl -n falco-test exec <pod> -- cat /etc/shadow
```

Expected Falco event:

```text
Warning Sensitive file opened for reading by non-trusted program
file=/etc/shadow
```

This proves that Falco is not only installed, but actively observing runtime behavior.

## Validation script

Run:

```bash
./scripts/check-falco-stack.sh
```

The script validates:

- ArgoCD application status;
- Falco namespace labels;
- DaemonSet rollout;
- Falco startup logs;
- runtime event detection;
- cleanup of the test namespace.

## Current status

Falco is successfully deployed and detects runtime security events in the local Kubernetes platform.

This adds runtime detection to the existing security stack, complementing:

- Pod Security Admission;
- Kyverno admission policies;
- container hardening;
- NetworkPolicies;
- CI security scanning.

## Future improvements

Potential next steps:

- route Falco events to Loki;
- create Grafana panels for Falco detections;
- add custom Falco rules for platform-specific workloads;
- alert on high-severity Falco events through Alertmanager;
- document incident response actions for runtime detections.