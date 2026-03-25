# Wave 2 — AI Tokens

> Spec: 03-Agent System
> Dependencies: Spec 01 (Platform Core) must be complete

## Deliverables

- [ ] AiToken model + migration + factory + policy
- [ ] AiProvider enum
- [ ] AuthType enum
- [ ] TokenStatus enum
- [ ] RotationAlgorithm enum
- [ ] TokenRotationService (resolveToken logic with 3 algorithms)
- [ ] AI tokens CRUD API
- [ ] Feature tests for all endpoints + rotation service
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## AiToken Schema

```
ai_tokens
├── id: uuid PK
├── team_id: uuid FK → teams
├── provider: enum(anthropic, openai, google, openrouter)
├── auth_type: enum(api_key, subscription)
├── label: string nullable              // "Claude Max Account #1", "OpenAI Production Key"
├── credentials: text encrypted         // API key or subscription token
├── status: enum(active, inactive, rate_limited, expired)
├── rotation_algorithm: enum(fill_first, round_robin, random) default fill_first
├── last_used_at: timestamp nullable
├── usage_count: bigint default 0
├── cooldown_until: timestamp nullable  // rate limit cooldown
├── health_checked_at: timestamp nullable
├── settings: json nullable             // provider-specific settings
├── timestamps
└── soft_deletes
```

**Migration notes**:
- `team_id` FK references `teams.id`, `cascadeOnDelete`.
- `credentials` uses Laravel `encrypted` cast.
- Composite index: `(team_id, provider, status)`.
- `provider`, `auth_type`, `status`, `rotation_algorithm` stored as string columns (enum cast in model).
- `usage_count` defaults to 0.
- `cooldown_until` nullable timestamp.

**Model casts**:
```php
protected function casts(): array
{
    return [
        'credentials' => 'encrypted',
        'provider' => AiProvider::class,
        'auth_type' => AuthType::class,
        'status' => TokenStatus::class,
        'rotation_algorithm' => RotationAlgorithm::class,
        'settings' => 'array',
        'last_used_at' => 'datetime',
        'cooldown_until' => 'datetime',
        'health_checked_at' => 'datetime',
    ];
}
```

## Enums

```php
enum AiProvider: string
{
    case Anthropic = 'anthropic';
    case OpenAi = 'openai';
    case Google = 'google';
    case OpenRouter = 'openrouter';
}

enum AuthType: string
{
    case ApiKey = 'api_key';
    case Subscription = 'subscription';
}

enum TokenStatus: string
{
    case Active = 'active';
    case Inactive = 'inactive';
    case RateLimited = 'rate_limited';
    case Expired = 'expired';
}

enum RotationAlgorithm: string
{
    case FillFirst = 'fill_first';
    case RoundRobin = 'round_robin';
    case Random = 'random';
}
```

**MVP**: Only `AiProvider::Anthropic` tokens are functional. Other providers are accepted in the database but not usable for agent execution until their CLI backend strategies are implemented.

## TokenRotationService

Core service for selecting the best available token for an agent run.

```php
class TokenRotationService
{
    /**
     * Resolve the best available token for the given team and provider.
     *
     * @param Team $team
     * @param AiProvider $provider
     * @return AiToken|null  Returns null if no token available
     */
    public function resolveToken(Team $team, AiProvider $provider): ?AiToken;

    /**
     * Mark a token as rate-limited with cooldown.
     *
     * @param AiToken $token
     * @param int $cooldownSeconds  Default from config
     */
    public function markRateLimited(AiToken $token, ?int $cooldownSeconds = null): void;

    /**
     * Record token usage after a successful resolution.
     *
     * @param AiToken $token
     */
    public function recordUsage(AiToken $token): void;
}
```

### resolveToken Algorithm

```
resolveToken(Team $team, AiProvider $provider):
  1. Query: AiToken where team_id = team.id
                    AND provider = $provider
                    AND status = 'active'
                    AND (cooldown_until IS NULL OR cooldown_until <= now())
                    AND deleted_at IS NULL

  2. If no tokens found → return null

  3. Determine rotation algorithm:
     - All tokens for this team+provider should use the same algorithm
     - Use the first token's rotation_algorithm as the team's strategy for this provider

  4. Apply rotation algorithm:
     fill_first:
       → ORDER BY usage_count ASC, last_used_at ASC NULLS FIRST
       → Take first

     round_robin:
       → ORDER BY last_used_at ASC NULLS FIRST
       → Take first

     random:
       → Collect all eligible tokens
       → Pick one at random

  5. Update selected token:
     → last_used_at = now()
     → usage_count++
     (Do this atomically to prevent race conditions)

  6. Return selected token
```

### Rate Limit Handling

When the agent execution detects a 429 response from the AI provider:

```
markRateLimited(AiToken $token, ?int $cooldownSeconds):
  1. $cooldown = $cooldownSeconds ?? config('ai-tokens.rate_limit_cooldown', 60)
  2. $token->update([
       'cooldown_until' => now()->addSeconds($cooldown),
     ])
  3. Status stays 'active' — token auto-recovers when cooldown_until passes

Note: Do NOT change status to 'rate_limited'. The cooldown_until field handles
temporary rate limits. The 'rate_limited' status is for permanent/manual flag only.
```

### Config

```php
// config/ai-tokens.php
return [
    'rate_limit_cooldown' => env('AI_TOKEN_RATE_LIMIT_COOLDOWN', 60), // seconds
];
```

## API Endpoints

### GET /api/teams/{team}/ai-tokens

List all AI tokens for a team. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "team_id": 1,
            "provider": "anthropic",
            "auth_type": "api_key",
            "label": "Claude Production Key",
            "status": "active",
            "rotation_algorithm": "fill_first",
            "last_used_at": "2026-03-25T10:30:00Z",
            "usage_count": 42,
            "cooldown_until": null,
            "health_checked_at": "2026-03-25T09:00:00Z",
            "settings": null,
            "created_at": "2026-03-25T08:00:00Z",
            "updated_at": "2026-03-25T10:30:00Z"
        }
    ]
}
```

**Notes**: `credentials` is NEVER returned in API responses. Use a hidden attribute or resource exclusion.

---

### POST /api/teams/{team}/ai-tokens

Add a new AI token. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "provider": "string|required|in:anthropic,openai,google,openrouter",
    "auth_type": "string|required|in:api_key,subscription",
    "label": "string|nullable|max:255",
    "credentials": "string|required",
    "rotation_algorithm": "string|sometimes|in:fill_first,round_robin,random",
    "settings": "json|nullable"
}
```

**Response** `201 Created`:
```json
{
    "data": {
        "id": 2,
        "team_id": 1,
        "provider": "anthropic",
        "auth_type": "api_key",
        "label": "Claude Backup Key",
        "status": "active",
        "rotation_algorithm": "fill_first",
        "last_used_at": null,
        "usage_count": 0,
        "cooldown_until": null,
        "health_checked_at": null,
        "settings": null,
        "created_at": "2026-03-25T12:00:00Z",
        "updated_at": "2026-03-25T12:00:00Z"
    }
}
```

**Notes**:
- `status` defaults to `active`.
- `rotation_algorithm` defaults to `fill_first`.
- `credentials` is stored encrypted but never returned.

**Errors**:
- `403` — Not owner or admin
- `422` — Validation failed

---

### PUT /api/teams/{team}/ai-tokens/{token}

Update an AI token. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "label": "string|nullable|max:255",
    "credentials": "string|sometimes",
    "status": "string|sometimes|in:active,inactive",
    "rotation_algorithm": "string|sometimes|in:fill_first,round_robin,random",
    "settings": "json|nullable"
}
```

**Response** `200 OK`: Updated token (without credentials).

**Notes**:
- `provider` and `auth_type` are immutable after creation.
- If `credentials` is provided, it replaces the existing value.
- Only `active` and `inactive` statuses can be set manually. `rate_limited` and `expired` are system-managed.

**Errors**:
- `403` — Not owner or admin

---

### DELETE /api/teams/{team}/ai-tokens/{token}

Soft-delete an AI token. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "message": "AI token deleted successfully."
}
```

**Errors**:
- `403` — Not owner or admin

---

### POST /api/teams/{team}/ai-tokens/{token}/test

Health check the token by making a minimal API call to the provider.

**Headers**: `Authorization: Bearer {token}`

**Request**: Empty body.

**Response** `200 OK`:
```json
{
    "data": {
        "status": "healthy",
        "provider": "anthropic",
        "response_time_ms": 342,
        "checked_at": "2026-03-25T12:05:00Z"
    }
}
```

**Response** `200 OK` (unhealthy):
```json
{
    "data": {
        "status": "unhealthy",
        "provider": "anthropic",
        "error": "Invalid API key",
        "checked_at": "2026-03-25T12:05:00Z"
    }
}
```

**Notes**:
- MVP: For Anthropic, send a minimal `messages` API request (e.g., "ping" with `max_tokens: 1`).
- Updates `health_checked_at` on the token.
- If unhealthy and error indicates invalid key, set `status: expired`.

**Errors**:
- `403` — Not owner or admin

## Acceptance Criteria

### CRUD

**Given** a team admin,
**When** they POST to `/api/teams/{team}/ai-tokens` with valid Anthropic credentials,
**Then** a new AiToken is created with `status: active` and `credentials` stored encrypted.

**Given** a team with AI tokens,
**When** an admin GETs `/api/teams/{team}/ai-tokens`,
**Then** all tokens are returned WITHOUT the `credentials` field.

**Given** a team admin,
**When** they PUT to update a token's label,
**Then** the label is updated.

**Given** a team admin providing new `credentials` in a PUT request,
**When** the update is processed,
**Then** the encrypted credentials are replaced with the new value.

**Given** a team member with `member` role,
**When** they try to access any ai-tokens endpoint,
**Then** a 403 response is returned.

### Token Rotation — fill_first

**Given** a team with 3 active Anthropic tokens (usage_count: 10, 5, 8),
**When** `resolveToken` is called for Anthropic,
**Then** the token with `usage_count: 5` is selected and its `usage_count` becomes 6.

### Token Rotation — round_robin

**Given** a team with 3 active tokens with `rotation_algorithm: round_robin` and different `last_used_at`,
**When** `resolveToken` is called,
**Then** the token with the oldest `last_used_at` is selected.

### Token Rotation — random

**Given** a team with 3 active tokens with `rotation_algorithm: random`,
**When** `resolveToken` is called multiple times,
**Then** different tokens are selected (non-deterministic, but all eligible).

### Cooldown

**Given** a token with `cooldown_until` set to 30 seconds from now,
**When** `resolveToken` is called,
**Then** that token is excluded from selection.

**Given** a token with `cooldown_until` set to 30 seconds ago (expired cooldown),
**When** `resolveToken` is called,
**Then** that token IS eligible for selection.

### Rate Limit

**Given** a token that just received a 429 response,
**When** `markRateLimited` is called,
**Then** `cooldown_until` is set to `now + rate_limit_cooldown` seconds, and `status` remains `active`.

### No Tokens Available

**Given** a team with no active Anthropic tokens,
**When** `resolveToken` is called for Anthropic,
**Then** `null` is returned.

**Given** a team where all Anthropic tokens are in cooldown,
**When** `resolveToken` is called,
**Then** `null` is returned.

### Health Check

**Given** a valid Anthropic token,
**When** the test endpoint is called,
**Then** `status: "healthy"` is returned and `health_checked_at` is updated.

**Given** an invalid Anthropic API key,
**When** the test endpoint is called,
**Then** `status: "unhealthy"` is returned with the error, and token status is set to `expired`.

## Implementation Notes

- AiToken model uses `SoftDeletes` trait.
- AiToken belongs to Team. **Note**: User and Team models come from magic-starter and are extended by Kodizm.
- AiTokenPolicy: only owner/admin can manage tokens.
- `credentials` hidden attribute: exclude from `toArray()` and JSON serialization.
- TokenRotationService should use database-level locking or atomic updates to prevent race conditions when multiple agent runs resolve tokens simultaneously.
- Health check for Anthropic: use `Http::withToken($credentials)->post('https://api.anthropic.com/v1/messages', ...)` with a minimal payload.
- Config file: `config/ai-tokens.php` for rate limit cooldown duration.
