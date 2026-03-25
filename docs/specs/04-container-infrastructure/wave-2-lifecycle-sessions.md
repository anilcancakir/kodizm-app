# Wave 2 — Lifecycle & Sessions

> Spec: 04-Container Infrastructure
> Dependencies: 04-wave-1 (ContainerManager service must be complete)

## Deliverables

- [ ] Container lifecycle management (warm → dead transitions)
- [ ] Session volume creation and management
- [ ] Redis warm state tracking
- [ ] `containers:cleanup-warm` scheduled command (every 1 min)
- [ ] `sessions:cleanup` scheduled command (every 30 min)
- [ ] `runs:detect-orphans` scheduled command (every 15 min)
- [ ] Feature tests for lifecycle transitions
- [ ] Feature tests for scheduled commands
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 2-Phase Container Lifecycle

Simplified lifecycle — container is either alive (warm) or removed (dead). No intermediate cold phase.

```
Agent asks question during execution
         │
         ▼
┌─ WARM PHASE (configurable, default 5 min) ───────────────┐
│ Container stays running. TaskRun status: waiting_for_input │
│ warm_until = now + warm_timeout stored in Redis            │
│ WebSocket event: agent.question → Flutter shows question   │
│                                                            │
│ IF user answers while warm:                                │
│   → Answer piped to container via IPC (see 06-wave-3)     │
│   → Agent resumes, TaskRun status: running                 │
│   → Continue streaming                                     │
└────────────────────┬──── warm_until expired ───────────────┘
                     ▼
┌─ DEAD PHASE ──────────────────────────────────────────────┐
│ Container stopped + removed. Session volume preserved.     │
│ TaskRun status remains: waiting_for_input                  │
│                                                            │
│ IF user answers (anytime up to 24h):                       │
│   → Brand new container + session volume mount             │
│   → CLI resumes: --resume {session_id}                     │
│   → Answer injected into prompt context                    │
│   → TaskRun status: running, new container_name            │
│                                                            │
│ After 24h: session volume cleaned up.                      │
│ TaskRun status: timed_out                                  │
└────────────────────────────────────────────────────────────┘
```

## Warm Phase Management

### Entering Warm Phase

When an agent asks a question (detected during NDJSON streaming in 06-agent-execution):

1. Set TaskRun status to `waiting_for_input`
2. Store `warm_until` in Redis: key `warm:{task_run_id}`, value = `now() + config('docker.warm_timeout')`, TTL = `warm_timeout + 60` (buffer)
3. Update TaskRun model: `warm_until = now() + warm_timeout`
4. Container remains running (no action needed — it's already alive)

### Exiting Warm Phase (Answer While Warm)

When user answers and container is still alive:

1. Clear Redis key `warm:{task_run_id}`
2. Update TaskRun: `warm_until = null`, `status = running`
3. Answer delivery via IPC (handled by 06-wave-3)

### Warm Phase Expiry

Handled by `containers:cleanup-warm` scheduled command (see below).

## Dead Phase Management

### Entering Dead Phase

When warm phase expires (via scheduled command):

1. Stop container: `ContainerManager::stop($containerName)`
2. Remove container: `ContainerManager::remove($containerName)`
3. Update TaskRun: `container_name = null`, `warm_until = null`
4. TaskRun status remains `waiting_for_input`
5. Session volume is preserved at `{session_volume_base}/{taskRunId}/`

### Resuming From Dead Phase

When user answers after container has been removed (handled by 06-wave-3):

1. Start new container with session volume mount: `ContainerManager::start()`
2. New container gets a fresh name: `kodizm-{taskRunId}-{new_hash}`
3. CLI resumes with `--resume {session_id}` flag
4. Update TaskRun: `container_name = newContainerName`, `status = running`

## Session Volume Management

### Volume Paths

| CLI Backend | Host Path | Container Mount Path |
|-------------|-----------|---------------------|
| Claude Code | `{session_volume_base}/{taskRunId}/claude/` | `/home/agent/.claude/projects` |
| OpenCode (post-MVP) | `{session_volume_base}/{taskRunId}/opencode/` | `/home/agent/.local/share/opencode` |

Session volumes store CLI session state:
- Claude Code: `.jsonl` session files under `.claude/projects`
- OpenCode: session database under `.local/share/opencode`

### Volume Creation

Session volume directories are created on first container start for a TaskRun. `ContainerManager::start()` ensures the host directory exists before mounting.

### Volume Cleanup

Session volumes are cleaned up by the `sessions:cleanup` scheduled command after `session_max_age` (default 24h) from the TaskRun's last activity.

## Scheduled Commands

### containers:cleanup-warm

**Schedule**: Every 1 minute
**Purpose**: Find expired warm containers, stop + remove them, transition to dead phase.

```
containers:cleanup-warm:
  1. Scan Redis keys matching pattern warm:*
  2. For each key where value (warm_until timestamp) < now():
     a. Extract task_run_id from key
     b. Load TaskRun from DB
     c. If TaskRun.status != waiting_for_input → skip (already handled)
     d. ContainerManager::stop(TaskRun.container_name)
     e. ContainerManager::remove(TaskRun.container_name)
     f. Update TaskRun: container_name = null, warm_until = null
     g. Delete Redis key warm:{task_run_id}
     h. Log: "Container removed for TaskRun #{id}, entering dead phase"
  3. Report: "{N} warm containers cleaned up"
```

**Redis key format**:
- Key: `warm:{task_run_id}`
- Value: Unix timestamp of `warm_until`
- TTL: `warm_timeout + 60` seconds (auto-expire as safety net)

### sessions:cleanup

**Schedule**: Every 30 minutes
**Purpose**: Delete session volumes older than 24h, mark associated TaskRuns as timed_out.

```
sessions:cleanup:
  1. Scan session volume base directory for subdirectories
  2. For each directory (named by taskRunId):
     a. Load TaskRun from DB
     b. If TaskRun is null → delete directory (orphan volume)
     c. Calculate age: now() - max(TaskRun.updated_at, TaskRun.completed_at, TaskRun.started_at)
     d. If age > config('docker.session_max_age'):
        - If TaskRun.status == waiting_for_input:
          → Update TaskRun: status = timed_out, error = "Session expired after 24h"
          → Broadcast .agent.status event
        - Delete session volume directory recursively
        - Log: "Session volume cleaned for TaskRun #{id}"
  3. Report: "{N} session volumes cleaned up"
```

### runs:detect-orphans

**Schedule**: Every 15 minutes
**Purpose**: Find TaskRuns stuck in running state past max_run_duration. Kill container, mark failed.

```
runs:detect-orphans:
  1. Query: TaskRun where status = 'running'
     AND started_at < now() - config('docker.max_run_duration')
  2. For each orphaned TaskRun:
     a. If container_name is set and ContainerManager::exists(container_name):
        - ContainerManager::stop(container_name)
        - ContainerManager::remove(container_name)
     b. Update TaskRun:
        - status = failed
        - error = "Wall-clock timeout: exceeded max run duration of {max_run_duration}s"
        - completed_at = now()
        - container_name = null
     c. Broadcast .agent.status event with status=failed
     d. Log: "Orphaned TaskRun #{id} killed after wall-clock timeout"
  3. Report: "{N} orphaned runs detected and killed"
```

## Acceptance Criteria

### Warm Phase Entry

**Given** a running agent that emits a question event,
**When** the streaming handler detects the question,
**Then** a Redis key `warm:{task_run_id}` is set with the warm_until timestamp, the TaskRun.warm_until is updated, and the TaskRun status is set to `waiting_for_input`.

### Warm Phase — Answer While Warm

**Given** a TaskRun in `waiting_for_input` status with a running container (warm phase),
**When** the user submits an answer,
**Then** the Redis key `warm:{task_run_id}` is deleted, the TaskRun status returns to `running`, and the container remains alive for the answer to be piped via IPC.

### Warm Phase Expiry

**Given** a TaskRun in `waiting_for_input` with `warm_until` in the past,
**When** `containers:cleanup-warm` runs,
**Then** the container is stopped and removed, the TaskRun.container_name is set to null, the Redis key is deleted, and the TaskRun status remains `waiting_for_input`.

### Dead Phase — Answer After Container Removed

**Given** a TaskRun in `waiting_for_input` with no container (dead phase),
**When** the user submits an answer,
**Then** a new container is started with the session volume mounted, the CLI command includes `--resume {session_id}`, and the TaskRun is updated with the new container_name and status `running`.

### Session Volume Cleanup

**Given** a session volume directory older than 24h with a TaskRun in `waiting_for_input`,
**When** `sessions:cleanup` runs,
**Then** the volume directory is deleted, the TaskRun status is updated to `timed_out` with an appropriate error message, and a status broadcast event is emitted.

**Given** a session volume directory older than 24h with a TaskRun in `completed` or `failed` status,
**When** `sessions:cleanup` runs,
**Then** the volume directory is deleted (TaskRun status is not modified — already terminal).

### Orphan Detection

**Given** a TaskRun with status `running` and `started_at` older than `max_run_duration`,
**When** `runs:detect-orphans` runs,
**Then** the container is stopped and removed, the TaskRun status is set to `failed` with a wall-clock timeout error, and a status broadcast event is emitted.

**Given** a TaskRun with status `running` and `started_at` within `max_run_duration`,
**When** `runs:detect-orphans` runs,
**Then** the TaskRun is not modified (still within allowed duration).

### Scheduled Command Registration

**Given** the Laravel scheduler is running,
**When** the schedule is evaluated,
**Then** `containers:cleanup-warm` runs every 1 minute, `sessions:cleanup` runs every 30 minutes, and `runs:detect-orphans` runs every 15 minutes.

## Implementation Notes

- Redis warm state uses simple key-value with TTL. The TTL is a safety net — the scheduled command is the primary cleanup mechanism.
- `containers:cleanup-warm` should use `withoutOverlapping()` to prevent concurrent execution.
- `sessions:cleanup` should scan the filesystem directory, not query DB for all TaskRuns. This catches orphan volumes from crashed processes.
- `runs:detect-orphans` should broadcast WebSocket events so Flutter UI updates immediately.
- All scheduled commands should log their actions for debugging.
- Use `Illuminate\Support\Facades\Redis` for warm state management.
