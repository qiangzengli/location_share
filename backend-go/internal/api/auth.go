package api

import (
	"net/http"

	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/service"
)

type authHandler struct {
	svc *service.AuthService
}

func (h *authHandler) register(w http.ResponseWriter, r *http.Request) {
	var req model.RegisterRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	resp, err := h.svc.Register(r.Context(), &req)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, resp)
}

func (h *authHandler) login(w http.ResponseWriter, r *http.Request) {
	var req model.LoginRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	resp, err := h.svc.Login(r.Context(), &req)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *authHandler) refresh(w http.ResponseWriter, r *http.Request) {
	var req model.RefreshRequest
	if err := decode(r, &req); err != nil || req.RefreshToken == "" {
		writeError(w, apperr.BadRequest("refreshToken 不能为空"))
		return
	}
	resp, err := h.svc.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *authHandler) logout(w http.ResponseWriter, r *http.Request) {
	var req model.LogoutRequest
	if err := decode(r, &req); err != nil || req.RefreshToken == "" {
		writeError(w, apperr.BadRequest("refreshToken 不能为空"))
		return
	}
	_ = h.svc.Logout(r.Context(), req.RefreshToken)
	w.WriteHeader(http.StatusNoContent)
}

func (h *authHandler) logoutAll(w http.ResponseWriter, r *http.Request) {
	username := usernameFromCtx(r.Context())
	if err := h.svc.LogoutAll(r.Context(), username); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *authHandler) changePassword(w http.ResponseWriter, r *http.Request) {
	var req model.ChangePasswordRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	username := usernameFromCtx(r.Context())
	if err := h.svc.ChangePassword(r.Context(), username, &req); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
