package model

import (
	"time"

	"github.com/google/uuid"
)

// ── Requests ──────────────────────────────────────────────────────────────────

type RegisterRequest struct {
	Username    string  `json:"username"`
	Password    string  `json:"password"`
	Email       *string `json:"email"`
	DisplayName *string `json:"displayName"`
}

type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"currentPassword"`
	NewPassword     string `json:"newPassword"`
}

type UpdateProfileRequest struct {
	DisplayName *string `json:"displayName"`
	Email       *string `json:"email"`
}

type UpsertLocationRequest struct {
	ParticipantID string   `json:"participantId"`
	DisplayName   *string  `json:"displayName"`
	Latitude      *float64 `json:"latitude"`
	Longitude     *float64 `json:"longitude"`
	Accuracy      *float64 `json:"accuracy"`
	Heading       *float64 `json:"heading"`
	Speed         *float64 `json:"speed"`
	Platform      *string  `json:"platform"`
}

// ── Responses ─────────────────────────────────────────────────────────────────

type AuthResponse struct {
	AccessToken  string       `json:"accessToken"`
	RefreshToken string       `json:"refreshToken"`
	TokenType    string       `json:"tokenType"`
	ExpiresIn    int64        `json:"expiresIn"`
	User         UserResponse `json:"user"`
}

type UserResponse struct {
	ID          uuid.UUID  `json:"id"`
	Username    string     `json:"username"`
	Email       *string    `json:"email"`
	DisplayName string     `json:"displayName"`
	CreatedAt   time.Time  `json:"createdAt"`
}

type LocationResponse struct {
	GroupID       string     `json:"groupId"`
	ParticipantID string     `json:"participantId"`
	DisplayName   string     `json:"displayName"`
	Latitude      float64    `json:"latitude"`
	Longitude     float64    `json:"longitude"`
	Accuracy      *float64   `json:"accuracy"`
	Heading       *float64   `json:"heading"`
	Speed         *float64   `json:"speed"`
	UpdatedAt     time.Time  `json:"updatedAt"`
	Platform      string     `json:"platform"`
	OwnerUserID   *uuid.UUID `json:"ownerUserId"`
}
