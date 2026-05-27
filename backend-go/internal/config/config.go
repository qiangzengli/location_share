package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port               string
	JWTSecret          string
	AccessTokenMinutes int
	RefreshTokenDays   int
	// MySQL connection — provide either DATABASE_URL (full DSN) or individual vars.
	DBUrl string
}

func Load() *Config {
	return &Config{
		Port:               env("PORT", "8080"),
		JWTSecret:          env("JWT_SECRET", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"),
		AccessTokenMinutes: envInt("JWT_ACCESS_MINUTES", 15),
		RefreshTokenDays:   envInt("JWT_REFRESH_DAYS", 14),
		DBUrl:              env("DATABASE_URL", ""),
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
