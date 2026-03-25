# Wave 1 — Agent Roles

> Spec: 03-Agent System
> Dependencies: Spec 01 (Platform Core) must be complete

## Deliverables

- [ ] AgentRole model + migration + factory + policy
- [ ] AgentScope enum
- [ ] CliBackend enum
- [ ] Default agent roles seeder (5 roles, seeded per team)
- [ ] Seed default roles on team creation (listener/observer)
- [ ] Agent roles CRUD API
- [ ] Filament AgentRole resource
- [ ] Feature tests for all endpoints
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## AgentRole Schema

```
agent_roles
├── id: uuid PK
├── team_id: uuid FK → teams nullable     // null = system-level default
├── project_id: uuid FK → projects nullable // null = team-wide or system-level
├── parent_id: uuid FK → agent_roles nullable // system default this was cloned from
├── name: string                     // "Business Analyst", "Lead Developer", etc.
├── slug: string                     // "ba", "lead-dev", "developer", etc.
├── description: text nullable
├── cli_backend: enum(claude_code, opencode)
├── preferred_model: string nullable  // 'claude-sonnet-4-6', 'gemini-3.1-pro'
├── system_prompt: text nullable      // agent persona instructions (base prompt)
├── prompt_append: text nullable      // team/project-level prompt additions (POST-MVP)
├── backend_config: json nullable     // per-backend config (see below)
├── tool_permissions: json nullable   // allowed MCP tools for this role
├── scope: enum(system, team, project) default 'team'
├── is_active: boolean default true
├── sort_order: integer default 0
├── timestamps
└── soft_deletes
```

**Migration notes**:
- `team_id` FK nullable, references `teams.id`, `nullOnDelete`.
- `project_id` FK nullable, references `projects.id`, `nullOnDelete`.
- `parent_id` FK nullable, self-referencing `agent_roles.id`, `nullOnDelete`.
- Composite index: `(team_id, scope)`.
- Index on: `(parent_id)`.
- `cli_backend` stored as string column (enum cast in model).
- `scope` stored as string column (enum cast in model).
- Include ALL fields in migration — even post-MVP ones like `prompt_append`, `project_id`, `parent_id`, `scope`.

**Model casts**:
```php
protected function casts(): array
{
    return [
        'cli_backend' => CliBackend::class,
        'scope' => AgentScope::class,
        'backend_config' => 'array',
        'tool_permissions' => 'array',
        'is_active' => 'boolean',
    ];
}
```

**MVP behavior**: All seeded roles have `scope: team`, `team_id: set`, `parent_id: null`, `project_id: null`, `prompt_append: null`. Teams can edit ALL fields including `system_prompt`. No hierarchy enforcement. No system-level read-only prompts. The `scope`, `parent_id`, and `prompt_append` fields exist in the DB but are not functionally used in MVP.

## Default Agent Roles

Seeded per team on team creation. These 5 roles (Designer is post-MVP):

| # | Name | Slug | CLI Backend | Preferred Model | Purpose | sort_order |
|---|------|------|-------------|-----------------|---------|------------|
| 1 | Business Analyst | ba | claude_code | claude-opus-4-6 | Requirements, analysis, task creation | 1 |
| 2 | Lead Developer | lead-dev | claude_code | claude-opus-4-6 | Architecture, planning, decomposition | 2 |
| 3 | Developer | developer | claude_code | claude-sonnet-4-6 | Implementation, coding, testing | 3 |
| 4 | Code Reviewer | code-reviewer | claude_code | claude-opus-4-6 | Code quality, security, best practices | 4 |
| 5 | QA Engineer | qa | claude_code | claude-sonnet-4-6 | Test planning, execution, verification | 5 |

**System prompts** for each role should be substantial and role-specific. Define them in the seeder or a config file. Example structure:

```php
// database/seeders/data/agent-role-prompts.php or config
return [
    'ba' => <<<'PROMPT'
    You are a Business Analyst for the {project_name} project.
    Your job is to analyze requirements, clarify ambiguities, and produce structured task specifications.
    ...
    PROMPT,
    // ... etc.
];
```

**Default backend_config** for each role:
```json
{
    "claude-code": {
        "max_turns": 50,
        "max_budget_usd": 5.00,
        "allowed_tools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep"],
        "model_fallbacks": [],
        "mcp_servers": {}
    }
}
```

Specific overrides per role:
- **BA**: `max_turns: 30`, `max_budget_usd: 3.00`
- **Lead Developer**: `max_turns: 50`, `max_budget_usd: 5.00`
- **Developer**: `max_turns: 100`, `max_budget_usd: 10.00`
- **Code Reviewer**: `max_turns: 30`, `max_budget_usd: 3.00`
- **QA Engineer**: `max_turns: 50`, `max_budget_usd: 5.00`

## Seeding on Team Creation

When a new Team is created (including the auto-created personal team on registration), seed the 5 default agent roles:

```php
// Listener: SeedDefaultAgentRoles
// Listens to: TeamCreated event
// Action: Create 5 AgentRole records for the new team
```

## API Endpoints

### GET /api/teams/{team}/agent-roles

List all agent roles for a team. Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
- `active_only` (optional, boolean): Filter to `is_active = true`

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "team_id": 1,
            "project_id": null,
            "parent_id": null,
            "name": "Business Analyst",
            "slug": "ba",
            "description": "Requirements analysis and task specification",
            "cli_backend": "claude_code",
            "preferred_model": "claude-opus-4-6",
            "system_prompt": "You are a Business Analyst...",
            "prompt_append": null,
            "backend_config": {
                "claude-code": {
                    "max_turns": 30,
                    "max_budget_usd": 3.00,
                    "allowed_tools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep"],
                    "model_fallbacks": [],
                    "mcp_servers": {}
                }
            },
            "tool_permissions": null,
            "scope": "team",
            "is_active": true,
            "sort_order": 1,
            "created_at": "2026-03-25T10:00:00Z",
            "updated_at": "2026-03-25T10:00:00Z"
        }
    ]
}
```

---

### POST /api/teams/{team}/agent-roles

Create a custom agent role. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "name": "string|required|max:255",
    "slug": "string|required|max:100|alpha_dash",
    "description": "string|nullable|max:5000",
    "cli_backend": "string|required|in:claude_code,opencode",
    "preferred_model": "string|nullable|max:100",
    "system_prompt": "string|nullable",
    "backend_config": "json|nullable",
    "tool_permissions": "json|nullable",
    "is_active": "boolean|sometimes",
    "sort_order": "integer|sometimes"
}
```

**Response** `201 Created`:
```json
{
    "data": {
        "id": 6,
        "team_id": 1,
        "project_id": null,
        "parent_id": null,
        "name": "Security Auditor",
        "slug": "security-auditor",
        "description": "Security-focused code analysis",
        "cli_backend": "claude_code",
        "preferred_model": "claude-opus-4-6",
        "system_prompt": "You are a Security Auditor...",
        "prompt_append": null,
        "backend_config": { "claude-code": { "max_turns": 30, "max_budget_usd": 3.00 } },
        "tool_permissions": null,
        "scope": "team",
        "is_active": true,
        "sort_order": 6,
        "created_at": "2026-03-25T12:00:00Z",
        "updated_at": "2026-03-25T12:00:00Z"
    }
}
```

**Notes**:
- `scope` is always `team` in MVP (auto-set, not user-provided).
- `team_id` is auto-set from route.
- Slug must be unique within team.

**Errors**:
- `403` — Not owner or admin
- `422` — Validation failed (slug taken in team, etc.)

---

### GET /api/teams/{team}/agent-roles/{role}

Get agent role detail. Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`: Same shape as list item above.

---

### PUT /api/teams/{team}/agent-roles/{role}

Update an agent role. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "name": "string|sometimes|max:255",
    "description": "string|nullable|max:5000",
    "cli_backend": "string|sometimes|in:claude_code,opencode",
    "preferred_model": "string|nullable|max:100",
    "system_prompt": "string|nullable",
    "backend_config": "json|nullable",
    "tool_permissions": "json|nullable",
    "is_active": "boolean|sometimes",
    "sort_order": "integer|sometimes"
}
```

**Response** `200 OK`: Updated agent role.

**Notes**: Slug is immutable after creation.

**Errors**:
- `403` — Not owner or admin

---

### DELETE /api/teams/{team}/agent-roles/{role}

Soft-delete an agent role. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "message": "Agent role deleted successfully."
}
```

**Notes**: Cannot delete if the agent role has active task runs (return 409 Conflict).

**Errors**:
- `403` — Not owner or admin
- `409` — Agent role has active task runs

## Filament Resource

Create a Filament resource for AgentRole management in the admin panel:

- **List**: Table with name, slug, cli_backend, preferred_model, is_active, sort_order columns. Filterable by scope and active status.
- **Create/Edit**: Form with all fields. `system_prompt` as textarea/markdown. `backend_config` and `tool_permissions` as JSON editor or key-value editor.
- **View**: Read-only detail view.

## Acceptance Criteria

### Default Roles Seeding

**Given** a new team is created,
**When** the TeamCreated event fires,
**Then** 5 default agent roles (BA, Lead Dev, Developer, Code Reviewer, QA) are created for that team with `scope: team`.

**Given** user registration creates a personal team,
**When** the team is created,
**Then** the 5 default agent roles are seeded for the personal team.

### CRUD

**Given** a team with default agent roles,
**When** a team member GETs `/api/teams/{team}/agent-roles`,
**Then** all 5 default roles are returned, ordered by `sort_order`.

**Given** a team admin,
**When** they POST to `/api/teams/{team}/agent-roles` with valid data,
**Then** a new custom agent role is created with `scope: team`.

**Given** a team admin,
**When** they POST with a slug that already exists in the team,
**Then** a 422 response is returned.

**Given** a team admin,
**When** they PUT to update an agent role's `system_prompt`,
**Then** the system prompt is updated (no read-only enforcement in MVP).

**Given** a team admin,
**When** they DELETE an agent role with no active task runs,
**Then** the role is soft-deleted.

**Given** a team member with `member` role,
**When** they try to create/update/delete an agent role,
**Then** a 403 response is returned.

### Filament

**Given** a Filament admin user,
**When** they navigate to the AgentRole resource,
**Then** they can list, create, edit, and view agent roles.

## Implementation Notes

- AgentRole model uses `SoftDeletes` trait.
- AgentRole belongs to Team (nullable), Project (nullable), and self-references via `parent_id`. **Note**: User and Team models come from magic-starter and are extended by Kodizm.
- AgentRolePolicy checks team membership and role (owner/admin for write operations).
- Route model binding: resolve `{role}` within team scope.
- Seeder: `DefaultAgentRolesSeeder` — can be run standalone or triggered by TeamCreated event.
- System prompts: store in a config file or dedicated class, keep them out of the seeder for maintainability.
- The `cli_backend` column stores the enum value as a string. In MVP, all defaults use `claude_code`.
