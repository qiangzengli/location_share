package com.locationshare.backend.service;

import com.locationshare.backend.domain.AppUser;
import com.locationshare.backend.domain.ParticipantLocationId;
import com.locationshare.backend.domain.ParticipantLocationRow;
import com.locationshare.backend.repository.AppUserRepository;
import com.locationshare.backend.repository.ParticipantLocationRepository;
import com.locationshare.backend.web.dto.LocationResponse;
import com.locationshare.backend.web.dto.UpsertLocationRequest;
import com.locationshare.backend.web.error.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class LocationService {

    private final ParticipantLocationRepository locations;
    private final AppUserRepository users;

    public LocationService(ParticipantLocationRepository locations, AppUserRepository users) {
        this.locations = locations;
        this.users = users;
    }

    @Transactional(readOnly = true)
    public List<LocationResponse> listGroup(String groupId) {
        String gid = normalizeGroupId(groupId);
        return locations.findByIdGroupIdOrderByUpdatedAtDesc(gid).stream()
                .map(LocationResponse::from)
                .toList();
    }

    @Transactional
    public LocationResponse upsertMyLocation(String groupId, UpsertLocationRequest req, String username) {
        AppUser user = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        UUID userId = user.getId();
        String gid = normalizeGroupId(groupId);
        String participantId = req.participantId().trim();
        if (participantId.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "participantId 不能为空");
        }

        ParticipantLocationId id = new ParticipantLocationId(gid, participantId);
        Instant now = Instant.now();

        ParticipantLocationRow row = locations.findById(id).map(existing -> {
                    UUID owner = existing.getOwnerUserId();
                    if (owner != null && !owner.equals(userId)) {
                        throw new ApiException(HttpStatus.FORBIDDEN, "无权更新其他参与者的位置");
                    }
                    if (owner == null) {
                        existing.setOwnerUserId(userId);
                    }
                    return existing;
                })
                .orElseGet(() -> {
                    ParticipantLocationRow n = new ParticipantLocationRow();
                    n.setId(id);
                    n.setOwnerUserId(userId);
                    return n;
                });

        String display = req.displayName();
        if (display == null || display.isBlank()) {
            row.setDisplayName(user.getDisplayName() != null ? user.getDisplayName() : "");
        } else {
            row.setDisplayName(display.trim());
        }

        row.setLatitude(req.latitude());
        row.setLongitude(req.longitude());
        row.setAccuracy(req.accuracy());
        row.setHeading(req.heading());
        row.setSpeed(req.speed());
        row.setPlatform(req.platform() == null ? "" : req.platform().trim());
        row.setUpdatedAt(now);

        return LocationResponse.from(locations.save(row));
    }

    private static String normalizeGroupId(String groupId) {
        if (groupId == null || groupId.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "groupId 无效");
        }
        String t = groupId.trim();
        if (t.length() > 128) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "groupId 过长");
        }
        return t;
    }
}
