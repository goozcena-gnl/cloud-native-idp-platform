// Package config loads service configuration from environment variables.
package config

import (
	"os"
)

// Config holds runtime configuration for the demo-grpc service.
type Config struct {
	// GRPCPort is the port the gRPC server binds to.
	GRPCPort string
	// MetricsPort is the port the Prometheus /metrics HTTP server binds to.
	MetricsPort string
	// ServiceName is an informational label included in startup logs.
	ServiceName string
	// AppVersion is the build version included in startup logs.
	AppVersion string
}

// Load returns a Config populated from environment variables.
// Missing variables fall back to the documented defaults.
func Load() *Config {
	return &Config{
		GRPCPort:    getEnv("GRPC_PORT", "50051"),
		MetricsPort: getEnv("METRICS_PORT", "9090"),
		ServiceName: getEnv("SERVICE_NAME", "demo-grpc"),
		AppVersion:  getEnv("APP_VERSION", "dev"),
	}
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}
