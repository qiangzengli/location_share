package main

import (
	"log/slog"
	"net/http"
	"os"

	"github.com/locationshare/backend/internal/api"
	"github.com/locationshare/backend/internal/config"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/service"
	"github.com/locationshare/backend/internal/store"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg := config.Load()

	db, err := initDB(cfg)
	if err != nil {
		log.Error("database connection failed", "error", err)
		os.Exit(1)
	}

	if err := db.AutoMigrate(
		&model.AppUser{},
		&model.RefreshToken{},
		&model.ParticipantLocation{},
		&model.Group{},
		&model.GroupMember{},
	); err != nil {
		log.Error("migration failed", "error", err)
		os.Exit(1)
	}

	s := store.New(db)
	authSvc := service.NewAuthService(s, cfg)
	userSvc := service.NewUserService(s)
	locSvc := service.NewLocationService(s)
	groupSvc := service.NewGroupService(s)

	router := api.NewRouter(cfg, authSvc, userSvc, locSvc, groupSvc)

	addr := ":" + cfg.Port
	log.Info("server starting", "addr", addr)
	if err := http.ListenAndServe(addr, router); err != nil {
		log.Error("server error", "error", err)
		os.Exit(1)
	}
}

func initDB(cfg *config.Config) (*gorm.DB, error) {
	dsn := cfg.DBUrl
	if dsn == "" {
		// Build DSN from individual env vars when DATABASE_URL is not set.
		user := envOr("DATABASE_USER", "root")
		pass := envOr("DATABASE_PASSWORD", "")
		host := envOr("DATABASE_HOST", "localhost")
		port := envOr("DATABASE_PORT", "3306")
		name := envOr("DATABASE_NAME", "location_share")
		dsn = user + ":" + pass + "@tcp(" + host + ":" + port + ")/" + name +
			"?charset=utf8mb4&parseTime=True&loc=Local"
	}
	return gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
