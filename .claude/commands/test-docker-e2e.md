# End-to-End Docker Infrastructure Test

You have been working on code changes in this session. This command tests those changes end-to-end in the real Docker infrastructure. Your job: get your changes running in the real system, test with real API calls through the full agent pipeline, diagnose every layer, and fix any issues until everything works 100%.

**Arguments (optional):** $ARGUMENTS

---

## Phase 0: Analyze Your Changes

Before testing, understand WHAT you changed and HOW it affects the pipeline:

1. **Review your session's changes**: `git diff HEAD` and `git log --oneline -5` to see what you modified
2. **Classify impact** — which layers do your changes touch?
   - **API code** (Services, Jobs, Controllers, Models) → Horizon restart required (Phase 1)
   - **Docker files** (`docker/Dockerfile`, `docker/proxy/cli-proxy.js`, `docker/entrypoint.sh`, `docker/setup.sh`, `docker/scripts/`) → Image rebuild required (Phase 2)
   - **Bootstrap files** (ContainerBootstrapService, CLAUDE.md injection, .claude.json, settings.json) → Re-bootstrap container required
   - **Session/engine** (NativeSessionEngine, CliSessionDriver, PersistentProcessManager) → New conversation required to test
   - **Stream/broadcast** (BridgeEvent, StreamEvent, CliEventParser, WebSocket) → Verify stream events after message send
   - **Control protocol** (ControlResponseFormatter, AnswerDeliveryService, control_request/response) → Trigger a permission prompt and test warm IPC delivery
3. **Plan your test scenarios** based on impact — don't test unrelated flows, focus on what you changed

## Phase 1: Horizon Management (MANDATORY for any API code change)

Horizon workers cache PHP code at boot. If ANY API code changed since the last Horizon start, workers execute stale code. This causes silent, hard-to-debug issues (e.g., old service code running despite your fix being in the file).

```bash
# From API project: /Users/anilcan/Code/kodizm/api
php artisan horizon:terminate   # Kill existing workers
sleep 3                          # Wait for graceful shutdown
php artisan horizon &            # Start fresh with current code
sleep 5                          # Wait for supervisors to spawn
php artisan horizon:status       # Confirm "Horizon is running"
```

**If you skip this and your fix "doesn't work" — Horizon stale code is the #1 cause.** Always restart.

## Phase 2: Conditional Image Rebuild

Only rebuild if your changes touched `docker/` files:

```bash
# Check last image build time on remote host
ssh root@192.168.68.155 "docker images kodizm/agent-universal --format '{{.CreatedAt}}'"

# Check if docker/ has uncommitted or recent changes
git diff --name-only -- docker/
git log --since="<last build time>" --name-only -- docker/
```

- **No docker/ changes** → Skip rebuild, proceed to Phase 3
- **Docker/ changes exist** → Rebuild:
  ```bash
  php artisan docker:rebuild-image                      # All hosts
  php artisan docker:rebuild-image --host=home-docker   # Specific host
  ```
- **Force rebuild**: If `--force` or `--rebuild` is in arguments, always rebuild

## Phase 3: Verify Container State

Use **raw docker commands** for verification only:

```bash
# Active containers
ssh root@192.168.68.155 "docker ps --filter name=kodizm-project --format '{{.Names}} {{.Status}}'"

# Container using latest image?
ssh root@192.168.68.155 "docker images kodizm/agent-universal --format '{{.ID}}'"
ssh root@192.168.68.155 "docker inspect <container_name> --format '{{.Image}}' | cut -c8-19"

# tini is PID 1? (MUST be tini, not sleep/bash)
ssh root@192.168.68.155 "docker exec <container> ps -p 1 -o comm="

# Zero zombie processes?
ssh root@192.168.68.155 "docker exec <container> ps aux | grep -c defunct"
```

**If container is on old image** → reprovision via Kodizm services (see Rules section).
**If PID 1 is not tini** → Horizon was running stale code. Go back to Phase 1.

## Phase 4: Discover Test Data

Find real entities in the database using `mcp__laravel-boost__database-query`:

```sql
-- Team + user
SELECT t.id, t.name FROM teams t
JOIN team_user tu ON tu.team_id = t.id
GROUP BY t.id, t.name HAVING COUNT(*) > 0;

SELECT u.id, u.name, u.email FROM users u
JOIN team_user tu ON tu.user_id = u.id WHERE tu.team_id = '<team_id>';

-- Project with container
SELECT p.id, p.name, pc.container_name, pc.status, pc.bootstrapped_at
FROM projects p
LEFT JOIN project_containers pc ON pc.project_id = p.id
WHERE p.team_id = '<team_id>';

-- AI token health (CRITICAL — must have at least one active token)
SELECT id, label, status, auth_type, last_error FROM ai_tokens WHERE deleted_at IS NULL;
```

### Fix Expired OAuth Token (if ALL tokens expired)

1. Extract from macOS Keychain:
   ```bash
   bash /Users/anilcan/Code/kodizm/api/scripts/extract-claude-oauth.sh
   ```
2. Import via tinker:
   ```php
   $json = '<paste JSON output>';
   $service = app(\App\Contracts\ClaudeAuthServiceContract::class);
   [$token, $isNew] = $service->importOrUpdateOAuthToken($json);
   // Returns positional array [$token, $isNew] — NOT keyed!
   // Verify: $token->status->value === "active"
   ```

### Ensure Container is Bootstrapped

If container is running but `bootstrapped_at` is null:
```php
$container = \App\Models\ProjectContainer::where('project_id', $projectId)->first();
app(\App\Services\ContainerBootstrapService::class)->bootstrap($container);
```

## Phase 5: Test the Pipeline

Design test scenarios based on your Phase 0 analysis. At minimum, always test:

### 5A: Interactive Message Send

```php
$project = \App\Models\Project::find($projectId);
$user = \App\Models\User::find($userId);
$agentRole = \App\Models\AgentRole::where('slug', 'lead-developer')->first();

// Create conversation
$service = app(\App\Contracts\ConversationServiceContract::class);
$conversation = $service->create($project, $user, $agentRole);

// Create user message
$message = \App\Models\ConversationMessage::create([
    'conversation_id' => $conversation->id,
    'role' => \App\Enums\MessageRole::User,
    'content' => 'List the files in the root directory. Keep your answer very short.',
    'started_at' => now(),
]);

// Dispatch — MUST be SendConversationMessage, NOT ExecuteConversation!
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
```

**Wait 30-60s**, then verify:
```php
$conv = \App\Models\Conversation::find($conversationId);
$conv->messages()->count();  // 2+ (user + assistant)

// Model is \App\Models\Session, table is agent_sessions
$session = \App\Models\Session::where('sessionable_id', $conversationId)->first();
$session->phase->value;           // "warm"
$session->claude_session_id;      // UUID string (not null)
$session->total_cost_usd;         // > 0
```

### 5B: Stream Events

```sql
SELECT type, COUNT(*) FROM stream_events
WHERE session_id = '<session_id>' GROUP BY type ORDER BY count DESC;
-- Expected: system, text, cost_update, result (minimum set)
-- Complex tasks may also have: thinking, tool_use, tool_result

SELECT model, input_tokens, output_tokens, cost_usd
FROM session_usage_records WHERE session_id = '<session_id>';
```

### 5C: Warm Session Reuse

Send a follow-up to the SAME conversation:
```php
$message = \App\Models\ConversationMessage::create([
    'conversation_id' => $conversationId,
    'role' => \App\Enums\MessageRole::User,
    'content' => 'How many lines does composer.json have?',
    'started_at' => now(),
]);
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
```

**Wait 30-60s**, then verify:
- Session count = 1 (same session reused, NOT a new one)
- Same `claude_session_id` (CLI resumed, not restarted)
- `total_cost_usd` increased from first message
- `warm_until` timestamp extended (updated on each message)

Also verify Redis proxy TTL was refreshed:
```php
$key = 'session_proxy:' . $session->id;
$pid = \Illuminate\Support\Facades\Redis::get($key);
$ttl = \Illuminate\Support\Facades\Redis::ttl($key);
// pid should match container process, ttl should be ~1860 (DEFAULT_IDLE_TIMEOUT 1800 + 60)
```

### 5D: Control Request/Response (Permission Prompt Handling)

This tests the full control_request → user answer → control_response → CLI unblocks cycle. Send a message that triggers a tool requiring permission:

```php
$message = \App\Models\ConversationMessage::create([
    'conversation_id' => $conversationId,
    'role' => \App\Enums\MessageRole::User,
    'content' => 'Create a file called /tmp/test.txt with the text "hello" inside it.',
    'started_at' => now(),
]);
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
```

**Wait 20-30s**, then check for a pending question:
```php
$conv = \App\Models\Conversation::find($conversationId);
// Status should be 'paused' — CLI blocked on permission prompt
echo $conv->status->value; // "paused"

$question = \App\Models\AgentQuestion::where('conversation_id', $conversationId)
    ->whereNull('answered_at')
    ->latest()
    ->first();

// Must have these fields populated (from control_request):
echo $question->request_id;    // UUID — links to CLI's pending request
echo $question->tool_use_id;   // tool use ID from the CLI
```

Now deliver the answer via warm IPC:
```php
$user = \App\Models\User::find($userId);
$service = app(\App\Contracts\AnswerDeliveryServiceContract::class);
$method = $service->deliverForConversation($conv, $question, null, $user, 'allow');
echo $method; // "warm" — delivered via Unix socket IPC to live CLI process
```

**Wait 30-60s**, then verify CLI unblocked and completed:
```php
$conv->refresh();
echo $conv->status->value;     // "active" (no longer paused)

// Check if more questions came (CLI may ask multiple permissions in sequence)
$pending = \App\Models\AgentQuestion::where('conversation_id', $conversationId)
    ->whereNull('answered_at')
    ->count();
// If pending > 0, answer them too with the same pattern

// Once all questions answered, assistant message should appear
$session = \App\Models\Session::where('sessionable_id', $conversationId)->latest()->first();
echo $session->phase->value;   // "warm" (back to warm after execution)
```

**Key verification points:**
- `deliverForConversation` returns `'warm'` (not `'dead'`) — IPC worked
- The CLI unblocked after receiving the control_response
- No new Telescope exceptions
- Zero zombie processes in container after completion

**To test deny behavior:**
```php
$method = $service->deliverForConversation($conv, $question, 'Not allowed', $user, 'deny');
// CLI receives deny, stops the tool, continues with alternative approach
```

### 5E: Queued Messages (if your changes affect message queuing)

Messages can be sent while the agent is executing — they queue (max 3, configurable via `config('execution.max_queued_messages')`).

**Test queue creation via API** (requires session in `executing` phase):
```bash
# Send while agent is executing → should return 202 with status=queued
curl -X POST ".../conversations/{id}/messages" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"content":"queued message"}'
# Response: {"data": {"id": "...", "status": "queued", ...}}

# 4th message → should return 422 queue_full
curl -X POST ".../conversations/{id}/messages" -d '{"content":"4th"}'
# Response: {"error": "queue_full", "max": 3, "current": 3}

# Cancel a queued message
curl -X POST ".../conversations/{id}/messages/{msg_id}/cancel"
# Response: 200 for queued/delivering, 422 for already-delivered
```

**Test via tinker** (easier to control timing):
```php
// While session is executing, create queued message directly
$message = \App\Models\ConversationMessage::create([
    'conversation_id' => $convId,
    'role' => \App\Enums\MessageRole::User,
    'content' => 'queued question',
    'status' => \App\Enums\MessageStatus::Queued,
    'started_at' => now(),
]);
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
```

**Verify status transitions** in DB:
```sql
SELECT id, role, status, content FROM conversation_messages
WHERE conversation_id = '<id>' ORDER BY created_at;
-- Normal messages: status=null
-- Queued messages: status=queued → delivering → delivered (or cancelled/failed)
```

**Verify cancel endpoint:**
```php
$service = app(\App\Contracts\ConversationServiceContract::class);
$response = $service->cancelMessage($message); // Returns JsonResponse
$message->refresh();
echo $message->status->value; // "cancelled"
```

**Important**: The pending question guard in the controller blocks ALL messages (including queue attempts) when an `AgentQuestion` is unanswered. Send queued messages only when there's no pending permission prompt.

### 5F: Stop Mid-Execution (if your changes affect stop/abort)

```php
// Send long-running task + stop after 15s in same tinker process:
$message = \App\Models\ConversationMessage::create([...long task...]);
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
sleep(15);
$service->stopMessage($conversation, $user);

// After stop:
// - Session phase should NOT be stuck in "executing"
// - CLI/proxy processes should be gone from container
// - Zero zombie processes
// - ALL queued messages should be status=cancelled (stop cancels entire queue)
// - System interrupt message "[Request interrupted by user]" created
```

### 5F: Expired Warm Session Recovery

Test that an expired warm session is properly handled:
```php
// Manually expire the warm_until to simulate timeout
$session = \App\Models\Session::where('sessionable_id', $conversationId)->latest()->first();
$session->update(['warm_until' => now()->subMinutes(5)]);

// activeSession() should now return null (auto-transitions to Dead)
$active = $conv->activeSession();
var_dump($active); // null

// Session should be Dead
$session->refresh();
echo $session->phase->value; // "dead"

// Sending a new message should create a fresh session
$message = \App\Models\ConversationMessage::create([...]);
\App\Jobs\SendConversationMessage::dispatch(messageId: $message->id);
// Wait, then verify new session was created with new claude_session_id
```

### 5G: Scenario-Specific Tests

Based on your Phase 0 analysis, add tests for the specific flows your changes affect. Examples:
- **Changed bootstrap?** → Destroy + re-provision container, verify bootstrap output
- **Changed stream parsing?** → Check specific event types in stream_events table
- **Changed proxy?** → Verify proxy log: `ssh root@192.168.68.155 "docker exec <container> cat /tmp/kodizm-proxy-<session_id>.log"`
- **Changed auth/token?** → Verify token resolution and container credential injection
- **Changed control protocol?** → Full 5D cycle with both allow and deny
- **Changed AnswerDeliveryService?** → Test both warm and dead paths (kill proxy before answering to force dead path)

## Phase 6: Multi-Layer Verification

After each test, check ALL layers:

### Telescope

Use MCP tools — these are the authoritative source for runtime errors:
- `mcp__laravel-telescope__exceptions` — any new exceptions since your Horizon restart?
- `mcp__laravel-telescope__logs` with `level: "error"` — any errors?
- `mcp__laravel-telescope__jobs` — check for failed jobs
- Note: Telescope data resets on Horizon restart

### Database State

Use `mcp__laravel-boost__database-query` for all SQL queries:
```sql
-- Session lifecycle
SELECT id, phase, claude_session_id, execution_mode, total_cost_usd, warm_until
FROM agent_sessions WHERE sessionable_id = '<conversation_id>';

-- Stream events by type
SELECT type, COUNT(*) FROM stream_events WHERE session_id = '<session_id>' GROUP BY type;

-- Pending questions (should be 0 after full cycle)
SELECT id, request_id, tool_use_id, answered_at
FROM agent_questions WHERE conversation_id = '<conversation_id>';
```

### Container State

```bash
CNAME="<container_name>"
ssh root@192.168.68.155 "docker exec $CNAME ps -p 1 -o comm="          # tini
ssh root@192.168.68.155 "docker exec $CNAME ps aux | grep -c defunct"   # 0 zombies
```

After a warm session completes, proxy + CLI should still be alive:
```bash
# Use ps -ef (NOT ps aux) — ps aux truncates long command lines and may hide processes
ssh root@192.168.68.155 "docker exec $CNAME ps -ef | grep -E 'cli-proxy|claude' | grep -v grep"
```

After stop/abort, proxy + CLI should be gone:
```bash
ssh root@192.168.68.155 "docker exec $CNAME ps -ef | grep -E 'cli-proxy|claude' | grep -v grep"
# Should return empty — no orphan processes
```

### Redis State

```php
// Proxy PID tracking
$key = 'session_proxy:' . $sessionId;
$pid = \Illuminate\Support\Facades\Redis::get($key);    // PID or null
$ttl = \Illuminate\Support\Facades\Redis::ttl($key);    // seconds remaining
// After kill/stop: key should be deleted (ttl = -2)
```

### Queue Health

```bash
php artisan horizon:status
php artisan queue:failed | tail -5
```

## Phase 7: Diagnose & Fix

For ANY issue:
1. **Trace root cause** — read full error in Telescope/logs, don't guess
2. **Fix** — edit code in `/Users/anilcan/Code/kodizm/api`
3. **Restart Horizon** — `php artisan horizon:terminate && sleep 3 && php artisan horizon &`
4. **Re-test** — run the failing scenario again
5. **Verify** — check all layers for the specific issue

### Debugging Tips (learned the hard way)

- **`ps aux` truncates long command lines** — always use `ps -ef` when checking for CLI/proxy processes. The system prompt in the CLI command can be thousands of characters, causing `ps aux` to show nothing.
- **Process GC kills docker exec** — if you spawn a `Symfony\Component\Process` via `$process->start()` and discard the return value, PHP's garbage collector destroys the object and kills the underlying process. Always hold a reference or call `$process->wait()`.
- **Redis TTL != proxy lifetime** — the Redis key TTL (DEFAULT_IDLE_TIMEOUT 1800 + 60) tracks PID mapping, not the proxy's actual idle timeout. The proxy has its own `--idle-timeout` flag. Both must be in sync.
- **CLI stream-json input format** — the CLI expects `{"type":"user","message":{"role":"user","content":"..."}}` for stream-json, NOT `{"type":"user","content":"..."}`. Sending the wrong format causes `TypeError: undefined is not an object`.
- **control_response nesting** — CC CLI's SDKControlResponseSchema requires deep nesting: `{type: "control_response", response: {subtype: "success", request_id: "...", response: {behavior: "allow", updatedInput: {}, toolUseID: "..."}}}`. Flat structures fail silently — the CLI never finds the pending request and stays blocked forever.
- **Multiple control_requests in sequence** — the CLI may ask for multiple tool permissions in a single turn (e.g., Write then Bash). Each one creates a separate AgentQuestion. You must answer them one at a time, waiting for each to complete before checking for the next.
- **Permission prompts block the queue** — the controller's pending question guard (`AgentQuestion::whereNull('answered_at')`) fires BEFORE the queue limit check. While a permission is pending, no new messages (including queued ones) can be sent via API. Answer the permission first, then send queued messages.
- **Simple prompts for quick tests** — Use "What is 2+2?" or similar no-tool prompts for fast pipeline validation. Any prompt that triggers Read/Bash/Write will hit the permission prompt on first use and pause the session.
- **conversations queue has max 2 workers** — Horizon's supervisor-conversations has `maxProcesses: 2`. A stuck job (e.g., blocking in `streamEvents()` waiting for permission answer) occupies one worker. If both workers are stuck, the entire conversations queue is blocked. Fix: restart Horizon to kill stuck workers.
- **answerQuestion signature** — `ConversationServiceContract::answerQuestion(Conversation, questionModelId, answerText, User)` — the second param is the `AgentQuestion` model UUID (not the `request_id` from the CLI's control_request).
- **Queued message jobs send to proxy's pendingQueue** — when a `SendConversationMessage` job for a queued message calls `sendMessage()` while the proxy has an active turn, the proxy's `pendingQueue` holds the connection. The queued job's sock-client stays blocked until the current turn completes and proxy drains the pending queue.

## Phase 8: Final Report

```
## Results

### Infrastructure
- Horizon: restarted/running
- Image rebuild: skipped/rebuilt (reason)

### Container
- Name: ...
- Latest image: Y/N
- tini PID 1: Y/N
- Bootstrapped: Y/N
- Zombies: 0/N

### Test Results
| Scenario | Status | Notes |
|----------|--------|-------|
| Interactive message | Y/N | Messages: N, Cost: $X |
| Stream events | Y/N | Types found: ... |
| Warm reuse | Y/N | Same session ID: Y/N, cost increased: Y/N |
| Control request/response | Y/N | Delivery: warm/dead, CLI unblocked: Y/N |
| [Your specific test] | Y/N | ... |

### Issues Found & Fixed
1. [Issue] -> [Fix]

### Remaining Issues
- None / [List]
```

---

## Reference: Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Fix doesn't work despite code change | Horizon running stale code | Restart Horizon (Phase 1) |
| PID 1 is `sleep` not `tini` | Horizon cached old ContainerManager | Restart Horizon + reprovision container |
| Bootstrap fails "No healthy AI token" | OAuth token expired | `extract-claude-oauth.sh` + import (Phase 4) |
| Provision fails UniqueConstraintViolation | Soft-deleted container blocks unique index | `$container->forceDelete()` then re-provision |
| `sendMessage() Argument #2 must be string, null given` | Used `ExecuteConversation` instead of `SendConversationMessage` | Wrong job — use `SendConversationMessage` (Phase 5A) |
| Session phase stuck "executing" | CLI process orphaned | Check container for orphan processes, kill manually |
| Jobs not processing | Horizon not running | `php artisan horizon:status`, restart if needed |
| CLI blocked forever after control_response | Wrong NDJSON nesting | Verify `ControlResponseFormatter` output matches `SDKControlResponseSchema` nesting |
| API returns 409 when sending queued message | Pending permission/question blocks all messages | Answer the pending `AgentQuestion` first, then send queued messages |
| Queue badge never shows in Flutter | `queuedCount` or `onCancelMessage` not wired in view | Verify `conversation_chat_view.dart` passes both params to widgets |
| `deliverForConversation` returns `'dead'` when proxy is alive | Session phase not Executing/Warm | Check `session->phase->value`, check `warm_until` not expired |
| Warm delivery works but CLI doesn't unblock | control_response request_id doesn't match | Check `$question->request_id` matches what CLI sent in control_request |
| Process killed before socket delivery | `$process->wait()` missing | Ensure `AnswerDeliveryService::deliverWarm()` waits for sock-client |
| `ps aux` shows no CLI/proxy processes | Output truncation due to long system prompt | Use `ps -ef` instead — it shows full command line |
| Proxy dies between messages | Redis TTL expired, proxy not tracked | Check `Redis::ttl('session_proxy:{id}')`, verify `refreshProxyTtl()` called on sendMessage |
| activeSession() returns expired warm session | `warm_until` in past but phase still Warm | `activeSession()` auto-transitions — if not happening, check the method |
| Second message creates new session instead of reusing | warm_until expired before second message | Check time gap, increase idle timeout, verify TTL refresh |

## Reference: Naming Conventions

| DB Table | Eloquent Model | Gotcha |
|----------|---------------|--------|
| `agent_sessions` | `\App\Models\Session` | NOT `AgentSession` — class doesn't exist |
| `conversation_messages` | `\App\Models\ConversationMessage` | `role` is `MessageRole` enum, `status` is nullable `MessageStatus` enum |
| `stream_events` | — | Content in `content_text` column, NOT `content` |
| `session_usage_records` | — | Links to `agent_sessions.id` via `session_id` |
| `project_containers` | `\App\Models\ProjectContainer` | `status` is `ContainerStatus` enum |
| `ai_tokens` | `\App\Models\AiToken` | `status` is enum, use `->value` for string |
| `agent_questions` | `\App\Models\AgentQuestion` | `request_id`/`tool_use_id` from control_request |

## Reference: Architecture — How the Persistent Session Pipeline Works

Understanding this flow prevents 90% of debugging confusion:

```
User Message → SendConversationMessage job → ConversationService::sendMessage()
  → resolveActiveSession() — returns existing warm Session or creates new one
  → NativeSessionEngine::sendMessage()
    → if persistent: sendPersistentMessage()
      → PersistentProcessManager::ensureProxy() — starts cli-proxy.js if not running
      → CliSessionDriver::sendToPersistent() — sock-client.js writes to Unix socket
    → if one-shot: sendOneShotMessage() — docker exec claude ...
  → NativeSessionEngine::streamEvents() — reads NDJSON from CLI stdout
    → CliEventParser parses each line into BridgeEvent
    → BridgeEvents broadcast to WebSocket + accumulate text
    → "question" type → creates AgentQuestion, pauses conversation
    → "result" type → stream complete
  → ConversationService creates assistant message from accumulated text
  → Session transitions to Warm phase
```

**Control Request/Response flow (when CLI needs permission):**
```
CLI emits control_request NDJSON → CliEventParser detects "question" BridgeEvent
  → ConversationService creates AgentQuestion (request_id, tool_use_id)
  → Conversation status → "paused"
  → CLI process stays alive, blocked waiting for stdin response

User answers via API → ConversationController::answer()
  → AnswerDeliveryService::deliverForConversation()
    → resolveDeliveryMethod() checks Session phase (Executing/Warm = warm path)
    → deliverWarm():
      → PersistentProcessManager::isProxyAlive() — Redis PID + kill -0 check
      → ControlResponseFormatter::allow/deny() — builds SDKControlResponseSchema NDJSON
      → PersistentProcessManager::sendMessage() — sock-client.js → Unix socket → cli-proxy.js
      → cli-proxy.js handleMidTurnConnection() → forwards to CLI stdin
      → $process->wait() — CRITICAL: prevents GC from killing sock-client
    → deliverDead() (fallback):
      → ResumeConversationAnswer::dispatch() — restarts CLI with --resume
  → Conversation status → "active"
```

**Proxy lifecycle:**
```
cli-proxy.js (Node.js) — long-lived Unix socket server inside container
  ├── Spawns: claude CLI as child process (stdin/stdout pipes)
  ├── Listens: /tmp/kodizm-cli.sock for incoming connections
  ├── Per-message: sock-client.js connects, writes NDJSON, reads response, disconnects
  ├── Mid-turn: handleMidTurnConnection() forwards control_response to CLI stdin
  ├── Idle timeout: auto-exits after --idle-timeout seconds of no messages
  └── PID tracked in Redis: session_proxy:{session_id} with TTL = idle_timeout + 60s
```

## Reference: Key Files

| File | Purpose |
|------|---------|
| `app/Services/PersistentProcessManager.php` | Proxy lifecycle: start, kill, PID tracking in Redis, TTL refresh |
| `app/Services/NativeSessionEngine.php` | Session execution: message send, stream events, proxy management |
| `app/Services/AnswerDeliveryService.php` | Warm/dead answer routing, control_response delivery via IPC |
| `app/Services/ConversationService.php` | Conversation lifecycle: create, sendMessage, stream, question detection |
| `app/Support/ControlResponseFormatter.php` | SDKControlResponseSchema NDJSON builder (allow/deny) |
| `app/Support/CliEventParser.php` | NDJSON line → BridgeEvent parser (question/permission detection) |
| `app/Support/BridgeEvent.php` | Event DTO from CLI stream (type, contentText, data) |
| `app/Models/Conversation.php` | `activeSession()` — returns non-dead session, auto-expires warm |
| `app/Models/AgentQuestion.php` | Stores control_request data (request_id, tool_use_id, answers) |
| `docker/proxy/cli-proxy.js` | Unix socket proxy server inside container |
| `docker/proxy/sock-client.js` | Per-message socket client (connect → write → read → disconnect) |

## Rules

- **Phase 1 is mandatory for API changes** — Horizon caches PHP at boot. No restart = stale code = silent bugs.
- **Conditional image rebuild** — Only rebuild if `docker/` files changed. Saves 5+ min.
- **Raw docker for checks, Kodizm services for lifecycle** — `docker ps/exec/inspect/logs` for verification. For provision/start/stop/destroy:
  ```php
  $service = app(\App\Contracts\ProjectContainerServiceContract::class);
  $container = \App\Models\ProjectContainer::where('project_id', $projectId)->first();
  $service->stop($container);   // stop
  $service->start($container);  // recreate with latest image, same volume

  // Full destroy + reprovision:
  $service->destroy($container);
  $container->forceDelete();    // MUST forceDelete — soft-delete blocks unique constraint
  \App\Jobs\ProvisionProjectContainerJob::dispatch($project);
  ```
- **Interactive messages** → `SendConversationMessage::dispatch(messageId: $id)`. **NOT** `ExecuteConversation` (that's for autonomous task runs, requires task_id).
- **importOrUpdateOAuthToken** returns `[$token, $isNew]` (positional array, NOT keyed).
- **activeSession()** is a method (not a relationship) — always call with `()`. Auto-transitions expired warm_until sessions to Dead.
- **Use `ps -ef` not `ps aux`** — the CLI command line contains huge system prompts that cause `ps aux` truncation. `ps -ef` shows full command.
- **Use `mcp__laravel-boost__database-query`** for all SQL queries — never raw psql.
- **Use `mcp__laravel-telescope__exceptions`** for error checking — authoritative source.
- **Fix immediately** — don't just report issues, fix and re-verify.
- **3-strike rule** — if the same fix fails 3 times, stop and report to the user.
- **Wait 30-60s after dispatching** — jobs run async via Horizon. Don't check results immediately.
- **Always hold Process references** — `$process = $manager->sendMessage(...)` then `$process->wait()`. Never discard.
