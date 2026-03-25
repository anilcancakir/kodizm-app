# Wave 1 — Task CRUD & State Machine

> Spec: 05-Task Management
> Dependencies: 02 complete (Project model and API must exist)

## Deliverables

- [ ] Task model + migration + factory + policy
- [ ] TaskType enum
- [ ] TaskPriority enum
- [ ] TaskStatus enum with `allowedTransitions()` and `canTransitionTo()`
- [ ] TaskComplexity enum
- [ ] TaskSource enum
- [ ] Task CRUD API endpoints
- [ ] Task status transition endpoint
- [ ] Feature tests for CRUD
- [ ] Feature tests for state machine transitions
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## Task Schema

```
tasks
├── id: uuid PK
├── project_id: uuid FK → projects
├── parent_task_id: uuid FK → tasks nullable  // sub-task support
├── title: string
├── description: text nullable
├── acceptance_criteria: text nullable
├── type: enum(story, task, bug, spike)
├── priority: enum(p0, p1, p2, p3) default p2
├── status: enum(draft, analysis, planning, design, in_progress, review, testing, done, failed)
├── estimated_complexity: enum(xs, s, m, l, xl) nullable
├── assigned_agent_role_id: uuid FK → agent_roles nullable
├── created_by_user_id: uuid FK → users nullable  // null = agent-created
├── source: enum(manual, pm_conversation) default 'manual'
├── source_conversation_id: uuid FK → task_runs nullable  // PM chat session that created this task
├── design_needed: boolean default false              // PM flags → triggers Designer stage
├── retry_count: integer default 0                    // tracks reject→retry cycles
├── sprint_id: uuid FK → sprints nullable      // POST-MVP: add migration when sprints table exists
├── branch_name: string nullable          // feature/task-{id}
├── total_cost_usd: decimal(10,4) default 0
├── timestamps
└── soft_deletes
```

**Migration notes**:
- `sprint_id` FK: do NOT add foreign key constraint yet (sprints table does not exist). Add the column as `nullable` with no FK. Constraint added in post-MVP sprint migration.
- `source_conversation_id` FK: references `task_runs.id`. Add FK constraint only if task_runs table exists (it's built in spec 06). If building strictly in order, add as nullable column without FK, then add FK via spec 06 migration.
- All enum columns use string-backed PHP enums with cast.
- Index: `(project_id, status)` composite, `(parent_task_id)` single.

**Post-MVP fields** (include in migration, not in MVP API request validation):
- `source` — hardcode to `manual` on creation
- `source_conversation_id` — always null
- `design_needed` — always false
- `sprint_id` — always null

## TaskStatus Enum

```php
enum TaskStatus: string
{
    case Draft = 'draft';
    case Analysis = 'analysis';
    case Planning = 'planning';
    case Design = 'design';
    case InProgress = 'in_progress';
    case Review = 'review';
    case Testing = 'testing';
    case Done = 'done';
    case Failed = 'failed';

    /**
     * Returns the list of statuses this status can transition to.
     */
    public function allowedTransitions(): array
    {
        return match ($this) {
            self::Draft => [self::Analysis],
            self::Analysis => [self::Planning, self::Failed],
            self::Planning => [self::Design, self::InProgress, self::Failed],
            self::Design => [self::InProgress, self::Failed],
            self::InProgress => [self::Review, self::Failed],
            self::Review => [self::InProgress, self::Testing, self::Failed],
            self::Testing => [self::InProgress, self::Done, self::Failed],
            self::Done => [],
            self::Failed => [self::Draft],
        };
    }

    public function canTransitionTo(self $target): bool
    {
        return in_array($target, $this->allowedTransitions(), true);
    }

    public function isTerminal(): bool
    {
        return $this === self::Done;
    }
}
```

**MVP note**: The full state machine is implemented, but MVP workflows only use: `draft → in_progress → review → done/failed`. The pipeline stages (analysis, planning, design, testing) become active when pipeline orchestration (spec 13) is built.

## API Endpoints

### GET /api/teams/{team}/projects/{project}/tasks

List tasks for a project. Filterable by status, type, priority.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
```
?status=draft,in_progress    // comma-separated TaskStatus values
?type=story,bug              // comma-separated TaskType values
?priority=p0,p1              // comma-separated TaskPriority values
?parent_task_id=null         // null = top-level tasks only; integer = sub-tasks of that parent
?assigned_agent_role_id=5    // filter by assigned agent role
?search=login                // search in title and description
?sort=created_at             // sort field: created_at, updated_at, priority, status (default: created_at)
?direction=desc              // sort direction: asc, desc (default: desc)
?per_page=20                 // pagination (default: 20, max: 100)
```

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "project_id": 1,
            "parent_task_id": null,
            "title": "Implement user authentication",
            "description": "Add login and registration...",
            "acceptance_criteria": "Given a user with valid credentials...",
            "type": "story",
            "priority": "p1",
            "status": "draft",
            "estimated_complexity": "m",
            "assigned_agent_role_id": null,
            "created_by_user_id": 1,
            "source": "manual",
            "design_needed": false,
            "retry_count": 0,
            "branch_name": null,
            "total_cost_usd": "0.0000",
            "created_at": "2026-03-25T10:00:00Z",
            "updated_at": "2026-03-25T10:00:00Z"
        }
    ],
    "meta": {
        "current_page": 1,
        "last_page": 3,
        "per_page": 20,
        "total": 42
    }
}
```

---

### POST /api/teams/{team}/projects/{project}/tasks

Create a new task.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "title": "string|required|max:500",
    "description": "string|nullable|max:10000",
    "acceptance_criteria": "string|nullable|max:10000",
    "type": "string|required|in:story,task,bug,spike",
    "priority": "string|nullable|in:p0,p1,p2,p3",
    "estimated_complexity": "string|nullable|in:xs,s,m,l,xl",
    "assigned_agent_role_id": "integer|nullable|exists:agent_roles,id",
    "parent_task_id": "integer|nullable|exists:tasks,id"
}
```

**Response** `201 Created`:
```json
{
    "data": {
        "id": 1,
        "project_id": 1,
        "parent_task_id": null,
        "title": "Implement user authentication",
        "description": "Add login and registration...",
        "acceptance_criteria": "Given a user with valid credentials...",
        "type": "story",
        "priority": "p1",
        "status": "draft",
        "estimated_complexity": "m",
        "assigned_agent_role_id": null,
        "created_by_user_id": 1,
        "source": "manual",
        "design_needed": false,
        "retry_count": 0,
        "branch_name": null,
        "total_cost_usd": "0.0000",
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:00:00Z"
    }
}
```

**Business logic**:
- Status is always `draft` on creation.
- `created_by_user_id` is set to the authenticated user.
- `source` is set to `manual`.
- `priority` defaults to `p2` if not provided.
- If `parent_task_id` is provided, validate it belongs to the same project.
- If `assigned_agent_role_id` is provided, validate it belongs to the same team.

**Errors**:
- `422` — Validation failed
- `403` — User does not have permission (Viewer role)

---

### GET /api/teams/{team}/projects/{project}/tasks/{task}

Get task detail with sections and latest run info.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "project_id": 1,
        "parent_task_id": null,
        "title": "Implement user authentication",
        "description": "Add login and registration...",
        "acceptance_criteria": "Given a user with valid credentials...",
        "type": "story",
        "priority": "p1",
        "status": "in_progress",
        "estimated_complexity": "m",
        "assigned_agent_role_id": 3,
        "assigned_agent_role": {
            "id": 3,
            "name": "Developer",
            "slug": "developer"
        },
        "created_by_user_id": 1,
        "created_by_user": {
            "id": 1,
            "name": "John Doe"
        },
        "source": "manual",
        "design_needed": false,
        "retry_count": 0,
        "branch_name": "feature/task-1",
        "total_cost_usd": "1.2340",
        "sub_tasks_count": 2,
        "sections_count": 3,
        "runs_count": 1,
        "latest_run": {
            "id": 5,
            "status": "completed",
            "total_cost_usd": "1.2340",
            "started_at": "2026-03-25T10:05:00Z",
            "completed_at": "2026-03-25T10:12:00Z"
        },
        "created_at": "2026-03-25T10:00:00Z",
        "updated_at": "2026-03-25T10:12:00Z"
    }
}
```

**Errors**:
- `404` — Task not found or does not belong to project

---

### PUT /api/teams/{team}/projects/{project}/tasks/{task}

Update a task.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "title": "string|sometimes|required|max:500",
    "description": "string|nullable|max:10000",
    "acceptance_criteria": "string|nullable|max:10000",
    "type": "string|sometimes|in:story,task,bug,spike",
    "priority": "string|nullable|in:p0,p1,p2,p3",
    "status": "string|sometimes|in:draft,analysis,planning,design,in_progress,review,testing,done,failed",
    "estimated_complexity": "string|nullable|in:xs,s,m,l,xl",
    "assigned_agent_role_id": "integer|nullable|exists:agent_roles,id",
    "branch_name": "string|nullable|max:255"
}
```

**Response** `200 OK`:
```json
{
    "data": {
        "id": 1,
        "...": "...full task object..."
    }
}
```

**Business logic for status updates**:
- If `status` field is included, validate the transition using `TaskStatus::canTransitionTo()`.
- If the transition is not allowed, return 422 with error: `"Cannot transition from {current} to {target}."`
- When transitioning to `in_progress` from `review` or `testing` (reject), increment `retry_count`.
- When transitioning to `done`, set `branch_name` if not already set: `feature/task-{id}`.

**Errors**:
- `422` — Validation failed or invalid state transition
- `403` — User does not have permission (Viewer role)
- `404` — Task not found

---

### DELETE /api/teams/{team}/projects/{project}/tasks/{task}

Soft-delete a task.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "message": "Task deleted."
}
```

**Business logic**:
- Only allowed if task has no active runs (status = running or waiting_for_input).
- Soft deletes the task.

**Errors**:
- `409` — Task has active runs, cannot delete
- `403` — User does not have permission (Viewer role)
- `404` — Task not found

## Task Policy

```php
class TaskPolicy
{
    public function viewAny(User $user, Project $project): bool
    {
        // Any team member can list tasks (including Viewer)
        return $project->team->hasMember($user);
    }

    public function view(User $user, Task $task): bool
    {
        return $task->project->team->hasMember($user);
    }

    public function create(User $user, Project $project): bool
    {
        // Owner, Admin, Member can create. Viewer cannot.
        return $project->team->memberRole($user)?->canCreateTasks() ?? false;
    }

    public function update(User $user, Task $task): bool
    {
        return $task->project->team->memberRole($user)?->canCreateTasks() ?? false;
    }

    public function delete(User $user, Task $task): bool
    {
        return $task->project->team->memberRole($user)?->canCreateTasks() ?? false;
    }
}
```

## Acceptance Criteria

### Task Creation

**Given** an authenticated member of a team,
**When** they POST to `/api/teams/{team}/projects/{project}/tasks` with valid data,
**Then** a new Task is created with status `draft`, source `manual`, created_by_user_id set to the authenticated user, and a 201 response is returned.

**Given** an authenticated viewer of a team,
**When** they POST to `/api/teams/{team}/projects/{project}/tasks`,
**Then** a 403 response is returned.

**Given** a request with `parent_task_id` that belongs to a different project,
**When** the task is created,
**Then** a 422 response is returned with a validation error.

### Task Listing

**Given** a project with 5 tasks (2 draft, 2 in_progress, 1 done),
**When** GET `/api/teams/{team}/projects/{project}/tasks?status=draft`,
**Then** only the 2 draft tasks are returned.

**Given** a project with tasks,
**When** GET `/api/teams/{team}/projects/{project}/tasks?search=auth`,
**Then** only tasks with "auth" in title or description are returned.

### Task Update

**Given** a task in `draft` status,
**When** PUT with `status: "in_progress"`,
**Then** the task status transitions from `draft` to `in_progress` would fail — `draft` can only transition to `analysis`. A 422 response is returned.

**Note**: In MVP simplified flow, you may want to allow `draft → in_progress` directly. If so, add it to `allowedTransitions()` for Draft. The master spec shows the full pipeline. Decide based on CLAUDE.md guidance — the full state machine is canonical, but MVP can relax it.

**Given** a task in `draft` status,
**When** PUT with `status: "analysis"`,
**Then** the task status is updated to `analysis` and a 200 response is returned.

**Given** a task in `done` status,
**When** PUT with `status: "in_progress"`,
**Then** a 422 response is returned because `done` is terminal.

**Given** a task in `failed` status,
**When** PUT with `status: "draft"`,
**Then** the task status is updated to `draft` (reopen) and a 200 response is returned.

### Task Update — Reject Retry

**Given** a task in `review` status with `retry_count: 0`,
**When** PUT with `status: "in_progress"` (reject),
**Then** the task status is updated to `in_progress` and `retry_count` is incremented to 1.

### Task Delete

**Given** a task with no active runs,
**When** DELETE is called,
**Then** the task is soft-deleted and a 200 response is returned.

**Given** a task with an active run (status = running),
**When** DELETE is called,
**Then** a 409 response is returned with an error message.

### State Machine

**Given** each TaskStatus value,
**When** `allowedTransitions()` is called,
**Then** it returns exactly the transitions defined in the state machine diagram.

**Given** `TaskStatus::Done`,
**When** `canTransitionTo(TaskStatus::InProgress)` is called,
**Then** it returns false.

**Given** `TaskStatus::Failed`,
**When** `canTransitionTo(TaskStatus::Draft)` is called,
**Then** it returns true.

## Implementation Notes

- Use Laravel enum casting on the model: `'status' => TaskStatus::class`.
- State transition validation should live in a service method (e.g., `TaskService::transitionStatus($task, $newStatus)`) — not in the controller.
- Task model uses `SoftDeletes` trait.
- Factory should generate tasks with realistic titles and descriptions using `fake()`.
- The `total_cost_usd` field is updated by spec 06 (agent execution) when runs complete. Do not set it in task CRUD.
- Consider adding a `transitioned` model event for future pipeline orchestration to hook into.
- **Note**: User and Team models come from magic-starter and are extended by Kodizm.
