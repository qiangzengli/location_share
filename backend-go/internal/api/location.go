package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/service"
)

type locationHandler struct {
	svc *service.LocationService
}

func (h *locationHandler) list(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	resp, err := h.svc.ListGroup(r.Context(), groupID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *locationHandler) upsert(w http.ResponseWriter, r *http.Request) {
	var req model.UpsertLocationRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	groupID := chi.URLParam(r, "groupId")
	username := usernameFromCtx(r.Context())
	userID := userIDFromCtx(r.Context())

	resp, err := h.svc.UpsertMyLocation(r.Context(), groupID, &req, username, userID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
