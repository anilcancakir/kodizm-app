# Kodizm — Multi-Agent SDLC Orchestrator

Kodizm automates software development by orchestrating AI agents inside isolated Docker containers. A single main agent executes tasks end-to-end using composable skills, while the platform handles provisioning, streaming, cost tracking, and git isolation.

Built with a **Laravel API** (orchestration engine) and a **Flutter App** (web & mobile UI).

---

## Mission

Turn AI coding assistants (Claude Code) from single-user CLI tools into a managed, multi-agent development platform. Teams define agent configurations, assign work, monitor execution in real-time, and track costs, without giving up control over quality, security, or architecture.

---

## Core Loop

1. **Create a task** — describe the work, assign priority, set budget
2. **Agent executes** — platform provisions the container, injects context + skills, launches the AI CLI, streams events in real-time
3. **Human stays in the loop** — agents pause and ask questions when blocked, users can also chat interactively at any time
4. **Platform handles the rest** — containers, credentials, cost tracking, memory persistence, git isolation, tool access

---

## Key Features

### Agent Architecture (v2)

Three system agents, each with a distinct mission:

- **main-agent** — full pipeline execution (analysis, planning, implementation) and interactive conversations. Uses composable skills for each phase. System prompt: `prompts/system/main-agent.blade.php`
- **tech-profiler** — detects runtimes, frameworks, and services in a repository. Persists tech stack via MCP tools. System prompt: `prompts/system/tech-analyzer.blade.php`
- **codebase-analyser** — generates CLAUDE.md project instructions and `.claude/rules/` conventions from repository analysis. System prompt: `prompts/system/codebase-profiler.blade.php`

Six composable skills define workflows and conventions:
- **task-analysis**, **dev-planning**, **dev-execute** — pipeline phase skills
- **my-coding**, **my-language**, **git-master** — cross-cutting convention skills

Agent roles support 3-tier scoping (system / team / project) with inheritance. Legacy multi-agent roles (product-manager, lead-developer, developer, code-reviewer) are soft-deleted. The main-agent runs pipeline tasks end-to-end, using Claude Code's native subagent system for delegation internally.

### Persistent Containers

One Docker container per project (1:1 mapping), reused across all sessions. Containers are fully platform-managed: provisioned, bootstrapped, health-checked, and reaped automatically.

The universal agent image includes:

- 9 languages (Python, Node.js, Bun, Rust, Go, Ruby, Java, PHP, Flutter)
- Developer tools (LSP servers, linters, formatters, build systems)
- Databases (PostgreSQL 17 with pgvector/timescaledb, Redis, SQLite3)
- AI CLIs (Claude Code native binary)

Containers are bootstrapped once with SSH keys, git repos, credentials, skills, and memories. Runtime versions switch dynamically per project configuration without rebuilding. Per-session git worktrees (flock-protected) provide file isolation so concurrent agents don't collide.

### Project Onboarding & Profiling

When a project is added, Kodizm runs an automated profiling pipeline:

1. **Codebase Analysis** — tech-profiler agent scans the repository to detect languages, frameworks, package managers, build systems, test runners, and architectural patterns
2. **Tech Stack Configuration** — detected stack is mapped to optimal container runtime versions and required services (PostgreSQL, Redis) are activated automatically
3. **Project Instructions Generation** — codebase-analyser agent produces CLAUDE.md covering conventions, directory structure, build/test/lint commands, gotchas, and architectural rules. This becomes the system prompt foundation for all agents working on the project.

The result: a project goes from "git clone" to "ready for AI-driven development" with optimized agent configuration and accurate system prompts, all before the first task is created.

### Dual Execution Modes

Two modes for running AI agents inside containers, chosen automatically based on session type:

**One-Shot Resume** (autonomous task runs): Each message spawns a fresh CLI process inside the container. Subsequent messages resume the prior conversation context via session ID. Zero resource consumption between messages.

**Persistent Process** (interactive conversations): A long-lived Node.js socket proxy keeps the AI CLI process alive between messages. Near-instant responses with no cold start. Adaptive idle timeout (TTL refreshed on each message) releases resources after inactivity.

### Task Lifecycle

```
Draft -> Analysis -> Planning -> Design -> In Progress -> Review -> Testing -> Done
```

Tasks have types (Story, Task, Bug, Spike), priority (P0-P3), and 9 structured section types (analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments). Sections are versioned and track their creator (agent role or user).

**Section-driven workflow:** Agents populate sections during execution through MCP tools (`CreateTaskSection`, `UpdateTaskSection`). The platform uses section completion as pipeline triggers. Concurrency guards prevent runaway execution at three levels: per-task (max 1 active run), per-project (default 3 concurrent), per-team (default 10 concurrent).

### External Integrations

Kodizm integrates with external project management tools: Jira, ClickUp, Linear, Asana, and similar platforms. Bidirectional sync: import issues from existing boards into Kodizm for AI-driven execution, push agent results (status updates, dev reports, PR links) back to the source.

### Tool Extension (MCP)

The platform extends AI agent capabilities through the Model Context Protocol (MCP):

**Built-in tools** (19): task management, progress reporting, structured section writing, document persistence, full-text search, library documentation lookup, ask-user question bridge. All authenticated via session-scoped JWT tokens injected as environment variables.

**Custom MCP servers**: Users register their own external tool servers (HTTP or SSE) at system, team, or project scope. Auth tokens are encrypted and injected securely as environment variables. Narrower scope wins on conflicts.

### Sessions & Conversations

- **Conversation** — the user-facing entity. Can be interactive (user sends messages) or autonomous (triggered by a task run). Tracks messages, cost, and status.
- **Session** — the execution context behind a conversation. Manages the container, CLI process, streamed events, and token usage tracking. Sessions can be shared (user, team, or external link).

Session phases: Provisioning -> Executing -> Warm (idle but reusable) -> Dead (terminal).

**Agent Q&A flow:** Agents can pause mid-execution and ask clarifying questions (`AgentQuestion`). The conversation enters a waiting state, the user is notified, answers inline, and the agent resumes with the new context.

### Real-Time Streaming

WebSocket streaming (Laravel Reverb) delivers:
- **Session events**: CLI output (text, thinking, tool_use, tool_result, result), cost updates, agent questions. Complete events only (no deltas/partials).
- **List-level updates**: Task status changes, conversation status/title changes broadcast on project-level channels (`project.$projectId`). Flutter list views auto-refresh without manual reload.
- **Connection reliability**: Connection status banner, automatic reconnect with state refetch.

### Knowledge & Memory

Agents accumulate context over time within a project:

- **Memories** — persistent files synced bidirectionally between the database and container filesystem. Agents read and write them natively via Claude Code's memory system across sessions. Typed (user, feedback, project, reference) with metadata tracking.
- **Documents** — knowledge artifacts (architecture guides, API references, conventions, runbooks, agent outputs) created by agents or users. Categorized, markdown-rendered, searchable across the project.
- **Skills** — reusable instruction sets injected into agent prompts. Define coding conventions, domain rules, and workflow patterns.

**SkillsMP Marketplace:** A searchable skill marketplace with keyword and AI-powered semantic search (with quota tracking). Teams browse, preview, and import community skills.

### Configuration Hierarchy

4-level merge where each level can override the previous: System -> Agent Role -> Team -> Project. Applies to runtime config, permissions, environment variables, skills, and MCP servers. Narrower scope always wins on conflicts.

### AI Credential Pool

System-scoped OAuth/API key pool, managed entirely by the platform, invisible to teams and users. Multiple OAuth accounts and API keys across providers (Anthropic, OpenAI, Google, OpenRouter) are rotated automatically using configurable algorithms (FillFirst, RoundRobin, Random) with atomic leasing (database-level row locks).

Health monitoring runs continuously: proactive token refresh 2 hours before expiry, automatic rate-limit cooldown with TTL-based recovery, and health check sessions that validate token liveness. When an OAuth token fails in a running container, the system replaces it with a healthy credential from the pool and the agent continues.

### Cost & Billing

Credit-based model. Teams only see their credit balance. Every agent run deducts from team balance based on actual token usage. Per-turn cost tracking, real-time cost streaming via WebSocket, and pre-execution balance checks.

---

## Flutter App

### Screens

- **Dashboard** — active runs with agent role + cost, task summary by status, recent runs, monthly usage breakdown by model, quick actions
- **Projects** — full CRUD, multi-repository management (clone/pull with real-time progress), environment config (runtime versions, services), MCP server config, SSH deploy key generation, profiler toggle
- **Tasks** — filterable list (status/type/priority), sorting (priority/status/date), task creation (manual + quick run), detail view with section viewer, status transitions, one-click agent execution, real-time status updates via WebSocket
- **Chat** — real-time WebSocket streaming of CLI events (text, tool use, thinking blocks, subagent progress, file changes), attachment support (images, PDFs), agent Q&A inline flow. Complete events only.
- **Conversations** — dual mode: simple Q&A view + agent execution view, conversation list with cost/status, real-time list updates
- **Sessions** — global execution monitor, live event streaming, phase indicators, per-model cost breakdown, session sharing, usage records
- **Skills** — team skill directory + SkillsMP marketplace (keyword + AI semantic search with quota tracking, one-click import)
- **Documents & Memory** — project-scoped knowledge base: documents (7 categories, markdown), agent memories (4 types, bidirectional sync)
- **Billing** — credit balance, monthly summary with average cost/run, usage by agent role, paginated usage history
- **Settings** — AI token status display, user profile, 2FA setup, browser session management

### Real-Time

WebSocket streaming (Laravel Reverb) delivers session events, conversation status changes, task status changes, cost updates, and balance changes to connected clients with auto-reconnect and connection status banner.

---

## Multi-Tenancy

- **Teams** own projects, billing, and configuration
- **3-tier scoping** — agent roles, skills, MCP servers configurable at system / team / project level
- **Access control** — Owner, Admin, Member roles with graduated permissions
- AI provider credentials are platform-managed; teams consume credits, never touch provider tokens

---

## Infrastructure

- **Docker hosts** — local or remote (SSH transport), health-monitored, auto-provisioned. Platform manages container lifecycle (create, bootstrap, health-check, reap)
- **Queues** — Laravel Horizon with Redis-backed job processing across 4 queues: default, agent_runs, conversations, container-lifecycle
- **Admin panel** — Filament for system management (agent roles, skills, MCP servers, Docker hosts, AI credentials, billing, containers, sessions, tasks, documents, memories)
- **AI credential pool** — system-scoped multi-provider with atomic rotation, proactive OAuth refresh, rate-limit cooldown, and automatic failover
- **Real-time** — Laravel Reverb WebSocket broadcasting
- **Deployment** — GitHub Actions CI/CD with submodule sync; seeders run manually via SSH after deploy
