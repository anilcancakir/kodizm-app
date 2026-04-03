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

One Docker container per project, reused across all sessions — not ephemeral. The universal agent image includes:

- 9 languages (Python, Node.js, Bun, Rust, Go, Ruby, Java, PHP, Flutter)
- Developer tools (LSP servers, linters, formatters)
- Databases (PostgreSQL 17, Redis, SQLite3)
- AI CLIs (Claude Code, OpenCode)

Containers are bootstrapped once with SSH keys, git repos, credentials, skills, and memories. Runtime versions switch dynamically per project configuration without rebuilding the container. Per-session git worktrees provide file isolation so concurrent agents don't collide.

### Project Onboarding & Profiling

When a project is added to the platform, Kodizm runs an automated profiling pipeline before any task execution begins:

1. **Codebase Analysis** — a Tech Analyzer agent scans the repository to detect languages, frameworks, package managers, build systems, test runners, and architectural patterns
2. **Tech Stack Configuration** — detected stack is mapped to optimal container runtime versions and required services (PostgreSQL, Redis) are activated automatically
3. **Project Instructions Generation** — a Codebase Profiler agent produces a comprehensive instruction file covering conventions, directory structure, build/test/lint commands, gotchas, and architectural rules. This becomes the system prompt foundation for all agents working on the project.
4. **Documentation Generation** — a Documentation Writer agent creates or updates project documentation (README, architecture guides, API references, onboarding docs) based on the analyzed codebase
5. **Agent Optimization** — agent role configurations (model selection, system prompts, tool permissions, budget limits) are tuned to match the project's complexity and stack

The result: a project goes from "git clone" to "ready for AI-driven development" with optimized agent configuration, accurate system prompts, and generated documentation — all before the first task is created.

### Dual Execution Modes

Two modes for running AI agents inside containers, chosen automatically based on session type:

**One-Shot Resume** (autonomous task runs): Each message spawns a fresh CLI process inside the container. Subsequent messages resume the prior conversation context via session ID. Zero resource consumption between messages — ideal for autonomous runs that execute a prompt and complete.

**Persistent Process** (interactive conversations): A long-lived proxy keeps the AI CLI process alive between messages. Near-instant responses with no cold start. Adaptive idle timeout releases resources after inactivity — ideal for interactive chat where users send multiple messages in quick succession.

### Task Lifecycle

```
Draft -> Analysis -> Planning -> Design -> In Progress -> Review -> Testing -> Done
```

Tasks have types (Story, Task, Bug, Spike), priority (P0-P3), structured sections (Analysis, Plan, Dev Report, Review, Test Report), and subtask hierarchy. Agents populate these sections during execution through platform tools. Concurrency guards prevent runaway execution (per-task, per-project, per-team limits).

### External Integrations

Kodizm integrates with external project management tools — Jira, ClickUp, Linear, Asana, and similar platforms. Bidirectional sync: import issues from existing boards into Kodizm for AI-driven execution, push agent results (status updates, dev reports, PR links) back to the source. Teams adopt Kodizm without abandoning their current workflow.

### Tool Extension (MCP)

The platform extends AI agent capabilities through the Model Context Protocol (MCP):

**Built-in tools** (15+): task management, progress reporting, structured section writing, document persistence, full-text search, library documentation lookup. All authenticated via session-scoped tokens.

**Custom MCP servers**: Users register their own external tool servers (HTTP or SSE) at system, team, or project scope. Auth tokens are encrypted and injected securely as environment variables — no secrets in config files. Narrower scope wins on conflicts.

### Sessions & Conversations

- **Conversation** — the user-facing entity. Can be interactive (user sends messages) or autonomous (triggered by a task run). Tracks messages, cost, and status. Agents can pause and ask questions mid-execution.
- **Session** — the execution context behind a conversation. Manages the container, CLI process, streamed events, and token usage tracking.

Session phases: Provisioning -> Executing -> Warm (idle but reusable) -> Dead (terminal).

### Knowledge & Memory

Agents accumulate context over time within a project:

- **Memories** — persistent files synced bidirectionally between the database and container. Agents read and write them natively across sessions.
- **Documents** — knowledge artifacts (guides, decisions, issues) created by agents or users, searchable across the project.
- **Skills** — reusable instruction sets injected into agent prompts. Define coding conventions, domain rules, and workflow patterns. Importable from the SkillsMP marketplace.

### Configuration Hierarchy

4-level merge where each level can override the previous: System -> Agent Role -> Team -> Project. Applies to runtime config, permissions, environment variables, skills, and MCP servers. Narrower scope always wins on conflicts.

### Cost & Billing

Credit-based model. Platform admins manage AI provider credentials centrally — teams only see their credit balance. Every agent run deducts from team balance based on actual token usage. Per-turn cost tracking, real-time cost streaming via WebSocket, and pre-execution balance checks ensure no surprises.

---

## Flutter App

### Screens

- **Dashboard** — active runs, task summary by status, recent runs with cost, monthly usage
- **Projects** — CRUD, repository management, environment config, MCP servers, SSH keys
- **Task Board** — filterable list with status/priority badges, one-click autonomous execution
- **Chat** — real-time WebSocket conversation with agents, streaming tool use, agent Q&A flow
- **Sessions** — global execution monitor across all projects, phase indicators, token counts
- **Skills** — team skill directory + SkillsMP marketplace with keyword and AI semantic search
- **Billing** — credit balance, monthly breakdown, detailed usage history

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

- **Docker hosts** — local or remote (SSH transport), load-balanced, health-monitored
- **Queues** — Laravel Horizon with Redis-backed job processing for autonomous execution
- **Admin panel** — Filament for system management (agent roles, skills, MCP servers, Docker hosts, AI tokens, billing)
- **AI token pool** — multi-provider (Anthropic, OpenAI, Google, OpenRouter) with automatic rotation, health checks, and OAuth refresh
- **Real-time** — Laravel Reverb WebSocket for event broadcasting
