package service

import (
	"context"
	"strings"

	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/store"
)

type LocationService struct {
	store *store.Store
}

func NewLocationService(s *store.Store) *LocationService { return &LocationService{store: s} }

func (svc *LocationService) ListGroup(ctx context.Context, groupID string, callerID uuid.UUID) ([]model.LocationResponse, error) {
	groupID = strings.TrimSpace(groupID)
	if groupID == "" || len(groupID) > 128 {
		return nil, apperr.BadRequest("groupId 无效")
	}

	gid, err := uuid.Parse(groupID)
	if err != nil {
		return nil, apperr.BadRequest("groupId 格式无效")
	}
	isMember, err := svc.store.IsMember(ctx, gid, callerID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if !isMember {
		return nil, apperr.Forbidden("你不是该群组成员")
	}

	locs, err := svc.store.LocationsByGroup(ctx, groupID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}

	resp := make([]model.LocationResponse, len(locs))
	for i := range locs {
		resp[i] = toLocationResponse(&locs[i])
	}
	return resp, nil
}

func (svc *LocationService) UpsertMyLocation(
	ctx context.Context,
	groupID string,
	req *model.UpsertLocationRequest,
	callerUsername string,
	callerUserID uuid.UUID,
) (*model.LocationResponse, error) {
	groupID = strings.TrimSpace(groupID)
	if groupID == "" || len(groupID) > 128 {
		return nil, apperr.BadRequest("groupId 无效")
	}

	participantID := strings.TrimSpace(req.ParticipantID)
	if participantID == "" {
		return nil, apperr.BadRequest("participantId 不能为空")
	}

	if req.Latitude == nil || req.Longitude == nil {
		return nil, apperr.BadRequest("latitude 和 longitude 为必填项")
	}
	if *req.Latitude < -90 || *req.Latitude > 90 {
		return nil, apperr.BadRequest("latitude 须在 -90~90 之间")
	}
	if *req.Longitude < -180 || *req.Longitude > 180 {
		return nil, apperr.BadRequest("longitude 须在 -180~180 之间")
	}

	// Membership check
	gid, parseErr := uuid.Parse(groupID)
	if parseErr != nil {
		return nil, apperr.BadRequest("groupId 格式无效")
	}
	isMember, memberErr := svc.store.IsMember(ctx, gid, callerUserID)
	if memberErr != nil {
		return nil, apperr.Internal("查询失败")
	}
	if !isMember {
		return nil, apperr.Forbidden("你不是该群组成员")
	}

	// Ownership check
	existing, err := svc.store.LocationByKey(ctx, groupID, participantID)
	if err != nil {
		return nil, apperr.Internal("数据库错误")
	}
	if existing != nil && existing.OwnerUserID != nil && *existing.OwnerUserID != callerUserID {
		return nil, apperr.Forbidden("无权更新其他参与者的位置")
	}

	// Caller's display name as fallback
	caller, err := svc.store.UserByUsername(ctx, callerUsername)
	if err != nil || caller == nil {
		return nil, apperr.Internal("用户不存在")
	}

	displayName := caller.DisplayName
	if req.DisplayName != nil && strings.TrimSpace(*req.DisplayName) != "" {
		displayName = strings.TrimSpace(*req.DisplayName)
	}

	platform := ""
	if req.Platform != nil {
		platform = strings.TrimSpace(*req.Platform)
	}

	loc := &model.ParticipantLocation{
		GroupID:       groupID,
		ParticipantID: participantID,
		DisplayName:   displayName,
		Latitude:      *req.Latitude,
		Longitude:     *req.Longitude,
		Accuracy:      req.Accuracy,
		Heading:       req.Heading,
		Speed:         req.Speed,
		Platform:      platform,
		OwnerUserID:   &callerUserID,
	}

	if err := svc.store.SaveLocation(ctx, loc); err != nil {
		return nil, apperr.Internal("位置更新失败")
	}

	resp := toLocationResponse(loc)
	return &resp, nil
}

func toLocationResponse(loc *model.ParticipantLocation) model.LocationResponse {
	return model.LocationResponse{
		GroupID:       loc.GroupID,
		ParticipantID: loc.ParticipantID,
		DisplayName:   loc.DisplayName,
		Latitude:      loc.Latitude,
		Longitude:     loc.Longitude,
		Accuracy:      loc.Accuracy,
		Heading:       loc.Heading,
		Speed:         loc.Speed,
		UpdatedAt:     loc.UpdatedAt,
		Platform:      loc.Platform,
		OwnerUserID:   loc.OwnerUserID,
	}
}
