package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AppUser holds account credentials and profile data.
type AppUser struct {
	ID           uuid.UUID `gorm:"type:varchar(36);primaryKey"`
	Username     string    `gorm:"size:64;not null;uniqueIndex"`
	Email        *string   `gorm:"size:255;uniqueIndex"`
	PasswordHash string    `gorm:"column:password_hash;size:120;not null"`
	DisplayName  string    `gorm:"column:display_name;size:128;not null;default:''"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

func (AppUser) TableName() string { return "app_users" }

func (u *AppUser) BeforeCreate(_ *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}

// RefreshToken tracks issued refresh tokens (stored as SHA-256 hash).
type RefreshToken struct {
	ID        uuid.UUID `gorm:"type:varchar(36);primaryKey"`
	UserID    uuid.UUID `gorm:"column:user_id;type:varchar(36);not null;index"`
	TokenHash string    `gorm:"column:token_hash;size:64;not null;uniqueIndex"`
	ExpiresAt time.Time `gorm:"column:expires_at;not null"`
	Revoked   bool      `gorm:"not null;default:false"`
	CreatedAt time.Time
}

func (RefreshToken) TableName() string { return "refresh_tokens" }

func (r *RefreshToken) BeforeCreate(_ *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return nil
}

func (r *RefreshToken) IsExpired() bool { return time.Now().After(r.ExpiresAt) }

// ParticipantLocation stores a participant's last known position in a group.
// Primary key is composite (group_id, participant_id).
type ParticipantLocation struct {
	GroupID       string     `gorm:"column:group_id;size:128;primaryKey"`
	ParticipantID string     `gorm:"column:participant_id;size:128;primaryKey"`
	DisplayName   string     `gorm:"column:display_name;size:256;not null;default:''"`
	Latitude      float64    `gorm:"not null"`
	Longitude     float64    `gorm:"not null"`
	Accuracy      *float64
	Heading       *float64
	Speed         *float64
	UpdatedAt     time.Time  `gorm:"column:updated_at;not null"`
	Platform      string     `gorm:"size:32;not null;default:''"`
	OwnerUserID   *uuid.UUID `gorm:"column:owner_user_id;type:varchar(36)"`
}

func (ParticipantLocation) TableName() string { return "participant_locations" }
