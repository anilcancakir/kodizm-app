# Wave 2 — Task Sections

> Spec: 05-Task Management
> Dependencies: 05-wave-1 (Task model and CRUD must be complete)

## Deliverables

- [ ] TaskSection model + migration + factory
- [ ] TaskSectionType enum
- [ ] TaskSection CRUD API endpoints
- [ ] Version increment logic on update
- [ ] Feature tests for CRUD
- [ ] Feature tests for version increment
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## TaskSection Schema

```
task_sections
├── id: uuid PK
├── task_id: uuid FK → tasks
├── type: enum(analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments)
├── title: string
├── content: text
├── created_by_agent_role_id: uuid FK → agent_roles nullable
├── created_by_user_id: uuid FK → users nullable
├── version: int default 1
├── timestamps
```

**Migration notes**:
- FK on `task_id` with cascade delete (when task is deleted, sections are deleted).
- FK on `created_by_agent_role_id` references `agent_roles.id`, set null on delete.
- FK on `created_by_user_id` references `users.id`, set null on delete.
- Index: `(task_id, type)` composite.
- No soft deletes on TaskSection (hard delete is fine — sections are owned by tasks).

## TaskSectionType Enum

```php
enum TaskSectionType: string
{
    case Analysis = 'analysis';
    case Plan = 'plan';
    case DesignBrief = 'design_brief';
    case DesignAssets = 'design_assets';
    case DevReport = 'dev_report';
    case ReviewReport = 'review_report';
    case TestReport = 'test_report';
    case Notes = 'notes';
    case Comments = 'comments';
}
```

## Version Increment Rule

Every time a section's `content` is updated (via API or MCP tool), `version` is incremented by 1. This allows tracking how many times an agent or user has revised a section.

```php
// In TaskSectionService::update()
$section->content = $newContent;
$section->version = $section->version + 1;
$section->save();
```

The version is always incremented on update regardless of whether the content actually changed. This provides an audit trail of all updates.

## API Endpoints

### GET /api/teams/{team}/projects/{project}/tasks/{task}/sections

List all sections for a task.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
```
?type=analysis,plan     // comma-separated TaskSectionType values
```

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "task_id": 1,
            "type": "analysis",
            "title": "Requirements Analysis",
            "content": "## Overview\n\nThe user authentication system needs...",
            "created_by_agent_role_id": 1,
            "created_by_agent_role": {
                "id": 1,
                "name": "Business Analyst",
                "slug": "ba"
            },
            "created_by_user_id": null,
            "version": 2,
            "created_at": "2026-03-25T10:05:00Z",
            "updated_at": "2026-03-25T10:15:00Z"
        },
        {
            "id": 2,
            "task_id": 1,
            "type": "plan",
            "title": "Development Plan",
            "content": "## Approach\n\n1. Set up Fortify...",
            "created_by_agent_role_id": 2,
            "created_by_agent_role": {
                "id": 2,
                "name": "Lead Developer",
                "slug": "lead-dev"
            },
            "created_by_user_id": null,
            "version": 1,
            "created_at": "2026-03-25T10:10:00Z",
            "updated_at": "2026-03-25T10:10:00Z"
        }
    ]
}
```

---

### POST /api/teams/{team}/projects/{project}/tasks/{task}/sections

Add a new section to a task.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "type": "string|required|in:analysis,plan,design_brief,design_assets,dev_report,review_report,test_report,notes,comments",
    "title": "string|required|max:500",
    "content": "string|required|max:100000"
}
```

**Response** `201 Created`:
```json
{
    "data": {
        "id": 3,
        "task_id": 1,
        "type": "notes",
        "title": "Implementation Notes",
        "content": "Remember to check the edge case for...",
        "created_by_agent_role_id": null,
        "created_by_user_id": 1,
        "version": 1,
        "created_at": "2026-03-25T10:20:00Z",
        "updated_at": "2026-03-25T10:20:00Z"
    }
}
```

**Business logic**:
- `created_by_user_id` is set to the authenticated user (API call).
- `created_by_agent_role_id` is null when created via API. Set when created via MCP tool (spec 08).
- `version` starts at 1.
- Multiple sections of the same type are allowed (e.g., multiple `notes` sections).

**Errors**:
- `422` — Validation failed
- `403` — User does not have permission (Viewer role)
- `404` — Task not found

---

### PUT /api/teams/{team}/projects/{project}/tasks/{task}/sections/{section}

Update an existing section.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "title": "string|sometimes|required|max:500",
    "content": "string|sometimes|required|max:100000"
}
```

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "task_id": 1,
        "type": "analysis",
        "title": "Requirements Analysis (Revised)",
        "content": "## Updated Overview\n\n...",
        "created_by_agent_role_id": 1,
        "created_by_user_id": null,
        "version": 3,
        "created_at": "2026-03-25T10:05:00Z",
        "updated_at": "2026-03-25T10:25:00Z"
    }
}
```

**Business logic**:
- `version` is incremented by 1 on every update.
- `type` cannot be changed after creation.
- `created_by_agent_role_id` and `created_by_user_id` are not modified on update.

**Errors**:
- `422` — Validation failed
- `403` — User does not have permission (Viewer role)
- `404` — Section not found or does not belong to task

---

### DELETE /api/teams/{team}/projects/{project}/tasks/{task}/sections/{section}

Delete a section.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "message": "Section deleted."
}
```

**Errors**:
- `403` — User does not have permission (Viewer role)
- `404` — Section not found or does not belong to task

## Acceptance Criteria

### Section Creation

**Given** an authenticated member and an existing task,
**When** they POST a new section with type `analysis`, title, and content,
**Then** a TaskSection is created with version 1, created_by_user_id set to the authenticated user, and a 201 response is returned.

**Given** a task that already has an `analysis` section,
**When** another `analysis` section is posted,
**Then** the section is created successfully (multiple sections of the same type are allowed).

### Section Listing

**Given** a task with 3 sections (1 analysis, 1 plan, 1 notes),
**When** GET sections with `?type=analysis`,
**Then** only the analysis section is returned.

**Given** a task with 3 sections,
**When** GET sections without type filter,
**Then** all 3 sections are returned.

### Section Update

**Given** a section with version 1,
**When** PUT with updated content,
**Then** the section content is updated and version is incremented to 2.

**Given** a section with version 3,
**When** PUT with updated content,
**Then** the version is incremented to 4.

**Given** a section update request that includes `type`,
**When** PUT is processed,
**Then** the `type` field is ignored (type is immutable after creation).

### Section Delete

**Given** an existing section,
**When** DELETE is called,
**Then** the section is hard-deleted and a 200 response is returned.

### Version Increment via MCP

**Given** a section created by an agent via MCP `create-task-section` tool,
**When** the same agent updates it via MCP `update-task-section` tool,
**Then** the version is incremented (same version logic applies regardless of update source).

### Authorization

**Given** an authenticated viewer of a team,
**When** they attempt to create, update, or delete a section,
**Then** a 403 response is returned.

**Given** an authenticated viewer of a team,
**When** they GET sections for a task,
**Then** the sections are returned successfully (read access allowed).

## Implementation Notes

- Use Laravel enum casting: `'type' => TaskSectionType::class`.
- No soft deletes on TaskSection — hard delete is appropriate since sections don't have dependent records.
- Factory should generate sections with Markdown-formatted content using `fake()->paragraphs()`.
- The MCP tool `create-task-section` and `update-task-section` (spec 08) will use the same `TaskSectionService` — share the logic.
- Version increment should be in a service method, not in the controller, to ensure consistency across API and MCP updates.
