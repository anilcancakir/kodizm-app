# Spec 01 — Platform Core

> Auth, User, Team, Roles, Permissions — built on magic-starter-laravel.
> Dependencies: magic-starter-laravel boilerplate plugin.

## Foundation: magic-starter-laravel

The boilerplate provides a complete, production-ready foundation:

| Layer | Provided by magic-starter |
|-------|--------------------------|
| **Auth** | Sanctum token auth, registration, login, logout, email verification, password reset, 2FA |
| **User** | User model with `ConditionallyUsesUuids` trait, profile update, avatar |
| **Team** | Team model, TeamUser pivot, TeamInvitation model, team CRUD, invite members, team switching |
| **Roles** | TeamRole enum (OWNER, ADMIN, EDITOR, MEMBER), role management |
| **Infra** | 25 controllers, 14 actions, 18 contracts, feature flags system |

Kodizm does **not** rebuild any of this. It configures and extends.

## What Kodizm Extends

| Change | Why |
|--------|-----|
| Override TeamRole enum: `owner`, `admin`, `member`, `viewer` | Drop `editor` (unused), add `viewer` (read-only stakeholder access) |
| Add `balance` column to teams (`decimal(12,2)` default 0) | Credit-based billing for AI agent runs |
| Add `max_concurrent_runs` column to teams (`int` default 10) | Throttle concurrent agent executions per team |
| Viewer role permission gate | Read-only policy on tasks, docs, knowledge |
| Configure feature flags | Enable/disable magic features for Kodizm needs |
| UUID primary keys | Enable via `ConditionallyUsesUuids` (magic supports this natively) |

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Magic Starter Configuration | Install magic-starter, configure feature flags, override TeamRole enum, enable UUIDs, verify auth + team endpoints |
| 2 | Kodizm Team Extensions | Add balance + max_concurrent_runs to teams, viewer role policy, team balance service + API |

## Dependencies on Other Specs

None. This is the first spec in the build order. All other specs depend on this.

## Data Models — Kodizm Extensions Only

> Base User, Team, TeamUser, TeamInvitation models are provided by magic-starter. Below shows only what Kodizm adds or overrides.

### Team (extended fields)

```
teams (magic-starter provides base columns: id, name, etc.)
├── balance: decimal(12,2) default 0          // credit balance in USD — ADDED
└── max_concurrent_runs: int default 10       // agent run throttle — ADDED
```

### TeamRole (override)

```php
// Overrides magic-starter's TeamRole enum (OWNER, ADMIN, EDITOR, MEMBER)
// Drops EDITOR, adds VIEWER
enum TeamRole: string
{
    case Owner = 'owner';
    case Admin = 'admin';
    case Member = 'member';
    case Viewer = 'viewer';
}
```

**TeamRole descriptions**:
- **Owner**: Full access — all CRUD, admin, billing, delete team
- **Admin**: Manage projects, agents, tokens, members (except owner removal)
- **Member**: Create tasks, run agents, read knowledge
- **Viewer**: Read-only access to tasks, docs, knowledge — cannot run agents or view billing

## Business Rules

### Team Role Permissions

| Permission | Owner | Admin | Member | Viewer |
|-----------|-------|-------|--------|--------|
| View team | Yes | Yes | Yes | Yes |
| Update team | Yes | Yes | No | No |
| Delete team | Yes | No | No | No |
| Manage members | Yes | Yes | No | No |
| Invite members | Yes | Yes | No | No |
| Remove members | Yes | Yes (not owner) | No | No |
| Change member roles | Yes | Yes (not to owner) | No | No |
| View balance | Yes | Yes | Yes | No |
| Task CRUD | Yes | Yes | Yes | Read only |
| Doc CRUD | Yes | Yes | Yes | Read only |
| Knowledge | Full | Full | Read | Read |
| Run agents | Yes | Yes | Yes | No |
| Manage AI tokens | Yes | Yes | No | No |
| Manage agent roles | Yes | Yes | No | No |

### Multi-tenancy
- All data is scoped to team via `team_id` FK.
- A user can belong to multiple teams.
- A user has exactly one role per team.

### Auth
- API auth via Sanctum (token-based, used by Flutter app) — provided by magic-starter.
- UUID primary keys on all models — enabled via magic-starter's `ConditionallyUsesUuids` trait.

### Conventions
- All code, comments, naming in English.
- Strict types on every param, return, property.
- TDD: failing test first, then implementation.
- Thin controllers, fat services.
