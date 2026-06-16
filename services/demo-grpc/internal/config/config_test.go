package config_test

import (
	"os"
	"testing"

	"github.com/goozdu12/cloud-native-idp-platform/services/demo-grpc/internal/config"
)

func TestLoad_Defaults(t *testing.T) {
	os.Unsetenv("GRPC_PORT")
	os.Unsetenv("SERVICE_NAME")
	os.Unsetenv("APP_VERSION")

	cfg := config.Load()

	if cfg.GRPCPort != "50051" {
		t.Errorf("GRPCPort: got %q, want %q", cfg.GRPCPort, "50051")
	}
	if cfg.ServiceName != "demo-grpc" {
		t.Errorf("ServiceName: got %q, want %q", cfg.ServiceName, "demo-grpc")
	}
	if cfg.AppVersion != "dev" {
		t.Errorf("AppVersion: got %q, want %q", cfg.AppVersion, "dev")
	}
}

func TestLoad_EnvOverride(t *testing.T) {
	os.Setenv("GRPC_PORT", "9090")
	os.Setenv("SERVICE_NAME", "my-service")
	os.Setenv("APP_VERSION", "v1.2.3")
	t.Cleanup(func() {
		os.Unsetenv("GRPC_PORT")
		os.Unsetenv("SERVICE_NAME")
		os.Unsetenv("APP_VERSION")
	})

	cfg := config.Load()

	if cfg.GRPCPort != "9090" {
		t.Errorf("GRPCPort: got %q, want %q", cfg.GRPCPort, "9090")
	}
	if cfg.ServiceName != "my-service" {
		t.Errorf("ServiceName: got %q, want %q", cfg.ServiceName, "my-service")
	}
	if cfg.AppVersion != "v1.2.3" {
		t.Errorf("AppVersion: got %q, want %q", cfg.AppVersion, "v1.2.3")
	}
}
