package com.locationshare.backend.web.dto;

import jakarta.validation.constraints.Size;

public record UpdateProfileRequest(
        @Size(max = 128) String displayName,
        @Size(max = 255) String email
) {
}
