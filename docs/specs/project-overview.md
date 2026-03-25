# Kodizm — Project Overview

> Context document for LLM agents implementing this project.
> Read this FIRST before any spec file.

## What is Kodizm?

Multi-agent SDLC orchestrator. Routes software development tasks to AI CLI agents (Claude Code) running in isolated Docker containers. Each agent has a role-based persona (BA, Lead Dev, Developer, Code Reviewer, QA). SaaS product with credit-based billing.

**One-liner**: Not another coding agent — the orchestration layer that makes multiple AI agents work together across the full software development lifecycle.

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Backend | Laravel | 12 (PHP 8.4) |
| Frontend | Flutter | Web + Mobile (Dart) |
| Admin Panel | Filament | 5 (global admin only) |
| Database | PostgreSQL | + pgvector (post-MVP) |
| Cache/Queue | Redis | Queue driver, cache, container state |
| Queue Dashboard | Laravel Horizon | Job monitoring, metrics |
| WebSocket | Laravel Reverb | Private channels, real-time streaming |
| Auth | Fortify (web) + Sanctum (API) | Session + token auth |
| Containers | Docker | Universal agent image |
| State Management | ChangeNotifier | Flutter state (magic framework pattern) |
| Boilerplate | magic-starter (Laravel + Flutter) | Auth, Teams, Profiles, Notifications |
| Billing | Stripe (post-MVP) | Credit purchase |

## Boilerplate (magic-starter)

magic-starter-laravel provides auth (Fortify + Sanctum), team management, user profiles, and notifications as base infrastructure. Kodizm extends these models (User, Team) with domain-specific fields and relationships.

## Architecture

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
                  │ Claude Code││ Claude Code││ Claude Code│
                  │ (agent usr)││ (agent usr)││ (agent usr)│
                  └────────────┘└────────────┘└────────────┘
```

## Core Flow (MVP)

```
1. User creates task (manual)
2. User picks agent role + clicks "Run"
3. Laravel: balance check → token resolve → container start
4. Docker: git clone repo → checkout feature branch → mount session volume
5. docker exec: claude -p "{prompt}" --output-format stream-json ...
6. NDJSON stream → normalize → persist StreamEvent → broadcast via Reverb
7. Flutter: WebSocket receives events → renders terminal view in real-time
8. If agent asks question → container stays warm → user answers → agent resumes
9. On completion: record cost → deduct balance → cleanup container
```

## Docker Image

Pre-built universal image at `~/Code/kodizm.com/docker/`:
- Ubuntu 24.04 base
- 9 language runtimes (Python, Node, Bun, Rust, Go, Ruby, PHP, Java, Flutter)
- Claude Code CLI + OpenCode CLI pre-installed
- Non-root `agent` user (UID 1001) via gosu
- tini as init process
- PostgreSQL 17, Redis available inside container
- LSP servers, linters, formatters included

## Key Conventions

- **All code, comments, naming in English**
- **Multi-tenancy**: All data scoped to team via `team_id` FK
- **API-first**: Laravel serves JSON API, Flutter consumes it
- **Thin controllers, fat services**: No business logic in controllers
- **Strict types**: Every param, return, property typed
- **TDD**: Failing test first, then implementation
- **Enums**: PHP backed enums for all finite value sets
- **Encrypted storage**: API keys and SSH keys encrypted at rest (Laravel encrypted cast)
- **UUID primary keys**: All models use UUID PKs via magic's `ConditionallyUsesUuids` trait
- **Soft deletes**: On all models referenced by FKs (User, Team, Project, Task, AgentRole, AiToken)

## MVP Scope

MVP = Claude Code only (no OpenCode). Single-agent task execution with real-time streaming.

**In MVP**: Auth & Teams (from magic boilerplate), Projects, Agent Roles, AI Tokens (Anthropic only), Tasks, Single Agent Execution, Container Lifecycle (warm/dead), NDJSON Streaming, BA Chat, Agent Q&A, Session Resume, Knowledge Docs, Balance Tracking, Git Integration, Flutter Web+Mobile, Filament Admin, WebSocket Events.

**NOT in MVP**: OpenCode backend, Pipeline orchestration, Designer agent, Multi-model routing, Stripe billing, External integrations, Push notifications, Social login, Kanban board, Sprint management, CI/CD integration.

## Reference Materials

- Master spec (consolidated): `docs/specs/kodizm-spec.md`
- Decisions log: `docs/drafts/decisions.md`
- Agents & workflow: `docs/drafts/agents-and-workflow.md`
- Market research: `docs/drafts/research-notes.md`
- Existing Docker image: `~/Code/kodizm.com/docker/`
- Previous v2 architecture: `~/Code/kodizm.com/CLAUDE.local.md`
- CLI reference docs: `~/Code/kodizm.com/docs/clis/`
