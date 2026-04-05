# Create Kodizm Agent

You are building a Kodizm agent definition. Two artifact types exist — determine which from the user's request:

| Type | Artifact | Location | Injected Via |
|------|----------|----------|-------------|
| `cc-agent` | CC subagent .md (YAML frontmatter + prompt) | Kodizm API: `resources/agents/{Name}.md` | CC `loadAgentsDir` — shadows/extends built-in agents |
| `role-prompt` | Blade system prompt + optional user prompt | Kodizm API: `resources/views/prompts/system/{slug}.blade.php` | `--system-prompt` CLI option via PromptRenderer |

If ambiguous, ask. Common signals:
- "explore agent", "plan agent", "subagent" → `cc-agent`
- "developer role", "reviewer role", "PM agent", "autonomous agent" → `role-prompt`

The user's request: $ARGUMENTS

---

## Phase 1: Research (MANDATORY — do NOT skip)

Spawn these research agents IN PARALLEL in a single message. Do not proceed to Phase 2 until ALL complete.

### 1A: CC Built-in Agent Analysis

Spawn an explore agent to read from the **clean CC source** at `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code`:

- `tools/AgentTool/built-in/` — Read ALL built-in agent definitions. Find the one closest to the requested agent role.
- `tools/AgentTool/prompt.ts` — What CC injects into the Agent tool description (agent listing, usage notes). This is what the ORCHESTRATOR sees.
- `tools/AgentTool/loadAgentsDir.ts` lines 106-165 — `AgentDefinition` type: all frontmatter fields, how custom agents override built-ins (Map.set last-wins). Full schema at lines 73-99.
- `constants/prompts.ts` lines 758-791 — `DEFAULT_AGENT_PROMPT` and `enhanceSystemPromptWithEnvDetails()`. AUTO-INJECTED into every subagent. **Never duplicate:**
  - "use absolute file paths", "share file paths", "avoid using emojis", "do not use a colon before tool calls"
  - Working directory, platform, OS info, model info
- `tools/AgentTool/runAgent.ts` lines 380-410 — How `omitClaudeMd` and `gitStatus` stripping work.
- `tools/AgentTool/runAgent.ts` lines 248-329 — Subagent spawning: fresh context window, zero parent history, cloned file cache, isolated state.
- `tools/AgentTool/runAgent.ts` lines 500-502 — Tool filtering: allowlist/denylist resolution via `resolveAgentTools()`.
- `tools/AgentTool/runAgent.ts` lines 340-345 — Model resolution: tool param > frontmatter > parent model.
- `context.ts` lines 155-189 — `getUserContext()`: CLAUDE.md loaded as userContext (first user message), not system prompt.

**Report**: What CC provides automatically, closest built-in agent, context isolation model, what custom agent must NOT repeat.

### 1B: ac Plugin Agent Patterns

Spawn an explore agent to read from `/Users/anilcan/Code/kodizm/api/references/ac/plugins/ac/agents/`:

- Read agent file(s) most similar to the requested role.
- Read `explore.md` as baseline reference for format and conciseness.
- Extract PATTERNS (not literal content): frontmatter structure, success/failure conditions, output format contracts, model routing philosophy.

**Report**: Relevant agent definitions (full content), design patterns, model/effort recommendations.

### 1C: oh-my-openagent Reference

Spawn an explore agent to search `/Users/anilcan/Code/kodizm/api/references/oh-my-openagent/src/agents/`:

- Find the agent most similar to the requested role.
- Read its prompt and factory function.
- Check `dynamic-agent-prompt-builder.ts` for shared patterns.
- Check `AGENTS.md` for conventions.

**Report**: Closest agent's prompt, notable patterns, anything that informs the new agent.

### 1D: Kodizm Context

Spawn an explore agent to read:

- `/Users/anilcan/Code/kodizm/app/PROJECT.md` — Kodizm mission, features, agent roles.
- `/Users/anilcan/Code/kodizm/api/resources/agents/` — ALL existing CC agent .md files.
- `/Users/anilcan/Code/kodizm/api/resources/views/prompts/` — ALL existing Blade templates (system/, user/, claude-md.blade.php).
- `/Users/anilcan/Code/kodizm/api/app/Services/PromptRenderer.php` — How system prompts + CLAUDE.md are rendered. Note the Blade bindings: `$project`, `$task`, `$user`, `$team`, `$role`, `$conversation`.
- `/Users/anilcan/Code/kodizm/api/app/Services/NativeSessionEngine.php` lines 695-760 — How CLI options are built (model, max_turns, allowed/disallowed tools, systemPrompt injection).

**Report**: Full content of ALL existing agents/prompts, platform architecture, available Blade bindings, what the platform already controls.

---

## Phase 2: Synthesize (YOU do this — do NOT delegate)

After ALL research agents return, YOU must synthesize.

### 2A: Deduplication Checklist

Cross-reference research results. The agent prompt must NOT include:

**Both artifact types — CC auto-injects:**

| CC Auto-Injects | Do NOT Write |
|-----------------|-------------|
| `enhanceSystemPromptWithEnvDetails()` | Absolute path instructions, emoji rules, colon-before-tool rules, env info |
| Tool schemas (Grep, Glob, Read, Bash) | Tool usage tutorials (output_mode, head_limit, offset/limit) |
| `DEFAULT_AGENT_PROMPT` (if no custom prompt) | "Complete the task fully" boilerplate |

**For `role-prompt` only — claude-md.blade.php already provides:**

| claude-md.blade.php Provides | Do NOT Repeat in System Prompt |
|------------------------------|-------------------------------|
| Container environment (Ubuntu, tools, services, runtimes) | Container description, available tools list |
| Project name, tech stack, default branch, repos table | Project context (say "in your CLAUDE.md" instead) |
| MCP tools table (all tools with descriptions) | MCP tool reference or tutorials |
| Agent Delegation (Explore, librarian, challenger, feasibility) | General-purpose subagent descriptions |
| Memory guidance | Memory instructions |
| Skills reference (`my-coding`, `my-language`) | Skill application rules (but DO reference: "Apply `my-coding` skill") |
| Rules (scope, tests, commits, secrets, dependencies, blockers, ambiguity) | Generic working rules |
| Tool Usage (Read not cat, Edit not sed, Glob not find, Grep not grep, Bash for system only) | Tool preference rules, parallel call guidance |
| Safety (reversible=proceed, destructive=confirm, no secrets) | Action safety rules |
| Output (lead with action, concise, milestones/blockers) | Output style rules |
| Scope (only what requested, no bonus refactors, no premature abstractions) | Scope discipline rules |

**Pattern from existing role prompts**: Start with "Project details, MCP tool reference, available agents, and working rules are in your CLAUDE.md."

**For `cc-agent` only — CLAUDE.md IS injected into ALL custom subagents:**

CC's `omitClaudeMd` flag only works for built-in agents (Explore, Plan). Custom agents from `.claude/agents/` ALWAYS receive CLAUDE.md. In Kodizm containers, CLAUDE.md = rendered `claude-md.blade.php`. So cc-agent prompts must also deduplicate against it:

| CLAUDE.md (= claude-md.blade.php) Provides | Do NOT Repeat in cc-agent Prompt |
|---------------------------------------------|----------------------------------|
| Container environment (Ubuntu, tools, services, runtimes) | Container description, tool availability |
| Project name, tech stack, default branch, repos table | Project context |
| MCP tools table (all tools with descriptions) | MCP tool reference or tutorials |
| Agent Delegation (general-purpose agents) | When-to-use guidance for Explore/librarian/etc. |
| Rules (scope, tests, commits, secrets, dependencies) | Generic working rules |
| Skills reference (`my-coding`, `my-language`) | Skill instructions |
| Orchestrator's Agent tool description | Agent listing, usage notes |
| Tool Usage (Read not cat, Edit not sed, parallel calls) | Tool preference rules |
| Safety (reversible=proceed, destructive=confirm, no secrets) | Action safety rules |
| Output (lead with action, concise, milestones/blockers) | Output style rules |
| Scope (only what requested, no bonus refactors) | Scope discipline rules |

### Prompt Composition (what the LLM sees)

Understanding the full prompt stack prevents duplication and ensures each layer carries only its unique content.

**For role agents** (main CLI session via `--system-prompt`):
```
[CC attribution header + CLI prefix]              ← non-negotiable, always present
+ [--system-prompt: our Blade role prompt]         ← REPLACES CC's default system prompt
+ [userContext: CLAUDE.md = claude-md.blade.php]   ← injected via <system-reminder> in messages
```

**For subagents** (CC Agent tool via `.claude/agents/*.md`):
```
[agent .md systemPrompt + enhanceSystemPromptWithEnvDetails()]  ← agent's prompt + CC env injection
+ [userContext: CLAUDE.md = claude-md.blade.php]                ← always injected for custom agents
+ [systemContext: gitStatus]                                    ← unless stripped (Explore/Plan)
```

### 2A-2: CC Subagent Context Architecture

Understanding what CC automatically provides to subagents is **critical** for writing non-redundant, effective prompts.

#### Context Isolation Model

**Subagents start with a FRESH context window.** They receive ZERO parent conversation history. The orchestrator must provide a complete, self-contained briefing in the Agent tool prompt — no "based on what we discussed" or "as shown above."

Each subagent gets:
- Fresh message history (only the task prompt from orchestrator)
- Cloned file read cache (100MB LRU, not shared back to parent)
- Independent abort controller
- Isolated mutable state (subagent's `setAppState()` is a no-op — changes don't leak to parent)

**Results flow one-way**: Subagent yields messages back to parent. Parent's conversation is never updated with subagent internals — only the final result summary.

#### What Subagents Receive Automatically (DO NOT duplicate)

| Layer | Source | Content | Injection Point |
|-------|--------|---------|-----------------|
| **System Prompt** | Agent .md content | The markdown body of the agent definition | `getSystemPrompt()` closure |
| **Env Details** | `enhanceSystemPromptWithEnvDetails()` | Notes (absolute paths, no emojis, no colons) + env info (cwd, platform, shell, OS, model, cutoff) | Appended to system prompt array |
| **User Context** | `getUserContext()` | CLAUDE.md (= rendered claude-md.blade.php) + currentDate | Prepended as first user message via `<system-reminder>` |
| **System Context** | `getSystemContext()` | Git status snapshot (stale from session start, up to 40KB) | Appended to system prompt |
| **MCP Servers** | Parent inheritance | All parent MCP connections + agent-specific (if `mcpServers` in frontmatter) | Merged tool list |
| **Tool Schemas** | `resolveAgentTools()` | Full JSON schemas for all allowed tools | Part of API call |

#### What Subagents DO NOT Receive (must be explicit)

| Missing | Implication for Prompt Writing |
|---------|-------------------------------|
| Parent conversation history | Prompt must be fully self-contained — include all relevant context, file paths, findings |
| Other agents' outputs | If agent A's findings inform agent B, the orchestrator must relay them in agent B's prompt |
| Task-specific context | MCP task details, acceptance criteria, etc. must be in the prompt if needed |
| Parent's working decisions | Architecture choices, approach rationale — include if the subagent needs to align |

#### CLAUDE.md Injection Details

- CLAUDE.md is **userContext** (first user message), NOT part of the system prompt
- Custom agents (`.claude/agents/*.md`) **always** receive CLAUDE.md — `omitClaudeMd` frontmatter field is only honored for built-in agents (Explore, Plan) behind a feature flag
- In Kodizm containers: CLAUDE.md = rendered `claude-md.blade.php` (container info, project, MCP tools, rules, tool usage, safety, output, scope)
- `CLAUDE_CODE_DISABLE_CLAUDE_MDS` env var or `--bare` mode can disable CLAUDE.md loading entirely

#### Model & Effort Inheritance

**Model resolution precedence** (highest → lowest):
1. Orchestrator's `model` param in Agent tool call (runtime override)
2. Agent definition's `model` frontmatter field
3. Parent session's `mainLoopModel` (inherited)

**Effort inheritance**: If agent defines `effort` in frontmatter → override. Otherwise → inherit parent's effort level.

This means a single agent definition can serve multiple tiers — the orchestrator overrides the model at runtime:
```
Agent(subagent_type="plan-worker", model="haiku", ...)   // quick tier
Agent(subagent_type="plan-worker", model="sonnet", ...)   // mid tier
Agent(subagent_type="plan-worker", model="opus", ...)     // senior tier
```

#### Agent Spawning Recursion

- Subagents CAN spawn other subagents (depth tracked via `queryTracking.depth`)
- Fork subagents CANNOT spawn forks (hard error)
- Each nested subagent gets its own fresh context window
- No explicit depth limit — only practical limits from context exhaustion

#### Git Status Behavior

- Parent's git status is captured once at session start (memoized, labeled "stale")
- Most subagents inherit this stale snapshot
- Explore and Plan agents have git status **stripped** — they run `git status` fresh themselves
- Custom agents receive the parent's stale snapshot unless they explicitly re-run git commands

### 2B: Design Decisions

#### For `cc-agent` (CC subagent .md):

**Model routing**: `haiku` (search/fast), `sonnet` (balanced/review), `opus` (high-judgment/adversarial)

**Effort**: `low` (search), `medium` (most work), `high` (deep analysis)

**Tool Access — allowlist vs denylist (CRITICAL):**

| Mode | Frontmatter | Effect | MCP Tools |
|------|-------------|--------|-----------|
| **Allowlist** | `tools: Glob, Grep, Read` | ONLY listed tools available | **EXCLUDED** unless explicitly listed (you can't list MCP tools by name) |
| **Denylist** | `disallowedTools: Write, Edit, Agent` | ALL tools MINUS listed ones | **INCLUDED** automatically |
| **Both** | `tools: X` + `disallowedTools: Y` | Allowlist filtered by denylist | Follows allowlist rule |
| **Neither** | (omit both) | ALL tools available | **INCLUDED** |

**Rule**: If the agent needs MCP tools (resolve-library, search-docs, get-task, etc.), use `disallowedTools` only (denylist mode). An allowlist EXCLUDES MCP tools.

Common patterns:
- Read-only, no MCP needed: `tools: Glob, Grep, LS, Read, Bash` (allowlist)
- Read-only, MCP needed: `disallowedTools: Write, Edit, NotebookEdit, Agent` (denylist)
- Full access: `disallowedTools: Agent, NotebookEdit` (denylist, blocks spawning)
- Full access: `disallowedTools: Agent` or omit both fields entirely

**Color**: `green` (search/implementation), `yellow` (lint/review), `red` (security/adversarial), `blue` (docs), `cyan` (analysis)

**Agent Naming Conventions:**
- To shadow/replace a CC built-in: use the EXACT same `name` (case-sensitive, e.g., `Explore`)
- New agents: kebab-case (e.g., `plan-reviewer`)
- Related agents: use a shared prefix (e.g., `plan-reviewer`, `plan-worker`, `plan-verifier`, `plan-code-review`)
- The `name` field in frontmatter MUST match the filename (without `.md`)

**claude-md Agent Delegation — what goes there vs role prompts:**
- `claude-md.blade.php` Agent Delegation section: ONLY general-purpose research agents usable by ALL roles (Explore, librarian, challenger, feasibility)
- Purpose-specific subagents (plan-worker, plan-code-review, etc.): belong in the role prompt that uses them, NOT in claude-md
- Rationale: Not every role needs to know about plan-specific agents. Keeps claude-md concise (every token costs money on every message)

#### For `role-prompt` (Blade system prompt):

**Structure**: Identity → Capabilities & Constraints (CAN/CANNOT/MUST) → Workflow → Output Format

**Blade bindings available**: `$project`, `$task`, `$user`, `$team`, `$role`, `$conversation` — use for dynamic content.

**Blade syntax**: `@if($project)`, `@foreach`, `@php ... @endphp`, `{{ $var }}`, `{!! $html !!}` — use sparingly, only when content genuinely varies per session.

**User prompt** (optional): Create `resources/views/prompts/user/{slug}.blade.php` only for autonomous agents that need an initial instruction. Keep it 1-3 lines.

**Role slug**: Must match the AgentRole's `slug` field exactly — `prompts.system.{slug}` is how PromptRenderer resolves the view.

**Subagent briefing guidance**: When a role-prompt orchestrates subagents, include clear briefing format in the workflow. Subagents have ZERO parent context — the orchestrator must provide self-contained prompts with all context, file paths, and constraints.

### 2C: Prompt Architecture

#### For `cc-agent` — 40-80 lines:

**Context awareness**: The subagent starts with a FRESH context window. It has NO access to the parent's conversation. The orchestrator's Agent tool prompt is the ONLY briefing it receives. Write the agent prompt assuming it will be combined with: (1) enhanceSystemPromptWithEnvDetails (env info, notes), (2) CLAUDE.md as userContext (project, container, MCP tools, rules). The prompt must define what the agent IS and HOW it works — not repeat what CLAUDE.md already provides.

1. **Identity** (1-2 sentences)
2. **Delivery contract** (structured output format)
3. **Execution directives** (HOW to approach work)
4. **Failure conditions** (explicit contract)
5. **Constraints** (hard boundaries)

**Project conventions**: The worker/implementer agents will automatically receive the target project's CLAUDE.md and `.claude/rules/` files. These contain project-specific conventions (naming, patterns, test commands, framework rules). The agent prompt should reference "Follow project CLAUDE.md and .claude/rules/ conventions" — but must NOT repeat or assume specific conventions, as these vary per project.

#### For `role-prompt` — 80-200 lines:

CC's default identity is NOT present — the role prompt IS the entire system prompt. Identity must be definitive, not supplementary. Pattern: `"You are the {Role Name} — {primary responsibility}. {What you deliver}. {Core restriction}."`

**Context awareness**: The role agent IS the main session. It receives: (1) CC attribution header + CLI prefix (non-negotiable), (2) this Blade prompt as `--system-prompt` (REPLACES CC's default), (3) CLAUDE.md as userContext via `<system-reminder>`. The role prompt defines identity and workflow. CLAUDE.md provides platform context (container, project, MCP tools, rules). When this agent spawns subagents via the Agent tool, those subagents get FRESH context — they see only the orchestrator's prompt + their own CLAUDE.md, never this role's conversation history.

1. **Identity** (2-3 sentences) — strong, definitive role identity + reference to CLAUDE.md for platform context
2. **Capabilities & Constraints** — explicit CAN / CANNOT / MUST lists
3. **Workflow** — step-by-step for the role's primary task (load context → investigate → act → report)
4. **Output format** — structured deliverable format (for MCP task sections)
5. **Edge cases** — complexity handling, ambiguity resolution

---

## Phase 3: Generate

### For `cc-agent`:

Agent .md files are injected into containers at `/home/agent/.claude/agents/` by `ContainerBootstrapService.injectAgents()`. CC's `loadAgentsDir` auto-discovers them. Custom agents override built-ins via Map.set (last-wins).

Write to `/Users/anilcan/Code/kodizm/api/resources/agents/{agent-name}.md`:

```markdown
---
name: {agent-name}
description: "{One-line for orchestrator — when to use + what it returns}"
model: {haiku|sonnet|opus}
effort: {low|medium|high}
disallowedTools: {comma-separated denylist — prefer this over tools allowlist}
color: {green|yellow|red|blue|cyan}
---

{Agent system prompt — 40-80 lines, following 2C architecture}
```

**Frontmatter fields reference** (use sparingly — only what's needed):

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | kebab-case for new, PascalCase to shadow built-in. Must match filename |
| `description` | Yes | One-line — what the ORCHESTRATOR reads to decide when to use this agent |
| `model` | Yes | Default model. Orchestrator can override via `model` param at runtime |
| `effort` | No | `low`/`medium`/`high`. Omit to inherit parent's effort |
| `tools` | No | Allowlist — EXCLUDES MCP tools. Use `disallowedTools` instead if MCP needed |
| `disallowedTools` | No | Denylist — gives ALL tools (including MCP) minus listed. Preferred approach |
| `color` | No | Terminal color for agent output |
| `isolation` | No | `worktree` — isolated git worktree per agent. Use for parallel file-writing agents |
| `memory` | No | `user`/`project`/`local` — persistent memory scope |
| `background` | No | `true` — always run as background task |
| `permissionMode` | No | `bypassPermissions`/`plan`/`default`. Parent's strict mode overrides agent's |
| `skills` | No | Comma-separated skill names to preload |
| `mcpServers` | No | Additional MCP server connections (JSON array) |
| `initialPrompt` | No | Prepended to first user turn |

**DO NOT use `maxTurns`** unless explicitly asked or the agent has a known runaway risk. CC handles turn limits adequately via context exhaustion and abort controllers.

### For `role-prompt`:

Write system prompt to `/Users/anilcan/Code/kodizm/api/resources/views/prompts/system/{slug}.blade.php`:

```blade
## Identity

You are the {Role Name} — {primary responsibility}. {What you deliver}. {Core restriction}.
Project details, MCP tool reference, available agents, and working rules are in your CLAUDE.md.

## Capabilities & Constraints

**You CAN:**
- {capability with tool names}

**You CANNOT:**
- {hard constraint — explain alternative}

**You MUST:**
- {non-negotiable behavior}

## Workflow

{Step-by-step for primary task}

## {Deliverable} Format

{Structured output template — for task sections, review reports, plans, etc.}
```

If the role needs an autonomous initial instruction, also write `/Users/anilcan/Code/kodizm/api/resources/views/prompts/user/{slug}.blade.php` (1-3 lines).

---

## Quality Checklist

### Shared (both types)

- [ ] No duplication with CC auto-injected content (2A checklist)
- [ ] Prompt addresses the agent (LLM), not the orchestrator
- [ ] Output format is structured and parseable
- [ ] Failure conditions or success criteria are explicit
- [ ] Read ALL existing agents/prompts for consistency before writing

### `cc-agent` specific

- [ ] Frontmatter fields match CC's `AgentDefinition` type exactly
- [ ] `name`: PascalCase if shadowing built-in, kebab-case if new. Matches filename
- [ ] `description` is what the ORCHESTRATOR reads to decide when to use this agent
- [ ] No duplication with CLAUDE.md content (always loaded as userContext for custom agents)
- [ ] No duplication with `enhanceSystemPromptWithEnvDetails()` (env info, notes — auto-injected)
- [ ] Prompt is self-contained — subagent has zero parent conversation history
- [ ] Total prompt under 80 lines
- [ ] Model choice justified by role complexity
- [ ] Tool access mode chosen correctly: denylist if MCP needed, allowlist if MCP not needed
- [ ] Related agents share a naming prefix (e.g., `plan-*`)
- [ ] No `maxTurns` unless explicitly requested or agent has known runaway risk

### `role-prompt` specific

- [ ] No duplication with `claude-md.blade.php` (2A checklist — MCP tools, project info, container, rules)
- [ ] Opens with "...in your CLAUDE.md" reference for platform context
- [ ] CAN/CANNOT/MUST constraints are explicit and complete
- [ ] Workflow references MCP tool names accurately (get-task, create-task-section, report-progress, etc.)
- [ ] Blade syntax only where content genuinely varies per session
- [ ] Slug matches intended AgentRole slug
- [ ] User prompt created only if role runs autonomously
- [ ] If role spawns subagents: workflow includes complete briefing format (subagents have zero parent context)
- [ ] Purpose-specific subagents listed in role prompt, NOT in claude-md Agent Delegation

---

## Reference Quick Links

| Source | Path | What to Look For |
|--------|------|-----------------|
| CC Clean Source | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code` | Built-in agents, auto-injected prompts, agent system |
| CC runAgent.ts | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code/tools/AgentTool/runAgent.ts` | Subagent lifecycle, context isolation, CLAUDE.md omission, tool filtering |
| CC loadAgentsDir.ts | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code/tools/AgentTool/loadAgentsDir.ts` | Frontmatter schema (lines 73-99), parsing, deduplication |
| CC prompt.ts | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code/tools/AgentTool/prompt.ts` | Agent tool description for orchestrator, agent listing format |
| CC prompts.ts | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code/constants/prompts.ts` | enhanceSystemPromptWithEnvDetails, DEFAULT_AGENT_PROMPT, computeEnvInfo |
| CC context.ts | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-source-code/context.ts` | getUserContext (CLAUDE.md loading), getSystemContext (git status) |
| CC Minified Source | `/Users/anilcan/Code/kodizm/api/references/claude-code-cli-reversed` | Fallback if clean source missing |
| ac Plugin Agents | `/Users/anilcan/Code/kodizm/api/references/ac/plugins/ac/agents/` | Agent design patterns, format reference |
| oh-my-openagent | `/Users/anilcan/Code/kodizm/api/references/oh-my-openagent/src/agents/` | Alternative agent patterns |
| Kodizm Agents | `/Users/anilcan/Code/kodizm/api/resources/agents/` | Existing CC agent overrides |
| Kodizm Prompts | `/Users/anilcan/Code/kodizm/api/resources/views/prompts/` | Existing role prompts + claude-md template |
| PromptRenderer | `/Users/anilcan/Code/kodizm/api/app/Services/PromptRenderer.php` | Blade rendering + bindings |
| NativeSessionEngine | `/Users/anilcan/Code/kodizm/api/app/Services/NativeSessionEngine.php` | CLI options, systemPrompt injection |
| Kodizm App | `/Users/anilcan/Code/kodizm/app/PROJECT.md` | Platform mission, features |
