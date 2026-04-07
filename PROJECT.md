# Kodizm — Multi-Agent SDLC Orchestrator

Kodizm automates software development by orchestrating teams of specialized AI agents. Each agent has a distinct role, tools, and permissions, running inside isolated Docker containers. The platform manages the full lifecycle — from task creation through implementation, review, and testing.

Built with a **Laravel API** (orchestration engine) and a **Flutter App** (web & mobile UI).

---

## Mission

Turn AI coding assistants (Claude Code, OpenCode) from single-user CLI tools into a managed, multi-agent development platform. Teams define agent roles, assign work, monitor execution in real-time, and track costs — without giving up control over quality, security, or architecture.

---

## Core Loop

1. **Create a task** — describe the work, assign an agent role, set priority
2. **Agent executes** — platform provisions the container, injects context, launches the AI CLI, streams events in real-time
3. **Human stays in the loop** — agents pause and ask questions when blocked, users can also chat interactively at any time
4. **Platform handles the rest** — containers, credentials, cost tracking, memory persistence, git isolation, tool access

---

## Key Features

### Agent Roles

Specialized AI agent personas with configurable model, system prompt, budget cap, and tool permissions. Default roles that seed on team creation:

- **Product Manager** — requirements analysis, specifications
- **Lead Developer** — architecture, task decomposition
- **Developer** — implementation, bug fixes, refactoring
- **Code Reviewer** — code review, read-only access
- **QA Engineer** — testing, quality verification

Roles support 3-tier scoping (system / team / project) with inheritance — a project-level role can override its team-level parent.

### Persistent Containers

One Docker container per project (1:1 mapping), reused across all sessions — not ephemeral. Containers are fully platform-managed: provisioned, bootstrapped, health-checked, and reaped automatically. Users only see container status (Creating, Running, Stopped, Failed) — no Docker host management exposed to end users.

The universal agent image includes:

- 9 languages (Python, Node.js, Bun, Rust, Go, Ruby, Java, PHP, Flutter)
- Developer tools (LSP servers, linters, formatters, build systems)
- Databases (PostgreSQL 17 with pgvector/timescaledb, Redis, SQLite3)
- AI CLIs (Claude Code native binary, OpenCode)

Containers are bootstrapped once with SSH keys, git repos, credentials, skills, and memories — all steps idempotent. Runtime versions switch dynamically per project configuration without rebuilding. Per-session git worktrees (flock-protected) provide file isolation so concurrent agents don't collide.

### Project Onboarding & Profiling

When a project is added to the platform, Kodizm runs an automated profiling pipeline before any task execution begins:

1. **Codebase Analysis** — a Tech Analyzer agent scans the repository to detect languages, frameworks, package managers, build systems, test runners, and architectural patterns
2. **Tech Stack Configuration** — detected stack is mapped to optimal container runtime versions and required services (PostgreSQL, Redis) are activated automatically
3. **Project Instructions Generation** — a Codebase Profiler agent produces a comprehensive instruction file covering conventions, directory structure, build/test/lint commands, gotchas, and architectural rules. This becomes the system prompt foundation for all agents working on the project.
4. **Documentation Generation** — a Documentation Writer agent creates or updates project documentation (README, architecture guides, API references, onboarding docs) based on the analyzed codebase
5. **Agent Optimization** — agent role configurations (model selection, system prompts, tool permissions, budget limits) are tuned to match the project's complexity and stack

The result: a project goes from "git clone" to "ready for AI-driven development" with optimized agent configuration, accurate system prompts, and generated documentation — all before the first task is created.

### Agent Architecture

Built on Claude Code's native agent/subagent system. Each task run spawns a primary agent with a specific role (Lead Developer, Developer, QA, etc.). The primary agent orchestrates its own subagents internally — planning, analysis, implementation, review — using Claude Code's built-in delegation. Agents write their outputs into task sections via MCP tools, and the platform advances the pipeline based on section completion. This means multi-agent coordination happens organically through Claude Code's architecture, not through custom inter-agent messaging.

### Dual Execution Modes

Two modes for running AI agents inside containers, chosen automatically based on session type:

**One-Shot Resume** (autonomous task runs): Each message spawns a fresh CLI process inside the container. Subsequent messages resume the prior conversation context via session ID. Zero resource consumption between messages — ideal for autonomous runs that execute a prompt and complete.

**Persistent Process** (interactive conversations): A long-lived Node.js socket proxy keeps the AI CLI process alive between messages. Near-instant responses with no cold start. Adaptive idle timeout (TTL refreshed on each message) releases resources after inactivity — ideal for interactive chat where users send multiple messages in quick succession.

### Task Lifecycle

```
Draft -> Analysis -> Planning -> Design -> In Progress -> Review -> Testing -> Done
```

Tasks have types (Story, Task, Bug, Spike), priority (P0-P3), and 9 structured section types (analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments). Sections are versioned and track their creator (agent role or user).

**Section-driven workflow:** Agents populate sections during execution through MCP tools (`CreateTaskSection`, `UpdateTaskSection`). The platform uses section completion as pipeline triggers — e.g., when an agent writes an `analysis` section, the system auto-dispatches the next pipeline stage (`planning`). This creates a natural sequential flow where each agent's output feeds the next phase.

**Concurrency guards** prevent runaway execution at three levels: per-task (max 1 active run), per-project (default 3 concurrent), per-team (default 10 concurrent). Violations throw scoped exceptions — pipeline stages fail gracefully without retry.

### External Integrations

Kodizm integrates with external project management tools — Jira, ClickUp, Linear, Asana, and similar platforms. Bidirectional sync: import issues from existing boards into Kodizm for AI-driven execution, push agent results (status updates, dev reports, PR links) back to the source. Teams adopt Kodizm without abandoning their current workflow.

### Tool Extension (MCP)

The platform extends AI agent capabilities through the Model Context Protocol (MCP):

**Built-in tools** (15+): task management, progress reporting, structured section writing, document persistence, full-text search, library documentation lookup. All authenticated via session-scoped tokens.

**Custom MCP servers**: Users register their own external tool servers (HTTP or SSE) at system, team, or project scope. Auth tokens are encrypted and injected securely as environment variables — no secrets in config files. Narrower scope wins on conflicts.

### Sessions & Conversations

- **Conversation** — the user-facing entity. Can be interactive (user sends messages) or autonomous (triggered by a task run). Tracks messages, cost, and status.
- **Session** — the execution context behind a conversation. Manages the container, CLI process, streamed events, and token usage tracking. Sessions can be shared (user, team, or external link).

Session phases: Provisioning → Executing → Warm (idle but reusable) → Dead (terminal).

**Agent Q&A flow:** Agents can pause mid-execution and ask clarifying questions (`AgentQuestion`). The conversation enters a waiting state, the user is notified, answers inline, and the agent resumes with the new context. This keeps humans in the loop without breaking autonomous execution.

### Knowledge & Memory

Agents accumulate context over time within a project:

- **Memories** — persistent files synced bidirectionally between the database and container filesystem. Agents read and write them natively via Claude Code's memory system across sessions. Typed (user, feedback, project, reference) with metadata tracking.
- **Documents** — knowledge artifacts (architecture guides, API references, conventions, runbooks, agent outputs) created by agents or users. Categorized, markdown-rendered, searchable across the project.
- **Skills** — reusable instruction sets injected into agent prompts. Define coding conventions, domain rules, and workflow patterns.

**SkillsMP Marketplace:** A searchable skill marketplace with two search modes — keyword search and AI-powered semantic search (with quota tracking). Teams browse, preview, and import community skills directly into their workspace. Already-imported skills are visually marked in search results.

### Configuration Hierarchy

4-level merge where each level can override the previous: System -> Agent Role -> Team -> Project. Applies to runtime config, permissions, environment variables, skills, and MCP servers. Narrower scope always wins on conflicts.

### AI Credential Pool

System-scoped OAuth/API key pool — managed entirely by the platform, invisible to teams and users. Multiple OAuth accounts and API keys across providers (Anthropic, OpenAI, Google, OpenRouter) are rotated automatically using configurable algorithms (FillFirst, RoundRobin, Random) with atomic leasing (database-level row locks).

Health monitoring runs continuously: proactive token refresh 2 hours before expiry, automatic rate-limit cooldown with TTL-based recovery, and health check sessions that validate token liveness. When an OAuth token fails in a running container (expired, rate-limited, revoked), the system replaces it with a healthy credential from the pool and the agent continues — zero downtime, zero user intervention. Three consecutive refresh failures mark a token as Expired and remove it from rotation.

### Cost & Billing

Credit-based model. Teams only see their credit balance — never provider tokens or credentials. Every agent run deducts from team balance based on actual token usage. Per-turn cost tracking, real-time cost streaming via WebSocket, and pre-execution balance checks ensure no surprises.

---

## Flutter App

### Screens

- **Dashboard** — active runs with agent role + cost, task summary by status, recent runs, monthly usage breakdown by model, quick actions
- **Projects** — full CRUD, multi-repository management (clone/pull with real-time progress), environment config (runtime versions, services), MCP server config, SSH deploy key generation
- **Tasks** — filterable list (status/type/priority), sorting (priority/status/date), task creation (manual + quick run), detail view with section viewer, status transitions, one-click agent execution with role picker
- **Chat** — real-time WebSocket streaming of Claude Code CLI events (text deltas, tool use, thinking blocks, subagent progress, file changes), attachment support (images, PDFs), agent Q&A inline flow
- **Conversations** — dual mode: simple Q&A view + agent execution view, conversation list with cost/status
- **Sessions** — global execution monitor, live event streaming, phase indicators, per-model cost breakdown, session sharing, usage records
- **Skills** — team skill directory + SkillsMP marketplace (keyword + AI semantic search with quota tracking, one-click import)
- **Documents & Memory** — project-scoped knowledge base: documents (7 categories, markdown), agent memories (4 types, bidirectional sync)
- **Billing** — credit balance, monthly summary with average cost/run, usage by agent role, paginated usage history
- **Settings** — AI token status display, user profile, 2FA setup, browser session management

### Real-Time

WebSocket streaming (Laravel Reverb) delivers session events, conversation status changes, cost updates, and balance changes to connected clients with auto-reconnect.

---

## Multi-Tenancy

- **Teams** own projects, billing, and configuration
- **3-tier scoping** — agent roles, skills, MCP servers configurable at system / team / project level
- **Access control** — Owner, Admin, Member roles with graduated permissions
- AI provider credentials are platform-managed — teams consume credits, never touch provider tokens

---

## Infrastructure

- **Docker hosts** — local or remote (SSH transport), health-monitored, auto-provisioned. Platform manages container lifecycle (create, bootstrap, health-check, reap) — users never touch Docker
- **Queues** — Laravel Horizon with Redis-backed job processing across 4 queues: default, agent_runs, conversations, container-lifecycle. Scoped wait thresholds and trim policies per queue
- **Admin panel** — Filament for system management (17 resource types: agent roles, skills, MCP servers, Docker hosts, AI credentials, billing, containers, sessions, tasks, documents, memories)
- **AI credential pool** — system-scoped multi-provider (Anthropic, OpenAI, Google, OpenRouter) with atomic rotation (FillFirst/RoundRobin/Random), proactive OAuth refresh, rate-limit cooldown, and automatic failover in running containers
- **Real-time** — Laravel Reverb WebSocket broadcasting: conversation messages, session events, cost updates, balance changes, pipeline progress, repository clone status
