package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/locationshare/backend/internal/model"
	"gorm.io/gorm"
)

// Store wraps gorm.DB and provides typed query methods.
type Store struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Store { return &Store{db: db} }

// ── User ──────────────────────────────────────────────────────────────────────

func (s *Store) CreateUser(ctx context.Context, u *model.AppUser) error {
	return s.db.WithContext(ctx).Create(u).Error
}

func (s *Store) UserByUsername(ctx context.Context, username string) (*model.AppUser, error) {
	var u model.AppUser
	err := s.db.WithContext(ctx).Where("LOWER(username) = LOWER(?)", username).First(&u).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &u, err
}

func (s *Store) UserByID(ctx context.Context, id uuid.UUID) (*model.AppUser, error) {
	var u model.AppUser
	err := s.db.WithContext(ctx).First(&u, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &u, err
}

func (s *Store) UsernameExists(ctx context.Context, username string) (bool, error) {
	var count int64
	err := s.db.WithContext(ctx).Model(&model.AppUser{}).
		Where("LOWER(username) = LOWER(?)", username).Count(&count).Error
	return count > 0, err
}

func (s *Store) EmailExists(ctx context.Context, email string, excludeID uuid.UUID) (bool, error) {
	var count int64
	q := s.db.WithContext(ctx).Model(&model.AppUser{}).Where("LOWER(email) = LOWER(?)", email)
	if excludeID != uuid.Nil {
		q = q.Where("id != ?", excludeID)
	}
	err := q.Count(&count).Error
	return count > 0, err
}

func (s *Store) UpdateUser(ctx context.Context, u *model.AppUser, fields map[string]any) error {
	return s.db.WithContext(ctx).Model(u).Updates(fields).Error
}

// ── Refresh token ─────────────────────────────────────────────────────────────

func (s *Store) CreateToken(ctx context.Context, t *model.RefreshToken) error {
	return s.db.WithContext(ctx).Create(t).Error
}

func (s *Store) TokenByHash(ctx context.Context, hash string) (*model.RefreshToken, error) {
	var t model.RefreshToken
	err := s.db.WithContext(ctx).Where("token_hash = ? AND revoked = ?", hash, false).First(&t).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &t, err
}

func (s *Store) RevokeToken(ctx context.Context, t *model.RefreshToken) error {
	return s.db.WithContext(ctx).Model(t).Update("revoked", true).Error
}

func (s *Store) RevokeAllUserTokens(ctx context.Context, userID uuid.UUID) error {
	return s.db.WithContext(ctx).Model(&model.RefreshToken{}).
		Where("user_id = ? AND revoked = ?", userID, false).
		Update("revoked", true).Error
}

// ── Location ──────────────────────────────────────────────────────────────────

func (s *Store) LocationsByGroup(ctx context.Context, groupID string) ([]model.ParticipantLocation, error) {
	var locs []model.ParticipantLocation
	err := s.db.WithContext(ctx).
		Where("group_id = ?", groupID).
		Order("updated_at DESC").
		Find(&locs).Error
	return locs, err
}

func (s *Store) LocationByKey(ctx context.Context, groupID, participantID string) (*model.ParticipantLocation, error) {
	var loc model.ParticipantLocation
	err := s.db.WithContext(ctx).
		Where("group_id = ? AND participant_id = ?", groupID, participantID).
		First(&loc).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	return &loc, err
}

func (s *Store) SaveLocation(ctx context.Context, loc *model.ParticipantLocation) error {
	loc.UpdatedAt = time.Now()
	existing, err := s.LocationByKey(ctx, loc.GroupID, loc.ParticipantID)
	if err != nil {
		return err
	}
	if existing == nil {
		return s.db.WithContext(ctx).Create(loc).Error
	}
	return s.db.WithContext(ctx).Model(existing).Updates(map[string]any{
		"display_name":  loc.DisplayName,
		"latitude":      loc.Latitude,
		"longitude":     loc.Longitude,
		"accuracy":      loc.Accuracy,
		"heading":       loc.Heading,
		"speed":         loc.Speed,
		"updated_at":    loc.UpdatedAt,
		"platform":      loc.Platform,
		"owner_user_id": loc.OwnerUserID,
	}).Error
}
