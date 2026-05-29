# Location Share - Project Context

## Overview

Real-time family location sharing app. Flutter (iOS + Android) + Go backend + MySQL. Uses AMap (Gaode) SDK for maps and positioning in China.

**Production server:** `106.14.193.30` (Ubuntu), backend exposed on port `8082` (maps to container port 8080).

**Test account:** `2224357370@qq.com` / `12345678`

## Architecture

```
Flutter App (Provider state management)
    |
    |  REST API (HTTP + JWT auth)
    v
Go Backend (chi router, GORM ORM)
    |
    v
MySQL 8 (Docker Compose)
```

- No Firebase/Firestore - fully self-hosted auth and data
- JWT auth: access token (15 min) + refresh token (14 days), auto-refresh on expiry
- Location polling: Flutter HTTP polls `/api/groups/{id}/locations` every 3 seconds
- AMap SDK for map rendering and device positioning (requires privacy consent flow)

## Flutter App Structure (`lib/`)

### Entry & Shell
- `main.dart` — App entry. Creates `LocalPrefs`, `HttpAuthService`, `HttpLocationSyncRepository`, `GroupRepository`. Wires 3 ChangeNotifierProviders (SharingController, AuthController, GroupController).
- `widgets/app_shell.dart` — Auth gate + bottom nav (3 tabs: map, groups, settings). On auth, binds user to SharingController and initializes GroupController.

### State Management (Provider + ChangeNotifier)
- `providers/auth_controller.dart` — Wraps `HttpAuthService`. Manages user state, login/register/signOut, error messages. Listens to `authStateChanges()` stream.
- `providers/sharing_controller.dart` — Core location logic. Manages AMap location SDK, location polling pipeline (start/stop), upsert throttling (2s interval, 8m min movement). Maintains `myLatLng`, `remoteById` map, `sharingEnabled` toggle.
- `providers/group_controller.dart` — Group CRUD. Manages group list, active group selection (persisted in SharedPreferences). Auto-selects first group if active becomes invalid.

### Screens
- `screens/auth_screen.dart` — Login/register form with tab switching
- `screens/map_screen.dart` — AMap widget with markers for self (blue) and others (red). Top status bar (sharing status, group switcher). Bottom draggable sheet with people list. Privacy consent gate.
- `screens/groups_screen.dart` — List of user's groups. FAB for create/join. Active group shown with checkmark. Tap for detail.
- `screens/create_group_screen.dart` — Simple name input to create group
- `screens/join_group_screen.dart` — Invite code input to join group
- `screens/group_detail_screen.dart` — Shows invite code (copy button), member list. Admin: rename, regen code, kick members, delete group. Non-admin: leave group.
- `screens/settings_screen.dart` — User info, sharing toggle, display name edit, permission status

### Services & Repos
- `services/http_auth_service.dart` — JWT auth client. Login, register, logout, token refresh. Stores tokens + user JSON in SharedPreferences. Decodes JWT payload to check expiry, auto-refreshes when < 60s remaining.
- `services/local_prefs.dart` — SharedPreferences wrapper for participant ID, display name, group ID, privacy consent, sharing toggle, active group ID.
- `repositories/location_sync_repository.dart` — Abstract interface for location sync
- `repositories/http_location_sync_repository.dart` — REST implementation. `fetchGroup()` GET, `upsertMyLocation()` PUT, `watchGroupSnapshots()` async* generator polling every 3s.
- `repositories/group_repository.dart` — REST client for all group endpoints (CRUD, join, leave, kick, regen code)

### Models
- `models/auth_user.dart` — `AuthUser` (uid, username, email, displayName)
- `models/group.dart` — `Group`, `GroupDetail`, `GroupMember` with `fromJson` factories
- `models/participant_location.dart` — `ParticipantLocation` with `fromApiJson` factory, `latLng` getter

### Widgets
- `widgets/amap_privacy_dialog.dart` — AMap privacy consent dialog (required before SDK use)
- `widgets/people_sheet.dart` — Scrollable list of people (self + others) for bottom sheet
- `widgets/person_detail_sheet.dart` — Person detail modal with distance, coordinates, last update

### Config & Utils
- `config/env.dart` — AMap API keys (Android + iOS)
- `utils/geo_utils.dart` — `distanceMeters()` Haversine calculation
- `utils/time_utils.dart` — `relativeTimeZh()` for Chinese relative time strings

## Go Backend Structure (`backend-go/`)

### Entry
- `cmd/server/main.go` — DB init (MySQL via GORM), auto-migrate all entities, create services, wire router, start HTTP server.

### API Layer (`internal/api/`)
- `server.go` — Chi router. Routes: `/api/health`, `/api/auth/*`, `/api/users/*`, `/api/groups/*` (with nested `/{groupId}/locations/*`)
- `auth.go` — Register, login, refresh, logout, logout-all, change-password handlers
- `group.go` — CRUD, join (by invite code), leave, kick, regenerate-code handlers
- `location.go` — List group locations, upsert my location (with group membership check)
- `middleware.go` — JWT auth middleware, CORS middleware
- `response.go` — JSON response helpers
- `user.go` — Get/update current user profile

### Service Layer (`internal/service/`)
- `auth.go` — Register (bcrypt hash), login (verify + issue JWT pair), refresh, logout, change-password
- `group.go` — Create (+ auto add creator as member), list my groups, detail (membership check), update/delete (admin only), join by invite code, leave (admin can't), kick (admin only), regenerate invite code
- `location.go` — List group locations (with membership check), upsert location
- `user.go` — Get/update user profile

### Store Layer (`internal/store/`)
- `store.go` — GORM-based data access for users, refresh tokens, locations
- `group.go` — Group and GroupMember queries (CRUD, membership checks, invite code lookup)

### Models (`internal/model/`)
- `entity.go` — `AppUser`, `RefreshToken`, `ParticipantLocation` GORM entities
- `dto.go` — Auth request/response DTOs
- `group.go` — `Group`, `GroupMember` GORM entities with UUID PKs, `RandomCode()` generator
- `group_dto.go` — Group request/response DTOs

### Config & Error
- `config/config.go` — Loads env vars (DB, JWT secret, port)
- `apperr/apperr.go` — App-level error types with HTTP status codes

## API Endpoints

### Auth (public)
- `POST /api/auth/register` — `{username, password, email, displayName}` -> tokens + user
- `POST /api/auth/login` — `{username, password}` -> tokens + user
- `POST /api/auth/refresh` — `{refreshToken}` -> new tokens + user
- `POST /api/auth/logout` — `{refreshToken}`

### Auth (protected)
- `POST /api/auth/logout-all`
- `POST /api/auth/change-password`

### User (protected)
- `GET /api/users/me`
- `PATCH /api/users/me`

### Groups (protected)
- `GET /api/groups` — List my groups
- `POST /api/groups` — `{name}` -> create group (201)
- `POST /api/groups/join` — `{inviteCode}` -> join group
- `GET /api/groups/{groupId}` — Group detail with members
- `PATCH /api/groups/{groupId}` — `{name}` update (admin only)
- `DELETE /api/groups/{groupId}` — Delete group (admin only, 204)
- `DELETE /api/groups/{groupId}/leave` — Leave group (204)
- `POST /api/groups/{groupId}/kick/{userId}` — Kick member (admin only, 204)
- `POST /api/groups/{groupId}/regenerate-code` — New invite code (admin only)

### Locations (protected, requires group membership)
- `GET /api/groups/{groupId}/locations` — All member locations
- `PUT /api/groups/{groupId}/locations/me` — Upsert my location

## Deployment

### Backend
```bash
# Cross-compile on Mac
cd backend-go
GOOS=linux GOARCH=amd64 go build -o server_linux ./cmd/server

# Deploy to server
scp server_linux root@106.14.193.30:/root/location_share/backend-go/
ssh root@106.14.193.30 "cd /root/location_share/backend-go && docker compose up -d --build"
```

### Flutter
```bash
# Android debug (device connected via USB)
flutter run -d <device_id>

# iOS (requires paired iPhone via Xcode Devices window)
flutter run -d <iphone_id>

# Build APK
flutter build apk --debug
```

## Planned Features (not yet implemented)

Phase 2: Friend system (search by username, friend requests, accept/decline)
Phase 3: WebSocket real-time channel + in-app messaging (private + group chat)
Phase 4: Location visibility controls (per-member show/hide, group-level bulk toggle)

## Key Decisions

- AMap (Gaode) SDK used because app targets China market; requires privacy consent before any SDK call
- `x_amap_flutter_map` is vendored locally (`packages/`) because pub version has incompatible `FlutterMain` reference
- HTTP polling (3s) for location sync instead of WebSocket (WebSocket planned for Phase 3)
- Group admin = creator (simple model, no role transfer yet)
- UUID primary keys for all entities
- Invite code: 8-char alphanumeric, regeneratable by admin
