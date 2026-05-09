package com.locationshare.backend.web.error;

import java.time.Instant;
import java.util.Map;

public record ApiErrorBody(
        Instant timestamp,
        int status,
        String error,
        String message,
        Map<String, String> details
) {
    public static ApiErrorBody of(int status, String error, String message, Map<String, String> details) {
        return new ApiErrorBody(Instant.now(), status, error, message, details);
    }
}
