# Claude Code CLI — OAuth Authentication

> Source: Official Claude Code CLI (TypeScript)
> Last updated: 2026-04-04

This document describes how the official Claude Code CLI handles OAuth 2.0 authentication — token acquisition, refresh, HTTP headers, and credential storage across platforms.

---

## Configuration

### Production endpoints

| Key | Value |
|-----|-------|
| Authorization URL (Claude.ai) | `https://claude.com/cai/oauth/authorize` |
| Authorization URL (Console) | `https://platform.claude.com/oauth/authorize` |
| Token URL | `https://platform.claude.com/v1/oauth/token` |
| Profile URL | `https://api.anthropic.com/api/oauth/profile` |
| Roles URL | `https://api.anthropic.com/api/oauth/claude_cli/roles` |
| API Key URL | `https://api.anthropic.com/api/oauth/claude_cli/create_api_key` |
| Manual Redirect URL | `https://platform.claude.com/oauth/code/callback` |
| Client ID | `9d1c250a-e61b-44d9-88ed-5944d1962f5e` |
| Beta Header | `oauth-2025-04-20` |

Source: `src/constants/oauth.ts:84-104`

### Scopes

Claude.ai subscribers (Pro/Max/Team/Enterprise):

```
user:profile
user:inference
user:sessions:claude_code
user:mcp_servers
user:file_upload
```

Console users (API key creation):

```
org:create_api_key
user:profile
```

Login requests the union of both scope sets.

Source: `src/constants/oauth.ts:33-58`

---

## PKCE implementation

RFC 7636 compliant. Source: `src/services/oauth/crypto.ts` (24 lines total).

### Code verifier

32 random bytes encoded as base64url (no padding). Produces a 43-character string.

```typescript
base64URLEncode(randomBytes(32))
```

### Code challenge

SHA-256 hash of verifier encoded as base64url.

```typescript
base64URLEncode(SHA256(codeVerifier))
```

### State token

32 random bytes encoded as base64url. Used for CSRF protection.

### Base64url encoding

Standard base64 with `+` replaced by `-`, `/` replaced by `_`, and `=` padding stripped.

---

## Login flow

Entry point: `src/cli/handlers/auth.ts:112-230`

### Step 1 — Environment variable fast path

If `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` is set (with `CLAUDE_CODE_OAUTH_SCOPES`), the CLI skips the browser entirely and exchanges the refresh token directly for an access token.

```
refreshOAuthToken(envRefreshToken, { scopes }) → installOAuthTokens() → exit
```

### Step 2 — Start OAuth service

Source: `src/services/oauth/index.ts:28-53`

1. Generate code verifier (43-char random base64url).
2. Start localhost HTTP server on an OS-assigned random port (e.g. `52847`).
3. Generate code challenge (SHA-256 of verifier) and state token.
4. Build two authorization URLs:
   - **Automatic**: redirect URI is `http://localhost:{port}/callback`
   - **Manual**: redirect URI is `https://platform.claude.com/oauth/code/callback`

### Step 3 — Build authorization URL

Source: `src/services/oauth/client.ts:46-105`

Example URL:

```
https://claude.com/cai/oauth/authorize
  ?code=true
  &client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e
  &response_type=code
  &redirect_uri=http://localhost:52847/callback
  &scope=user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload org:create_api_key
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
  &state=xyzABC123...
```

Optional parameters: `login_hint` (email), `login_method` (e.g. `sso`), `orgUUID`.

The `?code=true` parameter tells the login page to show Claude Max upsell.

### Step 4 — Capture authorization code

Source: `src/services/oauth/auth-code-listener.ts:18-211`

The localhost HTTP server listens for the OAuth redirect:

```
http://localhost:{port}/callback?code=AUTH_CODE&state=STATE
```

The server validates the `state` parameter against the expected value (CSRF protection). On mismatch, returns HTTP 400. On success, holds the response object for later redirect to the success page.

### Step 5 — Token exchange

Source: `src/services/oauth/client.ts:107-144`

HTTP request:

```
POST https://platform.claude.com/v1/oauth/token
Content-Type: application/json

{
  "grant_type": "authorization_code",
  "code": "<authorization_code>",
  "redirect_uri": "http://localhost:{port}/callback",
  "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
  "code_verifier": "<43_char_base64url>",
  "state": "<state_token>"
}
```

Response:

```json
{
  "access_token": "sk-ant-oat01-...",
  "refresh_token": "sk-ant-...",
  "expires_in": 86400,
  "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload",
  "account": {
    "uuid": "acc-uuid",
    "email_address": "user@example.com"
  },
  "organization": {
    "uuid": "org-uuid"
  }
}
```

`expiresAt` is calculated as `Date.now() + expires_in * 1000` (millisecond timestamp).

### Step 6 — Post-login setup

Source: `src/cli/handlers/auth.ts:50-110` — `installOAuthTokens()`

1. `performLogout()` — clear old auth state.
2. Fetch profile:
   ```
   GET https://api.anthropic.com/api/oauth/profile
   Authorization: Bearer <access_token>
   Content-Type: application/json
   ```
3. Store account info in global config (`~/.claude.json`).
4. Save tokens to secure storage (Keychain on macOS, plaintext file on Linux).
5. Fetch and store user roles:
   ```
   GET https://api.anthropic.com/api/oauth/claude_cli/roles
   Authorization: Bearer <access_token>
   ```
6. For Console users only — create API key:
   ```
   POST https://api.anthropic.com/api/oauth/claude_cli/create_api_key
   Authorization: Bearer <access_token>
   ```

---

## Token refresh

### Expiration check

Source: `src/services/oauth/client.ts:344-353`

Token is considered expired when current time + 5-minute buffer >= `expiresAt`.

```typescript
const bufferTime = 5 * 60 * 1000  // 5 minutes
return (Date.now() + bufferTime) >= expiresAt
```

### Refresh request

Source: `src/services/oauth/client.ts:146-274`

```
POST https://platform.claude.com/v1/oauth/token
Content-Type: application/json

{
  "grant_type": "refresh_token",
  "refresh_token": "<refresh_token>",
  "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
  "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
}
```

Response contains new `access_token`, optionally a new `refresh_token`, and `expires_in`. The backend allows scope expansion on refresh via `ALLOWED_SCOPE_EXPANSIONS`, so old tokens can gain new scopes without re-login.

### Concurrency control

Source: `src/utils/auth.ts:1447-1562`

Refresh is guarded by multiple layers:

1. **In-flight dedup**: `pendingRefreshCheck` promise prevents duplicate calls within the same process.
2. **Disk mtime check**: `stat('~/.claude/.credentials.json')` detects if another process already refreshed.
3. **Async re-read**: After cache clear, reads from storage to check if tokens are still expired.
4. **File lock**: `lockfile.lock(~/.claude/)` ensures only one process refreshes at a time.
5. **ELOCKED retry**: Up to 5 retries with 1000 + random(1000) ms backoff.
6. **Post-lock recheck**: After acquiring the lock, re-reads tokens — if another process already refreshed, skips.
7. **Lock release**: Always in `finally` block.

### 401 error handling

Source: `src/utils/auth.ts:1360-1392`

When the API returns 401:

1. Clear all caches (memoize + keychain).
2. Async re-read from storage.
3. If storage has a different token than the failed one — another instance already refreshed, use it.
4. If same token — force refresh (bypasses local expiration check).
5. Concurrent 401s with the same `failedAccessToken` are deduplicated via `pending401Handlers` Map.

---

## HTTP headers

### OAuth-authenticated requests

```
Authorization: Bearer <access_token>
```

### API key-authenticated requests (Console path)

```
x-api-key: <api_key>
anthropic-beta: oauth-2025-04-20
```

### Token exchange and refresh

```
Content-Type: application/json
```

---

## Credential storage

### Platform backend selection

Source: `src/utils/secureStorage/index.ts`

| Platform | Backend | Fallback |
|----------|---------|----------|
| macOS | Keychain | Plaintext file |
| Linux | Plaintext file | None |
| Windows | Plaintext file | None |

On macOS, a `createFallbackStorage()` wrapper tries Keychain first, falls back to plaintext if Keychain fails. Source: `src/utils/secureStorage/fallbackStorage.ts`

### Stored data structure

Both backends store the same JSON:

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-...",
    "expiresAt": 1712345678000,
    "scopes": [
      "user:profile",
      "user:inference",
      "user:sessions:claude_code",
      "user:mcp_servers",
      "user:file_upload"
    ],
    "subscriptionType": "pro",
    "rateLimitTier": "tier_2"
  }
}
```

### macOS Keychain

Source: `src/utils/secureStorage/macOsKeychainStorage.ts`

**Service name**: `Claude Code-credentials` (default). For custom `CLAUDE_CONFIG_DIR`, appends `-{sha256_hash_first_8_chars}`.

Source: `src/utils/secureStorage/macOsKeychainHelpers.ts:29-41`

**Account**: Current OS username (`process.env.USER` or `os.userInfo().username`).

**Write** (preferred — stdin, hides payload from process monitors like CrowdStrike):

```bash
echo 'add-generic-password -U -a "{username}" -s "Claude Code-credentials" -X "{hex_encoded_json}"' | security -i
```

If payload exceeds 4032 bytes (security stdin buffer limit), falls back to argv:

```bash
security add-generic-password -U -a "{username}" -s "Claude Code-credentials" -X "{hex_encoded_json}"
```

The `-X` flag means hex-encoded data. JSON is converted to hex via `Buffer.from(json, 'utf-8').toString('hex')`.

**Read**:

```bash
security find-generic-password -a "{username}" -w -s "Claude Code-credentials"
```

Output is hex-encoded JSON, parsed via `JSON.parse()`.

**Cache**: 30-second TTL. Stale-while-error: if keychain read fails, serves cached value instead of returning null. Generation counter prevents stale async reads from overwriting fresh writes.

**Keychain locked detection**: `security show-keychain-info` — exit code 36 means keychain is locked (common in SSH sessions). Result cached for process lifetime.

**Prefetch**: At CLI startup, two keychain reads are fired in parallel with module evaluation (OAuth credentials + legacy API key). Results prime the cache so sync reads hit cache instead of spawning subprocesses.

Source: `src/utils/secureStorage/keychainPrefetch.ts`

### Linux plaintext storage

Source: `src/utils/secureStorage/plainTextStorage.ts`

**File path**: `~/.claude/.credentials.json` (or `$CLAUDE_CONFIG_DIR/.credentials.json`).

**Write**:

```
mkdir ~/.claude/
writeFile ~/.claude/.credentials.json <json>
chmod 0o600 ~/.claude/.credentials.json   (rw-------)
```

Returns warning: `"Warning: Storing credentials in plaintext."`

**No encryption at rest** — security relies on file permissions. No libsecret/GNOME Keyring/KDE Wallet integration (marked as TODO in source).

**No XDG compliance** — hardcoded `~/.claude`, overridable via `CLAUDE_CONFIG_DIR`.

### Fallback storage behavior (macOS)

Source: `src/utils/secureStorage/fallbackStorage.ts`

```
read():   Keychain → null? → plaintext file
update(): Keychain → fail? → plaintext file (+ delete stale keychain entry)
delete(): Delete from both
```

On first successful Keychain write, the plaintext file is deleted (migration). This prevents stale plaintext entries from shadowing fresh Keychain data when sharing `.claude` between host and containers.

---

## Global config file

Path: `~/.claude.json`

Stores account metadata only — **never tokens**:

```json
{
  "oauthAccount": {
    "accountUuid": "acc-uuid",
    "emailAddress": "user@example.com",
    "organizationUuid": "org-uuid",
    "displayName": "User Name",
    "organizationRole": "admin",
    "workspaceRole": "developer",
    "organizationName": "My Org",
    "hasExtraUsageEnabled": true,
    "billingType": "stripe",
    "accountCreatedAt": "2024-01-01T00:00:00Z",
    "subscriptionCreatedAt": "2024-06-01T00:00:00Z"
  },
  "hasCompletedOnboarding": true
}
```

---

## Token read priority

Source: `src/utils/auth.ts:1255-1300` — `getClaudeAIOAuthTokens()`

1. `--bare` mode → return null (API key only mode).
2. `CLAUDE_CODE_OAUTH_TOKEN` env var → inference-only token (no refresh, no expiry tracking).
3. File descriptor token → inference-only token.
4. Secure storage → Keychain (macOS) or `.credentials.json` (Linux).

Environment variable tokens are never refreshed and have no expiration check — they return with `scopes: ['user:inference']` only.

---

## Cross-process synchronization

Source: `src/utils/auth.ts:1313-1336`

### mtime-based cache invalidation

Before every token read, the CLI stats `~/.claude/.credentials.json`. If `mtimeMs` changed since last check, all caches (memoize + keychain) are cleared, forcing a fresh read from storage.

### Multi-instance scenario

1. Instance A: Token expires → acquires lock → refreshes → writes new token → releases lock.
2. Instance B: Next request triggers `invalidateOAuthCacheIfDiskChanged()` → mtime changed → cache cleared → reads fresh token from storage.

### 401 recovery across instances

1. Instance A: Runs `/login` → gets new token → writes to Keychain.
2. Instance B: API returns 401 with old token → `handleOAuth401Error()` → clears cache → reads from Keychain → finds different (fresh) token → uses it without refreshing.

---

## Environment variable overrides

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Direct access token (inference-only, no refresh) |
| `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` | Refresh token for headless `claude login` |
| `CLAUDE_CODE_OAUTH_SCOPES` | Required with refresh token (space-separated) |
| `CLAUDE_CONFIG_DIR` | Override `~/.claude` directory |
| `CLAUDE_CODE_CUSTOM_OAUTH_URL` | FedStart/PubSec deployment override |
| `CLAUDE_CODE_OAUTH_CLIENT_ID` | Client ID override (e.g. Xcode integration) |
| `CLAUDE_CODE_ACCOUNT_UUID` | SDK caller account info injection |
| `CLAUDE_CODE_USER_EMAIL` | SDK caller email injection |
| `CLAUDE_CODE_ORGANIZATION_UUID` | SDK caller org injection |

### Custom OAuth URL allowlist

Source: `src/constants/oauth.ts:179-183`

Only these base URLs are permitted for `CLAUDE_CODE_CUSTOM_OAUTH_URL`:

```
https://beacon.claude-ai.staging.ant.dev
https://claude.fedstart.com
https://claude-staging.fedstart.com
```

Any other URL throws: `"CLAUDE_CODE_CUSTOM_OAUTH_URL is not an approved endpoint."`

---

## Flow diagram

```
claude login
    |
    +-- CLAUDE_CODE_OAUTH_REFRESH_TOKEN set?
    |   YES --> refreshOAuthToken() --> installOAuthTokens() --> exit
    |
    NO
    |
    +-- OAuthService.startOAuthFlow()
    |   +-- Start localhost:{random}/callback server
    |   +-- Generate PKCE (verifier + challenge + state)
    |   +-- Open browser --> claude.com/cai/oauth/authorize?...
    |   +-- User authorizes
    |   +-- Redirect --> localhost:{port}/callback?code=XXX&state=YYY
    |   +-- Validate state (CSRF)
    |   +-- POST platform.claude.com/v1/oauth/token
    |       { grant_type: authorization_code, code, code_verifier, client_id }
    |
    +-- installOAuthTokens()
    |   +-- performLogout() (clear old state)
    |   +-- GET api.anthropic.com/api/oauth/profile (Bearer token)
    |   +-- storeOAuthAccountInfo() --> ~/.claude.json
    |   +-- saveOAuthTokensIfNeeded() --> Keychain (macOS) / .credentials.json (Linux)
    |   +-- GET api.anthropic.com/api/oauth/claude_cli/roles (Bearer token)
    |   +-- Console: POST .../create_api_key (Bearer token)
    |
    +-- "Login successful."

--- Runtime (before every API call) ---

checkAndRefreshOAuthTokenIfNeeded()
    +-- Token expired? (5 min buffer)
    |   NO --> return
    |
    +-- invalidateOAuthCacheIfDiskChanged() (mtime check)
    +-- Async re-read (another process refreshed?)
    +-- lockfile.lock(~/.claude/)
    |   ELOCKED --> retry (max 5, 1-2s backoff)
    +-- Post-lock recheck
    +-- POST platform.claude.com/v1/oauth/token
    |   { grant_type: refresh_token, refresh_token, client_id, scope }
    +-- saveOAuthTokensIfNeeded() --> write to storage
    +-- release lock
```

---

## Source file index

| File | Purpose |
|------|---------|
| `src/constants/oauth.ts` | Endpoints, client ID, scopes, environment configs |
| `src/services/oauth/crypto.ts` | PKCE code verifier, challenge, state generation |
| `src/services/oauth/index.ts` | OAuthService — orchestrates the full OAuth flow |
| `src/services/oauth/client.ts` | buildAuthUrl, exchangeCodeForTokens, refreshOAuthToken |
| `src/services/oauth/auth-code-listener.ts` | Localhost HTTP server for OAuth callback capture |
| `src/services/oauth/getOauthProfile.ts` | Profile fetch via Bearer token or API key |
| `src/cli/handlers/auth.ts` | Login command handler, installOAuthTokens |
| `src/utils/auth.ts` | Token storage, retrieval, refresh, cache, 401 handling |
| `src/utils/secureStorage/index.ts` | Platform backend selection |
| `src/utils/secureStorage/macOsKeychainStorage.ts` | macOS Keychain read/write/delete |
| `src/utils/secureStorage/macOsKeychainHelpers.ts` | Service name, username, cache state |
| `src/utils/secureStorage/keychainPrefetch.ts` | Startup keychain read parallelization |
| `src/utils/secureStorage/plainTextStorage.ts` | Linux/fallback plaintext file storage |
| `src/utils/secureStorage/fallbackStorage.ts` | Primary-with-fallback storage wrapper |
| `src/utils/envUtils.ts` | getClaudeConfigHomeDir (~/.claude resolution) |
