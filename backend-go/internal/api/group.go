package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/service"
)

type groupHandler struct {
	svc *service.GroupService
}

func (h *groupHandler) create(w http.ResponseWriter, r *http.Request) {
	var req model.CreateGroupRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.Create(r.Context(), &req, callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, resp)
}

func (h *groupHandler) list(w http.ResponseWriter, r *http.Request) {
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.MyGroups(r.Context(), callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *groupHandler) detail(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.Detail(r.Context(), groupID, callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *groupHandler) update(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	var req model.UpdateGroupRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.Update(r.Context(), groupID, callerID, &req)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *groupHandler) delete(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	if err := h.svc.Delete(r.Context(), groupID, callerID); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *groupHandler) join(w http.ResponseWriter, r *http.Request) {
	var req model.JoinGroupRequest
	if err := decode(r, &req); err != nil {
		writeError(w, apperr.BadRequest("请求体解析失败"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.Join(r.Context(), &req, callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *groupHandler) leave(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	if err := h.svc.Leave(r.Context(), groupID, callerID); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *groupHandler) kick(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	targetID, err := uuid.Parse(chi.URLParam(r, "userId"))
	if err != nil {
		writeError(w, apperr.BadRequest("userId 格式无效"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	if err := h.svc.Kick(r.Context(), groupID, targetID, callerID); err != nil {
		writeError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *groupHandler) regenerateCode(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "groupId"))
	if err != nil {
		writeError(w, apperr.BadRequest("groupId 格式无效"))
		return
	}
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.RegenerateCode(r.Context(), groupID, callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
