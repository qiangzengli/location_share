# Phase 1: Family Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a family group system so users can create groups with invite codes, join groups, and see only group members' locations on the map.

**Architecture:** New `Group` and `GroupMember` entities in the Go backend with full CRUD API. Flutter gets new screens for group management and a group switcher on the map. Existing location endpoints are modified to enforce group membership. The current free-form `groupId` string in `SharingController` is replaced by server-managed group UUIDs.

**Tech Stack:** Go (chi, GORM, MySQL), Flutter (provider, http)

---

## File Structure

### Backend — New Files

| File | Responsibility |
|------|---------------|
| `backend-go/internal/model/group.go` | Group + GroupMember entities |
| `backend-go/internal/model/group_dto.go` | Group request/response DTOs |
| `backend-go/internal/store/group.go` | Group + GroupMember DB queries |
| `backend-go/internal/service/group.go` | Group business logic (create, join, leave, kick, invite code) |
| `backend-go/internal/api/group.go` | Group HTTP handlers |

### Backend — Modified Files

| File | Change |
|------|--------|
| `backend-go/internal/api/server.go` | Add group routes, inject GroupService |
| `backend-go/internal/service/location.go` | Add membership check in ListGroup and UpsertMyLocation |
| `backend-go/internal/store/store.go` | Add `IsMember` helper |
| `backend-go/cmd/server/main.go` | AutoMigrate new models, create GroupService |

### Flutter — New Files

| File | Responsibility |
|------|---------------|
| `lib/models/group.dart` | Group + GroupMember models |
| `lib/repositories/group_repository.dart` | Group REST API calls |
| `lib/providers/group_controller.dart` | Group list state, active group selection |
| `lib/screens/groups_screen.dart` | My groups list |
| `lib/screens/create_group_screen.dart` | Create group form |
| `lib/screens/join_group_screen.dart` | Join by invite code |
| `lib/screens/group_detail_screen.dart` | Group detail: members, invite code, leave/kick |

### Flutter — Modified Files

| File | Change |
|------|--------|
| `lib/widgets/app_shell.dart` | Add bottom navigation with 3 tabs (map, groups, settings) |
| `lib/screens/map_screen.dart` | Add group switcher dropdown in top bar |
| `lib/screens/settings_screen.dart` | Remove groupId text field |
| `lib/providers/sharing_controller.dart` | Use active group UUID from GroupController instead of manual groupId |
| `lib/main.dart` | Create GroupRepository + GroupController providers |
| `lib/services/local_prefs.dart` | Add activeGroupId pref key |

---

### Task 1: Backend — Group and GroupMember Entities

**Files:**
- Create: `backend-go/internal/model/group.go`

- [ ] **Step 1: Create the Group and GroupMember entity file**

```go
// backend-go/internal/model/group.go
package model

import (
	"crypto/rand"
	"math/big"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Group struct {
	ID         uuid.UUID `gorm:"type:varchar(36);primaryKey"`
	Name       string    `gorm:"size:64;not null"`
	InviteCode string    `gorm:"column:invite_code;size:8;not null;uniqueIndex"`
	OwnerID    uuid.UUID `gorm:"column:owner_id;type:varchar(36);not null;index"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

func (Group) TableName() string { return "groups" }

func (g *Group) BeforeCreate(_ *gorm.DB) error {
	if g.ID == uuid.Nil {
		g.ID = uuid.New()
	}
	if g.InviteCode == "" {
		g.InviteCode = randomCode(8)
	}
	return nil
}

type GroupMember struct {
	ID       uuid.UUID `gorm:"type:varchar(36);primaryKey"`
	GroupID  uuid.UUID `gorm:"column:group_id;type:varchar(36);not null;index:idx_group_user,unique"`
	UserID   uuid.UUID `gorm:"column:user_id;type:varchar(36);not null;index:idx_group_user,unique"`
	JoinedAt time.Time `gorm:"column:joined_at;not null"`
}

func (GroupMember) TableName() string { return "group_members" }

func (m *GroupMember) BeforeCreate(_ *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	if m.JoinedAt.IsZero() {
		m.JoinedAt = time.Now()
	}
	return nil
}

const codeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func randomCode(n int) string {
	b := make([]byte, n)
	for i := range b {
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(codeChars))))
		b[i] = codeChars[idx.Int64()]
	}
	return string(b)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd backend-go && git add internal/model/group.go
git commit -m "feat(backend): add Group and GroupMember entities"
```

---

### Task 2: Backend — Group DTOs

**Files:**
- Create: `backend-go/internal/model/group_dto.go`

- [ ] **Step 1: Create the group DTO file**

```go
// backend-go/internal/model/group_dto.go
package model

import (
	"time"

	"github.com/google/uuid"
)

// ── Group Requests ───────────────────────────────────────────────────────────

type CreateGroupRequest struct {
	Name string `json:"name"`
}

type JoinGroupRequest struct {
	InviteCode string `json:"inviteCode"`
}

type UpdateGroupRequest struct {
	Name string `json:"name"`
}

type InviteToGroupRequest struct {
	UserID string `json:"userId"`
}

// ── Group Responses ──────────────────────────────────────────────────────────

type GroupResponse struct {
	ID         uuid.UUID          `json:"id"`
	Name       string             `json:"name"`
	InviteCode string             `json:"inviteCode"`
	OwnerID    uuid.UUID          `json:"ownerId"`
	MemberCount int               `json:"memberCount"`
	CreatedAt  time.Time          `json:"createdAt"`
}

type GroupDetailResponse struct {
	ID         uuid.UUID          `json:"id"`
	Name       string             `json:"name"`
	InviteCode string             `json:"inviteCode"`
	OwnerID    uuid.UUID          `json:"ownerId"`
	Members    []GroupMemberResponse `json:"members"`
	CreatedAt  time.Time          `json:"createdAt"`
}

type GroupMemberResponse struct {
	UserID      uuid.UUID `json:"userId"`
	Username    string    `json:"username"`
	DisplayName string    `json:"displayName"`
	JoinedAt    time.Time `json:"joinedAt"`
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd backend-go && git add internal/model/group_dto.go
git commit -m "feat(backend): add group request/response DTOs"
```

---

### Task 3: Backend — Group Store Methods

**Files:**
- Create: `backend-go/internal/store/group.go`
- Modify: `backend-go/internal/store/store.go`

- [ ] **Step 1: Create the group store file**

```go
// backend-go/internal/store/group.go
package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/model"
	"gorm.io/gorm"
)

func (s *Store) CreateGroup(ctx context.Context, g *model.Group) error {
	return s.db.WithContext(ctx).Create(g).Error
}

func (s *Store) GroupByID(ctx context.Context, id uuid.UUID) (*model.Group, error) {
	var g model.Group
	err := s.db.WithContext(ctx).First(&g, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &g, err
}

func (s *Store) GroupByInviteCode(ctx context.Context, code string) (*model.Group, error) {
	var g model.Group
	err := s.db.WithContext(ctx).Where("invite_code = ?", code).First(&g).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &g, err
}

func (s *Store) GroupsByUser(ctx context.Context, userID uuid.UUID) ([]model.Group, error) {
	var groups []model.Group
	err := s.db.WithContext(ctx).
		Joins("JOIN group_members ON group_members.group_id = groups.id").
		Where("group_members.user_id = ?", userID).
		Order("groups.created_at DESC").
		Find(&groups).Error
	return groups, err
}

func (s *Store) UpdateGroup(ctx context.Context, g *model.Group, fields map[string]any) error {
	return s.db.WithContext(ctx).Model(g).Updates(fields).Error
}

func (s *Store) DeleteGroup(ctx context.Context, id uuid.UUID) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("group_id = ?", id).Delete(&model.GroupMember{}).Error; err != nil {
			return err
		}
		return tx.Delete(&model.Group{}, "id = ?", id).Error
	})
}

func (s *Store) AddMember(ctx context.Context, m *model.GroupMember) error {
	return s.db.WithContext(ctx).Create(m).Error
}

func (s *Store) RemoveMember(ctx context.Context, groupID, userID uuid.UUID) error {
	return s.db.WithContext(ctx).
		Where("group_id = ? AND user_id = ?", groupID, userID).
		Delete(&model.GroupMember{}).Error
}

func (s *Store) IsMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).
		Where("group_id = ? AND user_id = ?", groupID, userID).
		Count(&count).Error
	return count > 0, err
}

func (s *Store) GroupMembers(ctx context.Context, groupID uuid.UUID) ([]model.GroupMember, error) {
	var members []model.GroupMember
	err := s.db.WithContext(ctx).
		Where("group_id = ?", groupID).
		Order("joined_at ASC").
		Find(&members).Error
	return members, err
}

func (s *Store) MemberCount(ctx context.Context, groupID uuid.UUID) (int64, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.GroupMember{}).
		Where("group_id = ?", groupID).
		Count(&count).Error
	return count, err
}

func (s *Store) RemoveAllMembers(ctx context.Context, groupID uuid.UUID) error {
	return s.db.WithContext(ctx).
		Where("group_id = ?", groupID).
		Delete(&model.GroupMember{}).Error
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd backend-go && git add internal/store/group.go
git commit -m "feat(backend): add group store methods"
```

---

### Task 4: Backend — Group Service

**Files:**
- Create: `backend-go/internal/service/group.go`

- [ ] **Step 1: Create the group service**

```go
// backend-go/internal/service/group.go
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
```

- [ ] **Step 2: Export randomCode in model/group.go**

In `backend-go/internal/model/group.go`, rename `randomCode` to `RandomCode` (exported) so the service can call it:

Change:
```go
func randomCode(n int) string {
```
To:
```go
func RandomCode(n int) string {
```

And update the `BeforeCreate` call from `randomCode(8)` to `RandomCode(8)`.

- [ ] **Step 3: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
cd backend-go && git add internal/service/group.go internal/model/group.go
git commit -m "feat(backend): add group service with full CRUD + invite code"
```

---

### Task 5: Backend — Group HTTP Handlers and Routes

**Files:**
- Create: `backend-go/internal/api/group.go`
- Modify: `backend-go/internal/api/server.go`

- [ ] **Step 1: Create the group handler file**

```go
// backend-go/internal/api/group.go
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
```

- [ ] **Step 2: Update server.go to add group routes**

In `backend-go/internal/api/server.go`, update the `NewRouter` function signature to accept `*service.GroupService` and add the group route block:

```go
func NewRouter(
	cfg *config.Config,
	authSvc *service.AuthService,
	userSvc *service.UserService,
	locSvc *service.LocationService,
	groupSvc *service.GroupService,
) http.Handler {
```

Add handler init after `lh`:
```go
	gh := &groupHandler{svc: groupSvc}
```

Replace the existing `/api/groups` route block with:
```go
	// Groups — all protected.
	r.Route("/api/groups", func(r chi.Router) {
		r.Use(jwtAuth)
		r.Post("/", gh.create)
		r.Get("/", gh.list)
		r.Post("/join", gh.join)

		r.Route("/{groupId}", func(r chi.Router) {
			r.Get("/", gh.detail)
			r.Patch("/", gh.update)
			r.Delete("/", gh.delete)
			r.Delete("/leave", gh.leave)
			r.Post("/kick/{userId}", gh.kick)
			r.Post("/regenerate-code", gh.regenerateCode)

			// Location sub-routes (existing)
			r.Get("/locations", lh.list)
			r.Put("/locations/me", lh.upsert)
		})
	})
```

- [ ] **Step 3: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: will fail because main.go doesn't pass groupSvc yet — that's Task 6

- [ ] **Step 4: Commit**

```bash
cd backend-go && git add internal/api/group.go internal/api/server.go
git commit -m "feat(backend): add group HTTP handlers and routes"
```

---

### Task 6: Backend — Wire Up in main.go and AutoMigrate

**Files:**
- Modify: `backend-go/cmd/server/main.go`

- [ ] **Step 1: Update main.go**

Add `GroupService` creation after `locSvc` (around line 41):
```go
	groupSvc := service.NewGroupService(s)
```

Update the `AutoMigrate` call (around line 29) to include new models:
```go
	if err := db.AutoMigrate(
		&model.AppUser{},
		&model.RefreshToken{},
		&model.ParticipantLocation{},
		&model.Group{},
		&model.GroupMember{},
	); err != nil {
```

Update the router call (around line 43):
```go
	router := api.NewRouter(cfg, authSvc, userSvc, locSvc, groupSvc)
```

- [ ] **Step 2: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
cd backend-go && git add cmd/server/main.go
git commit -m "feat(backend): wire group service into main and auto-migrate"
```

---

### Task 7: Backend — Add Membership Check to Location Endpoints

**Files:**
- Modify: `backend-go/internal/service/location.go`

- [ ] **Step 1: Add store dependency and membership check**

Update `LocationService` to accept store for membership checks. Change the struct and constructor:

```go
type LocationService struct {
	store *store.Store
}

func NewLocationService(s *store.Store) *LocationService { return &LocationService{store: s} }
```

No change needed since it already has `store`. Add a membership check to `ListGroup` — add `callerID uuid.UUID` parameter:

```go
func (svc *LocationService) ListGroup(ctx context.Context, groupID string, callerID uuid.UUID) ([]model.LocationResponse, error) {
	groupID = strings.TrimSpace(groupID)
	if groupID == "" || len(groupID) > 128 {
		return nil, apperr.BadRequest("groupId 无效")
	}

	// Membership check: parse groupID as UUID and verify membership
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
```

Similarly add `callerID` to `UpsertMyLocation` and add membership check at the start (after validation, before existing ownership check):

```go
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
```

- [ ] **Step 2: Update location handler to pass callerID**

In `backend-go/internal/api/location.go`, update the `list` method:

```go
func (h *locationHandler) list(w http.ResponseWriter, r *http.Request) {
	groupID := chi.URLParam(r, "groupId")
	callerID := userIDFromCtx(r.Context())
	resp, err := h.svc.ListGroup(r.Context(), groupID, callerID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd backend-go && go build ./...`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
cd backend-go && git add internal/service/location.go internal/api/location.go
git commit -m "feat(backend): enforce group membership on location endpoints"
```

---

### Task 8: Backend — Build and Deploy

**Files:**
- Modify: none (build + deploy steps)

- [ ] **Step 1: Cross-compile for Linux**

Run:
```bash
cd backend-go && GOOS=linux GOARCH=amd64 go build -o server_linux ./cmd/server
```
Expected: `server_linux` binary created

- [ ] **Step 2: Copy to server and restart**

```bash
scp backend-go/server_linux root@106.14.193.30:/opt/location_share/server_linux
ssh root@106.14.193.30 "cd /opt/location_share && docker compose down && docker compose up -d --build"
```

- [ ] **Step 3: Verify health check**

```bash
ssh root@106.14.193.30 "curl -s http://localhost:8082/api/health"
```
Expected: `{"status":"UP"}`

- [ ] **Step 4: Commit binary**

```bash
cd backend-go && git add server_linux
git commit -m "build: update linux binary with group endpoints"
```

---

### Task 9: Flutter — Group Model

**Files:**
- Create: `lib/models/group.dart`

- [ ] **Step 1: Create the group model**

```dart
// lib/models/group.dart

class Group {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final int memberCount;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.memberCount,
    required this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      ownerId: json['ownerId'] as String,
      memberCount: json['memberCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupDetail {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final List<GroupMember> members;
  final DateTime createdAt;

  GroupDetail({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) {
    return GroupDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['inviteCode'] as String,
      ownerId: json['ownerId'] as String,
      members: (json['members'] as List<dynamic>)
          .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupMember {
  final String userId;
  final String username;
  final String displayName;
  final DateTime joinedAt;

  GroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/group.dart
git commit -m "feat(flutter): add Group, GroupDetail, GroupMember models"
```

---

### Task 10: Flutter — Group Repository

**Files:**
- Create: `lib/repositories/group_repository.dart`

- [ ] **Step 1: Create the group repository**

```dart
// lib/repositories/group_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location_share/models/group.dart';

class GroupRepository {
  GroupRepository({
    required this.baseUrl,
    required this.getAccessToken,
  });

  final String baseUrl;
  final Future<String?> Function() getAccessToken;

  Future<Map<String, String>> _headers() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Group>> myGroups() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/groups'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('获取群组列表失败: ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Group> createGroup(String name) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 201) {
      throw Exception('创建群组失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<GroupDetail> groupDetail(String groupId) async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('获取群组详情失败: ${resp.statusCode}');
    }
    return GroupDetail.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Group> joinGroup(String inviteCode) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/join'),
      headers: await _headers(),
      body: jsonEncode({'inviteCode': inviteCode}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? '加入群组失败');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> leaveGroup(String groupId) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/api/groups/$groupId/leave'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('退出群组失败: ${resp.statusCode}');
    }
  }

  Future<void> kickMember(String groupId, String userId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/kick/$userId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('踢出成员失败: ${resp.statusCode}');
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final resp = await http.delete(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 204) {
      throw Exception('解散群组失败: ${resp.statusCode}');
    }
  }

  Future<Group> regenerateCode(String groupId) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/groups/$groupId/regenerate-code'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('重新生成邀请码失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Group> updateGroup(String groupId, String name) async {
    final resp = await http.patch(
      Uri.parse('$baseUrl/api/groups/$groupId'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('修改群组失败: ${resp.statusCode}');
    }
    return Group.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/repositories/group_repository.dart
git commit -m "feat(flutter): add group repository for REST API"
```

---

### Task 11: Flutter — Group Controller

**Files:**
- Create: `lib/providers/group_controller.dart`
- Modify: `lib/services/local_prefs.dart`

- [ ] **Step 1: Add activeGroupId to LocalPrefs**

In `lib/services/local_prefs.dart`, add:

```dart
  static const _keyActiveGroupId = 'active_group_id';

  Future<String?> getActiveGroupId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyActiveGroupId);
  }

  Future<void> setActiveGroupId(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_keyActiveGroupId);
    } else {
      await p.setString(_keyActiveGroupId, id);
    }
  }
```

- [ ] **Step 2: Create group controller**

```dart
// lib/providers/group_controller.dart
import 'package:flutter/foundation.dart';
import 'package:location_share/models/group.dart';
import 'package:location_share/repositories/group_repository.dart';
import 'package:location_share/services/local_prefs.dart';

class GroupController extends ChangeNotifier {
  GroupController({
    required GroupRepository repository,
    required LocalPrefs prefs,
  })  : _repo = repository,
        _prefs = prefs;

  final GroupRepository _repo;
  final LocalPrefs _prefs;

  List<Group> groups = [];
  String? activeGroupId;
  bool isLoading = false;
  String? error;

  Group? get activeGroup {
    if (activeGroupId == null) return null;
    try {
      return groups.firstWhere((g) => g.id == activeGroupId);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    activeGroupId = await _prefs.getActiveGroupId();
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      groups = await _repo.myGroups();
      // If active group no longer exists, clear it
      if (activeGroupId != null &&
          !groups.any((g) => g.id == activeGroupId)) {
        activeGroupId = groups.isNotEmpty ? groups.first.id : null;
        await _prefs.setActiveGroupId(activeGroupId);
      }
      // Default to first group if none selected
      if (activeGroupId == null && groups.isNotEmpty) {
        activeGroupId = groups.first.id;
        await _prefs.setActiveGroupId(activeGroupId);
      }
    } catch (e) {
      error = e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> setActiveGroup(String groupId) async {
    activeGroupId = groupId;
    await _prefs.setActiveGroupId(groupId);
    notifyListeners();
  }

  Future<Group> createGroup(String name) async {
    final group = await _repo.createGroup(name);
    await refresh();
    activeGroupId = group.id;
    await _prefs.setActiveGroupId(group.id);
    notifyListeners();
    return group;
  }

  Future<Group> joinGroup(String inviteCode) async {
    final group = await _repo.joinGroup(inviteCode);
    await refresh();
    activeGroupId = group.id;
    await _prefs.setActiveGroupId(group.id);
    notifyListeners();
    return group;
  }

  Future<void> leaveGroup(String groupId) async {
    await _repo.leaveGroup(groupId);
    if (activeGroupId == groupId) {
      activeGroupId = null;
      await _prefs.setActiveGroupId(null);
    }
    await refresh();
  }

  Future<void> deleteGroup(String groupId) async {
    await _repo.deleteGroup(groupId);
    if (activeGroupId == groupId) {
      activeGroupId = null;
      await _prefs.setActiveGroupId(null);
    }
    await refresh();
  }

  Future<GroupDetail> groupDetail(String groupId) async {
    return _repo.groupDetail(groupId);
  }

  Future<void> kickMember(String groupId, String userId) async {
    await _repo.kickMember(groupId, userId);
  }

  Future<Group> regenerateCode(String groupId) async {
    return _repo.regenerateCode(groupId);
  }

  Future<Group> updateGroupName(String groupId, String name) async {
    final group = await _repo.updateGroup(groupId, name);
    await refresh();
    return group;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/providers/group_controller.dart lib/services/local_prefs.dart
git commit -m "feat(flutter): add GroupController with active group management"
```

---

### Task 12: Flutter — Groups Screen

**Files:**
- Create: `lib/screens/groups_screen.dart`

- [ ] **Step 1: Create the groups list screen**

```dart
// lib/screens/groups_screen.dart
import 'package:flutter/material.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/screens/create_group_screen.dart';
import 'package:location_share/screens/group_detail_screen.dart';
import 'package:location_share/screens/join_group_screen.dart';
import 'package:provider/provider.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.watch<GroupController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的群组'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: '加入群组',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinGroupScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: gc.isLoading && gc.groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : gc.groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('还没有加入任何群组',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text('创建一个新群组或通过邀请码加入',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              )),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: gc.refresh,
                  child: ListView.builder(
                    itemCount: gc.groups.length,
                    itemBuilder: (context, index) {
                      final group = gc.groups[index];
                      final isActive = group.id == gc.activeGroupId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.group,
                            color: isActive
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(group.name),
                        subtitle: Text('${group.memberCount} 位成员'),
                        trailing: isActive
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  GroupDetailScreen(groupId: group.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          gc.setActiveGroup(group.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换到「${group.name}」')),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/groups_screen.dart
git commit -m "feat(flutter): add groups list screen"
```

---

### Task 13: Flutter — Create Group Screen

**Files:**
- Create: `lib/screens/create_group_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/screens/create_group_screen.dart
import 'package:flutter/material.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:provider/provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入群组名称');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<GroupController>().createGroup(name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建群组')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '群组名称',
                hintText: '例如：我的家人',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/create_group_screen.dart
git commit -m "feat(flutter): add create group screen"
```

---

### Task 14: Flutter — Join Group Screen

**Files:**
- Create: `lib/screens/join_group_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/screens/join_group_screen.dart
import 'package:flutter/material.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:provider/provider.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入邀请码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final group = await context.read<GroupController>().joinGroup(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已加入「${group.name}」')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入群组')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '邀请码',
                hintText: '输入 8 位邀请码',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('加入'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/join_group_screen.dart
git commit -m "feat(flutter): add join group screen"
```

---

### Task 15: Flutter — Group Detail Screen

**Files:**
- Create: `lib/screens/group_detail_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
// lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location_share/models/group.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:provider/provider.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _detail = await context.read<GroupController>().groupDetail(widget.groupId);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final myUserId = auth.user?.uid;
    final isOwner = _detail != null && _detail!.ownerId == myUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.name ?? '群组详情'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (v) => _onMenu(v, context),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('修改名称')),
                const PopupMenuItem(value: 'regen', child: Text('重新生成邀请码')),
                const PopupMenuItem(value: 'delete', child: Text('解散群组')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(context, isOwner, myUserId),
    );
  }

  Widget _buildContent(BuildContext context, bool isOwner, String? myUserId) {
    final detail = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('邀请码', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          detail.inviteCode,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: '复制邀请码',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: detail.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('邀请码已复制')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('成员 (${detail.members.length})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...detail.members.map((m) => ListTile(
                leading: CircleAvatar(child: Text(m.displayName[0])),
                title: Text(m.displayName),
                subtitle: Text(m.username),
                trailing: _memberTrailing(m, isOwner, myUserId, detail.ownerId),
              )),
          const SizedBox(height: 24),
          if (!isOwner)
            OutlinedButton(
              onPressed: () => _leaveGroup(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('退出群组'),
            ),
        ],
      ),
    );
  }

  Widget? _memberTrailing(
      GroupMember m, bool isOwner, String? myUserId, String ownerId) {
    if (m.userId == ownerId) {
      return const Chip(label: Text('管理员'));
    }
    if (isOwner && m.userId != myUserId) {
      return IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        color: Theme.of(context).colorScheme.error,
        tooltip: '踢出',
        onPressed: () => _kickMember(context, m),
      );
    }
    return null;
  }

  Future<void> _kickMember(BuildContext context, GroupMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认踢出'),
        content: Text('确定要将「${m.displayName}」移出群组吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<GroupController>().kickMember(widget.groupId, m.userId);
    _load();
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后将无法查看该群组的位置信息。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<GroupController>().leaveGroup(widget.groupId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onMenu(String action, BuildContext context) async {
    final gc = context.read<GroupController>();
    switch (action) {
      case 'rename':
        final ctrl = TextEditingController(text: _detail?.name);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('修改名称'),
            content: TextField(controller: ctrl, decoration: const InputDecoration(border: OutlineInputBorder())),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('确认')),
            ],
          ),
        );
        ctrl.dispose();
        if (name != null && name.trim().isNotEmpty) {
          await gc.updateGroupName(widget.groupId, name.trim());
          _load();
        }
      case 'regen':
        await gc.regenerateCode(widget.groupId);
        _load();
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认解散'),
            content: const Text('解散后所有成员将被移出，此操作不可撤销。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('解散', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          await gc.deleteGroup(widget.groupId);
          if (mounted) Navigator.of(context).pop();
        }
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/group_detail_screen.dart
git commit -m "feat(flutter): add group detail screen with members, invite code, admin actions"
```

---

### Task 16: Flutter — Wire Providers and Update Navigation

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/widgets/app_shell.dart`
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Update main.dart to add GroupRepository and GroupController**

```dart
// Add imports at top:
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/repositories/group_repository.dart';

// After locationSync creation, add:
  final groupRepo = GroupRepository(
    baseUrl: 'http://106.14.193.30:8082',
    getAccessToken: authService.getAccessToken,
  );

// Add GroupController to MultiProvider (after the existing two):
        ChangeNotifierProvider(
          create: (_) => GroupController(
            repository: groupRepo,
            prefs: prefs,
          ),
        ),
```

- [ ] **Step 2: Update app_shell.dart for bottom navigation**

Replace the entire `app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/group_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/screens/auth_screen.dart';
import 'package:location_share/screens/groups_screen.dart';
import 'package:location_share/screens/map_screen.dart';
import 'package:location_share/screens/settings_screen.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _lastBoundUid;
  int _currentIndex = 0;

  static const _screens = <Widget>[
    MapScreen(),
    GroupsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = auth.user;
    if (user == null) {
      _lastBoundUid = null;
      return const AuthScreen();
    }

    final sharing = context.read<SharingController>();
    if (_lastBoundUid != user.uid ||
        sharing.participantId != user.uid ||
        sharing.displayName != user.displayName) {
      _lastBoundUid = user.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        sharing.applyAuthenticatedUser(
          uid: user.uid,
          displayName: user.displayName,
        );
        context.read<GroupController>().initialize();
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '地图'),
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: '群组'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Update settings_screen.dart — remove groupId field**

In `lib/screens/settings_screen.dart`:

Remove `_groupCtrl` declaration, initialization, and dispose.
Remove the group ID `TextField` and the save button's `setGroupId` call.
Remove the `const SizedBox(height: 12)` between the two text fields.

The settings screen should keep: user info, sign out, sharing toggle, display name field, save button (displayName only), permissions, and config status.

- [ ] **Step 4: Update map_screen.dart — add group switcher**

In the map screen's top status bar, add a group selector dropdown. In the `Row` children, after the `Expanded` column, before the settings `IconButton`, add:

```dart
                          Consumer<GroupController>(
                            builder: (_, gc, __) {
                              if (gc.groups.isEmpty) return const SizedBox.shrink();
                              return PopupMenuButton<String>(
                                tooltip: '切换群组',
                                icon: const Icon(Icons.swap_horiz),
                                onSelected: (id) {
                                  gc.setActiveGroup(id);
                                  context.read<SharingController>().setGroupId(id);
                                },
                                itemBuilder: (_) => gc.groups
                                    .map((g) => PopupMenuItem(
                                          value: g.id,
                                          child: Row(
                                            children: [
                                              if (g.id == gc.activeGroupId)
                                                Icon(Icons.check,
                                                    size: 18,
                                                    color: Theme.of(context).colorScheme.primary),
                                              if (g.id == gc.activeGroupId)
                                                const SizedBox(width: 8),
                                              Text(g.name),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              );
                            },
                          ),
```

Remove the settings `IconButton` from map_screen.dart (settings is now in bottom nav).

- [ ] **Step 5: Update SharingController to sync with active group**

In `lib/providers/sharing_controller.dart`, the `setGroupId` method already restarts the pipeline with the new groupId. No change needed — the map screen's group switcher calls `setGroupId` which handles everything.

- [ ] **Step 6: Verify Flutter builds**

Run: `flutter build apk --debug 2>&1 | tail -5`
Expected: BUILD SUCCESSFUL

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/widgets/app_shell.dart lib/screens/settings_screen.dart lib/screens/map_screen.dart
git commit -m "feat(flutter): wire group providers, add bottom nav, group switcher on map"
```

---

### Task 17: Integration Test — End to End

- [ ] **Step 1: Test backend group endpoints**

```bash
# Create group
ssh root@106.14.193.30 "curl -s -X POST http://localhost:8082/api/groups -H 'Content-Type: application/json' -H 'Authorization: Bearer <token>' -d '{\"name\":\"测试家庭\"}'"

# List groups
ssh root@106.14.193.30 "curl -s http://localhost:8082/api/groups -H 'Authorization: Bearer <token>'"

# Join by invite code
ssh root@106.14.193.30 "curl -s -X POST http://localhost:8082/api/groups/join -H 'Content-Type: application/json' -H 'Authorization: Bearer <token2>' -d '{\"inviteCode\":\"<code>\"}'"
```

- [ ] **Step 2: Run Flutter app on device**

```bash
flutter run -d da259617
```

Verify: bottom navigation shows 3 tabs, groups screen shows empty state, can create group, invite code displays correctly.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix: integration test fixes for phase 1"
```
