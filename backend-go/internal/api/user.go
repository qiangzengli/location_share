package api

import (
	"net/http"

	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/service"
)

type userHandler struct {
	svc *service.UserService
}

func (h *userHandler) me(w http.ResponseWriter, r *http.Request) {
	username := usernameFromCtx(r.Context())
	resp, err := h.svc.Me(r.Context(), username)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *userHandler) updateMe(w http.ResponseWriter, r *http.Request) {
	var req model.UpdateProfileRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	username := usernameFromCtx(r.Context())
	resp, err := h.svc.UpdateProfile(r.Context(), username, &req)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
