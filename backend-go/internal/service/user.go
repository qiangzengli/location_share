package service

import (
	"context"
	"strings"
	"time"

	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/store"
)

type UserService struct {
	store *store.Store
}

func NewUserService(s *store.Store) *UserService { return &UserService{store: s} }

func (svc *UserService) Me(ctx context.Context, username string) (*model.UserResponse, error) {
	user, err := svc.store.UserByUsername(ctx, username)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if user == nil {
		return nil, apperr.NotFound("用户不存在")
	}
	resp := toUserResponse(user)
	return &resp, nil
}

func (svc *UserService) UpdateProfile(ctx context.Context, username string, req *model.UpdateProfileRequest) (*model.UserResponse, error) {
	user, err := svc.store.UserByUsername(ctx, username)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if user == nil {
		return nil, apperr.NotFound("用户不存在")
	}

	updates := map[string]any{"updated_at": time.Now()}

	if req.DisplayName != nil {
		dn := strings.TrimSpace(*req.DisplayName)
		if dn != "" {
			updates["display_name"] = dn
		}
	}

	if req.Email != nil {
		e := strings.TrimSpace(*req.Email)
		if e == "" {
			updates["email"] = nil
		} else {
			e = strings.ToLower(e)
			if !validEmail(e) {
				return nil, apperr.BadRequest("邮箱格式不正确")
			}
			dup, err := svc.store.EmailExists(ctx, e, user.ID)
			if err != nil {
				return nil, apperr.Internal("数据库错误")
			}
			if dup {
				return nil, apperr.Conflict("邮箱已被使用")
			}
			updates["email"] = e
		}
	}

	if err := svc.store.UpdateUser(ctx, user, updates); err != nil {
		return nil, apperr.Internal("更新失败")
	}

	// reload
	updated, err := svc.store.UserByID(ctx, user.ID)
	if err != nil || updated == nil {
		return nil, apperr.Internal("数据库错误")
	}
	resp := toUserResponse(updated)
	return &resp, nil
}

// validEmail is shared across the service package.
func validEmail(e string) bool {
	// Same regex as the Java backend.
	// Using uuid to avoid importing regexp unnecessarily — we use a simple loop check.
	at := strings.LastIndex(e, "@")
	if at < 1 || at == len(e)-1 {
		return false
	}
	local := e[:at]
	domain := e[at+1:]
	if len(local) == 0 || len(domain) == 0 {
		return false
	}
	dot := strings.LastIndex(domain, ".")
	if dot < 1 || dot == len(domain)-1 {
		return false
	}
	tld := domain[dot+1:]
	return len(tld) >= 2 && len(tld) <= 6
}
