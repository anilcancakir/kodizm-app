# Wave 1 — Project CRUD

> Spec: 02-Project Management
> Dependencies: Spec 01 (Platform Core) must be complete

## Deliverables

- [ ] Project model + migration + factory + policy
- [ ] ExecutionMode enum
- [ ] Project CRUD endpoints
- [ ] Feature tests for all endpoints
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## Project Schema

```
projects
├── id: uuid PK
├── team_id: uuid FK → teams
├── name: string
├── slug: string
├── description: text nullable
├── repository_url: string nullable       // git@github.com:org/repo.git
├── default_branch: string default 'main'
├── tech_stack: string nullable            // e.g. 'laravel-flutter', 'laravel-blade'
├── ssh_private_key: text encrypted nullable  // for private repo access
├── ssh_public_key: text nullable             // displayed to user for deploy key setup
├── execution_mode: enum(manual, semi_auto, full_auto) default 'manual'
├── pipeline_config: json nullable         // pipeline stage→agent mapping (POST-MVP)
├── settings: json nullable                // project-specific settings
├── timestamps
└── soft_deletes
```

**Migration notes**:
- `team_id` foreign key references `teams.id` with `cascadeOnDelete`.
- `slug` has a unique compound index: `unique(team_id, slug)` — unique within team scope.
- `ssh_private_key` uses Laravel `encrypted` cast in the model.
- `execution_mode` defaults to `manual`.
- `pipeline_config` and `settings` are `json` nullable columns.
- Do NOT create a `sprints` table. `sprint_id` on tasks is POST-MVP.

**Model casts**:
```php
protected function casts(): array
{
    return [
        'ssh_private_key' => 'encrypted',
        'execution_mode' => ExecutionMode::class,
        'pipeline_config' => 'array',
        'settings' => 'array',
    ];
}
```

## ExecutionMode Enum

```php
enum ExecutionMode: string
{
    case Manual = 'manual';
    case SemiAuto = 'semi_auto';
    case FullAuto = 'full_auto';
}
```

MVP: Only `manual` mode is functional. Include the enum values for forward compatibility.

## API Endpoints

### GET /api/teams/{team}/projects

List all projects for a team. Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
- `search` (optional): Filter by name (LIKE search)

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "team_id": 1,
            "name": "Kodizm Backend",
            "slug": "kodizm-backend",
            "description": "Laravel API backend for Kodizm",
            "repository_url": "git@github.com:kodizm/backend.git",
            "default_branch": "main",
            "tech_stack": "laravel",
            "execution_mode": "manual",
            "has_ssh_key": true,
            "created_at": "2026-03-25T10:00:00Z",
            "updated_at": "2026-03-25T10:00:00Z"
        }
    ]
}
```

**Notes**: `has_ssh_key` is a computed boolean (true if `ssh_public_key` is not null). Never expose `ssh_private_key` in API responses.

---

### POST /api/teams/{team}/projects

Create a new project. Requires owner, admin, or member role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "name": "string|required|max:255",
    "description": "string|nullable|max:5000",
    "repository_url": "string|nullable|max:500",
    "default_branch": "string|sometimes|max:100",
    "tech_stack": "string|nullable|max:100"
}
```

**Response** `201 Created`:
```json
{
    "data": {
        "id": 1,
        "team_id": 1,
        "name": "Kodizm Backend",
        "slug": "kodizm-backend",
        "description": "Laravel API backend for Kodizm",
        "repository_url": "git@github.com:kodizm/backend.git",
        "default_branch": "main",
        "tech_stack": "laravel",
        "execution_mode": "manual",
        "pipeline_config": null,
        "settings": null,
        "has_ssh_key": false,
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:00:00Z"
    }
}
```

**Notes**: Slug is auto-generated from name, unique within team. `execution_mode` defaults to `manual`.

**Errors**:
- `403` — Viewer role cannot create projects
- `422` — Validation failed

---

### GET /api/teams/{team}/projects/{project}

Get project details. Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "team_id": 1,
        "name": "Kodizm Backend",
        "slug": "kodizm-backend",
        "description": "Laravel API backend for Kodizm",
        "repository_url": "git@github.com:kodizm/backend.git",
        "default_branch": "main",
        "tech_stack": "laravel",
        "execution_mode": "manual",
        "pipeline_config": null,
        "settings": null,
        "has_ssh_key": true,
        "ssh_public_key": "ssh-ed25519 AAAA... kodizm-project-1",
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:00:00Z"
    }
}
```

**Notes**: `ssh_public_key` is included in detail view (for deploy key setup). `ssh_private_key` is NEVER returned.

**Errors**:
- `403` — Not a team member
- `404` — Project not found

---

### PUT /api/teams/{team}/projects/{project}

Update project. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "name": "string|sometimes|max:255",
    "description": "string|nullable|max:5000",
    "repository_url": "string|nullable|max:500",
    "default_branch": "string|sometimes|max:100",
    "tech_stack": "string|nullable|max:100",
    "settings": "json|sometimes|nullable"
}
```

**Response** `200 OK`: Same shape as GET detail.

**Notes**: Slug does not change on name update (immutable after creation).

**Errors**:
- `403` — Not owner or admin

---

### DELETE /api/teams/{team}/projects/{project}

Soft-delete project. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "message": "Project deleted successfully."
}
```

**Errors**:
- `403` — Not owner or admin

## Acceptance Criteria

### Project CRUD

**Given** a team member with `member` role,
**When** they POST to `/api/teams/{team}/projects` with a valid name,
**Then** a new Project is created with auto-generated slug and the response status is 201.

**Given** a team member with `viewer` role,
**When** they POST to `/api/teams/{team}/projects`,
**Then** a 403 response is returned.

**Given** two projects in a team,
**When** a team member GETs `/api/teams/{team}/projects`,
**Then** both projects are returned.

**Given** a project,
**When** a team member GETs `/api/teams/{team}/projects/{project}`,
**Then** the project detail is returned including `ssh_public_key` but NOT `ssh_private_key`.

**Given** a team admin,
**When** they PUT `/api/teams/{team}/projects/{project}` with a new name,
**Then** the name is updated but the slug remains unchanged.

**Given** a team admin,
**When** they DELETE `/api/teams/{team}/projects/{project}`,
**Then** the project is soft-deleted.

### Slug Generation

**Given** a team with a project named "My App",
**When** another project named "My App" is created in the same team,
**Then** the slug is auto-suffixed (e.g., "my-app-2") to maintain uniqueness within the team.

**Given** two different teams,
**When** both create a project named "My App",
**Then** both can have the slug "my-app" (unique only within team scope).

### Authorization

**Given** a user who is not a member of the team,
**When** they try to access any project endpoint for that team,
**Then** a 403 response is returned.

## Implementation Notes

- Project model uses `SoftDeletes` trait.
- Project belongs to Team (`team_id` FK). **Note**: User and Team models come from magic-starter and are extended by Kodizm.
- ProjectPolicy checks team membership and role.
- Route model binding: resolve `{project}` within team scope.
- Slug generation: `Str::slug($name)` with uniqueness check within team (append `-2`, `-3`, etc.).
- Never return `ssh_private_key` in any API response. Use a hidden attribute or a resource that explicitly excludes it.
- The `has_ssh_key` computed field: `!is_null($this->ssh_public_key)`.
