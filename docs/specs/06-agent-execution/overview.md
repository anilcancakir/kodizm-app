# Spec 06 — Agent Execution

> Agent execution engine: the CORE of the system.
> Dependencies: 03-Agent System, 04-Container Infrastructure, 05-Task Management.

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Agent Runner & Streaming | AgentRunner service, ExecuteAgentTask job, basic NDJSON stdout reading, run start/detail/cancel API |
| 2 | NDJSON Events | StreamEvent model, NDJSON normalization, event persistence |
| 3 | Q&A Flow & Resume | AgentQuestion model, Q&A API, answer delivery IPC, session resume |
| 4 | Cost Recording | TeamUsageRecord model, cost calculation service, balance deduction |

## Dependencies on Other Specs

- **03-Agent System** (all waves): CLI backend strategy, token rotation, agent role config
- **04-Container Infrastructure** (wave-1): ContainerManager for starting/stopping containers
- **04-Container Infrastructure** (wave-2): Lifecycle management for warm/dead transitions (needed by wave-3)
- **05-Task Management** (wave-1): Task model for creating runs against tasks
- **09-Billing & Credits** (wave-1): Team balance model (wave-4 can be built in parallel with 09)
- **Note**: User and Team models come from magic-starter and are extended by Kodizm.

## This Is the Core

This spec implements the full agent execution pipeline — from user clicking "Run" to agent output streaming in real-time on the Flutter UI. Every other spec feeds into or consumes from this one.

**Full execution flow** (Section 5.2 from master spec):

```
1. User creates task + assigns agent role + clicks "Run"
2. Flutter → POST /api/projects/{id}/tasks/{id}/runs
3. Laravel validates: balance check, concurrency check, token availability
4. Dispatches ExecuteAgentTask job to `agent_runs` queue
5. AgentRunner::execute($taskRun):
   a. resolveStrategy($taskRun) → ClaudeCodeStrategy (MVP)
   b. resolveToken(provider) → pick token via rotation algorithm
   c. resolveModel(agentRole) → model with fallback chain
   d. Container start:
      - git clone/pull repo into workspace (or SCP for remote host)
      - git checkout -b feature/task-{id} from default_branch
      - docker run -d --entrypoint sleep universal-image infinity
      - mount: workspace, session volume, config files (CLAUDE.md, settings.json)
      - inject: API key env var, MCP endpoint
   e. Build CLI command:
      Claude Code: claude -p "{prompt}" --output-format stream-json
        --model {model} --max-turns {N} --max-budget-usd {N}
        --append-system-prompt "{agent_system_prompt}"
        --dangerously-skip-permissions
        --resume {session_id}  (if resuming)
   f. Wrap: docker exec -i {container} {command}
   g. Stream NDJSON:
      - Read line by line from process stdout
      - strategy.normalizeEvent(rawEvent) → canonical event
      - Persist to StreamEvent
      - Broadcast via Reverb on task-run.{taskRunId} channel
      - Detect question → create AgentQuestion, set status=waiting_for_input
   h. On result event:
      - Record cost: model, tokens, USD → TeamUsageRecord
      - Deduct from team.balance
      - Update task_run: completed/failed, total_cost_usd, usage, duration_ms
6. Container lifecycle (if no question → stop container)
7. If question asked → warm/dead/resume lifecycle (see 04-wave-2)
```

## Data Models

### TaskRun
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

### StreamEvent
```
stream_events
├── id: uuid PK
├── task_run_id: uuid FK → task_runs
├── type: enum(system, assistant, result, question, auto_answer, file_change, error)
├── data: json                    // raw normalized event data
├── content_text: text nullable   // extracted text content (searchable)
├── file_path: string nullable    // if file_change type
├── is_question: boolean default false
├── occurred_at: timestamp
├── timestamps
```

### AgentQuestion
```
agent_questions
├── id: uuid PK
├── task_run_id: uuid FK → task_runs
├── stream_event_id: uuid FK → stream_events nullable  // correlate with terminal stream
├── question_text: text
├── answer_text: text nullable
├── answered_by_user_id: uuid FK → users nullable
├── answered_at: timestamp nullable
├── created_at: timestamp
```

### TeamUsageRecord
```
team_usage_records
├── id: uuid PK
├── team_id: uuid FK → teams
├── task_run_id: uuid FK → task_runs nullable
├── model: string nullable
├── input_tokens: bigint unsigned nullable
├── output_tokens: bigint unsigned nullable
├── cost_usd: decimal(10,6)
├── period: string                    // '2026-03' (month)
├── recorded_at: timestamp
├── timestamps
```

## Relevant Enums

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
}

enum StreamEventType: string
{
    case System = 'system';
    case Assistant = 'assistant';
    case Result = 'result';
    case Question = 'question';
    case AutoAnswer = 'auto_answer';
    case FileChange = 'file_change';
    case Error = 'error';
}
```

### TaskRunStatus Transitions

```
pending → running
running → waiting_for_input, completed, failed, cancelled
waiting_for_input → running (resume), timed_out, cancelled
completed → (terminal)
failed → (terminal)
cancelled → (terminal)
timed_out → (terminal)
```

## Database Indexes

```
task_runs:          (task_id, status), (status, started_at), (session_id)
stream_events:      (task_run_id, occurred_at), (task_run_id, is_question)
agent_questions:    (task_run_id, answered_at)
team_usage_records: (team_id, recorded_at), (team_id, period)
```

## Business Rules

### Balance Check
- Before dispatching: `team.balance >= estimated_min_cost` (default $0.10, configurable).
- If balance insufficient: return 402 Payment Required.

### Concurrency Check
- Max concurrent runs per project: 3 (configurable).
- Max concurrent runs per team: 10 (configurable).
- Same task: max 1 active run.
- If limit exceeded: return 429 Too Many Requests.

### Cost Recording
- Cost formula: `(input_tokens / 1_000_000 * input_price) + (output_tokens / 1_000_000 * output_price)`
- Pricing from `config/model-pricing.php` (move to DB for production).
- On crash/timeout with missing result event: use `max_budget_usd` as estimated cost.
