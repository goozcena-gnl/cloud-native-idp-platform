package config_test

import (
	"os"
	"testing"

	"github.com/goozdu12/cloud-native-idp-platform/services/demo-grpc/internal/config"
)

func TestLoad_Defaults(t *testing.T) {
	os.Unsetenv("GRPC_PORT")
	os.Unsetenv("METRICS_PORT")
	os.Unsetenv("SERVICE_NAME")
	os.Unsetenv("APP_VERSION")
	os.Unsetenv("OTEL_TRACES_ENABLED")
	os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")

	cfg := config.Load()

	if cfg.GRPCPort != "50051" {
		t.Errorf("GRPCPort: got %q, want %q", cfg.GRPCPort, "50051")
	}
	if cfg.MetricsPort != "9090" {
		t.Errorf("MetricsPort: got %q, want %q", cfg.MetricsPort, "9090")
	}
	if cfg.ServiceName != "demo-grpc" {
		t.Errorf("ServiceName: got %q, want %q", cfg.ServiceName, "demo-grpc")
	}
	if cfg.AppVersion != "dev" {
		t.Errorf("AppVersion: got %q, want %q", cfg.AppVersion, "dev")
	}
	if cfg.OTelTracesEnabled {
		t.Errorf("OTelTracesEnabled: got true, want false")
	}
	if cfg.OTelExporterOTLPEndpoint != "" {
		t.Errorf("OTelExporterOTLPEndpoint: got %q, want empty", cfg.OTelExporterOTLPEndpoint)
	}
}

func TestLoad_EnvOverride(t *testing.T) {
	os.Setenv("GRPC_PORT", "60000")
	os.Setenv("METRICS_PORT", "19090")
	os.Setenv("SERVICE_NAME", "custom-service")
	os.Setenv("APP_VERSION", "v1.2.3")
	os.Setenv("OTEL_TRACES_ENABLED", "true")
	os.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "tempo.observability.svc.cluster.local:4317")
	t.Cleanup(func() {
		os.Unsetenv("GRPC_PORT")
		os.Unsetenv("METRICS_PORT")
		os.Unsetenv("SERVICE_NAME")
		os.Unsetenv("APP_VERSION")
		os.Unsetenv("OTEL_TRACES_ENABLED")
		os.Unsetenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	})

	cfg := config.Load()

	if cfg.GRPCPort != "60000" {
		t.Errorf("GRPCPort: got %q, want %q", cfg.GRPCPort, "60000")
	}
	if cfg.MetricsPort != "19090" {
		t.Errorf("MetricsPort: got %q, want %q", cfg.MetricsPort, "19090")
	}
	if cfg.ServiceName != "custom-service" {
		t.Errorf("ServiceName: got %q, want %q", cfg.ServiceName, "custom-service")
	}
	if cfg.AppVersion != "v1.2.3" {
		t.Errorf("AppVersion: got %q, want %q", cfg.AppVersion, "v1.2.3")
	}
	if !cfg.OTelTracesEnabled {
		t.Errorf("OTelTracesEnabled: got false, want true")
	}
	if cfg.OTelExporterOTLPEndpoint != "tempo.observability.svc.cluster.local:4317" {
		t.Errorf("OTelExporterOTLPEndpoint: got %q, want %q", cfg.OTelExporterOTLPEndpoint, "tempo.observability.svc.cluster.local:4317")
	}
}
