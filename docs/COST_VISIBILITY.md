# Cost Visibility with OpenCost

This document describes the cost visibility layer implemented in the local cloud-native IDP platform.

The goal is to demonstrate that the platform can expose Kubernetes cost allocation data in a GitOps-managed way.

## Implemented capabilities

The platform now includes:

- OpenCost deployed through ArgoCD;
- integration with the existing Prometheus stack;
- OpenCost namespace managed declaratively;
- OpenCost exporter and UI;
- ServiceMonitor for Prometheus scraping;
- allocation API validation;
- repeatable validation script.

## Architecture

```text
Kubernetes workloads
  -> kube-state-metrics / node-exporter / Prometheus metrics
  -> kube-prometheus-stack
  -> OpenCost
  -> allocation API
  -> cost visibility by namespace
```

## GitOps application

OpenCost is deployed as an ArgoCD application:

```text
opencost
```

Expected state:

```text
opencost   Synced   Healthy
```

The application uses the OpenCost Helm chart and configures OpenCost to use the existing Prometheus service:

```text
kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090
```

## Runtime components

OpenCost runs in the `opencost` namespace.

Validated resources:

- deployment;
- pod;
- service;
- ServiceMonitor.

## Prometheus integration

OpenCost is configured to use the existing Prometheus instance from `kube-prometheus-stack`.

Validated Prometheus service:

```text
kube-prometheus-stack-prometheus
```

Prometheus readiness endpoint:

```text
/-/ready
```

Expected result:

```text
Prometheus Server is Ready.
```

## Allocation API validation

The OpenCost allocation API is validated with:

```bash
curl "http://127.0.0.1:19003/allocation/compute?window=1h&aggregate=namespace"
```

The response must return valid JSON with a `data` field.

## Validation script

Run:

```bash
./scripts/check-opencost-stack.sh
```

The script validates:

- ArgoCD application status;
- namespace labels;
- deployment rollout;
- pod and service state;
- ServiceMonitor presence;
- OpenCost allocation API response.

## Current status

The OpenCost layer is successfully deployed and integrated with Prometheus.

This demonstrates that the platform can expose cost allocation data without adding a separate monitoring stack.

## Future improvements

Potential next steps:

- add a Grafana dashboard for namespace cost visibility;
- document example namespace allocation output;
- add screenshots of the OpenCost UI;
- configure custom pricing for local or homelab assumptions;
- integrate cost visibility into the final platform demo.