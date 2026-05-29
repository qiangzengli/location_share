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
