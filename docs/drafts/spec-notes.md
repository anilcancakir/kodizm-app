# Kodizm — Spec Breakdown Plan

> 20 karar kesinleşti, tüm açık sorular kapatıldı. Artık spec'lere ayırıyoruz.

---

## Spec Dosya Yapısı

Her spec bağımsız bir domain'i kapsar. Full system + MVP scope her spec'te ayrı belirtilir.

```
docs/specs/
├── 01-platform-core.md          # Auth, Team, User, Roles & Permissions
├── 02-project-management.md     # Project CRUD, Git integration, SSH keys, Settings
├── 03-agent-system.md           # Agent roles, config, CLI backends, prompts, MCP tools
├── 04-container-infrastructure.md # Docker execution, lifecycle (warm/cold/resume), universal image
├── 05-task-management.md        # Task CRUD, state machine, structured sections, artifacts
├── 06-agent-execution.md        # AgentRunner, streaming, NDJSON, event normalization
├── 07-realtime-communication.md # WebSocket (Reverb), events, Flutter streaming
├── 08-knowledge-system.md       # Project/team docs, pgvector, semantic search, MCP tools
├── 09-billing-credits.md        # Team balance, credit tracking, cost calculation, (post-MVP: Stripe)
├── 10-git-integration.md        # Repo clone, branch strategy, SSH, remote Docker host code sync
├── 11-flutter-app.md            # Web + Mobile app, screens, navigation, state management
├── 12-filament-admin.md         # Admin panel: agent roles, tokens, teams, system config
├── 13-pipeline-orchestration.md # (POST-MVP) Multi-agent pipeline, approval gates, retry loops
├── 14-designer-agent.md         # (POST-MVP) Figma MCP, atomic design, design.md
├── 15-external-integrations.md  # (POST-MVP) Jira, ClickUp sync, notification channels
├── 16-multi-model-routing.md    # (POST-MVP) Category decomposition, parallel waves, consensus
```

---

## Spec İçerik Template'i

Her spec aşağıdaki yapıda olacak:

```markdown
# Spec: [Domain Name]

## Overview
One paragraph description.

## MVP Scope
What's in MVP (must-have).

## Full Scope
What's in full version (post-MVP additions).

## Data Models
Entity definitions, fields, relationships, enums.

## API Endpoints
REST API for Flutter consumption.

## Business Rules
Core logic, validation, state transitions.

## UI/UX Requirements
Flutter screens, Filament pages (where applicable).

## Events & Broadcasting
WebSocket events, internal events.

## Dependencies
Which other specs this depends on.

## Acceptance Criteria
Testable criteria (Given/When/Then).
```

---

## Spec İçerik Özeti (Her Spec'te Ne Olacak)

### 01: Platform Core
- User registration/login (email + social)
- Team CRUD (create, invite members, manage roles)
- Team roles: Owner, Admin, Member, Viewer
- Multi-tenancy (all data scoped to team)
- Auth: Laravel Fortify (web) + Passport/Sanctum (API for Flutter)
- **MVP**: Full (temel altyapı)

### 02: Project Management
- Project CRUD (create new, import existing git repo)
- Project settings: default branch, tech stack, auto_mode config
- Git repo connection: SSH key management (encrypted), clone
- Project ↔ Team relationship
- Supported tech stacks (Laravel+Flutter, Laravel+Blade, etc.)
- **MVP**: Create project, connect git repo, basic settings

### 03: Agent System
- AgentRole model: name, slug, system_prompt, cli_backend, model, tool_permissions, backend_config
- CLI backends: ClaudeCode, OpenCode (strategy pattern)
- Agent prompt management: system_prompt stored in DB, injected via CLI flags
- Per-agent MCP tool access configuration
- Token/auth management: subscription + API key, multi-account, rotation (fill-first/round-robin)
- **MVP**: CRUD agent roles, configure prompts, assign CLI backend + model
- **Post-MVP**: Model-specific prompt variants, category routing

### 04: Container Infrastructure
- Universal Docker image (claude + opencode pre-installed)
- Container lifecycle: start → execute → warm (120s) → cold (90min) → dead (24h cleanup)
- Session volume persistence (Claude Code sessions, OpenCode sessions)
- Config injection: CLAUDE.md, settings.json, env vars → mount into container
- Remote Docker host support (not just local)
- Security: --dangerously-skip-permissions, resource limits (memory, CPU)
- **MVP**: Full (critical path)

### 05: Task Management
- Task CRUD: title, description, acceptance_criteria, type, priority, estimation
- Task state machine: Draft → Analysis → Planning → InProgress → Review → Testing → Done/Failed
- Structured sections per task: analysis, plan, dev_report, review_report, design_needs, documents, comments, notes
- Task artifacts (agent-produced documents attached to task)
- Sprint assignment (basic)
- **MVP**: Basic CRUD + state machine + agent notes/artifacts
- **Post-MVP**: Jira/ClickUp sync, kanban board, sprint management

### 06: Agent Execution
- AgentRunner: resolve strategy → resolve token → build command → execute in container
- NDJSON streaming: CLI output → normalize per backend → broadcast events
- Question/elicitation capture: detect question event → pause → wait for user answer → resume
- Cost recording: token usage + model pricing → deduct from team balance
- Session management: capture session_id, resume support
- **MVP**: Full single-agent execution (critical path)

### 07: Real-time Communication
- Laravel Reverb (WebSocket server)
- Event types: agent.system, agent.assistant, agent.result, agent.question
- Private channels: task-run.{id}
- Flutter WebSocket client (Echo equivalent)
- Event replay API (catch-up for reconnections)
- **MVP**: Full (critical for streaming UX)

### 08: Knowledge System
- ProjectDocument model: title, content, category, embedding (pgvector)
- Team-level knowledge entries
- Semantic search (cosine similarity)
- MCP tools: search-knowledge, create-document, update-document
- Agent read/write access to project docs
- **MVP**: Basic document storage + MCP read/write
- **Post-MVP**: pgvector embeddings, semantic search

### 09: Billing & Credits
- Team balance (credits field)
- Per-run cost calculation: model × tokens × pricing
- Cost deduction after each agent run
- Balance check before dispatch (block if insufficient)
- Usage records: team, task_run, model, tokens, cost
- **MVP**: Balance tracking + cost recording (no payment integration)
- **Post-MVP**: Stripe integration, auto-reload, pay-as-go, usage dashboards

### 10: Git Integration
- Repo clone into Docker container workspace
- Branch creation per task: feature/task-{id} from default branch
- SSH key management (encrypted, per-project)
- Remote Docker host: code sync via SCP or git clone inside container
- Git operations tracked (commits, diffs)
- **MVP**: Clone + branch + basic git ops
- **Post-MVP**: Auto-merge, PR creation, GitHub/GitLab integration

### 11: Flutter App
- Auth screens (login, register)
- Team selection/creation
- Project list + detail
- Task list + detail + create
- Agent run: start, real-time streaming terminal, Q&A
- Chat with BA (continuous session)
- Dashboard (stats, active runs)
- Settings
- Responsive: web + mobile layout
- **MVP**: All above (Flutter is the primary UI)

### 12: Filament Admin
- AgentRole CRUD (system prompts, config)
- AI Token management (add/remove API keys, rotation config)
- Team management (billing, limits)
- Docker host configuration
- System stats & monitoring
- **MVP**: AgentRole + Token management + basic team admin

### 13: Pipeline Orchestration (POST-MVP)
- Stage → agent role mapping (project config)
- Auto/manual/hybrid pipeline modes
- Approval gates
- Stage context passing (shared worktree + artifacts)
- Retry loops (max 2 → escalation)
- PipelineStageRun state machine

### 14: Designer Agent (POST-MVP)
- Figma MCP integration
- Atomic design methodology
- Project design.md (design system)
- Multiple variant generation
- Design approval flow

### 15: External Integrations (POST-MVP)
- Jira sync (bidirectional)
- ClickUp sync
- Push notifications (FCM, APNs)
- Email notifications
- Slack integration
- GitHub/GitLab webhook integration

### 16: Multi-Model Routing (POST-MVP)
- Category-based task decomposition
- Category → optimal model mapping
- Wave-based parallel execution (GSD pattern)
- Model consensus scoring (MCO pattern)
- Model-specific prompt variants per agent role
