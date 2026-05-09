package com.locationshare.backend.web.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpsertLocationRequest(
        @NotBlank @Size(max = 128) String participantId,
        @Size(max = 256) String displayName,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        Double accuracy,
        Double heading,
        Double speed,
        @Size(max = 32) String platform
) {
}
