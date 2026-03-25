# Wave 1 — Agent Runner & Streaming

> Spec: 06-Agent Execution
> Dependencies: 03-wave-3 (CLI backend strategy), 04-wave-1 (ContainerManager), 05-wave-1 (Task model)

## Deliverables

- [ ] TaskRun model + migration + factory
- [ ] TaskRunStatus enum with transitions
- [ ] `AgentRunner` service class
- [ ] `ExecuteAgentTask` queued job (dispatched to `agent_runs` queue)
- [ ] Basic NDJSON stdout line-by-line reading
- [ ] Process management: start, monitor, timeout
- [ ] API: POST start run
- [ ] API: GET run detail
- [ ] API: POST cancel run
- [ ] Feature tests for AgentRunner
- [ ] Feature tests for API endpoints
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## TaskRun Schema

```
task_runs
├── id: uuid PK
├── task_id: uuid FK → tasks
├── agent_role_id: uuid FK → agent_roles
├── ai_token_id: uuid FK → ai_tokens nullable
├── status: enum(pending, running, waiting_for_input, completed, failed, cancelled, timed_out)
├── prompt: text                           // full prompt sent to CLI
├── model: string nullable                 // actual model used
├── session_id: string nullable            // CLI session ID for resume
├── container_name: string nullable        // Docker container name
├── worktree_path: string nullable         // git worktree path in container
├── worktree_branch: string nullable       // branch name
├── total_cost_usd: decimal(10,4) nullable
├── usage: json nullable                   // {input_tokens, output_tokens, cache_read, cache_write}
├── duration_ms: bigint nullable
├── num_turns: int nullable
├── mcp_token: string nullable             // signed JWT for MCP auth, scoped to this run
├── warm_until: timestamp nullable         // warm phase deadline (also in Redis)
├── error: text nullable                   // error message if failed
├── started_at: timestamp nullable
├── completed_at: timestamp nullable
├── timestamps
```

**Migration notes**:
- FK on `task_id` references `tasks.id`, cascade delete.
- FK on `agent_role_id` references `agent_roles.id`, restrict delete.
- FK on `ai_token_id` references `ai_tokens.id`, set null on delete.
- Indexes: `(task_id, status)`, `(status, started_at)`, `(session_id)`.
- No soft deletes on TaskRun (runs are historical records, never deleted).

## TaskRunStatus Enum

```php
enum TaskRunStatus: string
{
    case Pending = 'pending';
    case Running = 'running';
    case WaitingForInput = 'waiting_for_input';
    case Completed = 'completed';
    case Failed = 'failed';
    case Cancelled = 'cancelled';
    case TimedOut = 'timed_out';

    public function allowedTransitions(): array
    {
        return match ($this) {
            self::Pending => [self::Running],
            self::Running => [self::WaitingForInput, self::Completed, self::Failed, self::Cancelled],
            self::WaitingForInput => [self::Running, self::TimedOut, self::Cancelled],
            self::Completed => [],
            self::Failed => [],
            self::Cancelled => [],
            self::TimedOut => [],
        };
    }

    public function canTransitionTo(self $target): bool
    {
        return in_array($target, $this->allowedTransitions(), true);
    }

    public function isTerminal(): bool
    {
        return in_array($this, [self::Completed, self::Failed, self::Cancelled, self::TimedOut], true);
    }

    public function isActive(): bool
    {
        return in_array($this, [self::Pending, self::Running, self::WaitingForInput], true);
    }
}
```

## AgentRunner Service

`App\Services\AgentRunner`

### execute(TaskRun $taskRun): void

Main execution method, called from the `ExecuteAgentTask` job.

```
AgentRunner::execute($taskRun):
  1. resolveStrategy($taskRun)
     → Get agentRole.cli_backend
     → Return ClaudeCodeStrategy (MVP) or OpenCodeStrategy (post-MVP)

  2. resolveToken($taskRun)
     → Get task → project → team
     → Call TokenRotation::resolve(team, provider: strategy.provider())
     → If no token available: fail TaskRun with error "No API token available"
     → Store ai_token_id on TaskRun

  3. resolveModel($taskRun)
     → agentRole.preferred_model ?? strategy.defaultModel()
     → Check backend_config.model_fallbacks for fallback chain
     → Store model on TaskRun

  4. Container start
     → Build volume mounts array:
        - workspace: {workspace_volume_base}/{taskRunId}/ → /workspace
        - session: {session_volume_base}/{taskRunId}/claude/ → /home/agent/.claude/projects
        - CLAUDE.md: generated config → /workspace/CLAUDE.md:ro
     → Build env vars array:
        - ANTHROPIC_API_KEY: token.credentials (decrypted)
        - KODIZM_MCP_TOKEN: generated JWT
        - KODIZM_MCP_ENDPOINT: docker_host.mcp_endpoint + '/api/mcp'
     → ContainerManager::start($taskRun, $volumeMounts, $envVars)

  5. Build CLI command via strategy
     → strategy.buildCommand($taskRun)
     → Claude Code example:
        claude -p "{prompt}" \
          --output-format stream-json \
          --model {model} \
          --max-turns {backend_config.max_turns ?? 50} \
          --max-budget-usd {backend_config.max_budget_usd ?? 5.00} \
          --append-system-prompt "{resolved_system_prompt}" \
          --dangerously-skip-permissions \
          --resume {session_id}  (only if resuming)

  6. Execute in container
     → process = ContainerManager::exec(containerName, command)
     → process.start()
     → TaskRun: status = running, started_at = now()

  7. Stream NDJSON
     → Read process stdout line by line
     → For each line:
        a. JSON decode
        b. strategy.normalizeEvent(rawEvent) → canonical StreamEventType + data
        c. Persist to StreamEvent (wave-2 handles this in detail)
        d. Broadcast via Reverb (wave-2 handles this in detail)
        e. Detect question type → create AgentQuestion (wave-3 handles this)
     → On result event:
        a. Record cost (wave-4 handles this)
        b. Update TaskRun: status, total_cost_usd, usage, duration_ms, num_turns, completed_at

  8. Process completion
     → If process exit code != 0 and no result event received:
        - TaskRun: status = failed, error = stderr output
     → If no question pending: stop + remove container
     → If question pending: enter warm phase (04-wave-2 handles this)
```

### Pre-dispatch Validations

Before creating the TaskRun and dispatching the job:

```php
// 1. Balance check
$team = $task->project->team;
$minCost = config('billing.estimated_min_cost', 0.10);
if ($team->balance < $minCost) {
    throw new InsufficientBalanceException($team, $minCost);
}

// 2. Concurrency check — same task
$activeRunExists = TaskRun::where('task_id', $task->id)
    ->whereIn('status', ['pending', 'running', 'waiting_for_input'])
    ->exists();
if ($activeRunExists) {
    throw new ConcurrencyLimitException('Task already has an active run.');
}

// 3. Concurrency check — project
$projectActiveRuns = TaskRun::whereHas('task', fn ($q) => $q->where('project_id', $task->project_id))
    ->whereIn('status', ['pending', 'running', 'waiting_for_input'])
    ->count();
if ($projectActiveRuns >= config('execution.max_concurrent_per_project', 3)) {
    throw new ConcurrencyLimitException('Project concurrent run limit reached.');
}

// 4. Concurrency check — team
$teamActiveRuns = TaskRun::whereHas('task.project', fn ($q) => $q->where('team_id', $team->id))
    ->whereIn('status', ['pending', 'running', 'waiting_for_input'])
    ->count();
if ($teamActiveRuns >= config('execution.max_concurrent_per_team', 10)) {
    throw new ConcurrencyLimitException('Team concurrent run limit reached.');
}
```

## ExecuteAgentTask Job

`App\Jobs\ExecuteAgentTask`

```php
class ExecuteAgentTask implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 3700; // slightly above max_run_duration
    public int $tries = 1;     // no auto-retry — agent runs are not idempotent
    public string $queue = 'agent_runs';

    public function __construct(
        public TaskRun $taskRun,
    ) {}

    public function handle(AgentRunner $agentRunner): void
    {
        $agentRunner->execute($this->taskRun);
    }

    public function failed(\Throwable $exception): void
    {
        $this->taskRun->update([
            'status' => TaskRunStatus::Failed,
            'error' => $exception->getMessage(),
            'completed_at' => now(),
        ]);

        // Broadcast failure event
        // Cleanup container if exists
    }
}
```

**Queue configuration**: `agent_runs` queue processed by Horizon. Configure Horizon supervisor with appropriate process count and timeout.

## API Endpoints

### POST /api/teams/{team}/projects/{project}/tasks/{task}/runs

Start a new agent run for a task.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "agent_role_id": "integer|required|exists:agent_roles,id",
    "prompt": "string|nullable|max:50000",
    "model": "string|nullable|max:100"
}
```

- `agent_role_id`: Required. Which agent role to use for this run.
- `prompt`: Optional override. If null, a default prompt is generated from task title + description + acceptance_criteria + relevant sections.
- `model`: Optional override. If null, uses agent role's preferred_model.

**Response** `201 Created`:
```json
{
    "data": {
        "id": 1,
        "task_id": 1,
        "agent_role_id": 3,
        "agent_role": {
            "id": 3,
            "name": "Developer",
            "slug": "developer"
        },
        "status": "pending",
        "prompt": "Implement user authentication with Fortify and Sanctum...",
        "model": "claude-sonnet-4-6",
        "session_id": null,
        "container_name": null,
        "total_cost_usd": null,
        "usage": null,
        "duration_ms": null,
        "num_turns": null,
        "error": null,
        "started_at": null,
        "completed_at": null,
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:00:00Z"
    }
}
```

**Business logic**:
1. Validate balance, concurrency, token availability.
2. Generate default prompt if not provided (from task data + sections).
3. Generate MCP token (signed JWT).
4. Create TaskRun with status `pending`.
5. Dispatch `ExecuteAgentTask` job to `agent_runs` queue.
6. Return the TaskRun immediately (job runs async).

**Errors**:
- `402` — Insufficient balance
- `409` — Task already has an active run
- `422` — Validation failed
- `429` — Concurrency limit reached (project or team)
- `403` — User does not have permission (Viewer role)

---

### GET /api/task-runs/{run}

Get run detail. Flat route — auth scoped to user's teams.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "task_id": 1,
        "task": {
            "id": 1,
            "title": "Implement user authentication",
            "status": "in_progress"
        },
        "agent_role_id": 3,
        "agent_role": {
            "id": 3,
            "name": "Developer",
            "slug": "developer"
        },
        "ai_token_id": 2,
        "status": "running",
        "prompt": "Implement user authentication...",
        "model": "claude-sonnet-4-6",
        "session_id": "abc-123-def",
        "container_name": "kodizm-1-a1b2c3",
        "worktree_path": "/workspace",
        "worktree_branch": "feature/task-1",
        "total_cost_usd": null,
        "usage": null,
        "duration_ms": null,
        "num_turns": null,
        "warm_until": null,
        "error": null,
        "started_at": "2026-03-25T10:01:00Z",
        "completed_at": null,
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:01:00Z"
    }
}
```

**Authorization**: User must be a member of the team that owns the task's project.

**Errors**:
- `404` — Run not found or user not authorized
- `401` — Unauthenticated

---

### POST /api/task-runs/{run}/cancel

Cancel a running or pending agent run.

**Headers**: `Authorization: Bearer {token}`

**Request**: Empty body.

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "status": "cancelled",
        "completed_at": "2026-03-25T10:05:00Z"
    }
}
```

**Business logic**:
1. Validate TaskRun status is `pending`, `running`, or `waiting_for_input`.
2. If running: kill the process, stop + remove container.
3. Update TaskRun: status = `cancelled`, completed_at = now().
4. Broadcast `.agent.status` event with status = cancelled.

**Errors**:
- `409` — Run is already in a terminal state (completed, failed, cancelled, timed_out)
- `403` — User does not have permission
- `404` — Run not found

## Acceptance Criteria

### Run Start

**Given** a task with no active runs, sufficient team balance, and available tokens,
**When** POST to start a new run with a valid agent_role_id,
**Then** a TaskRun is created with status `pending`, an `ExecuteAgentTask` job is dispatched to the `agent_runs` queue, and a 201 response is returned.

**Given** a task with an existing active run (status = running),
**When** POST to start a new run,
**Then** a 409 response is returned with error "Task already has an active run."

**Given** a team with balance below the minimum estimated cost,
**When** POST to start a new run,
**Then** a 402 response is returned with error "Insufficient balance."

**Given** a project with 3 active runs (max concurrent reached),
**When** POST to start another run in the same project,
**Then** a 429 response is returned with error "Project concurrent run limit reached."

**Given** a team with 10 active runs (max concurrent reached),
**When** POST to start another run,
**Then** a 429 response is returned with error "Team concurrent run limit reached."

### AgentRunner Execution

**Given** a pending TaskRun dispatched to the job queue,
**When** `ExecuteAgentTask` is processed,
**Then** `AgentRunner::execute()` resolves the strategy, token, and model, starts a container, builds the CLI command, executes it, and reads NDJSON output line by line.

**Given** an agent run that completes successfully with a result event,
**When** the process exits with code 0,
**Then** the TaskRun status is set to `completed`, total_cost_usd and usage are populated from the result event, duration_ms is calculated, completed_at is set, and the container is stopped + removed.

**Given** an agent run where the process exits with a non-zero exit code,
**When** no result event was received,
**Then** the TaskRun status is set to `failed`, the error field contains stderr output, and the container is stopped + removed.

### Run Cancel

**Given** a TaskRun with status `running`,
**When** POST to cancel,
**Then** the container process is killed, the container is stopped + removed, the TaskRun status is set to `cancelled`, and a status broadcast event is emitted.

**Given** a TaskRun with status `completed`,
**When** POST to cancel,
**Then** a 409 response is returned (already terminal).

### Run Detail

**Given** a TaskRun that belongs to a team the user is a member of,
**When** GET run detail,
**Then** the full TaskRun data is returned with task and agent_role relations.

**Given** a TaskRun that belongs to a different team,
**When** GET run detail,
**Then** a 404 response is returned.

## Implementation Notes

- `AgentRunner` should be injected via Laravel's service container — use an interface for testability.
- `ExecuteAgentTask` job has `$tries = 1` — agent runs are not idempotent, do not auto-retry.
- Job timeout should be slightly above `max_run_duration` to allow graceful cleanup.
- NDJSON streaming in this wave is basic — read lines, JSON decode. Full normalization and persistence happen in wave-2.
- The `prompt` field stores the full prompt sent to CLI. Generate it from task data if not provided by user.
- MCP token generation: use `Firebase\JWT\JWT` or `Laravel\Passport\JWT` — signed JWT with claims `{task_run_id, project_id, team_id, agent_role_slug, exp: +24h}`.
- Horizon queue `agent_runs` should be configured with a dedicated supervisor in `config/horizon.php`.
