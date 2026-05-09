package com.locationshare.backend.web.dto;

import com.locationshare.backend.domain.AppUser;

import java.time.Instant;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String username,
        String email,
        String displayName,
        Instant createdAt
) {
    public static UserResponse from(AppUser u) {
        return new UserResponse(
                u.getId(),
                u.getUsername(),
                u.getEmail(),
                u.getDisplayName(),
                u.getCreatedAt()
        );
    }
}
