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
		g.InviteCode = RandomCode(8)
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

func RandomCode(n int) string {
	b := make([]byte, n)
	for i := range b {
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(codeChars))))
		b[i] = codeChars[idx.Int64()]
	}
	return string(b)
}
