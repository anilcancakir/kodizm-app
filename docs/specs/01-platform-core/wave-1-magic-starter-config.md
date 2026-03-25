# Wave 1 — Magic Starter Configuration

> Spec: 01-Platform Core
> Dependencies: magic-starter-laravel boilerplate

## Goal

Install and configure magic-starter-laravel as the foundation. Override the TeamRole enum to match Kodizm's role model. Enable UUID primary keys. Verify all provided auth and team endpoints work out of the box.

## Deliverables

- [ ] Install magic-starter-laravel plugin
- [ ] Configure magic feature flags for Kodizm needs
- [ ] Override TeamRole enum: `owner`, `admin`, `member`, `viewer` (drop `editor`, add `viewer`)
- [ ] Enable UUID primary keys via `ConditionallyUsesUuids`
- [ ] Verify auth endpoints: register, login, logout, email verification, password reset, 2FA
- [ ] Verify team endpoints: CRUD, invite members, role management, team switching
- [ ] Feature tests confirming auth + team endpoints work with Kodizm role enum

## What magic-starter Provides (no custom code needed)

### Auth Endpoints (provided)

| Endpoint | Description |
|----------|-------------|
| `POST /api/auth/register` | Register new user, returns Sanctum token |
| `POST /api/auth/login` | Login, returns Sanctum token |
| `POST /api/auth/logout` | Revoke current token |
| `GET /api/auth/user` | Get authenticated user profile |
| `POST /api/auth/forgot-password` | Send password reset link |
| `POST /api/auth/reset-password` | Reset password with token |
| `POST /api/auth/email/verify` | Email verification |
| `POST /api/auth/2fa/*` | Two-factor authentication |

### Team Endpoints (provided)

| Endpoint | Description |
|----------|-------------|
| `GET /api/teams` | List user's teams |
| `POST /api/teams` | Create team (creator becomes owner) |
| `GET /api/teams/{team}` | Get team details |
| `PUT /api/teams/{team}` | Update team |
| `DELETE /api/teams/{team}` | Delete team |
| `GET /api/teams/{team}/members` | List team members |
| `POST /api/teams/{team}/members` | Invite member |
| `PUT /api/teams/{team}/members/{member}` | Update member role |
| `DELETE /api/teams/{team}/members/{member}` | Remove member |

### Profile Endpoints (provided)

| Endpoint | Description |
|----------|-------------|
| `PUT /api/auth/profile` | Update user profile |
| `POST /api/auth/avatar` | Upload avatar |

## Configuration Tasks

### 1. Feature Flags

Configure magic-starter's feature flag system for Kodizm:

```php
// config/magic.php or equivalent
return [
    'features' => [
        'registration' => true,
        'email_verification' => true,
        'two_factor_auth' => true,
        'teams' => true,
        'team_invitations' => true,
        'profile_photos' => true,
        // Disable features Kodizm doesn't need (if any)
    ],
];
```

### 2. TeamRole Enum Override

Replace magic-starter's default `TeamRole` enum (OWNER, ADMIN, EDITOR, MEMBER) with Kodizm's:

```php
enum TeamRole: string
{
    case Owner = 'owner';
    case Admin = 'admin';
    case Member = 'member';
    case Viewer = 'viewer';
}
```

This removes `EDITOR` (not needed — Kodizm has no editor/contributor distinction) and adds `VIEWER` (read-only stakeholder access).

Ensure the override hooks into magic-starter's role resolution. Check:
- Role enum is used in TeamUser pivot
- Role validation on invite/update-role endpoints accepts new values
- Any role-based gates/policies reference the overridden enum

### 3. UUID Primary Keys

Enable UUID support across all models:

```php
// Ensure ConditionallyUsesUuids trait is active
// Configure magic-starter to use UUID primary keys
```

Verify:
- User, Team, TeamUser, TeamInvitation all use UUID PKs
- Foreign keys reference UUIDs correctly
- API responses return UUID strings (not integers)

## Acceptance Criteria

### Magic Starter Installation

**Given** a fresh Kodizm Laravel project,
**When** magic-starter-laravel is installed and configured,
**Then** all auth, team, and profile routes are registered and functional.

### TeamRole Override

**Given** the overridden TeamRole enum,
**When** a team member is invited with role `viewer`,
**Then** the invitation succeeds and the member has `viewer` role.

**Given** the overridden TeamRole enum,
**When** a team member is invited with role `editor`,
**Then** a 422 validation error is returned (editor role does not exist).

### UUID Primary Keys

**Given** UUID configuration is enabled,
**When** a new user registers,
**Then** the user ID is a UUID string, not an integer.

**Given** UUID configuration is enabled,
**When** a new team is created,
**Then** the team ID is a UUID string, and the team membership record uses UUID FKs.

### Auth Verification

**Given** magic-starter auth is configured,
**When** a user registers via `POST /api/auth/register`,
**Then** a user record is created and a Sanctum token is returned (status 201).

**Given** a registered user,
**When** they login via `POST /api/auth/login`,
**Then** a Sanctum token is returned (status 200).

**Given** an authenticated user,
**When** they call `POST /api/auth/logout`,
**Then** the token is revoked (status 200).

**Given** an unauthenticated request,
**When** it hits any protected endpoint,
**Then** a 401 response is returned.

### Team Verification

**Given** magic-starter teams are configured,
**When** an authenticated user creates a team via `POST /api/teams`,
**Then** a team is created with the user as owner (UUID IDs, Kodizm role enum).

**Given** a team owner,
**When** they invite a user with role `member`,
**Then** the invitation/membership uses the Kodizm `TeamRole::Member` value.

## Implementation Notes

- magic-starter's contracts/interfaces define the extension points. Use those, not monkey-patching.
- The 14 actions in magic-starter contain the business logic. Override only what's necessary (role enum binding).
- Run magic-starter's own test suite after configuration to ensure nothing is broken.
- If magic-starter publishes config files, review defaults and adjust for Kodizm.
- Auto-create personal team on registration is likely a magic-starter feature flag — enable it.

## Done-When

Auth + team endpoints are functional with Kodizm's `owner/admin/member/viewer` role enum and UUID primary keys. All magic-starter provided features verified working. No custom auth or team CRUD code written.
