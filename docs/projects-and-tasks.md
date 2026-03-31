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
| techStack | String? | e.g. `'Laravel, PostgreSQL'` |
| executionMode | String | `'manual'` or `'auto'` |
| settings | Map? | Project-level settings |
| taskCount | int? | API-computed, read-only |
| activeRunCount | int? | API-computed, read-only |
| repositoriesCount | int? | API-computed, read-only |

Accessor: `repositories` — parsed from the API-included `repositories` array via `ProjectRepository.fromMap()`, returns `List<ProjectRepository>`.

### ProjectRepository

`lib/app/models/project_repository.dart` -- Immutable VO (`const` constructor + `fromMap` factory).

| Field | Type | Notes |
|-------|------|-------|
| id | String (UUID) | Primary key |
| projectId | String | Parent project |
| name | String | Display name |
| repositoryUrl | String | SSH or HTTPS Git URL |
| defaultBranch | String | Defaults to `'main'` |
| sshPublicKey | String? | Public key to add to Git host |
| repoStatus | String? | `null`, `'cloning'`, `'ready'`, `'error'` |
| repoError | String? | Last error message |
| lastSyncedAt | String? | ISO8601 last sync timestamp |
| mountPath | String? | Container workspace mount path |

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
| totalCostUsd | String? | Accumulated cost |
| linkedConversationsCount | int? | Count of linked conversations via pivot |
| assignedAgentRoleName | String? | Nested relation (detail) |
| createdByUserName | String? | Nested relation (detail) |

### Supporting Models

| Model | File | Pattern | Key Fields |
|-------|------|---------|------------|
| `TaskSection` | `lib/app/models/task_section.dart` | Immutable VO | id, taskId, type, title, content, version, createdByAgentRoleName |
| `AgentRole` | `lib/app/models/agent_role.dart` | Immutable VO | id, name, slug, scope, cliBackend, preferredModel, systemPrompt, toolPermissions |

Task execution is handled by the unified `Conversation` model (see [Conversations](conversations.md)).

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

HTTP interface: `HttpClient` (GET/POST/PUT/DELETE).

### ProjectRepositoryState

`lib/app/state/project_repository_state.dart` -- `MagicController with MagicStateMixin<List<ProjectRepository>>`.

| Method | Description |
|--------|-------------|
| `fetchRepositories(teamId, projectId)` | Load repository list for a project |
| `createRepository(teamId, projectId, data)` | Create new repository |
| `updateRepository(teamId, projectId, repositoryId, data)` | Update repository |
| `deleteRepository(teamId, projectId, repositoryId)` | Delete repository |
| `generateSshKey(teamId, projectId, repositoryId)` | Generate SSH key pair for repository |
| `fetchSshKey(teamId, projectId, repositoryId)` | Fetch current public key |
| `cloneRepository(teamId, projectId, repositoryId)` | Trigger background clone |
| `fetchRepoStatus(teamId, projectId, repositoryId)` | Poll clone/sync status |

HTTP interface: Injectable `HttpClient` (GET/POST/PUT/DELETE).

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
| `fetchAgentRoles(teamId)` | Load available agent roles |
| `sortTasks(field)` | Local sort by priority/status/date |

HTTP interface: `TaskHttpClient` (GET/POST/PUT/DELETE).

## Views

| View | File | Route | State |
|------|------|-------|-------|
| `ProjectListView` | `lib/resources/views/project/project_list_view.dart` | `/projects` | `ProjectState` |
| `ProjectDetailView` | `lib/resources/views/project/project_detail_view.dart` | `/projects/:id` | `ProjectState`, `ProjectRepositoryState` |
| `TaskListView` | `lib/resources/views/task/task_list_view.dart` | `/projects/:projectId/tasks` | `TaskState` |
| `TaskCreateView` | `lib/resources/views/task/task_create_view.dart` | `/projects/:projectId/tasks/create` | `TaskState` |
| `TaskDetailView` | `lib/resources/views/task/task_detail_view.dart` | `/projects/:projectId/tasks/:taskId` | `TaskState` |

## Related Docs

- [Conversations](conversations.md) -- conversation execution and chat
- [State Management](state-management.md) -- all state classes
- [Views and Routes](views-and-routes.md) -- complete route map
