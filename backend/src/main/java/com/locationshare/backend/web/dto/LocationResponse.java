package com.locationshare.backend.web.dto;

import com.locationshare.backend.domain.ParticipantLocationRow;

import java.time.Instant;
import java.util.UUID;

public record LocationResponse(
        String groupId,
        String participantId,
        String displayName,
        double latitude,
        double longitude,
        Double accuracy,
        Double heading,
        Double speed,
        Instant updatedAt,
        String platform,
        UUID ownerUserId
) {
    public static LocationResponse from(ParticipantLocationRow row) {
        return new LocationResponse(
                row.getId().getGroupId(),
                row.getId().getParticipantId(),
                row.getDisplayName(),
                row.getLatitude(),
                row.getLongitude(),
                row.getAccuracy(),
                row.getHeading(),
                row.getSpeed(),
                row.getUpdatedAt(),
                row.getPlatform(),
                row.getOwnerUserId()
        );
    }
}
