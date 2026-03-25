# Decision Log

## 2026-03-24 — Tech Stack: Laravel + Flutter
**Phase**: Pre-Phase — Project Setup
**Context**: Previous iteration used Laravel + Blade + Vue islands. User decided to switch.
**Options considered**:
- A) Laravel + Blade + Vue (previous approach)
- B) Laravel + Flutter (web + mobile)
- C) Laravel + Next.js/Nuxt
**Decision**: Laravel + Flutter
**Reasoning**: Single codebase for web AND mobile. Mobile app is a key differentiator. Strong typing with Dart. User's primary stack.
**Impact**: Frontend architecture completely changes. API-first backend design required. Real-time communication via WebSocket needs Flutter-side implementation.

## 2026-03-24 — All Agents Run as Docker CLI Tools (No Laravel AI SDK)
**Phase**: Pre-Phase — Architecture
**Context**: Original vision had two agent types: conversational (Laravel AI SDK) + coding (CLI in Docker). User decided to unify.
**Options considered**:
- A) Dual: Laravel AI SDK for chat/BA + CLI for coding
- B) All CLI: Every agent runs as Docker CLI tool
**Decision**: All CLI (Option B)
**Reasoning**: Laravel AI SDK agents are insufficient for file operations, codebase analysis, tool use. CLI tools (Claude Code, OpenCode) have mature tooling ecosystems. Unified execution model simplifies architecture.
**Impact**: BA/chat agents also need Docker containers. "Chat with BA" becomes a CLI agent session with streaming. No Laravel AI SDK dependency.

## 2026-03-24 — Designer Agent: Figma MCP (Not MVP)
**Phase**: Pre-Phase — Scope
**Context**: Designer agent needs to produce real design artifacts, not just text descriptions.
**Decision**: Designer agent will use Figma MCP tool to create designs in Figma. Atomic design methodology. Project-level design.md for design system. NOT in MVP but specified in full spec.
**Reasoning**: LLM + Figma MCP = actionable design output. Atomic design ensures consistency.
**Impact**: Figma API integration needed. Design.md becomes part of project scaffolding. Designer role has unique MCP configuration.

## 2026-03-24 — SaaS Only, Credit/Balance Revenue Model
**Phase**: Pre-Phase — Business
**Decision**: SaaS only (no self-hosted). Credit/balance model — users load balance, costs deducted per agent run based on model pricing.
**Reasoning**: Simpler ops (no self-hosted support). Credit model aligns with usage-based AI costs. Users pay for what they use.
**Impact**: Billing system needs credit purchase flow, per-run cost deduction, balance checks before agent dispatch. No subscription tiers in MVP.

## 2026-03-24 — CLI Backend Support: Claude Code + OpenCode (No Codex)
**Phase**: Pre-Phase — Architecture
**Decision**: Support Claude Code (primary) and OpenCode (for Gemini, GPT models). No Codex support.
**Reasoning**: Claude Code is primary, mature, well-documented. OpenCode supports multiple providers (Gemini, GPT, etc.) filling the multi-model gap. Codex has limited model support and uncertain future.
**Impact**: Two CLI backend strategies. OpenCode covers non-Anthropic models.

## 2026-03-24 — MVP Scope Definition
**Phase**: Pre-Phase — Scope
**Decision**: MVP = User registration → Team creation → Project creation (clone existing git repo) → Task-based agent execution → Real-time streaming → Agent Q&A → Session persistence
**Reasoning**: Minimum viable loop that demonstrates core value. No pipeline orchestration, no designer, no external integrations in MVP.
**Impact**: MVP focuses on single-agent task execution with transparency. Pipeline/multi-agent orchestration is post-MVP.

## 2026-03-24 — BA Chat: Continuous Session (MVP)
**Phase**: Pre-Phase — UX
**Decision**: BA agent ile continuous chat session. User mesaj yazar → BA cevaplar/soru sorar → user tekrar yazar → netleşene kadar döner → structured task üretilir. MVP'de bu var.
**Reasoning**: BA'nın gerçek değeri clarification loop'unda. One-shot yetersiz — gerçek bir BA gibi diyalog kurmalı.
**Impact**: Flutter'da chat UI gerekli. WebSocket üzerinden streaming. Session persistence zorunlu.

## 2026-03-24 — Agent Config: CLI Agent Flag Based
**Phase**: Pre-Phase — Architecture
**Decision**: Her agent role'ün kendi prompt/config'i var. Claude Code'a `--append-system-prompt` veya agent flag ile geçilir. Docker container'da o agent promptu ile çalıştırılır. Config DB'de saklanır, container start'ta inject edilir.
**Reasoning**: Claude Code native agent/prompt mekanizması kullanılmalı. Kodizm sadece orchestration yapar, prompt'u container'a verir.
**Impact**: AgentRole model: system_prompt, cli_backend, model, tool_permissions, MCP config. Container'a CLAUDE.md + settings.json inject.

## 2026-03-24 — Team Balance: Credit System (MVP = Tracking Only)
**Phase**: Pre-Phase — Business
**Decision**: Team'lerin bakiyesi var. Her agent run'da model maliyeti düşer. Full version: auto-reload, pay-as-go, Stripe. MVP: sadece bakiye takibi (payment integration yok, manual credit).
**Reasoning**: MVP'de payment karmaşıklığı gereksiz. Core value = agent orchestration. Billing sonra.
**Impact**: Team model'de balance field. Her run sonrası cost deduction. Balance < 0 → agent dispatch engellenir. MVP'de admin manual balance ekler.

## 2026-03-24 — Container Lifecycle: Warm → Cold → Resume
**Phase**: Pre-Phase — Architecture
**Decision**: Agent'lar Docker'da sürekli aktif kalmaz. Çalışma modu: prompt al → execute → output üret → bitir. Soru sorarsa 3-aşamalı lifecycle:
1. **Warm (120s)**: Agent soru sorar → container açık kalır → user real-time izliyorsa anında cevap verir → devam eder
2. **Cold (90 dk)**: 120s'de cevap gelmezse container dondurulur ama session preserved → user cevap verirse container tekrar başlar → resume
3. **Dead**: 90 dk'da da cevap gelmezse container tamamen kapatılır → session data volume'da saklanır → user cevap verdiğinde yeni container + session resume (--resume flag)
**Reasoning**: Container'lar pahalı resource. Sürekli açık bırakmak mümkün değil. Ama session resume ile kullanıcı deneyimi korunur.
**Impact**: Redis'te warm_until timestamp. Session volume mounts. Claude Code --resume flag. Push notification sistemi (agent soru sordu). Container lifecycle commands (cleanup warm, cleanup cold, cleanup dead).

## 2026-03-24 — Model-Specific Prompt Variants (Post-MVP)
**Phase**: Pre-Phase — Architecture
**Decision**: Full spec'te her agent role için model-spesifik prompt variant'ları olacak (Claude/GPT/Gemini farklı davranır). MVP'de tek prompt.
**Reasoning**: oh-my-openagents pattern — model'ler farklı prompt style'lara farklı tepki veriyor. Ama MVP karmaşıklığı artırır.
**Impact**: AgentRole model'de prompt_variants JSON field (post-MVP).

## 2026-03-24 — Retry Limit: Max 2 Iterations
**Phase**: Pre-Phase — Workflow
**Decision**: Code Reviewer reject ederse → Developer'a geri döner. Max 2 retry. 3. fail'de → pipeline durur, human escalation.
**Reasoning**: Sonsuz loop tehlikeli + pahalı. 2 retry yeterli — genelde 1.'de düzelir.
**Impact**: Pipeline state machine'de retry counter. Escalation notification.

## 2026-03-24 — MCP Tools: Agent-Specific + Standardized Task Structure
**Phase**: Pre-Phase — Architecture
**Decision**: MCP tool set agent role'e göre değişir. PM/BA agent task CRUD yapabilir. Tüm agent'lar project+team knowledge/documentation'a read/write/search erişebilir. Task'lar standardized structure: analysis, planning, dev report, code review report, design needs, documents, comments, notes. Post-MVP: Jira/ClickUp sync integration.
**Reasoning**: Her agent'ın farklı ihtiyacı var. BA task yazar, Developer note tutar, Reviewer report yazar. Knowledge base ortak.
**Impact**: MCP tool registry agent role'e göre filtrelenir. Task model zengin (structured sections). Knowledge system project+team scoped.

## 2026-03-24 — Git Strategy: Task Branch + SSH Key + Remote Docker Hosts
**Phase**: Pre-Phase — Architecture
**Decision**: Her task için main/master'dan (project setting) feature branch açılır. Docker container task branch üzerinde çalışır. Git repo SSH key ile bağlanır (private repo desteği). Docker container'lar remote Docker host'larda çalışabilir (sadece local değil). Kod transferi SCP veya volume mount — remote host'a en uygun yöntem.
**Reasoning**: Task isolation gerekli. Private repo desteği şart. Production'da remote Docker host'lar kullanılacak (Kodizm server ≠ Docker host).
**Impact**: Project model: default_branch, ssh_key (encrypted). Docker host config: local vs remote. Remote host'ta repo clone/sync mekanizması. Task branch naming: configurable (default: feature/task-{id}).

## 2026-03-24 — Universal Docker Image (Single)
**Phase**: Pre-Phase — Architecture
**Decision**: Tek universal Docker image tüm CLI tool'ları içerir (claude, opencode). Per-backend ayrı image yok.
**Reasoning**: Image management basit kalır. Her container her backend'i çalıştırabilir.
**Impact**: Image size büyük (~29GB) ama cold start sadece bir kez. Layer caching ile optimize edilir.

## 2026-03-24 — MVP: No Notifications, Events Only
**Phase**: Pre-Phase — Scope
**Decision**: MVP'de push notification yok. Agent run bitti, soru sordu, çalışıyor gibi event'ler fire edilecek (WebSocket broadcast). Flutter UI bu event'leri dinleyip gösterecek.
**Reasoning**: Notification infrastructure (FCM, APNs) MVP karmaşıklığı artırır. Event broadcast yeterli — user zaten app'te.
**Impact**: Event system zorunlu (MVP). Notification service post-MVP.

## 2026-03-24 — Admin UI: Filament
**Phase**: Pre-Phase — Architecture
**Decision**: Admin panel Filament 4 ile. Agent role CRUD, team management, token management, system config. User-facing UI = Flutter.
**Reasoning**: Filament Laravel-native, hızlı admin panel. Flutter user-facing experience için.
**Impact**: İki ayrı UI katmanı: Filament (admin, /admin/*) + Flutter (user, API-driven).

## 2026-03-24 — Multi-Account CLI Auth Management
**Phase**: Pre-Phase — Architecture
**Context**: CLI tools (Claude Code, OpenCode) need API keys or subscription accounts. Teams will use multiple accounts/keys.
**Decision**: Admin manages CLI auth at team level. Support both subscription-based (Claude Max etc.) and API key-based auth. Multi-account with rotation (fill-first, round-robin). Store credentials securely in Kodizm DB, inject into containers at runtime. Same for OpenCode auth (multi-provider keys).
**Reasoning**: Teams have multiple API keys (rate limits, cost distribution). Some use subscription (Claude Max), some API keys. Admin manages centrally, not individual users.
**Impact**: AiToken model needs: provider, auth_type (subscription/api_key), credentials (encrypted), rotation algorithm, cooldown settings. Multi-key rotation service. Container gets injected credentials at start.

## 2026-03-24 — Category-Based Plan Decomposition with Parallel Execution (Post-MVP)
**Phase**: Pre-Phase — Architecture
**Context**: oh-my-openagents pattern — plans decomposed by category, routed to most effective model, run parallel where possible.
**Decision**: Full spec includes category-based planning where Lead Dev decomposes tasks into categorized sub-units (frontend, backend, database, etc.), each routed to the optimal model/agent, with dependency-aware parallel execution (wave pattern from GSD). Not in MVP.
**Reasoning**: Different models excel at different things (Gemini for frontend, Claude for architecture, etc.). Parallel execution dramatically reduces total time. But complexity too high for MVP.
**Impact**: Plan model needs category field, dependency graph. Executor needs wave-based parallelism. Model router needs category→model mapping.

## 2026-03-24 — Flutter Web + Mobile
**Phase**: Pre-Phase — Architecture
**Decision**: Both web and mobile from start. Flutter single codebase.
**Reasoning**: Mobile app for on-the-go monitoring/approvals is a differentiator. Flutter shares codebase.
**Impact**: Need responsive design from day one. API must support both platforms.

## 2026-03-24 — Start Fresh, Previous Plans as Reference Only
**Phase**: Pre-Phase — Project Setup
**Context**: v2 plans (Phase 0-7) existed in ~/Code/kodizm.com/.ac/ but nothing was implemented.
**Decision**: Start from scratch with clean slate. Use previous plans as research/reference material only.
**Reasoning**: Tech stack change (Flutter vs Blade+Vue) invalidates frontend plans. Backend architecture needs fresh evaluation with Flutter API requirements.
**Impact**: All specs will be written new. Previous architectural decisions (CLI-only agents, unified exec model, etc.) can be carried forward if still valid after research phase.

## 2026-03-25 — Agent Customization: System → Team → Project Scope Hierarchy (Full Scope)
**Phase**: Pre-Phase — Architecture
**Context**: Standard agent set should be centrally managed by Kodizm (system defaults), but teams/projects need flexibility to customize prompts and create their own agents.
**Options considered**:
- A) Fixed system agents, no customization
- B) Full override at team/project level (replace system prompt entirely)
- C) Append-only hierarchy: system prompt read-only, team/project can only append
**Decision**: Option C — 3-tier scope hierarchy (system → team → project) with append-only prompt chain
**Reasoning**: System-level guardrails must remain intact. Teams customize behavior by appending context, not overriding core persona. Custom agents (no parent) give full flexibility when needed.
**Impact**: AgentRole model gets scope, parent_id, prompt_append fields. Prompt resolution chains parent.system_prompt + team.prompt_append + project.prompt_append. MVP: team-scoped clones only (flat). Full: 3-tier hierarchy + custom agents.

## 2026-03-25 — Docker Non-Root Container Execution (Full Scope)
**Phase**: Pre-Phase — Security
**Context**: Docker containers should not run as root for security hardening.
**Options considered**:
- A) Root user (simple, current default)
- B) Non-root user from day 1 (MVP)
- C) Non-root user in full scope, root in MVP for simplicity
**Decision**: Option C — MVP runs as default (root for simplicity), full scope creates dedicated `kodizm` user (UID 1000)
**Reasoning**: Non-root adds complexity (file permissions, volume ownership, tool compatibility). MVP needs fast iteration. Full scope needs production hardening.
**Impact**: Universal Docker image Dockerfile adds `useradd kodizm`. Session volume paths change from /root/ to /home/kodizm/. Additional hardening: read-only rootfs, pids-limit, seccomp profile, network isolation option.

## 2026-03-25 — Laravel Horizon for Queue Management
**Phase**: Pre-Phase — Infrastructure
**Context**: Agent execution, container lifecycle, cost calculation — all async. Need robust queue management.
**Decision**: Laravel Horizon for queue dashboard, monitoring, job metrics, and retry management
**Reasoning**: First-party Laravel package. Dashboard provides visibility into agent execution jobs, failed jobs, throughput. Essential for debugging and ops.
**Impact**: Horizon installed alongside Reverb. Redis remains queue driver. Horizon dashboard accessible via Filament admin or standalone /horizon route.

## 2026-03-25 — Task Creation: Manual + PM Conversation
**Phase**: Pre-Phase — Workflow
**Context**: Users need multiple ways to create tasks — not just manual form filling.
**Decision**: Two task creation methods: (1) Manual — user fills form directly, (2) PM Conversation — user writes anything (customer request, bullet points, meeting notes, raw ideas), PM agent analyzes, groups if needed, clarifies via Socratic loop, and produces structured story spec task(s). No separate "meeting notes" source — PM agent handles all input types intelligently within a single conversation flow.
**Reasoning**: PM agent's real value is in understanding any input format, grouping related items, and producing structured story specs. Separate source types would be artificial — the PM agent is smart enough to handle all formats.
**Impact**: Task model gets `source` enum (manual, pm_conversation) + `source_conversation_id`. PM agent prompt needs story spec template + multi-item grouping logic. Post-MVP except manual.

## 2026-03-25 — Three Execution Modes: Manual / Semi-Auto / Full-Auto
**Phase**: Pre-Phase — Workflow
**Context**: Pipeline orchestration needs flexibility — some users want full control, some want automation.
**Decision**: Project-level execution_mode setting with 3 modes: Manual (every stage transition requires user action — MVP behavior), Semi-Auto (pipeline auto-advances but pauses on questions/rejects/approvals), Full-Auto (PM agent handles all decisions autonomously, escalates only on low confidence or max retries).
**Reasoning**: Manual = MVP-safe. Semi-auto = most teams' comfort zone. Full-auto = power mode for high-trust projects. PM agent as "project manager brain" in full-auto is unique differentiator.
**Impact**: Project model gets `execution_mode` enum. Pipeline needs PM agent decision-making capability. Escalation logic (confidence threshold, retry limits). All modes except manual are post-MVP.

## 2026-03-25 — Designer Stage: Conditional, Triggered by PM
**Phase**: Pre-Phase — Workflow
**Context**: Not every task needs design work. Designer stage should not be mandatory in pipeline.
**Decision**: Designer stage is CONDITIONAL — only runs if PM agent flags `design_needed: true` during analysis. If not flagged, pipeline skips Design and goes Planning → In Progress directly.
**Reasoning**: Most backend/infrastructure tasks don't need design. PM is best positioned to identify design needs during analysis. Saves cost and time by skipping when unnecessary.
**Impact**: Task model gets `design_needed` boolean. TaskStatus enum adds `design` state. Pipeline config needs conditional stage logic. Post-MVP.

## 2026-03-25 — MVP: Claude Code Only, OpenCode Post-MVP
**Phase**: Pre-Phase — Scope
**Context**: Challenger analysis identified MVP scope as too large. Supporting two CLI backends doubles streaming normalization, session resume testing, and token rotation complexity.
**Decision**: MVP ships with Claude Code only. OpenCode support (GPT, Gemini models) is post-MVP.
**Reasoning**: Core thesis is orchestration, not multi-model. One backend working flawlessly > two backends working adequately. Cuts NDJSON normalization work in half, eliminates untested OpenCode session resume, simplifies token management to Anthropic-only.
**Impact**: Strategy pattern still exists but only ClaudeCodeStrategy implemented in MVP. AiToken MVP supports only `provider: anthropic`. CliBackend enum kept for future.

## 2026-03-25 — Container Lifecycle Simplified: Warm + Dead (No Cold Phase)
**Phase**: Pre-Phase — Architecture
**Context**: 3-phase lifecycle (warm → cold → dead) adds complexity without proportional value. Cold phase (stop container, preserve session, restart on answer) is a middle ground that complicates state management.
**Decision**: 2-phase lifecycle: Warm (container alive, 5 min) → Dead (container removed, session volume preserved up to 24h, resume on answer). No cold phase.
**Reasoning**: Simpler state machine. Fewer scheduled commands. Warm covers immediate answers, Dead+resume covers delayed answers. The middle "cold" state adds container stop/start complexity for a marginal latency improvement over resume.
**Impact**: Remove `cold_until` from TaskRun model. Remove `containers:cleanup-cold` command. Simplify Redis state tracking. warm_timeout increased to 5 min (was 120s) to compensate.

## 2026-03-25 — Existing Docker Image Reuse (agent user, UID 1001)
**Phase**: Pre-Phase — Infrastructure
**Context**: Universal Docker image already built at ~/Code/kodizm.com/docker/ with non-root `agent` user (UID 1001), 9 language runtimes, Claude Code, OpenCode, gosu-based privilege drop.
**Decision**: Reuse existing Docker image as-is. Non-root execution is already MVP (not post-MVP as previously assumed).
**Reasoning**: Image is production-ready with proper security (gosu privilege drop, tini init, separate agent user). No need to rebuild or redesign.
**Impact**: Session volume paths use `/home/agent/` not `/root/` or `/home/kodizm/`. Security section updated — non-root is MVP. Docker image reference: `~/Code/kodizm.com/docker/`.

## 2026-03-25 — ~~Flutter State Management: Riverpod~~ SUPERSEDED
**Phase**: Pre-Phase — Architecture
**Decision**: ~~Riverpod for Flutter state management.~~ **SUPERSEDED** — see "ChangeNotifier over Riverpod" decision below.
**Reasoning**: Original reasoning was valid, but magic boilerplate uses ChangeNotifier + MagicStateMixin. Fighting the framework is not worth it.
**Impact**: Replaced by ChangeNotifier pattern.

## 2026-03-25 — Magic Boilerplate as Foundation
**Phase**: 5 — Spec
**Context**: Kodizm needs auth, teams, profiles, notifications — standard SaaS boilerplate features
**Options considered**: A) Build from scratch, B) Use magic-starter-laravel + magic/magic_starter Flutter plugins
**Decision**: Use magic framework plugin as 100% foundation
**Reasoning**: Already battle-tested, provides auth (Sanctum), team management, profiles, notifications, responsive layouts, Go Router, ChangeNotifier state management, Dio HTTP client. Building from scratch would waste weeks on solved problems.
**Impact**: Spec 01 (Platform Core) becomes "configure + extend magic-starter". Spec 11 (Flutter App) waves 1-2 heavily simplified. All Flutter state management uses ChangeNotifier (magic pattern), not Riverpod. HTTP uses magic's `Http` facade with Dio.

## 2026-03-25 — UUID Primary Keys
**Phase**: 5 — Spec
**Context**: Need to choose PK strategy for all database tables
**Options considered**: A) Auto-increment bigint, B) UUID
**Decision**: UUID for all primary keys
**Reasoning**: Magic boilerplate already supports UUID via `ConditionallyUsesUuids` trait + `MigrationHelper`. UUID prevents enumeration attacks, enables distributed ID generation, works across microservices.
**Impact**: All model schemas updated — `id: uuid PK`, all foreign keys are `uuid` type. Migration uses magic's `MigrationHelper::primaryKey()`.

## 2026-03-25 — ChangeNotifier over Riverpod (Flutter State Management)
**Phase**: 5 — Spec
**Context**: Previous decision chose Riverpod for Flutter state management, but magic boilerplate uses ChangeNotifier + MagicStateMixin
**Options considered**: A) Keep Riverpod (requires rewriting magic internals), B) Use ChangeNotifier (magic pattern)
**Decision**: ChangeNotifier + MagicStateMixin
**Reasoning**: Magic framework is built around ChangeNotifier pattern. Fighting the framework would create maintenance burden and break plugin compatibility. ChangeNotifier is sufficient for Kodizm's needs.
**Impact**: All Flutter specs updated. No Riverpod dependency. State classes extend ChangeNotifier, use MagicStateMixin for loading/error states. Provider injection via magic's DI.

## 2026-03-25 — Filament v5 Global Admin Only
**Phase**: 5 — Spec
**Context**: Admin panel scope and Filament version decision
**Options considered**: A) Filament v4 with team-scoped admin, B) Filament v5 global admin only
**Decision**: Filament v5, global admin panel only — not team admin
**Reasoning**: Team management happens in Flutter app. Filament serves platform operators (super admins) only — managing agent roles, AI tokens, teams, system config. No need for team-scoped Filament.
**Impact**: Spec 12 updated. Filament resources: AgentRole, AiToken, Team, User, SystemConfig. No tenant/team scoping in Filament. Team admins use Flutter app for their admin tasks.

## 2026-03-25 — Team Role Enum: Spec Roles Override Boilerplate
**Phase**: 5 — Spec
**Context**: Magic boilerplate has TeamRole enum (owner/admin/editor/member), spec requires (owner/admin/member/viewer)
**Options considered**: A) Use boilerplate roles as-is, B) Override with spec roles, C) Merge both sets
**Decision**: Override with spec roles: owner, admin, member, viewer
**Reasoning**: Product requires viewer role (read-only access for stakeholders). Editor role not needed — member already has full CRUD. Viewer is critical for team collaboration where some members should only observe agent runs and read docs.
**Impact**: Magic's TeamRole enum overridden in Kodizm. Permission matrix unchanged from spec. Magic's EDITOR maps to MEMBER conceptually.
