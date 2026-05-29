package service

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/apperr"
	"github.com/locationshare/backend/internal/model"
	"github.com/locationshare/backend/internal/store"
)

type GroupService struct {
	store *store.Store
}

func NewGroupService(s *store.Store) *GroupService {
	return &GroupService{store: s}
}

func (svc *GroupService) Create(ctx context.Context, req *model.CreateGroupRequest, callerID uuid.UUID) (*model.GroupResponse, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" || len(name) > 64 {
		return nil, apperr.BadRequest("组名长度须在 1~64 个字符之间")
	}

	group := &model.Group{
		Name:    name,
		OwnerID: callerID,
	}
	if err := svc.store.CreateGroup(ctx, group); err != nil {
		return nil, apperr.Internal("创建群组失败")
	}

	member := &model.GroupMember{
		GroupID: group.ID,
		UserID:  callerID,
	}
	if err := svc.store.AddMember(ctx, member); err != nil {
		return nil, apperr.Internal("加入群组失败")
	}

	return &model.GroupResponse{
		ID:          group.ID,
		Name:        group.Name,
		InviteCode:  group.InviteCode,
		OwnerID:     group.OwnerID,
		MemberCount: 1,
		CreatedAt:   group.CreatedAt,
	}, nil
}

func (svc *GroupService) MyGroups(ctx context.Context, callerID uuid.UUID) ([]model.GroupResponse, error) {
	groups, err := svc.store.GroupsByUser(ctx, callerID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}

	resp := make([]model.GroupResponse, len(groups))
	for i := range groups {
		count, _ := svc.store.MemberCount(ctx, groups[i].ID)
		resp[i] = model.GroupResponse{
			ID:          groups[i].ID,
			Name:        groups[i].Name,
			InviteCode:  groups[i].InviteCode,
			OwnerID:     groups[i].OwnerID,
			MemberCount: int(count),
			CreatedAt:   groups[i].CreatedAt,
		}
	}
	return resp, nil
}

func (svc *GroupService) Detail(ctx context.Context, groupID, callerID uuid.UUID) (*model.GroupDetailResponse, error) {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if group == nil {
		return nil, apperr.NotFound("群组不存在")
	}

	isMember, err := svc.store.IsMember(ctx, groupID, callerID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if !isMember {
		return nil, apperr.Forbidden("你不是该群组成员")
	}

	members, err := svc.store.GroupMembers(ctx, groupID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}

	memberResps := make([]model.GroupMemberResponse, len(members))
	for i, m := range members {
		user, _ := svc.store.UserByID(ctx, m.UserID)
		if user != nil {
			memberResps[i] = model.GroupMemberResponse{
				UserID:      user.ID,
				Username:    user.Username,
				DisplayName: user.DisplayName,
				JoinedAt:    m.JoinedAt,
			}
		}
	}

	return &model.GroupDetailResponse{
		ID:         group.ID,
		Name:       group.Name,
		InviteCode: group.InviteCode,
		OwnerID:    group.OwnerID,
		Members:    memberResps,
		CreatedAt:  group.CreatedAt,
	}, nil
}

func (svc *GroupService) Update(ctx context.Context, groupID, callerID uuid.UUID, req *model.UpdateGroupRequest) (*model.GroupResponse, error) {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if group == nil {
		return nil, apperr.NotFound("群组不存在")
	}
	if group.OwnerID != callerID {
		return nil, apperr.Forbidden("仅管理员可修改群组")
	}

	name := strings.TrimSpace(req.Name)
	if name == "" || len(name) > 64 {
		return nil, apperr.BadRequest("组名长度须在 1~64 个字符之间")
	}

	if err := svc.store.UpdateGroup(ctx, group, map[string]any{
		"name":       name,
		"updated_at": time.Now(),
	}); err != nil {
		return nil, apperr.Internal("更新失败")
	}

	count, _ := svc.store.MemberCount(ctx, groupID)
	return &model.GroupResponse{
		ID:          group.ID,
		Name:        name,
		InviteCode:  group.InviteCode,
		OwnerID:     group.OwnerID,
		MemberCount: int(count),
		CreatedAt:   group.CreatedAt,
	}, nil
}

func (svc *GroupService) Delete(ctx context.Context, groupID, callerID uuid.UUID) error {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return apperr.Internal("查询失败")
	}
	if group == nil {
		return apperr.NotFound("群组不存在")
	}
	if group.OwnerID != callerID {
		return apperr.Forbidden("仅管理员可解散群组")
	}
	return svc.store.DeleteGroup(ctx, groupID)
}

func (svc *GroupService) Join(ctx context.Context, req *model.JoinGroupRequest, callerID uuid.UUID) (*model.GroupResponse, error) {
	code := strings.TrimSpace(strings.ToUpper(req.InviteCode))
	if code == "" {
		return nil, apperr.BadRequest("邀请码不能为空")
	}

	group, err := svc.store.GroupByInviteCode(ctx, code)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if group == nil {
		return nil, apperr.NotFound("邀请码无效")
	}

	already, err := svc.store.IsMember(ctx, group.ID, callerID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if already {
		return nil, apperr.Conflict("你已经是该群组成员")
	}

	member := &model.GroupMember{
		GroupID: group.ID,
		UserID:  callerID,
	}
	if err := svc.store.AddMember(ctx, member); err != nil {
		return nil, apperr.Internal("加入群组失败")
	}

	count, _ := svc.store.MemberCount(ctx, group.ID)
	return &model.GroupResponse{
		ID:          group.ID,
		Name:        group.Name,
		InviteCode:  group.InviteCode,
		OwnerID:     group.OwnerID,
		MemberCount: int(count),
		CreatedAt:   group.CreatedAt,
	}, nil
}

func (svc *GroupService) Leave(ctx context.Context, groupID, callerID uuid.UUID) error {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return apperr.Internal("查询失败")
	}
	if group == nil {
		return apperr.NotFound("群组不存在")
	}
	if group.OwnerID == callerID {
		return apperr.BadRequest("管理员不能退出群组，请先解散或转让")
	}

	isMember, err := svc.store.IsMember(ctx, groupID, callerID)
	if err != nil {
		return apperr.Internal("查询失败")
	}
	if !isMember {
		return apperr.NotFound("你不是该群组成员")
	}

	return svc.store.RemoveMember(ctx, groupID, callerID)
}

func (svc *GroupService) Kick(ctx context.Context, groupID, targetUserID, callerID uuid.UUID) error {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return apperr.Internal("查询失败")
	}
	if group == nil {
		return apperr.NotFound("群组不存在")
	}
	if group.OwnerID != callerID {
		return apperr.Forbidden("仅管理员可踢人")
	}
	if targetUserID == callerID {
		return apperr.BadRequest("不能踢出自己")
	}

	isMember, err := svc.store.IsMember(ctx, groupID, targetUserID)
	if err != nil {
		return apperr.Internal("查询失败")
	}
	if !isMember {
		return apperr.NotFound("该用户不在群组中")
	}

	return svc.store.RemoveMember(ctx, groupID, targetUserID)
}

func (svc *GroupService) RegenerateCode(ctx context.Context, groupID, callerID uuid.UUID) (*model.GroupResponse, error) {
	group, err := svc.store.GroupByID(ctx, groupID)
	if err != nil {
		return nil, apperr.Internal("查询失败")
	}
	if group == nil {
		return nil, apperr.NotFound("群组不存在")
	}
	if group.OwnerID != callerID {
		return nil, apperr.Forbidden("仅管理员可重新生成邀请码")
	}

	newCode := model.RandomCode(8)
	if err := svc.store.UpdateGroup(ctx, group, map[string]any{
		"invite_code": newCode,
		"updated_at":  time.Now(),
	}); err != nil {
		return nil, apperr.Internal("更新失败")
	}

	count, _ := svc.store.MemberCount(ctx, groupID)
	return &model.GroupResponse{
		ID:          group.ID,
		Name:        group.Name,
		InviteCode:  newCode,
		OwnerID:     group.OwnerID,
		MemberCount: int(count),
		CreatedAt:   group.CreatedAt,
	}, nil
}
