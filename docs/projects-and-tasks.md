# Projects and Tasks

Core domain models for project management and multi-agent task execution.

## Models

### Project

`lib/app/models/project.dart` -- Magic ORM (`extends Model with HasTimestamps, InteractsWithPersistence`).

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key, `incrementing: false` |
| teamId | String? | Parent team |
| name, slug | String? | Display name + URL slug |
| description | String? | Project description |
| repositoryUrl | String? | SSH or HTTPS repo URL |
| defaultBranch | String | Defaults to `'main'` |
| techStack | String? | e.g. `'Laravel, PostgreSQL'` |
| sshPublicKey | String? | Agent SSH access key |
| executionMode | String | `'manual'` or `'auto'` |
| settings | Map? | Project-level settings |
| taskCount | int? | API-computed, read-only |
| activeRunCount | int? | API-computed, read-only |

### Task

`lib/app/models/task.dart` -- Magic ORM.

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key |
| projectId | String? | Parent project |
| parentTaskId | String? | Sub-task parent |
| title, type, priority, status | String? | Core attributes |
| estimatedComplexity | int? | Complexity score |
| assignedAgentRoleId | String? | Assigned agent |
| description, acceptanceCriteria | String? | Detail-shape only |
| branchName | String? | Git branch |
| totalCostUsd | String? | Accumulated run cost |
| assignedAgentRoleName | String? | Nested relation (detail) |
| createdByUserName | String? | Nested relation (detail) |

### Supporting Models

| Model | File | Pattern | Key Fields |
|-------|------|---------|------------|
| `TaskSection` | `lib/app/models/task_section.dart` | Immutable VO | id, taskId, type, title, content, version, createdByAgentRoleName |
| `TaskRun` | `lib/app/models/task_run.dart` | Immutable VO | id, taskId, agentRoleId/Name, status, model, totalCostUsd |
| `TaskRunDetail` | `lib/app/models/task_run_detail.dart` | Immutable VO + copyWith | Extends TaskRun with prompt, sessionId, worktreePath, usage, durationMs |
| `AgentRole` | `lib/app/models/agent_role.dart` | Immutable VO | id, name, slug, scope, cliBackend, preferredModel, systemPrompt, toolPermissions |

## State Classes

### ProjectState

`lib/app/state/project_state.dart` -- `MagicController with MagicStateMixin<List<Project>>`.

| Method | Description |
|--------|-------------|
| `fetchProjects(teamId)` | Load paginated project list |
| `fetchProject(teamId, projectId)` | Load single project |
| `createProject(teamId, data)` | Create new project |
| `updateProject(teamId, projectId, data)` | Update project |
| `deleteProject(teamId, projectId)` | Delete project |
| `sortProjects(field)` | Local sort by name or lastUpdated |
| `generateSshKey(teamId, projectId)` | Generate SSH key pair |
| `fetchRepoStatus(teamId, projectId)` | Check repository status |

HTTP interface: `HttpClient` (GET/POST/PUT/DELETE).

### TaskState

`lib/app/state/task_state.dart` -- `MagicController with MagicStateMixin<List<Task>>`.

| Method | Description |
|--------|-------------|
| `fetchTasks(teamId, projectId, filters)` | Load filtered task list |
| `fetchTask(teamId, projectId, taskId)` | Load single task |
| `createTask(teamId, projectId, data)` | Create new task |
| `updateTask(...)` | Update task |
| `deleteTask(...)` | Delete task |
| `transitionStatus(...)` | Change task status |
| `fetchSections(...)` | Load task sections |
| `fetchRuns(...)` | Load task runs |
| `startRun(...)` | Start agent execution run |
| `fetchAgentRoles(teamId)` | Load available agent roles |
| `sortTasks(field)` | Local sort by priority/status/date |

HTTP interface: `TaskHttpClient` (GET/POST/PUT/DELETE).

## Views

| View | File | Route | State |
|------|------|-------|-------|
| `ProjectListView` | `lib/resources/views/project/project_list_view.dart` | `/projects` | `ProjectState` |
| `ProjectCreateView` | `lib/resources/views/project/project_create_view.dart` | `/projects/create` | `ProjectState` |
| `ProjectDetailView` | `lib/resources/views/project/project_detail_view.dart` | `/projects/:id` | `ProjectState` |
| `TaskListView` | `lib/resources/views/task/task_list_view.dart` | `/projects/:projectId/tasks` | `TaskState` |
| `TaskCreateView` | `lib/resources/views/task/task_create_view.dart` | `/projects/:projectId/tasks/create` | `TaskState` |
| `TaskDetailView` | `lib/resources/views/task/task_detail_view.dart` | `/projects/:projectId/tasks/:taskId` | `TaskState` |

## Related Docs

- [Agent Run](agent-run.md) -- run execution and streaming
- [State Management](state-management.md) -- all state classes
- [Views and Routes](views-and-routes.md) -- complete route map
