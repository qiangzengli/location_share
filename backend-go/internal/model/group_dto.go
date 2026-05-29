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
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	InviteCode  string    `json:"inviteCode"`
	OwnerID     uuid.UUID `json:"ownerId"`
	MemberCount int       `json:"memberCount"`
	CreatedAt   time.Time `json:"createdAt"`
}

type GroupDetailResponse struct {
	ID         uuid.UUID             `json:"id"`
	Name       string                `json:"name"`
	InviteCode string                `json:"inviteCode"`
	OwnerID    uuid.UUID             `json:"ownerId"`
	Members    []GroupMemberResponse `json:"members"`
	CreatedAt  time.Time             `json:"createdAt"`
}

type GroupMemberResponse struct {
	UserID      uuid.UUID `json:"userId"`
	Username    string    `json:"username"`
	DisplayName string    `json:"displayName"`
	JoinedAt    time.Time `json:"joinedAt"`
}
