package com.locationshare.backend.web;

import com.locationshare.backend.service.LocationService;
import com.locationshare.backend.web.dto.LocationResponse;
import com.locationshare.backend.web.dto.UpsertLocationRequest;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 分组位置共享：上传本机定位、拉取同组全部参与者最新位置。
 */
@RestController
@RequestMapping("/api/groups")
public class GroupLocationController {

    private final LocationService locationService;

    public GroupLocationController(LocationService locationService) {
        this.locationService = locationService;
    }

    /**
     * 获取指定分组内所有参与者的最新位置（需登录）。
     */
    @GetMapping("/{groupId}/locations")
    public List<LocationResponse> listLocations(@PathVariable("groupId") String groupId) {
        return locationService.listGroup(groupId);
    }

    /**
     * 上传 / 更新当前用户在分组内的位置（幂等按 groupId + participantId）。
     */
    @PutMapping("/{groupId}/locations/me")
    public LocationResponse upsertMe(
            @PathVariable("groupId") String groupId,
            @Valid @RequestBody UpsertLocationRequest body,
            @AuthenticationPrincipal UserDetails principal
    ) {
        return locationService.upsertMyLocation(groupId, body, principal.getUsername());
    }
}
