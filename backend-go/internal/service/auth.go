package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/config"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/store"
	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	store *store.Store
	cfg   *config.Config
}

func NewAuthService(s *store.Store, cfg *config.Config) *AuthService {
	return &AuthService{store: s, cfg: cfg}
}

func (svc *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.AuthResponse, error) {
	username := strings.ToLower(strings.TrimSpace(req.Username))
	if len(username) < 3 || len(username) > 64 {
		return nil, apperr.BadRequest("用户名长度须在 3~64 个字符之间")
	}
	if len(req.Password) < 8 || len(req.Password) > 128 {
		return nil, apperr.BadRequest("密码长度须在 8~128 个字符之间")
	}

	exists, err := svc.store.UsernameExists(ctx, username)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if exists {
		return nil, apperr.Conflict("用户名已被占用")
	}

	var email *string
	if req.Email != nil && strings.TrimSpace(*req.Email) != "" {
		e := strings.ToLower(strings.TrimSpace(*req.Email))
		if !validEmail(e) {
			return nil, apperr.BadRequest("邮箱格式不正确")
		}
		dup, err := svc.store.EmailExists(ctx, e, uuid.Nil)
		if err != nil {
			return nil, apperr.Internal("数据库错误")
		}
		if dup {
			return nil, apperr.Conflict("邮箱已被使用")
		}
		email = &e
	}

	displayName := username
	if req.DisplayName != nil && strings.TrimSpace(*req.DisplayName) != "" {
		displayName = strings.TrimSpace(*req.DisplayName)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return nil, apperr.Internal("密码加密失败")
	}

	user := &model.AppUser{
		Username:     username,
		Email:        email,
		PasswordHash: string(hash),
		DisplayName:  displayName,
	}
	if err := svc.store.CreateUser(ctx, user); err != nil {
		return nil, apperr.Internal("注册失败")
	}

	return svc.issueTokens(ctx, user)
}

func (svc *AuthService) Login(ctx context.Context, req *model.LoginRequest) (*model.AuthResponse, error) {
	username := strings.ToLower(strings.TrimSpace(req.Username))

	user, err := svc.store.UserByUsername(ctx, username)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if user == nil {
		return nil, apperr.Unauthorized("用户名或密码错误")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, apperr.Unauthorized("用户名或密码错误")
	}

	return svc.issueTokens(ctx, user)
}

func (svc *AuthService) Refresh(ctx context.Context, rawToken string) (*model.AuthResponse, error) {
	hash := hashToken(rawToken)

	rt, err := svc.store.TokenByHash(ctx, hash)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if rt == nil {
		return nil, apperr.Unauthorized("刷新令牌无效或已失效")
	}
	if rt.IsExpired() {
		_ = svc.store.RevokeToken(ctx, rt)
		return nil, apperr.Unauthorized("刷新令牌已过期")
	}

	user, err := svc.store.UserByID(ctx, rt.UserID)
	if err != nil || user == nil {
		return nil, apperr.Unauthorized("用户不存在")
	}

	if err := svc.store.RevokeToken(ctx, rt); err != nil {
		return nil, apperr.Internal("数据库错误")
	}

	return svc.issueTokens(ctx, user)
}

func (svc *AuthService) Logout(ctx context.Context, rawToken string) error {
	rt, err := svc.store.TokenByHash(ctx, hashToken(rawToken))
	if err != nil {
		return apperr.Internal("数据库错误")
	}
	if rt != nil {
		_ = svc.store.RevokeToken(ctx, rt)
	}
	return nil
}

func (svc *AuthService) LogoutAll(ctx context.Context, username string) error {
	user, err := svc.store.UserByUsername(ctx, username)
	if err != nil {
		return apperr.Internal("数据库错误")
	}
	if user == nil {
		return apperr.NotFound("用户不存在")
	}
	return svc.store.RevokeAllUserTokens(ctx, user.ID)
}

func (svc *AuthService) ChangePassword(ctx context.Context, username string, req *model.ChangePasswordRequest) error {
	if len(req.NewPassword) < 8 || len(req.NewPassword) > 128 {
		return apperr.BadRequest("新密码长度须在 8~128 个字符之间")
	}

	user, err := svc.store.UserByUsername(ctx, username)
	if err != nil {
		return apperr.Internal("数据库错误")
	}
	if user == nil {
		return apperr.NotFound("用户不存在")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.CurrentPassword)); err != nil {
		return apperr.Unauthorized("当前密码错误")
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), 12)
	if err != nil {
		return apperr.Internal("密码加密失败")
	}

	if err := svc.store.UpdateUser(ctx, user, map[string]any{
		"password_hash": string(newHash),
		"updated_at":    time.Now(),
	}); err != nil {
		return apperr.Internal("更新失败")
	}

	return svc.store.RevokeAllUserTokens(ctx, user.ID)
}

// ── helpers ───────────────────────────────────────────────────────────────────

func (svc *AuthService) issueTokens(ctx context.Context, user *model.AppUser) (*model.AuthResponse, error) {
	accessToken, err := svc.signAccessToken(user)
	if err != nil {
		return nil, apperr.Internal("令牌生成失败")
	}

	rawRefresh, refreshHash, err := newRefreshToken()
	if err != nil {
		return nil, apperr.Internal("令牌生成失败")
	}

	rt := &model.RefreshToken{
		UserID:    user.ID,
		TokenHash: refreshHash,
		ExpiresAt: time.Now().Add(time.Duration(svc.cfg.RefreshTokenDays) * 24 * time.Hour),
	}
	if err := svc.store.CreateToken(ctx, rt); err != nil {
		return nil, apperr.Internal("令牌存储失败")
	}

	return &model.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: rawRefresh,
		TokenType:    "Bearer",
		ExpiresIn:    int64(svc.cfg.AccessTokenMinutes) * 60,
		User:         toUserResponse(user),
	}, nil
}

func (svc *AuthService) signAccessToken(user *model.AppUser) (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": user.Username,
		"uid": user.ID.String(),
		"iat": now.Unix(),
		"exp": now.Add(time.Duration(svc.cfg.AccessTokenMinutes) * time.Minute).Unix(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).
		SignedString([]byte(svc.cfg.JWTSecret))
}

func newRefreshToken() (raw, hash string, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return
	}
	raw = hex.EncodeToString(b)
	hash = hashToken(raw)
	return
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func toUserResponse(u *model.AppUser) model.UserResponse {
	return model.UserResponse{
		ID:          u.ID,
		Username:    u.Username,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		CreatedAt:   u.CreatedAt,
	}
}
