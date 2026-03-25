# Kodizm — Full Software Specification

> Version: 1.1 | Date: 2026-03-25
> Stack: Laravel 12 (PHP 8.4) + Flutter (Dart) + PostgreSQL + Redis + Docker
> Revenue: SaaS, credit/balance based
> Admin: Filament 5 | User UI: Flutter (web + mobile)
> MVP CLI: Claude Code only | Full: + OpenCode

---

## 1. Vision & Positioning

**One-liner**: Multi-agent SDLC orchestrator that routes tasks to AI CLI agents running in isolated Docker containers.

**Core thesis**: Single-agent coding tools are commoditizing. Kodizm is the orchestration layer that makes multiple AI agents work together across the full software development lifecycle — analysis, planning, implementation, review, testing — with real-time transparency, cost control, and team collaboration.

**Differentiators** (no competitor has all of these):
- Multi-agent with role-based personas (BA, Lead Dev, Developer, Reviewer, QA, Designer)
- Multi-model routing (MVP: Claude Code | Full: + OpenCode → Claude, GPT, Gemini models)
- Docker isolation per agent run (ephemeral containers, session persistence)
- Full SDLC pipeline orchestration (not just coding)
- Mobile app (Flutter — monitor agents, answer questions, approve work on-the-go)
- Built-in task management with standardized structure
- Credit-based billing with per-model cost tracking

**Target users**: Solo developers, small teams (2-10), agencies/freelancers.

---

## 2. Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Backend | Laravel 12 (PHP 8.4) | API-first, Reverb WebSocket, Horizon queues, Filament admin |
| Frontend | Flutter (Web + Mobile) | Single codebase, rich real-time UI, mobile differentiator |
| Admin | Filament 5 | Laravel-native admin CRUD, fast to build |
| Database | PostgreSQL + pgvector | Relational + vector embeddings for knowledge search |
| Queue Manager | Laravel Horizon | Dashboard, queue monitoring, job metrics, retry management |
| Cache/Queue | Redis | Session state, container tracking, token cooldown, job queues |
| Real-time | Laravel Reverb | First-party WebSocket server, private channels |
| Containers | Docker | Agent execution isolation, universal image |
| Auth | Fortify (web) + Sanctum (API) | Session auth for Filament, token auth for Flutter |
| Billing | Stripe (post-MVP) | Metered billing, credit purchase |

---

## 3. Data Models

### 3.1 User
```
users
├── id: bigint PK
├── name: string
├── email: string unique
├── password: string (hashed)
├── email_verified_at: timestamp nullable
├── avatar_url: string nullable
├── locale: string default 'en'
├── timestamps
└── soft_deletes
```

### 3.2 Team
```
teams
├── id: bigint PK
├── name: string
├── slug: string unique
├── balance: decimal(12,4) default 0  // credit balance in USD
├── owner_id: FK → users
├── settings: json nullable           // team-wide settings
├── timestamps
└── soft_deletes
```

### 3.3 TeamMember (pivot)
```
team_members
├── id: bigint PK
├── team_id: FK → teams
├── user_id: FK → users
├── role: enum(owner, admin, member, viewer)
├── timestamps
└── unique(team_id, user_id)
```

**TeamRole enum**: Owner (full access), Admin (manage projects/agents/tokens), Member (create tasks, run agents), Viewer (read-only).

### 3.4 Project
```
projects
├── id: bigint PK
├── team_id: FK → teams
├── name: string
├── slug: string
├── description: text nullable
├── repository_url: string nullable       // git@github.com:org/repo.git
├── default_branch: string default 'main'
├── tech_stack: string nullable            // e.g. 'laravel-flutter', 'laravel-blade'
├── ssh_private_key: text encrypted nullable  // for private repo access
├── ssh_public_key: text nullable             // displayed to user for deploy key setup
├── execution_mode: enum(manual, semi_auto, full_auto) default 'manual'
├── pipeline_config: json nullable         // pipeline stage→agent mapping (post-MVP)
├── settings: json nullable                // project-specific settings
├── timestamps
└── soft_deletes
```

### 3.5 AgentRole
```
agent_roles
├── id: bigint PK
├── team_id: FK → teams nullable     // null = system-level default
├── project_id: FK → projects nullable // null = team-wide or system-level
├── parent_id: FK → agent_roles nullable // system default this was cloned from
├── name: string                     // "Business Analyst", "Lead Developer", etc.
├── slug: string                     // "ba", "lead-dev", "developer", etc.
├── description: text nullable
├── cli_backend: enum(claude-code, opencode)
├── preferred_model: string nullable  // 'claude-sonnet-4-6', 'gemini-3.1-pro'
├── system_prompt: text nullable      // agent persona instructions (base prompt)
├── prompt_append: text nullable      // team/project-level prompt additions (appended to system_prompt)
├── backend_config: json nullable     // per-backend config (see below)
├── tool_permissions: json nullable   // allowed MCP tools for this role
├── scope: enum(system, team, project) default 'team'
├── is_active: boolean default true
├── sort_order: integer default 0
├── timestamps
└── soft_deletes
```

**Scope hierarchy** (full scope, not MVP):
- **System-level** (`scope: system`, `team_id: null`): Default agents defined by Kodizm admins. Seeded on install. Cannot be deleted by users. Serve as templates.
- **Team-level** (`scope: team`, `team_id: set`): Cloned from system defaults or created custom. Team owner/admin can edit `prompt_append`, `backend_config`, `tool_permissions`. `system_prompt` from parent is read-only; `prompt_append` is injected after it.
- **Project-level** (`scope: project`, `project_id: set`): Further customization for a specific project. Inherits team config, adds project-specific prompt/config.

**Prompt resolution** (runtime):
```
final_prompt = parent.system_prompt + "\n---\n" + self.prompt_append (team) + "\n---\n" + child.prompt_append (project)
```
Each level can only APPEND — never override parent system_prompt. This ensures system-level guardrails remain intact.

**Custom agents** (full scope): Teams/projects can create entirely new agents (no parent_id) with custom `system_prompt`, `cli_backend`, `preferred_model`, and `tool_permissions`. These are fully user-defined.

**MVP behavior**: System defaults are seeded per team (cloned to team scope). Teams can edit the full agent config. No project-level override, no system-level read-only enforcement. `prompt_append` and scope hierarchy are post-MVP.

**backend_config schema**:
```json
{
  "claude-code": {
    "claude_md": "Custom CLAUDE.md content for this agent...",
    "model_fallbacks": ["claude-opus-4-6"],
    "allowed_tools": ["Bash(npm:*)", "Read", "Write", "Edit"],
    "max_turns": 50,
    "max_budget_usd": 5.00,
    "mcp_servers": {}
  },
  "opencode": {
    "custom_instructions": "Custom instructions...",
    "model_fallbacks": ["gpt-5.4"],
    "tools": ["bash", "read", "write"]
  }
}
```

**Default agent roles** (seeded per team):

| Role | CLI Backend | Model | Purpose |
|------|-------------|-------|---------|
| Business Analyst | claude-code | claude-opus-4-6 | Requirements, analysis, task creation |
| Lead Developer | claude-code | claude-opus-4-6 | Architecture, planning, decomposition |
| Developer | claude-code | claude-sonnet-4-6 | Implementation, coding, testing |
| Code Reviewer | claude-code | claude-opus-4-6 | Code quality, security, best practices |
| QA Engineer | claude-code | claude-sonnet-4-6 | Test planning, execution, verification |
| Designer | claude-code | claude-opus-4-6 | UI/UX design via Figma MCP (post-MVP) |

### 3.6 AiToken
```
ai_tokens
├── id: bigint PK
├── team_id: FK → teams
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

### 3.7 Task
```
tasks
├── id: bigint PK
├── project_id: FK → projects
├── parent_task_id: FK → tasks nullable  // sub-task support
├── title: string
├── description: text nullable
├── acceptance_criteria: text nullable
├── type: enum(story, task, bug, spike)
├── priority: enum(p0, p1, p2, p3) default p2
├── status: enum(draft, analysis, planning, in_progress, review, testing, done, failed)
├── estimated_complexity: enum(xs, s, m, l, xl) nullable
├── assigned_agent_role_id: FK → agent_roles nullable
├── created_by_user_id: FK → users nullable  // null = agent-created
├── source: enum(manual, pm_conversation) default 'manual'
├── source_conversation_id: FK → task_runs nullable  // PM chat session that created this task
├── design_needed: boolean default false              // PM flags → triggers Designer stage
├── retry_count: integer default 0                    // tracks reject→retry cycles
├── sprint_id: FK → sprints nullable      // POST-MVP: add migration when sprints table exists
├── branch_name: string nullable          // feature/task-{id}
├── total_cost_usd: decimal(10,4) default 0
├── timestamps
└── soft_deletes
```

**TaskStatus enum with transitions**:
```
draft → analysis
analysis → planning, failed
planning → design (if design_needed), in_progress, failed
design → in_progress, failed
in_progress → review, failed
review → in_progress (reject → retry), testing, failed
testing → in_progress (fail → retry), done, failed
done → (terminal)
failed → draft (reopen)
```

### 3.8 TaskSection
```
task_sections
├── id: bigint PK
├── task_id: FK → tasks
├── type: enum(analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments)
├── title: string
├── content: text
├── created_by_agent_role_id: FK → agent_roles nullable
├── created_by_user_id: FK → users nullable
├── version: int default 1
├── timestamps
```

### 3.9 TaskRun
```
task_runs
├── id: bigint PK
├── task_id: FK → tasks
├── agent_role_id: FK → agent_roles
├── ai_token_id: FK → ai_tokens nullable
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

**TaskRunStatus enum**:
```
pending → running
running → waiting_for_input, completed, failed, cancelled
waiting_for_input → running (resume), timed_out, cancelled
completed → (terminal)
failed → (terminal)
cancelled → (terminal)
timed_out → (terminal)
```

### 3.10 StreamEvent
```
stream_events
├── id: bigint PK
├── task_run_id: FK → task_runs
├── type: enum(system, assistant, result, question, auto_answer, file_change, error)
├── data: json                    // raw normalized event data
├── content_text: text nullable   // extracted text content (searchable)
├── file_path: string nullable    // if file_change type
├── is_question: boolean default false
├── occurred_at: timestamp
├── timestamps
```

### 3.11 AgentQuestion
```
agent_questions
├── id: bigint PK
├── task_run_id: FK → task_runs
├── stream_event_id: FK → stream_events nullable  // correlate with terminal stream
├── question_text: text
├── answer_text: text nullable
├── answered_by_user_id: FK → users nullable
├── answered_at: timestamp nullable
├── created_at: timestamp
```

### 3.12 ProjectDocument
```
project_documents
├── id: bigint PK
├── project_id: FK → projects
├── title: string
├── content: text
├── category: enum(architecture, api, guide, convention, runbook, agent_output, other)
├── embedding: vector(1536) nullable  // pgvector for semantic search (post-MVP basic)
├── created_by_agent_role_id: FK → agent_roles nullable
├── created_by_user_id: FK → users nullable
├── timestamps
```

### 3.13 TeamUsageRecord
```
team_usage_records
├── id: bigint PK
├── team_id: FK → teams
├── task_run_id: FK → task_runs nullable
├── model: string nullable
├── input_tokens: bigint unsigned nullable
├── output_tokens: bigint unsigned nullable
├── cost_usd: decimal(10,6)
├── period: string                    // '2026-03' (month)
├── recorded_at: timestamp
├── timestamps
```

### 3.14 DockerHost (config-based, not DB)
```yaml
# config/docker-hosts.php
'hosts' => [
    'local' => [
        'docker_host' => null,              // local socket
        'mcp_endpoint' => env('APP_URL'),
        'tls_verify' => false,
    ],
    'remote-1' => [
        'docker_host' => 'tcp://192.168.1.100:2376',
        'mcp_endpoint' => 'http://192.168.1.100:8080',
        'tls_verify' => true,
    ],
]
```

### 3.15 PipelineStageRun (POST-MVP)
```
pipeline_stage_runs
├── id: bigint PK
├── task_id: FK → tasks
├── task_run_id: FK → task_runs nullable
├── stage: string                      // WorkflowStatus value
├── status: enum(pending, running, awaiting_approval, completed, failed, cancelled)
├── context_data: json nullable        // previous stage summary, diff, cost
├── approved_by_user_id: FK → users nullable
├── approved_at: timestamp nullable
├── error: text nullable
├── started_at: timestamp nullable
├── completed_at: timestamp nullable
├── timestamps
```

### 3.16 Database Indexes (Critical)
```
tasks:           (project_id, status), (parent_task_id), (sprint_id)
task_runs:       (task_id, status), (status, started_at), (session_id)
stream_events:   (task_run_id, occurred_at), (task_run_id, is_question)
agent_questions: (task_run_id, answered_at)
team_usage_records: (team_id, recorded_at), (team_id, period)
project_documents: (project_id, category)
ai_tokens:       (team_id, provider, status)
agent_roles:     (team_id, scope), (parent_id)
```

---

## 4. Enums

```php
// Auth & Roles
TeamRole: owner, admin, member, viewer

// AI Providers & Config
AiProvider: anthropic, openai, google, openrouter
CliBackend: claude_code, opencode
AuthType: api_key, subscription
TokenStatus: active, inactive, rate_limited, expired
RotationAlgorithm: fill_first, round_robin, random

// Tasks
TaskType: story, task, bug, spike
TaskPriority: p0, p1, p2, p3
TaskStatus: draft, analysis, planning, design, in_progress, review, testing, done, failed
TaskComplexity: xs, s, m, l, xl
TaskSectionType: analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments
TaskSource: manual, pm_conversation

// Project Execution Mode
ExecutionMode: manual, semi_auto, full_auto

// Execution
TaskRunStatus: pending, running, waiting_for_input, completed, failed, cancelled, timed_out

// Stream
StreamEventType: system, assistant, result, question, auto_answer, file_change, error

// Knowledge
DocumentCategory: architecture, api, guide, convention, runbook, agent_output, other

// Agent Scope
AgentScope: system, team, project

// Pipeline (post-MVP)
PipelineExecutionStatus: pending, running, awaiting_approval, completed, failed, cancelled
```

---

## 5. Architecture

### 5.1 System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Web + Mobile)                │
│  Auth │ Teams │ Projects │ Tasks │ Agent Runs │ Chat │ Admin  │
└────────────────────────┬─────────────────────────────────────┘
                         │ REST API + WebSocket
                         ↓
┌──────────────────────────────────────────────────────────────┐
│                     LARAVEL BACKEND                           │
│                                                               │
│  ┌─────────┐  ┌──────────┐  ┌───────────┐  ┌─────────────┐ │
│  │ Auth    │  │ API      │  │ WebSocket │  │ Filament    │ │
│  │ Fortify │  │ Sanctum  │  │ Reverb    │  │ Admin Panel │ │
│  └─────────┘  └──────────┘  └───────────┘  └─────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    SERVICES                              │ │
│  │  AgentRunner │ ContainerManager │ TokenRotation          │ │
│  │  UsageMeter  │ ConfigGenerator  │ SemanticSearch         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────────┐ │
│  │ Horizon  │  │ MCP Server│  │ Events   │  │ Broadcasts │ │
│  │ (Queues) │  │ (Agent↔DB)│  │ Listeners│  │ (Reverb)   │ │
│  └──────────┘  └───────────┘  └──────────┘  └────────────┘ │
└────────────────────────┬─────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ↓              ↓              ↓
   ┌────────────┐ ┌───────────┐ ┌────────────┐
   │ PostgreSQL │ │   Redis   │ │   Docker   │
   │ + pgvector │ │ Cache/Q's │ │   Host(s)  │
   └────────────┘ └───────────┘ └────────────┘
                                       │
                         ┌─────────────┼─────────────┐
                         ↓             ↓             ↓
                  ┌────────────┐┌────────────┐┌────────────┐
                  │ Container 1││ Container 2││ Container N│
                  │ (Agent Run)││ (Agent Run)││ (Agent Run)│
                  │ claude/oc  ││ claude/oc  ││ claude/oc  │
                  └────────────┘└────────────┘└────────────┘
```

### 5.2 Agent Execution Flow

```
1. User creates task + assigns agent role + clicks "Run"
2. Flutter → POST /api/projects/{id}/tasks/{id}/runs
3. Laravel validates: balance check, concurrency check, token availability
4. Dispatches ExecuteAgentTask job to `agent_runs` queue
5. AgentRunner::execute($taskRun):
   a. resolveStrategy($taskRun) → ClaudeCodeStrategy (MVP) | OpenCodeStrategy (full scope)
   b. resolveToken(provider) → pick token via rotation algorithm (MVP: anthropic only)
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
      OpenCode: opencode run --format json --model {model}
        --session {session_id}  (if resuming)
        "{prompt}"
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
7. If question asked → warm/cold/resume lifecycle (see section 5.3)
```

### 5.3 Container Lifecycle (Warm → Dead)

Simplified 2-phase lifecycle. No cold phase — container is either alive or removed.

```
Agent asks question during execution
         │
         ↓
┌─ WARM PHASE (configurable, default 5 min) ───────────────┐
│ Container stays running. TaskRun status: waiting_for_input │
│ warm_until = now + warm_timeout stored in Redis            │
│ WebSocket event: agent.question → Flutter shows question   │
│                                                            │
│ IF user answers while warm:                                │
│   → Answer piped to container via IPC (see 5.3.1)         │
│   → Agent resumes, TaskRun status: running                 │
│   → Continue streaming                                     │
└────────────────────┬──── warm_until expired ───────────────┘
                     ↓
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

#### 5.3.1 Answer Delivery Mechanism (IPC)

```
User answers question via Flutter UI
         │
         ↓
POST /api/task-runs/{run}/answer { answer_text }
         │
         ↓
┌─ WARM CONTAINER (container still alive) ─────────────────┐
│ 1. Laravel publishes to Redis channel: agent:answer:{id}  │
│ 2. Streaming worker (running docker exec) subscribes to   │
│    this channel in a parallel thread/fiber                 │
│ 3. On message: write answer to process stdin pipe          │
│ 4. Claude Code receives answer via elicitation response    │
│ 5. Agent resumes execution, streaming continues            │
└───────────────────────────────────────────────────────────┘

┌─ DEAD CONTAINER (container removed) ─────────────────────┐
│ 1. Laravel starts new container + session volume mount     │
│ 2. Builds resume command:                                  │
│    claude -p "User answered: {answer}" --resume {id}       │
│      --output-format stream-json ...                       │
│ 3. docker exec -i {new_container} {command}               │
│ 4. Fresh streaming worker picks up NDJSON output           │
│ 5. Standard execution flow from here                       │
└───────────────────────────────────────────────────────────┘
```

**Session volume paths**:
- Claude Code: `{volume}/{taskRunId}/claude:/home/agent/.claude/projects` → session .jsonl files
- OpenCode (full scope): `{volume}/{taskRunId}/opencode:/home/agent/.local/share/opencode` → session DB
- Note: Container runs as `agent` user (UID 1001) per existing Docker image. Paths use `/home/agent/`.

### 5.4 NDJSON Event Normalization

**Claude Code events → Canonical**:
| CC Event | Canonical | Transform |
|----------|-----------|-----------|
| system (subtype: init) | system | Extract session_id, model |
| assistant | assistant | Pass content array, ensure session_id |
| user | (drop) | Tool results — not broadcast |
| result | result | Map is_error, total_cost_usd, usage, duration_ms |
| elicitation | question | Question text extraction |

**OpenCode events → Canonical** (FULL SCOPE ONLY):
| OC Event | Canonical | Transform |
|----------|-----------|-----------|
| step_start | system | Session init equivalent |
| text | assistant | Text content |
| tool_use | assistant | Tool call details |
| step_finish | result | Completion with cost/usage |
| error | error | Error details |

### 5.5 MCP Server (Agent ↔ Kodizm)

Kodizm exposes an MCP server that agents call via tools inside the container.

**MCP Tools** (agent-accessible):

| Tool | Purpose | Access |
|------|---------|--------|
| `report-progress` | Agent reports status/progress | All agents |
| `search-knowledge` | Semantic search project+team docs | All agents |
| `get-task` | Read current task details | All agents |
| `get-project-info` | Read project metadata + tech stack | All agents |
| `create-task-section` | Write analysis/plan/report to task | All agents |
| `update-task-section` | Update existing section | All agents |
| `create-task` | Create new task/sub-task | BA, Lead Dev |
| `update-task` | Update task fields/status | BA, Lead Dev |
| `create-document` | Write project document | All agents |
| `update-document` | Update project document | All agents |
| `search-documents` | Search project documents | All agents |

**MCP auth**: Container receives `KODIZM_MCP_TOKEN` env var. MCP server validates token → resolves TaskRun → scopes all operations to task's project.

**MCP token lifecycle**:
1. On TaskRun creation: generate signed JWT containing `{task_run_id, project_id, team_id, agent_role_slug, exp: +24h}`
2. Store token on `task_runs.mcp_token` (for validation lookup fallback)
3. Inject as `KODIZM_MCP_TOKEN` env var into container
4. MCP server middleware: verify JWT signature → extract claims → scope all queries
5. Token expires with TaskRun completion or 24h, whichever comes first
6. No DB lookup needed for validation (JWT is self-contained), DB field is backup

**MCP Tool Schemas (MVP)**:

```json
// report-progress
{ "input": { "status": "string", "message": "string", "percentage": "number|null" },
  "output": { "ok": true } }

// get-task
{ "input": {},
  "output": { "id": "number", "title": "string", "description": "string|null",
              "acceptance_criteria": "string|null", "type": "string", "priority": "string",
              "status": "string", "sections": [{ "type": "string", "content": "string" }] } }

// get-project-info
{ "input": {},
  "output": { "id": "number", "name": "string", "tech_stack": "string|null",
              "default_branch": "string", "repository_url": "string|null" } }

// create-task-section
{ "input": { "type": "TaskSectionType", "title": "string|null", "content": "string" },
  "output": { "id": "number", "type": "string", "version": 1 } }

// update-task-section
{ "input": { "section_id": "number", "content": "string" },
  "output": { "id": "number", "version": "number" } }
// version auto-increments on each update

// search-knowledge
{ "input": { "query": "string", "limit": "number|null (default 5)" },
  "output": { "results": [{ "id": "number", "title": "string", "content": "string",
              "category": "string", "relevance_score": "number" }] } }

// create-task (BA, Lead Dev only)
{ "input": { "title": "string", "description": "string|null", "type": "TaskType",
              "priority": "TaskPriority|null", "acceptance_criteria": "string|null",
              "parent_task_id": "number|null", "design_needed": "boolean|null" },
  "output": { "id": "number", "title": "string", "status": "draft" } }

// update-task (BA, Lead Dev only)
{ "input": { "task_id": "number", "title": "string|null", "description": "string|null",
              "status": "TaskStatus|null", "priority": "TaskPriority|null",
              "acceptance_criteria": "string|null" },
  "output": { "id": "number", "title": "string", "status": "string" } }

// create-document
{ "input": { "title": "string", "content": "string", "category": "DocumentCategory" },
  "output": { "id": "number", "title": "string" } }

// update-document
{ "input": { "document_id": "number", "content": "string", "title": "string|null" },
  "output": { "id": "number", "title": "string" } }

// search-documents
{ "input": { "query": "string", "category": "DocumentCategory|null", "limit": "number|null" },
  "output": { "results": [{ "id": "number", "title": "string", "content": "string",
              "category": "string" }] } }
```

### 5.6 Token Rotation

```
resolveToken(AiProvider $provider):
  1. Get all active tokens for team + provider
  2. Exclude: status=rate_limited, cooldown_until > now()
  3. Apply rotation algorithm:
     - fill_first: lowest usage_count
     - round_robin: oldest last_used_at
     - random: random pick
  4. Update: last_used_at = now(), usage_count++
  5. Return token (or null if none available)

On rate limit (429 response detected):
  → Set cooldown_until = now + config('ai-tokens.rate_limit_cooldown', 60)
  → Status stays active (auto-recovers after cooldown)
```

### 5.7 Git Integration

```
Project setup:
  1. User provides repository_url (git@github.com:org/repo.git)
  2. Kodizm generates SSH keypair, stores private key encrypted
  3. User adds public key as deploy key in GitHub/GitLab

Agent run - repo setup in container:
  LOCAL Docker host:
    - git clone {repo} /workspace  (or git pull if cached)
    - git checkout -b feature/task-{id} {default_branch}
    - mount /workspace as volume

  REMOTE Docker host:
    - Kodizm server: git clone/pull to local cache
    - SCP workspace to remote host temp dir
    - Docker container mounts that temp dir
    - After run: SCP changed files back (or git push from container)

Branch strategy:
  - Default branch: project.default_branch (main/master)
  - Task branch: feature/task-{id} (configurable pattern)
  - Agent works on task branch
  - Post-MVP: auto-merge, PR creation via GitHub API
```

### 5.8 Task Creation & Workflow Pipeline (POST-MVP)

#### Task Creation Methods

```
┌─ METHOD 1: MANUAL ───────────────────────────────────────────┐
│ User creates task directly in Flutter UI.                     │
│ Fills: title, description, acceptance_criteria, type,         │
│        priority, estimation.                                  │
│ Task starts in: draft                                         │
│ source: manual                                                │
└───────────────────────────────────────────────────────────────┘

┌─ METHOD 2: PM CONVERSATION ──────────────────────────────────┐
│ User writes anything — customer request, bullet points,       │
│ meeting notes, raw idea, feature wish, bug report.            │
│ e.g. "login sayfasinda google ile giris de olsun"             │
│ e.g. "- search broken on mobile\n- need dark mode\n- ..."    │
│                                                               │
│ PM agent picks up → analyzes, groups, clarifies:              │
│   - Single item? → Socratic clarification loop, then task     │
│   - Multiple items? → Groups related items, prioritizes,      │
│     creates multiple story spec tasks                         │
│                                                               │
│ Clarification example:                                        │
│   PM: "Bu sadece web mi, mobile da mı?"                       │
│   User: "ikisi de"                                            │
│   PM: "Mevcut email login yanına mı, ayrı sayfa mı?"         │
│   User: "yanına, buton olarak"                                │
│   ...netleşene kadar devam eder                               │
│                                                               │
│ PM agent creates structured task(s) (story spec format):      │
│   - title, description, acceptance_criteria                   │
│   - type: story                                               │
│   - sections: analysis (PM's breakdown)                       │
│ source: pm_conversation                                       │
│ Task starts in: analysis (already analyzed by PM)             │
└───────────────────────────────────────────────────────────────┘
```

#### PM Story Spec Format

PM agent creates tasks in a **story spec** format — not raw user request but a structured, refined specification:

```
Title: [Clear, actionable title]
Description: [Refined problem statement + context]
Acceptance Criteria:
  - Given [context], when [action], then [result]
  - Given [context], when [action], then [result]
User Impact: [Who benefits, how]
Technical Hints: [If PM identifies relevant tech considerations]
Design Needs: [yes/no + brief if yes — triggers Designer involvement]
Dependencies: [Other task IDs if any]
```

#### Pipeline Stage Flow (Post-MVP)

```
┌─────────┐    ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐    ┌──────┐    ┌──────┐
│  DRAFT  │───→│ ANALYSIS │───→│ PLANNING │───→│  DESIGN   │───→│ IN_PROG  │───→│REVIEW│───→│ TEST │───→ DONE
│ (user)  │    │  (PM)    │    │(Lead Dev)│    │(Designer) │    │  (Dev)   │    │(Rev) │    │ (QA) │
└─────────┘    └──────────┘    └──────────┘    │ OPTIONAL  │    └──────────┘    └──────┘    └──────┘
                                                └───────────┘         ↑              │          │
                                                                      │    REJECT     │          │
                                                                      └──────────────┘          │
                                                                      │         REJECT           │
                                                                      └─────────────────────────┘
                                                                      (max 2 retries → escalation)
```

**Stage responsibilities**:

| Stage | Agent | Actions | Output |
|-------|-------|---------|--------|
| Analysis | PM/BA | Clarify requirements, write story spec, identify design needs | TaskSection: analysis |
| Planning | Lead Dev | Technical analysis, architecture decisions, dev plan, subtask decomposition | TaskSection: plan |
| Design | Designer | UI/UX design via Figma MCP, mockups, approval from user | TaskSection: design_brief + design_assets |
| In Progress | Developer | Implementation, coding, unit tests | TaskSection: dev_report, code changes |
| Review | Code Reviewer | Code quality, security, best practices, approve/reject | TaskSection: review_report |
| Testing | QA | Test execution, verification against AC, approve/reject | TaskSection: test_report |

**Design stage trigger**: Designer stage is CONDITIONAL — only runs if PM flags `design_needs: yes` in the analysis section. If no design needed, pipeline skips directly from Planning → In Progress.

**Reject flow**:
- Code Reviewer rejects → task returns to In Progress (Developer re-works)
- QA rejects → task returns to In Progress (Developer fixes)
- Max 2 retries per rejection source. 3rd fail → pipeline stops, human escalation notification
- Rejection includes: reason, specific issues, suggested fixes (in review_report/test_report section)

#### Three Execution Modes (Project-level setting)

```
┌─ MANUAL MODE ────────────────────────────────────────────────┐
│ Every stage transition requires user action.                  │
│ User manually: assigns agent, triggers run, reviews output,   │
│ approves/rejects, moves to next stage.                        │
│                                                               │
│ Pipeline is just a state machine — no automation.             │
│ This is the MVP behavior.                                     │
└───────────────────────────────────────────────────────────────┘

┌─ SEMI-AUTO MODE ─────────────────────────────────────────────┐
│ Pipeline runs automatically stage by stage.                   │
│ Each stage auto-dispatches the configured agent.              │
│                                                               │
│ PAUSES and waits for user when:                               │
│   - Agent asks a question (any stage)                         │
│   - Code Reviewer or QA rejects (user decides: retry or fix) │
│   - Design approval needed (user reviews mockups)             │
│   - Pipeline stage marked as "approval_required" in config    │
│                                                               │
│ Otherwise: auto-advances to next stage on completion.         │
└───────────────────────────────────────────────────────────────┘

┌─ FULL-AUTO MODE ─────────────────────────────────────────────┐
│ Pipeline runs without user intervention.                      │
│                                                               │
│ PM agent handles decisions autonomously:                      │
│   - Agent question → PM evaluates + auto-answers if confident │
│   - Reviewer reject → PM reviews rejection reason,            │
│     decides: send back to Dev with instructions                │
│   - QA reject → same: PM reviews, instructs Dev               │
│   - Design approval → PM reviews against requirements,        │
│     approves if aligned                                        │
│                                                               │
│ PM becomes the "project manager brain" — reads all context,   │
│ makes judgment calls, keeps pipeline flowing.                  │
│                                                               │
│ Escalation to human ONLY when:                                │
│   - PM is not confident (ambiguous requirement)               │
│   - Max retries exceeded (2 retries)                          │
│   - Budget threshold reached                                  │
│   - PM explicitly flags for human review                      │
└───────────────────────────────────────────────────────────────┘
```

#### Pipeline Configuration (per project)

```json
{
  "execution_mode": "semi_auto",
  "stage_agents": {
    "analysis": { "agent_role_slug": "ba", "auto_dispatch": true },
    "planning": { "agent_role_slug": "lead-dev", "auto_dispatch": true },
    "design": { "agent_role_slug": "designer", "auto_dispatch": true, "approval_required": true },
    "in_progress": { "agent_role_slug": "developer", "auto_dispatch": true },
    "review": { "agent_role_slug": "code-reviewer", "auto_dispatch": true },
    "testing": { "agent_role_slug": "qa", "auto_dispatch": true }
  },
  "approval_gates": ["design", "review", "testing"],
  "max_retries_per_stage": 2,
  "auto_answer_config": {
    "enabled": true,
    "answerer_agent": "ba",
    "confidence_threshold": 0.8
  },
  "design_trigger": "pm_flag",
  "escalation_notify": ["owner", "admin"]
}
```

#### MVP vs Full — Task Creation & Workflow

| Feature | MVP | Full |
|---------|-----|------|
| Manual task creation | ✅ | ✅ |
| PM conversation → task(s) | ❌ | ✅ |
| Manual execution mode | ✅ (only mode) | ✅ |
| Semi-auto mode | ❌ | ✅ |
| Full-auto mode | ❌ | ✅ |
| Designer stage | ❌ | ✅ |
| Auto-reject handling | ❌ | ✅ (PM agent decides) |
| Pipeline config per project | ❌ | ✅ |
| Approval gates | ❌ | ✅ |
| PM auto-answer questions | ❌ | ✅ |

---

## 6. API Endpoints (Flutter ↔ Laravel)

### Auth
```
POST   /api/auth/register          → Register new user
POST   /api/auth/login             → Login, return Sanctum token
POST   /api/auth/logout            → Revoke token
GET    /api/auth/user              → Current user profile
POST   /api/auth/forgot-password   → Send reset email
POST   /api/auth/reset-password    → Reset password
```

### Teams
```
GET    /api/teams                  → List user's teams
POST   /api/teams                  → Create team
GET    /api/teams/{team}           → Team detail
PUT    /api/teams/{team}           → Update team
DELETE /api/teams/{team}           → Delete team (owner only)
GET    /api/teams/{team}/members   → List members
POST   /api/teams/{team}/members   → Invite member
PUT    /api/teams/{team}/members/{id} → Update member role
DELETE /api/teams/{team}/members/{id} → Remove member
GET    /api/teams/{team}/balance   → Get current balance + usage summary
```

### Projects
```
GET    /api/teams/{team}/projects                → List projects
POST   /api/teams/{team}/projects                → Create project
GET    /api/teams/{team}/projects/{project}       → Project detail
PUT    /api/teams/{team}/projects/{project}       → Update project
DELETE /api/teams/{team}/projects/{project}       → Delete project
POST   /api/teams/{team}/projects/{project}/clone-repo → Trigger git clone
GET    /api/teams/{team}/projects/{project}/repo-status → Git repo status
GET    /api/teams/{team}/projects/{project}/ssh-public-key → Get public key for deploy key setup
POST   /api/teams/{team}/projects/{project}/generate-ssh-key → Generate new SSH keypair
```

### Agent Roles
```
GET    /api/teams/{team}/agent-roles              → List roles
POST   /api/teams/{team}/agent-roles              → Create custom role
GET    /api/teams/{team}/agent-roles/{role}        → Role detail
PUT    /api/teams/{team}/agent-roles/{role}        → Update role
DELETE /api/teams/{team}/agent-roles/{role}        → Delete role
```

### Tasks
```
GET    /api/teams/{team}/projects/{project}/tasks          → List tasks (filterable)
POST   /api/teams/{team}/projects/{project}/tasks          → Create task
GET    /api/teams/{team}/projects/{project}/tasks/{task}    → Task detail + sections
PUT    /api/teams/{team}/projects/{project}/tasks/{task}    → Update task
DELETE /api/teams/{team}/projects/{project}/tasks/{task}    → Delete task
GET    /api/teams/{team}/projects/{project}/tasks/{task}/sections → Task sections
POST   /api/teams/{team}/projects/{project}/tasks/{task}/sections → Add section
```

### BA Chat Sessions (MVP)
```
POST   /api/teams/{team}/projects/{project}/ba-sessions         → Start new BA chat session (creates TaskRun with BA role)
GET    /api/teams/{team}/projects/{project}/ba-sessions          → List BA sessions
GET    /api/teams/{team}/projects/{project}/ba-sessions/{run}    → Session detail + messages
POST   /api/teams/{team}/projects/{project}/ba-sessions/{run}/message → Send message (answer/continue)
```
Note: BA sessions are TaskRuns with `agent_role.slug = 'ba'`. Dedicated endpoints provide a chat-centric API surface. Streaming uses the same WebSocket channel (`task-run.{id}`).

### Task Runs (Agent Execution)
```
POST   /api/teams/{team}/projects/{project}/tasks/{task}/runs  → Start new agent run
GET    /api/teams/{team}/projects/{project}/tasks/{task}/runs   → List runs for task
GET    /api/task-runs/{run}                                     → Run detail (flat route, auth-scoped to user's teams)
POST   /api/task-runs/{run}/answer             → Answer agent question
POST   /api/task-runs/{run}/cancel             → Cancel running agent
GET    /api/task-runs/{run}/stream-events      → Replay stream events (paginated, ?after_id=N)
GET    /api/task-runs/{run}/questions           → List questions for run
GET    /api/task-runs/{run}/file-changes        → List changed files
```

### Knowledge / Documents
```
GET    /api/.../projects/{project}/documents       → List project documents
POST   /api/.../projects/{project}/documents       → Create document
GET    /api/.../projects/{project}/documents/{doc}  → Document detail
PUT    /api/.../projects/{project}/documents/{doc}  → Update document
DELETE /api/.../projects/{project}/documents/{doc}  → Delete document
POST   /api/.../projects/{project}/documents/search → Search (query string, semantic post-MVP)
```

### AI Tokens (Admin)
```
GET    /api/teams/{team}/ai-tokens                → List tokens
POST   /api/teams/{team}/ai-tokens                → Add token
PUT    /api/teams/{team}/ai-tokens/{token}         → Update token
DELETE /api/teams/{team}/ai-tokens/{token}         → Delete token
POST   /api/teams/{team}/ai-tokens/{token}/test    → Health check token
```

### Dashboard / Stats
```
GET    /api/teams/{team}/dashboard                 → Stats overview (active runs, tasks, costs)
GET    /api/teams/{team}/usage                     → Usage records (filterable by date, model, project)
```

---

## 7. WebSocket Events (Reverb)

### Channels

| Channel | Format | Auth |
|---------|--------|------|
| `private-task-run.{taskRunId}` | Private | Team member of task's project |
| `private-team.{teamId}` | Private | Team member |

### Events on task-run.{id}

| Event | Payload | When |
|-------|---------|------|
| `.agent.system` | `{type, session_id, model}` | Agent session starts |
| `.agent.assistant` | `{type, role, content[]}` | Agent produces output (text, tool_use) |
| `.agent.result` | `{type, is_error, total_cost_usd, duration_ms, usage}` | Agent run completes |
| `.agent.question` | `{type, question_id, question_text}` | Agent asks a question |
| `.agent.status` | `{status, task_run_id}` | TaskRun status changes |

### Events on team.{id}

| Event | Payload | When |
|-------|---------|------|
| `.run.started` | `{task_run_id, task_id, agent_role}` | Any run starts in team |
| `.run.completed` | `{task_run_id, task_id, cost_usd}` | Any run completes |
| `.run.question` | `{task_run_id, task_id, question_text}` | Any agent asks question |
| `.balance.updated` | `{team_id, new_balance, deducted}` | Balance changes |

---

## 8. Business Rules

### 8.1 Balance & Cost
- Team balance starts at 0. Admin adds credits manually (MVP).
- Before dispatching agent run: check `team.balance >= estimated_min_cost` (configurable, default $0.10).
- After run completes: `team.balance -= actual_cost`. Create TeamUsageRecord.
- If balance < 0 after deduction: allowed (soft limit). Next dispatch blocked.
- `--max-budget-usd` passed to CLI agent as hard stop per run.

### 8.2 Model Pricing
```php
// config/model-pricing.php
'claude-opus-4-6'    => ['input' => 5.00,  'output' => 25.00],  // per million tokens
'claude-sonnet-4-6'  => ['input' => 3.00,  'output' => 15.00],
'claude-haiku-4-5'   => ['input' => 0.80,  'output' => 4.00],
'gpt-5.4'            => ['input' => 6.00,  'output' => 18.00],   // full scope
'gemini-3.1-pro'     => ['input' => 3.00,  'output' => 12.00],   // full scope
// ... more models — NOTE: prices are placeholders, move to DB (Filament-editable) for production
```

Cost calculation: `(input_tokens / 1_000_000 * input_price) + (output_tokens / 1_000_000 * output_price)`

### 8.3 Concurrency
- Max concurrent agent runs per project: configurable (default 3)
- Max concurrent runs per team: configurable (default 10)
- Same task: max 1 active run (prevent duplicate execution)

### 8.4 Container Lifecycle Timings
```php
// config/docker.php
'warm_timeout'      => 300,    // seconds (5 min) — container stays alive after question
'session_max_age'   => 86400,  // seconds (24h) — session volume cleaned up after dead
'idle_timeout'      => 300,    // seconds — container killed if no activity (suspended during waiting_for_input)
'max_run_duration'  => 3600,   // seconds (1h) — hard wall-clock limit per run
```
Note: `idle_timeout` is suspended when TaskRun status is `waiting_for_input`. It only applies to active execution with no output.

### 8.5 Agent Role Permissions
| Role | Task CRUD | Doc CRUD | Knowledge | Run Agents | Admin |
|------|-----------|----------|-----------|------------|-------|
| Owner | ✅ | ✅ | ✅ | ✅ | ✅ |
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| Member | ✅ | ✅ | Read | ✅ | ❌ |
| Viewer | Read | Read | Read | ❌ | ❌ |

---

## 9. Flutter App Screens

### 9.1 Auth Flow
- **Login**: Email + password. Social login (Google, GitHub) post-MVP.
- **Register**: Name, email, password.
- **Forgot Password**: Email input → reset link.

### 9.2 Team Selection
- List of user's teams.
- Create new team.
- Switch between teams (persistent selection).

### 9.3 Dashboard (per team)
- Active agent runs (live status badges)
- Recent completed runs (task title, agent, cost, duration)
- Team stats: total tasks, runs today, costs this month, balance
- Quick actions: new task, new project

### 9.4 Projects
- **List**: Grid/list of projects with name, repo status, task counts
- **Detail**: Project info, settings, git status, recent tasks
- **Create**: Name, description, repository URL, SSH key setup, tech stack, default branch
- **Settings**: Edit project config, manage SSH key

### 9.5 Tasks
- **List**: Filterable by status, priority, type. Kanban view (post-MVP).
- **Detail**: Title, description, acceptance criteria, sections (analysis, plan, reports), run history, cost
- **Create**: Title, description, acceptance criteria, type, priority, assign agent role
- **Sections view**: Tabs for analysis, plan, dev report, review report, notes

### 9.6 Agent Run (Critical Screen)
- **Start run**: Select agent role (or use assigned), confirm
- **Live streaming terminal**:
  - Real-time NDJSON output rendered as styled text (WebSocket)
  - Auto-scroll to bottom, manual scroll stops auto-scroll
  - System messages (gray), assistant text (white), tool use (blue), errors (red)
  - Questions highlighted (amber, pulse animation)
- **Question panel**: Shows unanswered questions, text input to answer
- **Run info sidebar**: Agent role, model, status badge, elapsed time, cost accumulating
- **File changes panel**: List of modified files
- **Cost breakdown**: Input/output tokens, model, total cost

### 9.7 BA Chat (Continuous Session)
- Chat UI: Messages from user (right) and BA agent (left, streaming)
- User types message → sent as new prompt to BA agent run
- BA responds (streaming) → may ask clarifying questions
- Session persists across messages (--resume)
- When BA creates a task → shown in chat as structured card
- History of chat messages (StreamEvent records)

### 9.8 Settings
- Profile (name, email, avatar)
- Team settings (name, members)
- Notification preferences (post-MVP)

### 9.9 State Management (Flutter)
- **Riverpod** for state management (code-gen friendly, lighter than Bloc, idiomatic)
- WebSocket service: singleton, auto-reconnect with exponential backoff, event dedup by ID
- Auth state: Sanctum token storage (secure storage on mobile, localStorage on web)
- Team context: globally accessible current team

---

## 10. Filament Admin Panel

### Resources
- **AgentRoleResource**: CRUD with system_prompt textarea, cli_backend select, model select, backend_config JSON editor, tool_permissions
- **AiTokenResource**: CRUD with provider select, auth_type select, encrypted credentials, status badge, rotation algorithm, health check action
- **TeamResource**: List teams, view balance, view members, add credits action
- **ProjectResource**: List projects, view settings, repo status
- **TaskResource**: List tasks (read-only overview)
- **TaskRunResource**: List runs, view status, cost, stream events link

### Custom Pages
- **Dashboard**: System stats (total teams, projects, runs today, total costs)
- **Docker Hosts**: View configured hosts, container counts per host

---

## 11. Scheduled Commands

| Command | Schedule | Purpose |
|---------|----------|---------|
| `containers:cleanup-warm` | Every 1 min | Stop + remove containers past warm_until. Source of truth: Redis key `warm:{task_run_id}`. Also updates TaskRun DB record. |
| `sessions:cleanup` | Every 30 min | Delete session volumes older than 24h. Mark associated TaskRuns as `timed_out`. |
| `tokens:health-check` | Every 30 min | Verify AI token validity via lightweight API call. Mark expired/invalid as `inactive`. |
| `runs:detect-orphans` | Every 15 min | Find TaskRuns with `status=running` and `started_at < now - max_run_duration`. Action: kill container, mark `failed` with error "wall-clock timeout", broadcast `.agent.status` event. |
| `usage:flush` | Hourly | Aggregate usage records (post-MVP: flush to Stripe) |

---

## 12. MVP vs Full Scope

### MVP (Build First)
| Feature | Details |
|---------|---------|
| Auth + Teams | Register, login, create team, invite members, roles |
| Projects | Create, connect git repo (SSH), clone, settings |
| Agent Roles | Default 5 roles seeded per team (cloned from system), full CRUD |
| AI Tokens | Add/manage API keys per team, multi-account rotation |
| Tasks | CRUD, state machine, sections (analysis, plan, reports) |
| CLI Backend | Claude Code only (Anthropic models) |
| Single Agent Execution | Pick role → run on task → Docker → stream → Q&A |
| Container Lifecycle | Warm 5min → Dead (session resume via --resume) |
| Real-time Streaming | WebSocket events → Flutter terminal view |
| BA Chat | Continuous session, clarification loop |
| Agent Q&A | Detect question → show in UI → answer → resume |
| Session Persistence | Claude Code --resume, OpenCode --session |
| Knowledge Docs | Project documents CRUD, MCP read/write |
| Balance Tracking | Team credits, cost per run, usage records |
| Git Integration | Clone, feature branch per task, SSH key |
| Flutter App | Web + Mobile, all screens above |
| Filament Admin | Agent roles, tokens, teams |
| Events | WebSocket broadcast (no push notifications) |

### Post-MVP (Build Later)
| Feature | Details |
|---------|---------|
| PM Conversation → Task | Chat with PM agent — any input (requests, bullet points, notes) → story spec tasks |
| Semi-Auto Mode | Pipeline auto-advances, pauses on questions/rejects/approvals |
| Full-Auto Mode | PM agent handles all decisions, retries, approvals autonomously |
| Pipeline Orchestration | Analysis → Planning → Design → Dev → Review → QA auto-flow |
| Approval Gates | Manual approval at configured pipeline stages |
| PM Auto-Answer | PM agent answers other agents' questions if confident |
| Retry Loops | Reviewer/QA reject → Developer retry (max 2), PM manages in full-auto |
| Designer Agent | Figma MCP, atomic design, triggered by PM's design_needed flag |
| Category Decomposition | Task split by category → optimal model per category |
| Parallel Wave Execution | GSD-style dependency DAG → parallel sub-tasks |
| Model Consensus | MCO-style parallel fan-out → scoring |
| OpenCode Backend | OpenCode CLI support for GPT, Gemini, and other non-Anthropic models |
| Model-Specific Prompts | Per-role prompt variants for Claude/GPT/Gemini |
| Semantic Search | pgvector embeddings, cosine similarity |
| Stripe Billing | Credit purchase, auto-reload, pay-as-go |
| External Integrations | Jira, ClickUp bidirectional sync |
| Push Notifications | FCM (mobile), email notifications |
| Social Login | Google, GitHub OAuth |
| Kanban Board | Drag-and-drop task management |
| Sprint Management | Sprint CRUD, velocity tracking |
| CI/CD Integration | Headless mode, GitHub Actions/GitLab CI |
| Agent Customization | System→Team→Project scope hierarchy, prompt_append chain, custom agents |
| Workflow Customization | User-defined pipeline stage→agent mapping, custom approval gates |
| Docker Security Hardening | Non-root user, read-only rootfs, pids-limit, seccomp, network isolation |
| Dashboard Charts | Cost trends, usage analytics, Chart.js |

---

## 13. Implementation Phases (for LLM Agent Execution)

### Phase 0: Pre-Implementation Validation (CRITICAL)
Before writing any code, validate these assumptions:
1. **Session resume test**: Build a throwaway Docker container from `~/Code/kodizm.com/docker/`, run Claude Code with a multi-turn conversation including MCP tool calls and file edits, stop container, start new container with same session volume, verify `--resume {session_id}` works correctly. Document results.
2. **Docker image verification**: Confirm existing universal image at `~/Code/kodizm.com/docker/` builds and runs correctly. Test `claude` CLI is accessible as `agent` user. Measure image size and first-run latency.
3. **NDJSON streaming test**: Run `claude -p "test" --output-format stream-json` inside container, capture output, verify event types match spec (system, assistant, result, elicitation).

### Phase 1: Foundation (Laravel Setup)
- Fresh Laravel 12 project
- PostgreSQL + Redis configuration
- Filament 5 installation + team-scoped panel
- Auth: Fortify (web/admin) + Sanctum (API for Flutter)
- User, Team, TeamMember models + migrations + factories + policies
- Team role system (Owner/Admin/Member/Viewer)
- API auth middleware (Sanctum)
- Base API structure (routes, controllers, resources)
- **Tests**: Auth flow, team CRUD, member management, role enforcement

### Phase 2: Project & Agent Foundation
- Project model + migration + factory + policy
- AgentRole model + migration + factory + default seeder (5 roles)
- AiToken model + migration + factory (encrypted credentials)
- CliBackend enum + strategy pattern (ClaudeCodeStrategy only in MVP, OpenCodeStrategy post-MVP)
- TokenRotationService (fill-first, round-robin, random — MVP: Anthropic tokens only)
- Config files: cli-backends.php, ai-tokens.php, model-pricing.php
- Filament resources: AgentRole, AiToken, Project
- API endpoints: projects CRUD, agent-roles CRUD, ai-tokens CRUD
- **Tests**: Strategy pattern, token rotation, model pricing, CRUD APIs

### Phase 3: Task Management
- Task model + migration + factory + policy
- TaskSection model + migration + factory
- TaskStatus enum with allowedTransitions() state machine
- TaskSectionType enum
- Task CRUD API endpoints
- TaskSection CRUD API endpoints
- Filament: Task resource (read-only overview)
- **Tests**: Task state transitions, section CRUD, API validation

### Phase 4: Container Infrastructure
- Docker config: docker.php, docker-hosts.php
- ContainerLifecycle interface
- ClaudeCodeContainer implementation (sleep infinity + docker exec)
- Container warm→dead lifecycle (simplified 2-phase)
- ContainerManager (factory/resolver)
- Config generators: ClaudeCodeConfigGenerator, OpenCodeConfigGenerator
- Session volume management
- Container cleanup commands (warm, cold, sessions)
- **Tests**: Container lifecycle (mocked Docker), config generation, cleanup

### Phase 5: Agent Execution Engine
- AgentRunner service (core orchestration)
- ExecuteAgentTask job (queue dispatch)
- NDJSON streaming + event normalization per backend
- StreamEvent model + persistence
- AgentQuestion model + Q&A flow
- Cost recording (TeamUsageRecord, balance deduction)
- Event broadcasting (Reverb) on task-run channels
- Container lifecycle integration (warm/cold/resume)
- MCP server setup (basic tools: report-progress, get-task, get-project-info)
- Stream events replay API endpoint
- **Tests**: Full execution pipeline (mocked Docker + CLI), event normalization, Q&A flow, cost recording

### Phase 6: Knowledge System & MCP Expansion
- ProjectDocument model + migration + factory
- Document CRUD API + MCP tools (create-document, update-document, search-documents)
- Task section MCP tools (create-task-section, update-task-section)
- Task MCP tools (create-task, update-task — for BA/Lead Dev)
- Knowledge search (basic text search MVP, pgvector post-MVP)
- **Tests**: Document CRUD, MCP tool execution, search

### Phase 7: Git Integration
- SSH key generation + encrypted storage on Project
- Git clone service (clone repo to workspace)
- Branch creation service (feature/task-{id})
- Remote Docker host support (SCP sync)
- Git status tracking on Project
- **Tests**: Clone, branch, SSH key management

### Phase 8: Flutter App
- Flutter project setup (web + mobile targets)
- Auth screens (login, register, forgot password)
- State management setup (Riverpod/Bloc)
- WebSocket service (Reverb/Echo client)
- API client (Dio/http + Sanctum token)
- Team selection + creation screens
- Dashboard screen (stats, active runs)
- Project list + detail + create screens
- Task list + detail + create screens
- **Agent Run screen** (critical):
  - Terminal streaming view (WebSocket → styled text)
  - Question panel + answer input
  - Run info + cost breakdown
  - File changes panel
- BA Chat screen (continuous session)
- Settings screens
- Responsive layout (web + mobile)
- **Tests**: Widget tests, integration tests for critical flows

### Phase 9: Polish & Integration
- End-to-end testing: user → team → project → task → run → stream → Q&A → done
- Balance tracking verification
- Error handling (container failures, token exhaustion, network issues)
- Loading states, empty states, error states in Flutter
- Filament admin refinements
- Performance optimization (pagination, lazy loading)
- Documentation (CLAUDE.md, API docs)

---

## 14. Agent Prompts (Reference Sketches)

### Business Analyst (BA)
```
You are a Business Analyst for the {project_name} project.
Your job: understand what the user wants, ask clarifying questions, and produce a structured task.

BEHAVIOR:
- Listen carefully to the user's request
- Explore the codebase to understand current state (use your tools)
- Ask questions if anything is unclear — never assume
- Search the web for best practices if helpful
- When ready, create a structured task using the create-task MCP tool

OUTPUT (via MCP create-task):
- Title: clear, action-oriented
- Description: detailed explanation
- Acceptance criteria: Given/When/Then format, testable
- Type: story/task/bug/spike
- Priority: p0-p3
- Estimated complexity: xs/s/m/l/xl

Also write an analysis section (via create-task-section, type: analysis) covering:
- Current state (what exists in the codebase)
- Proposed change (what needs to change)
- Impact analysis (what other parts are affected)
- Open questions (if any remain)
```

### Lead Developer
```
You are a Lead Developer for the {project_name} project.
Your job: analyze the task technically and create an implementation plan.

INPUT: Read the task details and analysis section.

BEHAVIOR:
- Deeply analyze the codebase — understand architecture, patterns, dependencies
- Identify all affected files and modules
- Design the implementation approach
- Break complex tasks into sub-tasks if needed
- Assess risks and flag concerns

OUTPUT (via MCP create-task-section, type: plan):
- Implementation steps (ordered, with file references)
- Affected files list
- Dependencies between steps
- Risk assessment (severity + mitigation)
- Estimated effort per step
- If too complex: create sub-tasks via MCP create-task
```

### Developer
```
You are a Developer for the {project_name} project.
Your job: implement the task according to the plan.

INPUT: Read the task, analysis, and plan sections.

BEHAVIOR:
- Create feature branch: feature/task-{task_id}
- Follow the plan step by step
- Write clean, tested code following project conventions
- Commit after each logical unit
- If stuck, ask a question — don't guess
- Read and follow the project's CLAUDE.md conventions

OUTPUT:
- Code changes on feature branch
- Dev report (via MCP create-task-section, type: dev_report):
  - What was implemented
  - Files changed
  - Tests written
  - Any deviations from plan and why
```

### Code Reviewer
```
You are a Code Reviewer for the {project_name} project.
Your job: review the code changes and produce a quality report.

INPUT: Read the task, plan, and dev report. Examine the code diff on the task branch.

BEHAVIOR:
- Check code quality (SOLID, DRY, patterns)
- Check security (OWASP top 10)
- Verify acceptance criteria are met
- Assess test coverage
- Look for bugs and edge cases

OUTPUT (via MCP create-task-section, type: review_report):
- Findings list: CRITICAL / IMPORTANT / MINOR severity
- For each finding: file, line, description, suggested fix
- Verdict: APPROVE or REQUEST_CHANGES
- If REQUEST_CHANGES: specific items that must be fixed
```

### QA Engineer
```
You are a QA Engineer for the {project_name} project.
Your job: verify the implementation meets acceptance criteria.

INPUT: Read the task (especially acceptance criteria), plan, and dev report.

BEHAVIOR:
- Generate test cases from acceptance criteria
- Run existing test suite
- Write new tests for uncovered scenarios
- Identify edge cases
- Verify no regressions

OUTPUT (via MCP create-task-section, type: test_report):
- Test cases: pass/fail status
- Coverage assessment
- Bugs found (structured: steps to reproduce, expected, actual)
- Verdict: PASS or FAIL
```

---

## 15. Configuration Files Reference

```
config/
├── ai-tokens.php           # Provider health endpoints, format patterns, cooldown settings
├── billing.php              # Plan tiers (post-MVP), meter event name
├── cli-backends.php         # Binary paths, default models per CLI backend
├── docker.php               # Image name, resource limits, session config, security flags
├── docker-hosts.php         # Docker host configs (local, remote)
├── model-pricing.php        # Per-model input/output cost per million tokens
├── orchestration.php        # Pipeline defaults (post-MVP)
```

---

## 16. Security Considerations

### Application Security
- API keys encrypted at rest (Laravel encrypted cast)
- SSH private keys encrypted at rest
- MCP tokens: short-lived, scoped to single TaskRun
- Sanctum tokens: team-scoped API access
- Rate limiting on API endpoints
- CORS configuration for Flutter web
- No secrets in git (SSH keys, API keys stored in DB encrypted)
- CSRF protection on Filament (session-based)

### Docker Container Security
- **Non-root execution**: Containers run as unprivileged `agent` user (UID 1001) via `gosu` in entrypoint. Already implemented in existing Docker image (`~/Code/kodizm.com/docker/`). Root is only used briefly at container start (PostgreSQL, Redis, PHP version switch), then drops to `agent` user.
- `--security-opt no-new-privileges` — prevent privilege escalation inside container
- `--cap-drop ALL` — drop all Linux capabilities
- `--read-only` root filesystem (writable: `/workspace`, `/tmp`, session volume mounts only)
- Resource limits: memory (4GB default), CPU (2 cores default), configurable per DockerHost
- `--network=none` option for fully isolated execution (no internet — post-MVP, some agents need git push)
- `--pids-limit 256` — prevent fork bombs
- No Docker socket mount — containers cannot control Docker daemon
- `--dangerously-skip-permissions` for Claude Code (trusted execution within sandboxed container)
- Session volumes scoped per TaskRun — no cross-task data leakage
- Temp file cleanup on container removal

### Docker Security Roadmap
| Feature | MVP | Full |
|---------|-----|------|
| Non-root user in container | ✅ (`agent` user, UID 1001 — already in image) | ✅ |
| `--cap-drop ALL` | ✅ | ✅ |
| `--security-opt no-new-privileges` | ✅ | ✅ |
| Read-only root filesystem | ❌ | ✅ |
| `--pids-limit` | ❌ | ✅ |
| `--network=none` option | ❌ | ✅ (configurable per agent role) |
| Seccomp profile | ❌ | ✅ (custom profile) |
| AppArmor/SELinux profile | ❌ | ✅ (production hardening) |

---

## Appendix A: Competitive Positioning

**Market**: $8.5B AI code assistant market (2026), 24% CAGR → $47.3B by 2034.

**Gap exploited**: No commercial product combines multi-agent + multi-model + Docker isolation + SDLC pipeline + mobile + task management + credit billing.

**Closest competitor**: Augment Intent (BYOA orchestration) — but desktop-only, no Docker isolation, no mobile, no task management.

## Appendix B: Previous Research References

- Original vision: ~/Downloads/kod.txt
- Previous v2 PRD: ~/.claude/projects/-Users-anilcan-Code-kodizm-com/prd/kodizm/draft/kodizm.md
- Previous v2 plans (Phase 0-7): ~/Code/kodizm.com/.ac/plans/
- Architecture reference: ~/Code/kodizm.com/CLAUDE.local.md
- Agent patterns: oh-my-openagent (Sisyphus delegation), get-shit-done (wave parallelism), openhands (event sourcing)
- Model benchmarks: ~/Code/kodizm.com/docs/clis/model-benchmarks.md
- CLI internals: ~/Code/kodizm.com/docs/clis/ (claude-code, opencode, openagents, get-shit-done)
