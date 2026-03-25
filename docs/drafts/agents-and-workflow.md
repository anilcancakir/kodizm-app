# Kodizm — Agent Personas & Workflow Architecture (DRAFT v2)

> Referans projelerden (oh-my-openagent, get-shit-done, openhands) pattern analizi + model benchmark'ları ile sentezlenmiştir.

---

## Research Findings: 3 Dominant Orchestration Patterns

### 1. Sisyphus-Style Delegation (oh-my-openagent)
- Orchestrator agent intent detection yapar → category+skills table'dan doğru specialist agent'ı spawn eder
- 11 agent: exploration, specialist, advisor, utility kategorilerinde
- Her agent'ın model-specific prompt variant'ları var (Claude/GPT/Gemini farklı davranır)
- Tool gating: agent başına farklı izinler (Oracle read-only, Librarian search-only)

### 2. Wave-Based Parallelism (get-shit-done)
- Dependency DAG → wave grouping → parallel executors
- **Context rot çözümü**: Her executor fresh 200K token context alır (sadece kendi planı + project state)
- 12 agent: research, planner, executor, verifier, debugger
- Phase gates: discuss → plan → execute (waves) → verify
- Deviation auto-handling: 3 deneme → escalation

### 3. Event Sourcing (openhands)
- Immutable Action/Observation event'ler → EventStream pub/sub
- 9 Condenser stratejisi context overflow'u önler
- Docker sandbox izolasyonu (MicroVM-level)
- Issue-to-PR automation pipeline

### Model Benchmark Insights (March 2026)

| Görev | En İyi Model | Alternatif |
|-------|-------------|------------|
| Planning/Architecture | Claude Opus 4.6 (9.5) | Gemini 3.1 Pro (9.0) |
| Code Writing | Claude Opus 4.6 (9.5) | MiniMax M2.5 (9.0) |
| Agentic Terminal | GPT-5.3-Codex (9.0) | Claude Opus 4.6 (9.0) |
| Frontend/UI | Gemini 3.1 Pro (9.0) | Claude Opus 4.6 (9.0) |
| Research | Gemini (large context) | Claude Opus |
| Validation | DeepSeek V3.2 (budget) | GPT-5.4 |

**Community consensus**: "Write with Claude, review with GPT, research with Gemini, validate with DeepSeek"

### Competitive Landscape (Preliminary)

| Rakip | Ne Yapar | Kodizm Farkı |
|-------|----------|--------------|
| **Devin** (Cognition) | Single-agent autonomous coding, cloud sandbox | Kodizm: multi-agent, multi-model, role-based |
| **JetBrains Central** (Q2 2026 EAP) | Governance+execution+optimization layer, multi-agent support | En yakın rakip — ama enterprise-only, IDE-centric, henüz beta |
| **Cline** | Open-source, model-agnostic coding agent | Single-agent, no orchestration, no SDLC coverage |
| **Junie CLI** | JetBrains model-agnostic CLI agent | Single-agent, BYOK model, no pipeline |
| **OpenHands** | Open-source agent platform, event sourcing | Framework, not product — needs assembly |
| **Factory AI** | Drafter agent for PRs | Narrow scope — only PR generation |
| **Cursor/Windsurf** | AI-augmented IDE | IDE-bound, single-model, no orchestration |

**Gap Kodizm exploits**: Multi-agent orchestration + multi-model routing + full SDLC pipeline + mobile app + built-in task management. Hiçbir rakip bu kombinasyonu sunmuyor.

---

## Agent Personas (Revised)

### 1. Business Analyst (BA)
**Görev**: Kullanıcının ilk temas noktası. Gereksinimleri anlar, sorgular, scope belirler, task'a dönüştürür.
**CLI Backend**: Claude Code (Opus — deep reasoning)
**Çalışma Modu**: Chat-like continuous session. User mesaj yazar → BA analiz eder → soru sorar → user cevaplar → netleşene kadar döner → structured task üretir.
**Input**: User'ın doğal dilde isteği
**Output**: Structured task (title, description, acceptance criteria, type, priority, estimation) + analysis document
**Temel Yetenekler**:
- Codebase exploration (mevcut kodu analiz, ne var ne yok)
- Web search (best practices, benzer implementasyonlar)
- Scope definition (yapılacak/yapılmayacak)
- Clarifying questions (eksik bilgi → user'a soru)
- Task creation via Kodizm MCP tools
- Analysis document writing
**Davranış Kuralları**:
- Asla assumption yapma — emin değilsen sor
- Her task için acceptance criteria yaz (Given/When/Then)
- Mevcut codebase'i incele, conflict olabilecek yerleri belirt
- "Mom Test" lens: davranışa odaklan, varsayıma değil

### 2. Lead Developer
**Görev**: Teknik analiz, architecture kararları, task decomposition, planning.
**CLI Backend**: Claude Code (Opus — architecture reasoning)
**Çalışma Modu**: One-shot analysis. Task alır → codebase analiz eder → plan üretir.
**Input**: BA'nın ürettiği structured task
**Output**: Technical plan (implementation steps, affected files, dependencies, risks, estimates)
**Temel Yetenekler**:
- Deep codebase analysis (dependency graph, impact analysis)
- Architecture decision records (ADR)
- Task decomposition (big task → sub-tasks with dependency order)
- Risk assessment
- Implementation plan with step-by-step instructions
- Technology/pattern recommendation
**Davranış Kuralları**:
- Her plan'da "affected files" listesi ver
- Sub-task'lar arası dependency'leri belirt (DAG)
- Risk'leri severity ile sırala
- Scope'un BA'nın tanımıyla uyumlu olduğunu doğrula, değilse geri dön

### 3. Developer
**Görev**: Kod yazar. Plan'a göre implementation.
**CLI Backend**: Claude Code (Sonnet — fast) veya OpenCode (Gemini/GPT — multi-model)
**Çalışma Modu**: One-shot execution. Plan alır → branch açar → kodu yazar → commit atar.
**Input**: Lead Dev'in planı + task description + acceptance criteria
**Output**: Code changes on feature branch (commits, tests)
**Temel Yetenekler**:
- Code writing, editing, refactoring
- Test writing (TDD red-green-refactor)
- Git operations (branch, commit, push)
- Linting, formatting
- Documentation updates (code comments, README)
**Davranış Kuralları**:
- Feature branch oluştur: `feature/task-{id}`
- Her logical unit'te commit at
- Stuck olursa soru sor (Kodizm üzerinden user'a yansır)
- Projenin CLAUDE.md/project conventions'a uy
- Test yaz — minimum acceptance criteria coverage

### 4. Code Reviewer
**Görev**: Kod kalitesi, security, best practices, bug detection.
**CLI Backend**: Claude Code (Opus — deep analysis) veya OpenCode (GPT — review benchmark'ta güçlü)
**Çalışma Modu**: One-shot review. Developer'ın branch'ini alır → inceler → report üretir.
**Input**: Developer'ın code changes (git diff)
**Output**: Review report (findings + severity) + approval/rejection
**Temel Yetenekler**:
- Code quality analysis (SOLID, DRY, patterns)
- Security review (OWASP top 10)
- Performance analysis
- Test coverage assessment
- Acceptance criteria verification
**Davranış Kuralları**:
- Finding severity: CRITICAL / IMPORTANT / MINOR
- CRITICAL varsa → reject + fix önerisi
- Acceptance criteria karşılanıyor mu kontrol et
- Review report formatı standart

### 5. QA Agent
**Görev**: Test planning, test execution, quality assurance.
**CLI Backend**: Claude Code (Sonnet) veya OpenCode
**Çalışma Modu**: One-shot. Implementation'ı alır → test eder → rapor üretir.
**Input**: Task + code changes + acceptance criteria
**Output**: Test report (pass/fail, coverage, bugs found)
**Temel Yetenekler**:
- Test case generation from acceptance criteria
- Existing test suite execution
- Edge case identification
- Bug report creation (structured: steps to reproduce, expected, actual)
- Regression check
**Davranış Kuralları**:
- Acceptance criteria → test case mapping (her criteria en az 1 test)
- Bug bulursa structured report üretir, task'a ekler
- Test coverage report'u dahil et

### 6. Designer (Post-MVP)
**Görev**: UI/UX design, Figma'da component/page üretimi.
**CLI Backend**: Claude Code (Opus — creative reasoning)
**MCP Tools**: Figma MCP
**Çalışma Modu**: Iterative. Task alır → design.md okur → Figma'da variant'lar üretir → user seçer.
**Input**: Feature/task description + project design.md (design system)
**Output**: Figma frames/components + design decision document
**Temel Yetenekler**:
- Atomic design methodology (atoms → molecules → organisms → templates → pages)
- Design system compliance (project's design.md)
- Figma component creation via MCP
- Multiple variant generation (user seçimi için)
- Responsive layout design
**Davranış Kuralları**:
- Projenin design.md'sine sadık kal (colors, typography, spacing)
- En az 2 variant sun, user seçsin
- Atomic design hiyerarşisine uy

---

## Workflow Architecture (Revised)

### 3-Layer Orchestration (Inspired by research)

```
┌─────────────────────────────────────────┐
│  Layer 1: INTENT & ROUTING              │
│  User request → classify → route        │
│  (Complexity: Simple/Standard/Complex)  │
└──────────────────┬──────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│  Layer 2: PIPELINE EXECUTION            │
│  Stage-based sequential flow            │
│  BA → Lead Dev → Developer → Review → QA│
│  (with approval gates + failure loops)  │
└──────────────────┬──────────────────────┘
                   ↓
┌─────────────────────────────────────────┐
│  Layer 3: MODEL ROUTING                 │
│  Per-agent model selection              │
│  Opus for reasoning, Sonnet for speed   │
│  OpenCode for Gemini/GPT tasks          │
└─────────────────────────────────────────┘
```

### Layer 1: Intent & Routing

User request geldiğinde:

**Simple task** (bug fix, small change, single-file):
→ Skip BA/Lead Dev → Direkt Developer agent'a gider → Code Review → Done

**Standard task** (feature, multi-file, clear scope):
→ BA analyzes → Lead Dev plans → Developer implements → Code Review → Done

**Complex task** (architecture change, new module, unclear scope):
→ BA deep analysis + user Q&A → Lead Dev planning + decomposition → Developer (sub-tasks, potentially parallel) → Code Review → QA → Done

Routing karar mekanizması: İlk olarak user seçer (Simple/Standard/Complex). Opsiyonel: BA agent auto-classify yapabilir.

### Layer 2: Pipeline Execution

#### Task State Machine

```
                    ┌──── reject ────┐
                    ↓                │
Draft → Analysis → Planning → Implementation → Review → Testing → Done
  │         │          │           │               │         │
  └─────────┴──────────┴───────────┴───────────────┴─────────┴→ Failed
```

| State | Agent | Action | Approval Gate? |
|-------|-------|--------|----------------|
| Draft → Analysis | BA | Analyze, clarify, create structured task | Optional |
| Analysis → Planning | Lead Dev | Technical plan, decomposition | Optional |
| Planning → Implementation | Developer | Write code | Auto (configurable) |
| Implementation → Review | Code Reviewer | Review code | Auto |
| Review → Testing | QA | Run tests | Auto |
| Testing → Done | — | All passed | Auto |

**Approval gates**: Project config'te hangi stage'lerde insan onayı gerektiği belirlenir.

#### Failure & Retry Loops

- **Code Review reject** → Developer'a geri döner (max 2 iteration, sonra human escalation)
- **QA fail** → Developer'a geri döner (max 2 iteration)
- **3 fail** → Pipeline durur, human intervention gerekir
- **Budget exceeded** → Hard stop, user'a bildirim

#### Context Passing Between Stages

1. **Shared Git Worktree**: Tüm agent'lar aynı branch üzerinde çalışır. Developer'ın yazdığı kodu Reviewer aynı worktree'de görür.
2. **Task Artifacts**: Her agent'ın ürettiği document (analysis, plan, review report) task'a bağlı, persistent.
3. **Stage Context JSON**: Önceki stage'in summary'si, cost'u, diff'i → sonraki stage'e inject edilir.
4. **Project Knowledge Base**: pgvector — tüm agent'lar okur/yazar.
5. **CLAUDE.md / Project Config**: Project-level instructions → container'a inject.

### Layer 3: Model Routing

| Agent Role | Default Model | CLI Backend | Reasoning |
|------------|---------------|-------------|-----------|
| BA | Claude Opus 4.6 | Claude Code | Deep reasoning, user interaction |
| Lead Dev | Claude Opus 4.6 | Claude Code | Architecture, complex planning |
| Developer | Claude Sonnet 4.6 | Claude Code | Fast, cost-effective coding |
| Developer (alt) | Gemini 3.1 Pro | OpenCode | Frontend/UI tasks, large context |
| Code Reviewer | Claude Opus 4.6 | Claude Code | Deep analysis |
| Code Reviewer (alt) | GPT-5.4 | OpenCode | Strong review benchmark |
| QA | Claude Sonnet 4.6 | Claude Code | Pattern matching, test gen |
| Designer | Claude Opus 4.6 | Claude Code | Creative reasoning + Figma MCP |

**Configurable**: Team admin her role için model override yapabilir.
**Fallback chain**: Primary model unavailable → fallback model → error.

### Execution Model (Per Agent Run)

```
1. Pre-flight checks
   ├── Balance check (team has enough credits?)
   ├── Concurrency check (max N per project)
   └── Token availability (active API key/subscription for provider?)

2. Container start
   ├── docker run -d --entrypoint sleep kodizm/agent-universal infinity
   ├── Mount: project repo (clone), session volume, config files
   ├── Inject: CLAUDE.md, settings.json, API key env var
   └── MCP endpoint configured (agent ↔ Kodizm communication)

3. Agent execution
   ├── docker exec -i container claude -p "prompt" --output-format stream-json
   │   --append-system-prompt "{agent_role_prompt}"
   │   --model {model} --max-turns {N} --max-budget-usd {N}
   ├── NDJSON stream → normalize → WebSocket broadcast → Flutter UI
   └── Agent works: analyzes, codes, writes output...

4. Completion scenarios:

   A) NORMAL COMPLETION (no questions)
      Agent finishes → result event → cost recorded → container stops → done
      Output: files written, structured output, task artifacts

   B) AGENT ASKS QUESTION → 3-Phase Lifecycle:

      ┌─────────────────────────────────────────────────┐
      │  Phase 1: WARM (120 seconds)                    │
      │  Container stays alive. User is watching chat.  │
      │  User answers → agent resumes immediately.      │
      │  Push notification sent to user.                │
      └──────────────────┬────────────────────────────────┘
                         │ no answer in 120s
                         ↓
      ┌─────────────────────────────────────────────────┐
      │  Phase 2: COLD (90 minutes)                     │
      │  Container suspended/stopped.                   │
      │  Session data preserved in volume.              │
      │  User gets reminder notification.               │
      │  User answers → new container starts →          │
      │  session resumed (--resume flag).               │
      └──────────────────┬────────────────────────────────┘
                         │ no answer in 90 min
                         ↓
      ┌─────────────────────────────────────────────────┐
      │  Phase 3: DEAD                                  │
      │  Container fully removed.                       │
      │  Session data still in volume (persistent).     │
      │  User can still answer later →                  │
      │  brand new container + session resume.           │
      │  After 24h: session volume cleaned up.          │
      └─────────────────────────────────────────────────┘

5. Session Persistence
   ├── Claude Code: ~/.claude/projects/{hash}/{session}.jsonl → volume mount
   ├── OpenCode: ~/.local/share/opencode/ → volume mount
   ├── Session ID captured from first run's system/init event
   └── Resume: --resume {session_id} flag on next docker exec
```

### Agent Output Model

Agent'lar "prompt al → execute → output üret → bitir" modeli ile çalışır. Sürekli aktif değil.

**Output türleri:**
- **File-based**: Agent projeye dosya yazar (code, docs, plans). Git diff ile tracked.
- **Structured result**: Agent'ın result event'inde cost, duration, turn count.
- **Task artifacts**: Analysis doc, plan doc, review report — Kodizm MCP tool ile task'a attach.
- **Stream events**: Her NDJSON event persist edilir (StreamEvent model) — conversation history.

**Soru yakalama mekanizması:**
- CLI agent soru sorduğunda elicitation/question event gelir
- Kodizm bu event'i yakalar → TaskRun status: WaitingForInput
- Push notification → Flutter app'e (mobile + web)
- Chat UI'da soru görünür, user cevap yazar
- Cevap → container'a (warm) veya yeni container + resume (cold/dead) ile iletilir

### Concurrency Rules

- Max N agent per project (configurable, default: 3)
- Max 1 agent per task (sequential pipeline)
- Different tasks can run parallel
- Budget check before every dispatch
- Token rotation: fill-first / round-robin / random (configurable)

---

## MVP Workflow (Simplified)

MVP'de full pipeline yok. Sadece **Single Agent Mode**:

```
User → Create Task → Assign Agent Role → Run → Stream → Q&A → Done
```

- User bir task oluşturur (title, description)
- Bir agent role seçer (BA, Developer, etc.)
- "Run" der → agent Docker'da çalışır
- Real-time streaming izler
- Agent soru sorarsa cevaplar
- Agent bitirince → cost kaydedilir, session persist edilir
- Aynı task'ta tekrar "Run" diyebilir (session resume)

Pipeline orchestration (auto BA → Lead Dev → Developer → Review) = **Post-MVP**.

---

## Resolved Questions

1. ✅ **BA chat UX** → Continuous session (MVP). Real-time chat with clarification loop.
2. ✅ **Retry limit** → Max 2 iteration. 3rd fail = human escalation.
3. ✅ **Sub-task parallelism** → Post-MVP. Wave-based parallel (GSD pattern).
4. ✅ **Session resume** → Yes. Claude Code --resume, OpenCode --session. Volume-persisted.
5. ✅ **Config granularity** → Agent-role based. Claude Code agent flag + system prompt. DB-stored, container-injected.
6. ✅ **Budget control** → Team balance (credits). Pre-dispatch check. --max-budget-usd to CLI. MVP: balance tracking only (no payment).
7. ✅ **Model-specific prompt variants** → Full spec, not MVP.
8. ✅ **Container lifecycle** → 3-phase: Warm (120s) → Cold (90min) → Dead (volume preserved, 24h cleanup).
9. ✅ **Multi-account auth** → Admin manages. Subscription + API key. Fill-first/round-robin rotation.
10. ✅ **Category-based decomposition** → Full spec (oh-my-openagents pattern). Not MVP.

## All Questions Resolved

11. ✅ **MCP tools** → Agent-specific. PM: task CRUD. All: knowledge read/write/search, notes, task details. Standardized task sections (analysis, plan, dev report, review report, design needs, docs, comments).
12. ✅ **Git strategy** → Task branch from main/master (project setting). SSH key for private repos. Remote Docker host support (SCP/clone).
13. ✅ **Docker image** → Single universal image (claude + opencode).
14. ✅ **Notifications** → MVP: no push. Events fire via WebSocket (run complete, question, status change). Flutter listens.
15. ✅ **Admin UI** → Filament 4 (admin). Flutter (user-facing).
