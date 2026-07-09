# ${{ values.name }}

${{ values.description }}

## Generated from the cloud-native IDP platform golden path

This service skeleton is intended to follow the platform conventions:

- source code under `services/${{ values.name }}`;
- container image build;
- Helm chart under `charts/${{ values.name }}`;
- ArgoCD application under `platform/argocd/apps/${{ values.name }}.yaml`;
- metrics on port `${{ values.metricsPort }}`;
- gRPC service on port `${{ values.grpcPort }}`;
- security baseline;
- observability integration;
- service catalog metadata;
- runbook and readiness scorecard.

## Next steps

1. Implement the service.
2. Add tests.
3. Add Dockerfile.
4. Add Helm chart.
5. Add ArgoCD application.
6. Add catalog metadata.
7. Validate with the Production Readiness Scorecard.