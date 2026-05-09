package com.locationshare.backend.service;

import com.locationshare.backend.config.JwtProperties;
import com.locationshare.backend.domain.AppUser;
import com.locationshare.backend.domain.RefreshToken;
import com.locationshare.backend.repository.AppUserRepository;
import com.locationshare.backend.repository.RefreshTokenRepository;
import com.locationshare.backend.security.JwtTokenService;
import com.locationshare.backend.security.RefreshTokenFactory;
import com.locationshare.backend.security.TokenHasher;
import com.locationshare.backend.web.dto.AuthResponse;
import com.locationshare.backend.web.dto.ChangePasswordRequest;
import com.locationshare.backend.web.dto.LoginRequest;
import com.locationshare.backend.web.dto.RegisterRequest;
import com.locationshare.backend.web.dto.UserResponse;
import com.locationshare.backend.web.error.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
public class AuthService {

    private final AppUserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenService jwtTokenService;
    private final JwtProperties jwtProperties;
    private final RefreshTokenFactory refreshTokenFactory;
    private final TokenHasher tokenHasher;

    public AuthService(
            AppUserRepository users,
            RefreshTokenRepository refreshTokens,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtTokenService jwtTokenService,
            JwtProperties jwtProperties,
            RefreshTokenFactory refreshTokenFactory,
            TokenHasher tokenHasher
    ) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtTokenService = jwtTokenService;
        this.jwtProperties = jwtProperties;
        this.refreshTokenFactory = refreshTokenFactory;
        this.tokenHasher = tokenHasher;
    }

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        String username = req.username().trim().toLowerCase();
        if (users.existsByUsernameIgnoreCase(username)) {
            throw new ApiException(HttpStatus.CONFLICT, "用户名已被占用");
        }
        String emailNorm = normalizeEmail(req.email());
        UserService.validateEmailOptional(req.email());
        if (emailNorm != null && users.existsByEmailIgnoreCase(emailNorm)) {
            throw new ApiException(HttpStatus.CONFLICT, "邮箱已被占用");
        }
        String display = req.displayName() == null || req.displayName().isBlank()
                ? username
                : req.displayName().trim();
        AppUser user = new AppUser(
                username,
                emailNorm,
                passwordEncoder.encode(req.password()),
                display
        );
        users.save(user);
        return issueTokens(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest req) {
        String username = req.username().trim().toLowerCase();
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(username, req.password())
        );
        AppUser user = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        return issueTokens(user);
    }

    @Transactional
    public AuthResponse refresh(String rawRefreshToken) {
        String hash = tokenHasher.sha256Hex(rawRefreshToken);
        RefreshToken rt = refreshTokens.findByTokenHashAndRevokedIsFalse(hash)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "刷新令牌无效或已失效"));
        if (rt.getExpiresAt().isBefore(Instant.now())) {
            rt.setRevoked(true);
            refreshTokens.save(rt);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "刷新令牌已过期");
        }
        AppUser user = rt.getUser();
        rt.setRevoked(true);
        refreshTokens.save(rt);
        return issueTokens(user);
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        String hash = tokenHasher.sha256Hex(rawRefreshToken);
        refreshTokens.findByTokenHashAndRevokedIsFalse(hash).ifPresent(rt -> {
            rt.setRevoked(true);
            refreshTokens.save(rt);
        });
    }

    @Transactional
    public void logoutAll(String username) {
        AppUser user = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        refreshTokens.revokeAllActiveForUser(user);
    }

    @Transactional
    public void changePassword(String username, ChangePasswordRequest req) {
        AppUser user = users.findByUsernameIgnoreCase(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在"));
        if (!passwordEncoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "当前密码不正确");
        }
        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        user.touch();
        users.save(user);
        refreshTokens.revokeAllActiveForUser(user);
        SecurityContextHolder.clearContext();
    }

    private AuthResponse issueTokens(AppUser user) {
        String access = jwtTokenService.createAccessToken(user);
        String rawRefresh = refreshTokenFactory.newRawToken();
        String hash = tokenHasher.sha256Hex(rawRefresh);
        Instant exp = Instant.now().plus(jwtProperties.refreshTokenDays(), ChronoUnit.DAYS);
        refreshTokens.save(new RefreshToken(user, hash, exp));
        return AuthResponse.of(
                access,
                rawRefresh,
                jwtTokenService.accessTokenExpiresInSeconds(),
                UserResponse.from(user)
        );
    }

    private static String normalizeEmail(String email) {
        if (email == null || email.isBlank()) {
            return null;
        }
        return email.trim().toLowerCase();
    }
}
