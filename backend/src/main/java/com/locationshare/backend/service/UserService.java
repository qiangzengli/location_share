package com.locationshare.backend.service;

import com.locationshare.backend.domain.AppUser;
import com.locationshare.backend.repository.AppUserRepository;
import com.locationshare.backend.web.dto.UpdateProfileRequest;
import com.locationshare.backend.web.dto.UserResponse;
import com.locationshare.backend.web.error.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.regex.Pattern;

@Service
public class UserService {

    private static final Pattern EMAIL = Pattern.compile(
            "^[\\w!#$%&'*+/=?`{|}~^-]+(?:\\.[\\w!#$%&'*+/=?`{|}~^-]+)*@"
                    + "(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,6}$"
    );

    private final AppUserRepository users;

    public UserService(AppUserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public UserResponse me(String username) {
        AppUser u = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        return UserResponse.from(u);
    }

    @Transactional
    public UserResponse updateProfile(String username, UpdateProfileRequest req) {
        AppUser u = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        if (req.displayName() != null) {
            u.setDisplayName(req.displayName().trim());
        }
        if (req.email() != null) {
            String e = req.email().trim();
            if (e.isEmpty()) {
                u.setEmail(null);
            } else {
                if (!EMAIL.matcher(e).matches()) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "邮箱格式不正确");
                }
                String lower = e.toLowerCase();
                if (users.existsByEmailIgnoreCase(lower)
                        && (u.getEmail() == null || !u.getEmail().equalsIgnoreCase(lower))) {
                    throw new ApiException(HttpStatus.CONFLICT, "该邮箱已被使用");
                }
                u.setEmail(lower);
            }
        }
        u.touch();
        return UserResponse.from(users.save(u));
    }

    public static void validateEmailOptional(String email) {
        if (email == null || email.isBlank()) {
            return;
        }
        String t = email.trim();
        if (!EMAIL.matcher(t).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "邮箱格式不正确");
        }
    }
}
