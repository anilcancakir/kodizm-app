# Spec 03 — Agent System

> Agent roles, AI tokens, CLI backend strategy pattern.
> Dependencies: Spec 01 (Platform Core) must be complete.

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Agent Roles | AgentRole model + migration + factory + policy + default seeder (5 roles), CRUD API, Filament resource |
| 2 | AI Tokens | AiToken model + migration + factory + policy, CRUD API, TokenRotationService |
| 3 | CLI Backend Strategy | CliBackend enum, CliBackendStrategy interface, ClaudeCodeStrategy implementation, config files |

## Dependencies on Other Specs

- **Spec 01 — Platform Core**: Team model (agent roles and tokens belong to teams), auth (all endpoints require auth), TeamRole permissions. **Note**: User and Team models come from magic-starter and are extended by Kodizm.

## Data Models

### AgentRole
```
agent_roles
├── id: uuid PK
├── team_id: uuid FK → teams nullable     // null = system-level default
├── project_id: uuid FK → projects nullable // null = team-wide or system-level
├── parent_id: uuid FK → agent_roles nullable // system default this was cloned from
├── name: string                     // "Business Analyst", "Lead Developer", etc.
├── slug: string                     // "ba", "lead-dev", "developer", etc.
├── description: text nullable
├── cli_backend: enum(claude-code, opencode)
├── preferred_model: string nullable  // 'claude-sonnet-4-6', 'gemini-3.1-pro'
├── system_prompt: text nullable      // agent persona instructions (base prompt)
├── prompt_append: text nullable      // team/project-level prompt additions (appended to system_prompt)
├── backend_config: json nullable     // per-backend config (see below)
├── tool_permissions: json nullable   // allowed MCP tools for this role
├── scope: enum(system, team, project) default 'team'
├── is_active: boolean default true
├── sort_order: integer default 0
├── timestamps
└── soft_deletes
```

**Scope hierarchy** (full design, NOT enforced in MVP):
- **System-level** (`scope: system`, `team_id: null`): Default agents defined by Kodizm admins. Seeded on install. Cannot be deleted by users. Serve as templates.
- **Team-level** (`scope: team`, `team_id: set`): Cloned from system defaults or created custom. Team owner/admin can edit all fields.
- **Project-level** (`scope: project`, `project_id: set`): Further customization for a specific project. Inherits team config.

**Prompt resolution** (runtime, full scope):
```
final_prompt = parent.system_prompt + "\n---\n" + self.prompt_append (team) + "\n---\n" + child.prompt_append (project)
```

**MVP behavior**: System defaults are seeded per team (cloned to team scope on team creation). Teams can edit the full agent config including `system_prompt`. No project-level override. No system-level read-only enforcement. `prompt_append` and scope hierarchy are post-MVP features. Include ALL fields in migration for forward compatibility.

**backend_config JSON schema**:
```json
{
    "claude-code": {
        "claude_md": "Custom CLAUDE.md content for this agent...",
        "model_fallbacks": ["claude-opus-4-6"],
        "allowed_tools": ["Bash(npm:*)", "Read", "Write", "Edit"],
        "max_turns": 50,
        "max_budget_usd": 5.00,
        "mcp_servers": {}
    },
    "opencode": {
        "custom_instructions": "Custom instructions...",
        "model_fallbacks": ["gpt-5.4"],
        "tools": ["bash", "read", "write"]
    }
}
```

**Database indexes**:
```
agent_roles: (team_id, scope), (parent_id)
```

### AiToken
```
ai_tokens
├── id: uuid PK
├── team_id: uuid FK → teams
├── provider: enum(anthropic, openai, google, openrouter)
├── auth_type: enum(api_key, subscription)
├── label: string nullable              // "Claude Max Account #1", "OpenAI Production Key"
├── credentials: text encrypted         // API key or subscription token
├── status: enum(active, inactive, rate_limited, expired)
├── rotation_algorithm: enum(fill_first, round_robin, random) default fill_first
├── last_used_at: timestamp nullable
├── usage_count: bigint default 0
├── cooldown_until: timestamp nullable  // rate limit cooldown
├── health_checked_at: timestamp nullable
├── settings: json nullable             // provider-specific settings
├── timestamps
└── soft_deletes
```

**Database indexes**:
```
ai_tokens: (team_id, provider, status)
```

## Relevant Enums

```php
enum AiProvider: string
{
    case Anthropic = 'anthropic';
    case OpenAi = 'openai';
    case Google = 'google';
    case OpenRouter = 'openrouter';
}

enum CliBackend: string
{
    case ClaudeCode = 'claude_code';
    case OpenCode = 'opencode';
}

enum AuthType: string
{
    case ApiKey = 'api_key';
    case Subscription = 'subscription';
}

enum TokenStatus: string
{
    case Active = 'active';
    case Inactive = 'inactive';
    case RateLimited = 'rate_limited';
    case Expired = 'expired';
}

enum RotationAlgorithm: string
{
    case FillFirst = 'fill_first';
    case RoundRobin = 'round_robin';
    case Random = 'random';
}

enum AgentScope: string
{
    case System = 'system';
    case Team = 'team';
    case Project = 'project';
}
```

## Business Rules

### Agent Roles
- MVP: 5 default agent roles seeded per team on team creation (Designer is post-MVP).
- Teams can edit all agent fields in MVP (no read-only system prompt enforcement).
- Teams can create custom agent roles.
- Agent role slug must be unique within team scope.
- Soft deletes: agent roles referenced by task runs cannot be hard deleted.

### AI Tokens
- Tokens are scoped to a team.
- Credentials are encrypted at rest.
- MVP: Only `anthropic` provider tokens are functional.
- Token rotation selects the best available token based on the configured algorithm.
- Rate-limited tokens auto-recover after cooldown expires.
- Soft deletes on AiToken model.

### Token Rotation
- `fill_first`: Pick the token with the lowest `usage_count`.
- `round_robin`: Pick the token with the oldest `last_used_at`.
- `random`: Random selection from available tokens.
- Exclude tokens where `status != active` or `cooldown_until > now()`.
