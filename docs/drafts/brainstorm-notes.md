# Kodizm — Vision Synthesis & Project Definition

> Synthesized from: kod.txt (original vision), v2 PRD draft, v2 Phase 0-7 plans, AC plugin architecture

---

## What is Kodizm?

**One-liner**: AI-powered multi-agent software development platform that orchestrates CLI coding tools across the full SDLC.

**Elevator pitch**: Kodizm turns product requirements into shipped code by orchestrating multiple AI agents — each specialized for a role (Business Analyst, Lead Developer, Designer, Code Reviewer, QA) — running inside isolated Docker containers. Unlike Cursor/Devin/Windsurf which are single-AI code editors, Kodizm manages the entire development lifecycle: idea → analysis → planning → implementation → review → deployment. Teams define agent roles, configure which AI backend handles what, and watch agents collaborate in real-time.

---

## Core Thesis

### Problem
1. **AI coding tools are single-player** — Cursor, Windsurf, Devin each use one AI model in one context. No coordination between agents.
2. **Manual orchestration overhead** — Developers copy-paste prompts, manage CLI sessions, stitch outputs together. The "glue work" of AI-assisted development is still manual.
3. **No model flexibility** — Locked into one provider. Can't route architecture decisions to Claude Opus, quick fixes to Haiku, and large-context analysis to Gemini.
4. **No SDLC coverage** — AI tools help with coding but not with analysis, planning, design review, QA, or deployment coordination.
5. **No transparency or traceability** — When AI writes code, there's no audit trail of decisions, no cost tracking, no structured output.

### Solution
A platform that:
- **Orchestrates multiple AI agents** with role-based personas (BA, Tech Lead, Developer, Designer, Code Reviewer, QA)
- **Routes tasks to the best AI system** — Claude Code for architecture, OpenCode/Codex for quick tasks, any LLM API for analysis
- **Runs agents in isolated Docker containers** — full codebase access, ephemeral environments, no cross-contamination
- **Manages the full pipeline** — from user request → agent analysis → planning → implementation → code review → merge
- **Provides real-time transparency** — watch agents work, answer their questions, approve decisions
- **Tracks everything** — cost per task, per model, per agent; decision audit trail; structured artifacts

### Why Now?
- Claude Code, OpenCode, Codex CLI tools matured in 2025-2026 — reliable enough for production orchestration
- Multi-model strategies proven (different models excel at different tasks)
- Docker container isolation is cheap and fast
- MCP (Model Context Protocol) enables standardized tool integration
- Teams are already using 3-5 AI tools manually — orchestration is the natural next step

---

## Target Users

### Primary: Solo Developers & Small Teams (2-10)
- Already using AI coding tools (Claude Code, Cursor, etc.)
- Want to automate the coordination between multiple AI interactions
- Need cost visibility and control
- Value: "I describe what I want, agents figure out the how"

### Secondary: Agencies & Freelancers
- Multi-client project management
- Need structured output (PRDs, specs, test reports) for client communication
- Per-project cost tracking for billing clients

### Tertiary: Enterprise Dev Teams
- Governance and approval workflows
- Custom agent configurations per project/team
- Integration with existing tooling (Jira, GitHub, CI/CD)

---

## Core System Components

### 1. Team & Project Management
- **Organization/Team model** — all activity scoped to a team
- **Projects** — linked to git repos (new or imported), tech stack configured
- **Roles & Permissions** — team admin, developer, viewer
- **Multi-tenant** — data isolation between teams

### 2. AI Agent System (Dual Architecture)
Two types of agent execution:

**Type A: Conversational Agents (LLM API)**
- Run inside Laravel via AI SDK
- Handle: user chat, task analysis, requirement clarification, question answering
- Purpose: User-facing interaction + tool calling (task CRUD, agent dispatch, search)
- Think: BA agent chatting with user to understand requirements

**Type B: Coding Agents (CLI in Docker)**
- Run as CLI tools (Claude Code, OpenCode, Codex) inside ephemeral Docker containers
- Handle: code analysis, implementation, review, testing
- Full codebase access via volume mounts
- Real-time NDJSON streaming back to platform
- Session persistence for resume capability

### 3. Role-Based Agent Personas
Default roles with customizable system prompts:
- **Business Analyst (BA)** — Requirements gathering, story writing, scope definition
- **Lead Developer** — Architecture decisions, planning, task decomposition
- **Developer** — Implementation, bug fixes
- **Code Reviewer** — Code quality, best practices, security review
- **Designer** — UI/UX mockups (future: integrated with design tools)
- **QA** — Test planning, test execution, bug verification

Each role configures:
- Which CLI backend to use (Claude Code / OpenCode / Codex)
- Which LLM model (with fallback chain)
- System prompt / persona instructions
- Allowed tools and permissions
- MCP server connections

### 4. Task Management (Built-in)
- Full task lifecycle: Draft → Ready → Planned → In Progress → Review → Done/Failed
- Task types: Story, Task, Bug, Spike
- Priority, estimation, sprint assignment
- Each task has: analysis doc, plan, acceptance criteria, test cases
- Standardized format — every task follows the same structure regardless of who (human or AI) created it

### 5. Pipeline Orchestration
Configurable per project:
- **Auto mode**: Task flows through stages automatically (BA → Lead Dev → Developer → Code Review → Done)
- **Manual mode**: Human approval required at configured gates
- **Hybrid**: Some stages auto, some require approval
- Stage → Agent Role mapping configurable
- Shared git worktree across pipeline stages (each agent continues where the previous left off)

### 6. Real-time Transparency
- Watch agent terminal output as it happens (WebSocket streaming)
- Agent questions captured and displayed — user can answer in real-time
- File change tracking — see what the agent modified
- Cost tracking per task/run/model

### 7. Knowledge & Documentation System
- Project-level documents (architecture, conventions, API specs) stored in Kodizm
- pgvector embeddings for semantic search
- Agents can read AND write documentation via MCP tools
- Shared memory across agent sessions

### 8. Multi-Model Strategy
- No vendor lock-in — configure which model handles which role
- Token rotation — multiple API keys per provider with cooldown
- Model routing — task complexity → appropriate model tier
- Future: Run same task on multiple models, compare results

### 9. External Integrations
- **Git**: GitHub Flow — main + feature branches per task
- **Task tools**: Jira, ClickUp sync (import/export)
- **CI/CD**: Trigger pipelines after agent completes
- **Notifications**: In-app, email, Slack (future)

### 10. Billing & Cost Management
- Per-model cost tracking (input/output tokens × model price)
- Team-scoped usage dashboards
- Stripe metered billing
- Project-level cost allocation
- Budget limits per task/project

---

## Tech Stack Decision: Laravel + Flutter

### Backend: Laravel (PHP 8.4)
- API-first architecture (REST + WebSocket)
- Laravel Reverb for real-time (agent streaming, notifications)
- Horizon for queue management (agent job dispatch)
- PostgreSQL + pgvector for knowledge/embeddings
- Redis for caching, token cooldown, container state
- Docker SDK for container management
- MCP server for agent ↔ platform communication

### Frontend: Flutter (Web + Mobile)
- **Why Flutter over Blade+Vue?**
  - Single codebase for web AND mobile app
  - Rich real-time UI (terminal streaming, kanban boards, dashboards)
  - Strong typing with Dart
  - State management more predictable than Vue islands approach
  - Mobile app = key differentiator (manage AI agents from phone)
- **Web**: Flutter Web for dashboard, monitoring, task management
- **Mobile**: iOS/Android app for notifications, approvals, monitoring on-the-go

### Infrastructure
- Docker containers for agent execution
- Universal Docker image with all CLI tools pre-installed
- PostgreSQL (main DB + pgvector)
- Redis (cache, queues, container state)
- Reverb (WebSocket server)
- Stripe (billing)

---

## Key Technical Decisions (Carried from Research)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Agent execution | CLI tools in Docker (not SDK agents) | Full codebase access, tool ecosystem, session persistence |
| Container model | sleep infinity + docker exec | No HTTP overhead, unified for all backends |
| Config management | DB-stored, injected at container start | No .kodizm/ in repos, UI-manageable |
| Knowledge storage | Kodizm PostgreSQL + pgvector | Container storage is ephemeral, needs persistent store |
| Auth | Laravel Fortify + Passport | Web sessions + API tokens, future OAuth |
| Real-time | Laravel Reverb | First-party WebSocket, no external deps |
| Frontend | Flutter (web + mobile) | Cross-platform, rich real-time UI, mobile differentiator |
| Task management | Built-in with external sync | Full control over AI-friendly structure |
| Pipeline | Lightweight — config-based stage→agent mapping | No over-engineering, extend as needed |
| Multi-model | Strategy pattern per CLI backend | Clean abstraction, easy to add new backends |

---

## Supported Tech Stacks (for Projects)

System will support specific tech stacks with optimized agent prompts:
- Laravel + Blade/Livewire
- Laravel + Jetstream
- Laravel + Filament
- Laravel + Flutter (backend + mobile)
- Laravel + Vue/React (API + SPA)

For multi-repo stacks (e.g., Laravel + Flutter):
- Two repos: backend + frontend
- Agents can access both via Docker volume mounts
- Claude Code's --add-dir flag or workdir feature for cross-repo awareness

---

## What Makes Kodizm Different?

1. **Multi-agent, not single-agent** — Each role has a specialized agent, not one AI doing everything
2. **Multi-model, not single-model** — Route tasks to the best AI for the job
3. **Full SDLC, not just coding** — Analysis → Planning → Implementation → Review → Deploy
4. **Transparent, not black-box** — Watch agents work, see decisions, track costs
5. **Team-oriented, not solo** — Collaboration, approvals, role-based access
6. **Mobile-ready** — Flutter app for on-the-go management (unique in market)
7. **Customizable agents** — Your prompts, your tools, your workflow

---

## Open Questions for Discussion

1. **Conversational AI (Type A) architecture** — Laravel AI SDK ile mi, yoksa bu da Docker CLI agent mi olacak? kod.txt'te "chat window'da BA ile konuşma" var. Bu bir Laravel AI SDK chat mı, yoksa CLI agent session mı?

2. **Designer agent scope** — Mockup-only mı, yoksa gerçek design file (Figma?) üretecek mi? Flutter UI generation?

3. **Sıfırdan proje scaffolding** — User tech stack seçtiğinde Kodizm boş bir repo mu oluşturacak, yoksa boilerplate/starter template mi kuracak?

4. **Dogfooding priority** — Kodizm ile Kodizm'i geliştirme ne kadar öncelikli? MVP scope'u etkiler.

5. **Self-hosted vs SaaS** — Sadece SaaS mı, yoksa self-hosted option da olacak mı?

6. **Flutter web performance** — Dashboard gibi data-heavy sayfalar için Flutter Web yeterli mi? Hybrid (Flutter mobile + web dashboard separate) düşünülmeli mi?

7. **oh-my-openagents ve diğer referans projeler** — ~/Code/ai-help/repos altındaki projelerden hangilerini incelememiz gerekiyor? (henüz bakmadık)

8. **Revenue model** — Credit/balance-based (kullanıcı bakiye yükler) mı, subscription + metered mı, yoksa hybrid mı?
