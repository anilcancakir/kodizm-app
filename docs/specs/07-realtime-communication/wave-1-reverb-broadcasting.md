# Spec 07, Wave 1 — Reverb & Broadcasting

> Install and configure Laravel Reverb, define private channels, implement all broadcast event classes.
> Dependencies: 01 complete (auth + team membership).

## Deliverables

1. Laravel Reverb installation and configuration
2. Private channel authorization routes (Sanctum token-based)
3. Broadcast event classes for task-run channel (5 events)
4. Broadcast event classes for team channel (4 events)
5. Channel authorization logic
6. Broadcasting service provider configuration
7. Tests for channel auth and event broadcasting
8. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. Laravel Reverb Setup

### Installation

```bash
composer require laravel/reverb
php artisan reverb:install
```

### Configuration

- `config/broadcasting.php` — set default driver to `reverb`
- `config/reverb.php` — configure host, port, app credentials
- `.env` additions:

```env
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=kodizm
REVERB_APP_KEY=<generated>
REVERB_APP_SECRET=<generated>
REVERB_HOST=0.0.0.0
REVERB_PORT=8080
REVERB_SCHEME=https
```

### Broadcasting Service Provider

- Ensure `BroadcastServiceProvider` is registered
- Configure Sanctum token auth for channel authorization (private channels use the `/broadcasting/auth` endpoint)

## 2. Channels

### private-task-run.{taskRunId}

**Auth rule**: User's Sanctum token must resolve to a user who is a member of the team that owns the task's project.

**Authorization logic**:
```
1. Resolve TaskRun by taskRunId
2. Load TaskRun → Task → Project → Team
3. Verify authenticated user is a member of that team
4. Return true/false
```

### private-team.{teamId}

**Auth rule**: User's Sanctum token must resolve to a user who is a member of the team.

**Authorization logic**:
```
1. Resolve Team by teamId
2. Verify authenticated user is a member of that team (any role)
3. Return true/false
```

## 3. Events on task-run.{taskRunId}

All events broadcast on `private-task-run.{taskRunId}`. Events implement `ShouldBroadcast` and use the `ShouldBroadcastNow` trait (no queue delay for real-time streaming).

| Event Class | Event Name | Payload | When Fired |
|-------------|------------|---------|------------|
| `AgentSystemEvent` | `.agent.system` | `{type, session_id, model}` | Agent session starts (first NDJSON system event) |
| `AgentAssistantEvent` | `.agent.assistant` | `{type, role, content[]}` | Agent produces output (text, tool_use) |
| `AgentResultEvent` | `.agent.result` | `{type, is_error, total_cost_usd, duration_ms, usage}` | Agent run completes (result NDJSON event) |
| `AgentQuestionEvent` | `.agent.question` | `{type, question_id, question_text}` | Agent asks a question (elicitation detected) |
| `AgentStatusEvent` | `.agent.status` | `{status, task_run_id}` | TaskRun status changes (any transition) |

### Payload Details

**AgentSystemEvent**:
```json
{
  "type": "system",
  "session_id": "sess_abc123",
  "model": "claude-sonnet-4-6"
}
```

**AgentAssistantEvent**:
```json
{
  "type": "assistant",
  "role": "assistant",
  "content": [
    { "type": "text", "text": "I'll start by analyzing the codebase..." },
    { "type": "tool_use", "name": "Read", "input": { "file_path": "/src/app.ts" } }
  ]
}
```

**AgentResultEvent**:
```json
{
  "type": "result",
  "is_error": false,
  "total_cost_usd": 0.0342,
  "duration_ms": 45200,
  "usage": {
    "input_tokens": 12500,
    "output_tokens": 3200,
    "cache_read_tokens": 8000,
    "cache_write_tokens": 1500
  }
}
```

**AgentQuestionEvent**:
```json
{
  "type": "question",
  "question_id": 42,
  "question_text": "Should I use PostgreSQL or MySQL for this project?"
}
```

**AgentStatusEvent**:
```json
{
  "status": "running",
  "task_run_id": 123
}
```

## 4. Events on team.{teamId}

All events broadcast on `private-team.{teamId}`. These use `ShouldBroadcastNow` as well (low-latency dashboard updates).

| Event Class | Event Name | Payload | When Fired |
|-------------|------------|---------|------------|
| `RunStartedEvent` | `.run.started` | `{task_run_id, task_id, agent_role}` | Any run starts in the team |
| `RunCompletedEvent` | `.run.completed` | `{task_run_id, task_id, cost_usd}` | Any run completes in the team |
| `RunQuestionEvent` | `.run.question` | `{task_run_id, task_id, question_text}` | Any agent asks a question |
| `BalanceUpdatedEvent` | `.balance.updated` | `{team_id, new_balance, deducted}` | Team balance changes (cost deduction) |

### Payload Details

**RunStartedEvent**:
```json
{
  "task_run_id": 123,
  "task_id": 45,
  "agent_role": "developer"
}
```

**RunCompletedEvent**:
```json
{
  "task_run_id": 123,
  "task_id": 45,
  "cost_usd": 0.0342
}
```

**RunQuestionEvent**:
```json
{
  "task_run_id": 123,
  "task_id": 45,
  "question_text": "Should I use PostgreSQL or MySQL for this project?"
}
```

**BalanceUpdatedEvent**:
```json
{
  "team_id": 1,
  "new_balance": 24.9658,
  "deducted": 0.0342
}
```

## 5. Channel Authorization

Channel authorization uses Laravel's `Broadcast::channel()` method in `routes/channels.php`.

### Authorization Flow

```
Flutter → WebSocket connect with Sanctum token
  → Reverb validates connection
  → Client subscribes to private channel
  → Reverb calls /broadcasting/auth with Sanctum token
  → Laravel resolves user from token
  → Broadcast::channel() callback executes
  → Returns true (authorized) or false (denied)
```

### Key Implementation Notes

- Channel auth callbacks receive the authenticated `User` model and the route parameter (taskRunId or teamId)
- Use eager loading to minimize queries: `TaskRun::with('task.project.team')` for task-run channel
- Cache team membership check in Redis for the duration of the WebSocket connection (optional optimization)
- Return `false` (not exception) for unauthorized — Reverb handles the 403 response

## 6. File Structure

```
app/Events/
├── AgentRun/
│   ├── AgentSystemEvent.php
│   ├── AgentAssistantEvent.php
│   ├── AgentResultEvent.php
│   ├── AgentQuestionEvent.php
│   └── AgentStatusEvent.php
└── Team/
    ├── RunStartedEvent.php
    ├── RunCompletedEvent.php
    ├── RunQuestionEvent.php
    └── BalanceUpdatedEvent.php

routes/
└── channels.php              # Channel authorization

config/
├── broadcasting.php          # Reverb driver config
└── reverb.php                # Reverb server config
```

## Acceptance Criteria

### Reverb Setup
- **Given** the application is freshly installed, **when** `php artisan reverb:start` is executed, **then** the WebSocket server starts and accepts connections on the configured port.
- **Given** a valid Sanctum token, **when** a client connects to the WebSocket server, **then** the connection is authenticated and the client can subscribe to authorized channels.

### Channel Authorization — task-run
- **Given** a user who is a member of the team that owns the task's project, **when** they subscribe to `private-task-run.{taskRunId}`, **then** authorization succeeds.
- **Given** a user who is NOT a member of the team, **when** they subscribe to `private-task-run.{taskRunId}`, **then** authorization is denied (403).
- **Given** a task run ID that does not exist, **when** a subscription is attempted, **then** authorization is denied.

### Channel Authorization — team
- **Given** a user who is a member of the team, **when** they subscribe to `private-team.{teamId}`, **then** authorization succeeds.
- **Given** a user who is NOT a member of the team, **when** they subscribe to `private-team.{teamId}`, **then** authorization is denied (403).

### Event Broadcasting — task-run channel
- **Given** an active agent run, **when** the agent session starts (system NDJSON event), **then** an `AgentSystemEvent` is broadcast on `private-task-run.{taskRunId}` with `{type, session_id, model}`.
- **Given** an active agent run, **when** the agent produces output, **then** an `AgentAssistantEvent` is broadcast with `{type, role, content[]}`.
- **Given** an active agent run, **when** the run completes, **then** an `AgentResultEvent` is broadcast with `{type, is_error, total_cost_usd, duration_ms, usage}`.
- **Given** an active agent run, **when** the agent asks a question, **then** an `AgentQuestionEvent` is broadcast with `{type, question_id, question_text}`.
- **Given** a task run, **when** its status changes, **then** an `AgentStatusEvent` is broadcast with `{status, task_run_id}`.

### Event Broadcasting — team channel
- **Given** a team, **when** any run starts, **then** a `RunStartedEvent` is broadcast on `private-team.{teamId}` with `{task_run_id, task_id, agent_role}`.
- **Given** a team, **when** any run completes, **then** a `RunCompletedEvent` is broadcast with `{task_run_id, task_id, cost_usd}`.
- **Given** a team, **when** any agent asks a question, **then** a `RunQuestionEvent` is broadcast with `{task_run_id, task_id, question_text}`.
- **Given** a team, **when** the balance is deducted, **then** a `BalanceUpdatedEvent` is broadcast with `{team_id, new_balance, deducted}`.

### Broadcasting Behavior
- **Given** any broadcast event, **when** it is fired, **then** it is dispatched immediately (not queued) using `ShouldBroadcastNow`.
- **Given** a broadcast event, **when** no clients are subscribed to the channel, **then** the event is still fired (fire-and-forget) without errors.
