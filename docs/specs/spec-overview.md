# Kodizm — Spec Overview

> Index of all specs, dependency graph, and build order.
> Read `project-overview.md` first for context.

**Boilerplate**: magic-starter (Laravel + Flutter) provides auth, teams, profiles, notifications. Spec 01 configures this; Spec 11 leverages Flutter screens.

## Spec Structure

Each spec is a **domain** (e.g., "Platform Core", "Task Management"). Each spec contains:
- `overview.md` — What this domain covers, models, enums, rules, dependencies
- `wave-N-*.md` — Independently buildable chunk with full deliverables

**Wave = atomic unit of work.** An LLM agent should be able to pick up a wave file, read it + the spec overview + project overview, and implement everything in that wave without ambiguity. Each wave lists its dependencies (which waves must be complete first).

## All Specs

### MVP Specs (Build Order)

| # | Spec | Waves | Dependencies | Description |
|---|------|-------|--------------|-------------|
| 01 | Platform Core | 2 | — | Configure magic-starter, extend Team/User with Kodizm fields |
| 02 | Project Management | 2 | 01 | Project CRUD, settings, SSH key generation |
| 03 | Agent System | 3 | 01 | AgentRole, AiToken, CLI backend strategy |
| 04 | Container Infrastructure | 2 | 03 | Docker container manager, lifecycle, sessions |
| 05 | Task Management | 2 | 02 | Task CRUD, state machine, sections |
| 06 | Agent Execution | 4 | 03, 04, 05 | AgentRunner, streaming, Q&A, cost recording |
| 07 | Real-time Communication | 2 | 01 | Reverb setup, broadcasting, event replay |
| 08 | Knowledge System | 2 | 02, 06 | Project documents, MCP server + tools |
| 09 | Billing & Credits | 2 | 01, 06 | Team balance, cost tracking, usage API |
| 10 | Git Integration | 1 | 02, 04 | Repo clone, branch creation, SSH |
| 11 | Flutter App | 6 | 01-10 | All screens, state management, WebSocket (leverages magic_starter screens for auth/teams/profile) |
| 12 | Filament Admin | 2 | 01, 03, 09 | Admin resources and pages |

### Post-MVP Specs

| # | Spec | Dependencies | Description |
|---|------|--------------|-------------|
| 13 | Pipeline Orchestration | 06, 05 | Multi-agent pipeline, approval gates, retry loops |
| 14 | OpenCode Backend | 03, 06 | OpenCode CLI strategy, NDJSON normalization |
| 15 | Designer Agent | 13 | Figma MCP, atomic design, design approval |
| 16 | External Integrations | 05 | Jira/ClickUp sync, notifications |
| 17 | Multi-Model Routing | 14 | Category decomposition, parallel waves, consensus |

## Dependency Graph

```
01-Platform Core
├── 02-Project Management
│   ├── 05-Task Management
│   │   └── 06-Agent Execution ← (also needs 03, 04)
│   │       ├── 08-Knowledge System (MCP server)
│   │       └── 09-Billing & Credits
│   └── 10-Git Integration ← (also needs 04)
├── 03-Agent System
│   ├── 04-Container Infrastructure
│   └── 06-Agent Execution
├── 07-Real-time Communication (independent after 01)
└── 12-Filament Admin ← (also needs 03, 09)

11-Flutter App ← (needs ALL of 01-10)
```

## Parallelization Opportunities

These specs/waves can be built in parallel:

| Parallel Group | Specs | Prerequisite |
|----------------|-------|--------------|
| Group A | 02 + 03 + 07 | 01 complete |
| Group B | 04 + 05 | 02 + 03 complete |
| Group C | 10 + 06-wave-1 | 04 + 05 complete |
| Group D | 08 + 09 | 06 complete |
| Group E | 11-wave-1 through 11-wave-3 | 01-05 complete |
| Group F | 12 | 03 + 09 complete |

## Shared Enums (across all specs)

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

// Execution
TaskRunStatus: pending, running, waiting_for_input, completed, failed, cancelled, timed_out

// Stream
StreamEventType: system, assistant, result, question, auto_answer, file_change, error

// Knowledge
DocumentCategory: architecture, api, guide, convention, runbook, agent_output, other

// Agent Scope
AgentScope: system, team, project

// Project
ExecutionMode: manual, semi_auto, full_auto

// Pipeline (post-MVP)
PipelineExecutionStatus: pending, running, awaiting_approval, completed, failed, cancelled
```

## Shared Database Indexes

```
tasks:              (project_id, status), (parent_task_id)
task_runs:          (task_id, status), (status, started_at), (session_id)
stream_events:      (task_run_id, occurred_at), (task_run_id, is_question)
agent_questions:    (task_run_id, answered_at)
team_usage_records: (team_id, recorded_at), (team_id, period)
project_documents:  (project_id, category)
ai_tokens:          (team_id, provider, status)
agent_roles:        (team_id, scope), (parent_id)
```

## Business Rules (Global)

### Balance & Cost
- Team balance starts at 0. Admin adds credits manually (MVP).
- Before dispatch: `team.balance >= estimated_min_cost` (default $0.10).
- After run: `team.balance -= actual_cost`. Create TeamUsageRecord.
- `--max-budget-usd` passed to CLI as hard stop per run.

### Concurrency
- Max concurrent runs per project: 3 (configurable)
- Max concurrent runs per team: 10 (configurable)
- Same task: max 1 active run

### Container Lifecycle
- Warm timeout: 300s (container alive after question)
- Session max age: 86400s (24h — volume cleaned up)
- Idle timeout: 300s (suspended during waiting_for_input)
- Max run duration: 3600s (1h wall-clock hard limit)

### Team Role Permissions
| Role | Task CRUD | Doc CRUD | Knowledge | Run Agents | Admin |
|------|-----------|----------|-----------|------------|-------|
| Owner | ✅ | ✅ | ✅ | ✅ | ✅ |
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ |
| Member | ✅ | ✅ | Read | ✅ | ❌ |
| Viewer | Read | Read | Read | ❌ | ❌ |
