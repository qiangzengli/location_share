package api

import (
	"context"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/config"
)

type contextKey string

const (
	ctxUsername contextKey = "username"
	ctxUserID   contextKey = "userID"
)

// AuthMiddleware validates the Bearer JWT and injects username + userID into context.
func AuthMiddleware(cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				writeError(w, apperr.Unauthorized("缺少认证令牌"))
				return
			}

			tokenStr := header[7:]
			claims := jwt.MapClaims{}
			token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrSignatureInvalid
				}
				return []byte(cfg.JWTSecret), nil
			})
			if err != nil || !token.Valid {
				writeError(w, apperr.Unauthorized("令牌无效或已过期"))
				return
			}

			username, _ := claims["sub"].(string)
			userIDStr, _ := claims["uid"].(string)
			userID, _ := uuid.Parse(userIDStr)

			ctx := context.WithValue(r.Context(), ctxUsername, username)
			ctx = context.WithValue(ctx, ctxUserID, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// CORSMiddleware adds permissive CORS headers for development and mobile clients.
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "*")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func usernameFromCtx(ctx context.Context) string {
	v, _ := ctx.Value(ctxUsername).(string)
	return v
}

func userIDFromCtx(ctx context.Context) uuid.UUID {
	v, _ := ctx.Value(ctxUserID).(uuid.UUID)
	return v
}
