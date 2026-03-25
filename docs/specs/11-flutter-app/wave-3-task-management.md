# Wave 3 — Task Management Screens

> Spec: 11-Flutter App
> Dependencies: Wave 2 complete, 05-Task Management complete (backend task CRUD + sections + state machine)

## Deliverables

- [ ] TaskListScreen (filterable by status, type, priority)
- [ ] TaskDetailScreen (all fields, sections, run history, status timeline)
- [ ] TaskCreateScreen
- [ ] TaskSectionView with markdown rendering and version history
- [ ] Task state machine visualization (status badges + transition actions)
- [ ] TaskState (ChangeNotifier + MagicStateMixin)
- [ ] Freezed models: Task, TaskSection with UUID `String` ids

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## Task List Screen (`/projects/{projectId}/tasks`)

### Layout
- List view (default) — each task row shows:
  - **Title**: task title (bold)
  - **Status badge**: colored pill — draft (grey), analysis (blue), planning (purple), in_progress (orange), review (yellow), testing (cyan), done (green), failed (red)
  - **Priority badge**: p0 (red), p1 (orange), p2 (blue), p3 (grey)
  - **Type icon**: story (book), task (check), bug (bug), spike (lightning)
  - **Assigned agent**: agent role name or "Unassigned"
  - **Total cost**: `$X.XX` or `--` if no runs
  - **Created**: relative time (e.g., "2h ago")

### Filters
- **Status**: multi-select chips (all statuses from TaskStatus enum)
- **Type**: multi-select chips (story, task, bug, spike)
- **Priority**: multi-select chips (p0, p1, p2, p3)
- Filters persist in URL query params (web) / local state (mobile)
- "Clear filters" button when any filter is active

### Actions
- "Create Task" FAB or button
- Pull-to-refresh
- Tap task -> navigate to task detail

### Sorting
- Default: priority (p0 first), then by updated_at desc
- Sortable by: priority, status, created_at, updated_at

## Task Detail Screen (`/projects/{projectId}/tasks/{taskId}`)

### Header
- Title (editable inline for owner/admin/member)
- Status badge with transition actions (see below)
- Priority badge
- Type icon + label
- Assigned agent role (or "Unassigned")

### Status Actions (State Machine Visualization)
Based on current status and allowed transitions:

| Current Status | Available Actions |
|---------------|-------------------|
| draft | "Start Analysis" -> analysis |
| analysis | "Start Planning" -> planning |
| planning | "Start Development" -> in_progress |
| in_progress | "Submit for Review" -> review |
| review | "Approve -> Testing" -> testing, "Reject -> Rework" -> in_progress |
| testing | "Approve -> Done" -> done, "Reject -> Rework" -> in_progress |
| done | (no actions — terminal) |
| failed | "Reopen" -> draft |

### Info Section
- **Description**: rendered markdown (expandable if long)
- **Acceptance Criteria**: rendered markdown
- **Estimated Complexity**: xs/s/m/l/xl badge
- **Source**: manual / pm_conversation
- **Branch**: `feature/task-{id}` (copyable)
- **Total Cost**: sum of all runs
- **Created by**: user name or "Agent"
- **Created at / Updated at**: formatted dates

### Sections Tab
- List of TaskSection records, grouped by type:
  - Analysis
  - Plan
  - Design Brief (post-MVP)
  - Dev Report
  - Review Report
  - Test Report
  - Notes
  - Comments
- Each section shows:
  - Title
  - Type badge
  - Version number (e.g., "v3")
  - Created by (user or agent role)
  - Content: rendered markdown
  - "Show history" -> expandable version list

### Run History Tab
- List of TaskRun records for this task
- Each run row:
  - Agent role name + model
  - Status badge (pending, running, waiting_for_input, completed, failed, cancelled, timed_out)
  - Duration (formatted: "2m 34s")
  - Cost (`$1.23`)
  - Started at (relative time)
  - Tap -> navigate to Agent Run Screen (`/projects/{projectId}/tasks/{taskId}/runs/{runId}`)

### Start Run Action
- Button: "Run Agent" (visible when task has no active run)
- Opens modal:
  - Select agent role (dropdown from team's agent roles)
  - Shows: role name, model, description
  - "Start Run" confirmation button
- Submit: POST `/api/teams/{team}/projects/{project}/tasks/{task}/runs` via `Http` with `{ agent_role_id }`
- On success: navigate to Agent Run Screen

### Status Timeline
- Visual timeline of status transitions
- Each entry: status badge + timestamp + who/what triggered it
- Compact vertical timeline UI

## Create Task Screen (`/projects/{projectId}/tasks/create`)

### Fields
- **Title**: `string|required|max:255`
- **Description**: `text|nullable` — multiline text area with markdown preview toggle
- **Acceptance Criteria**: `text|nullable` — multiline, markdown preview
- **Type**: segmented control — story, task, bug, spike (default: task)
- **Priority**: segmented control — p0, p1, p2, p3 (default: p2)
- **Estimated Complexity**: segmented control — xs, s, m, l, xl (optional)

### Submit
- POST `/api/teams/{team}/projects/{project}/tasks` via `Http`
- Request body:
```json
{
    "title": "string",
    "description": "string|null",
    "acceptance_criteria": "string|null",
    "type": "story|task|bug|spike",
    "priority": "p0|p1|p2|p3",
    "estimated_complexity": "xs|s|m|l|xl|null"
}
```
- On success: navigate to task detail screen
- On error: show validation errors

## Task Section Viewer

### Markdown Rendering
- Use `flutter_markdown` package
- Support: headings, bold/italic, code blocks (syntax highlighted), lists, links, tables, blockquotes
- Code blocks: monospace font, background color, copy button
- Links: open in external browser

### Version History
- "Show history" button per section
- Loads all versions from GET `/api/.../tasks/{task}/sections?type={type}` via `Http`
- Displays: version number, created_at, diff summary (if available)
- Tap version -> shows that version's content

## State Management

### TaskState (ChangeNotifier + MagicStateMixin)

```dart
class TaskState extends ChangeNotifier with MagicStateMixin {
  List<Task> _tasks = [];
  Task? _selectedTask;
  List<TaskSection> _sections = [];

  List<Task> get tasks => _tasks;
  Task? get selectedTask => _selectedTask;
  List<TaskSection> get sections => _sections;

  Future<void> loadTasks(
    String teamId,
    String projectId, {
    List<String>? statusFilter,
    List<String>? typeFilter,
    List<String>? priorityFilter,
  }) async {
    await run(() async {
      final queryParams = <String, dynamic>{};
      if (statusFilter != null) queryParams['status'] = statusFilter.join(',');
      if (typeFilter != null) queryParams['type'] = typeFilter.join(',');
      if (priorityFilter != null) queryParams['priority'] = priorityFilter.join(',');

      final response = await Http.get(
        '/teams/$teamId/projects/$projectId/tasks',
        queryParameters: queryParams,
      );
      _tasks = (response.data['data'] as List)
          .map((json) => Task.fromJson(json))
          .toList();
      notifyListeners();
    });
  }

  Future<void> loadTask(String teamId, String projectId, String taskId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects/$projectId/tasks/$taskId');
      _selectedTask = Task.fromJson(response.data['data']);
      notifyListeners();
    });
  }

  Future<Task> createTask(String teamId, String projectId, Map<String, dynamic> data) async {
    return await run(() async {
      final response = await Http.post('/teams/$teamId/projects/$projectId/tasks', data: data);
      final task = Task.fromJson(response.data['data']);
      _tasks.add(task);
      notifyListeners();
      return task;
    });
  }

  Future<void> transitionStatus(String teamId, String projectId, String taskId, String newStatus) async {
    await run(() async {
      final response = await Http.put(
        '/teams/$teamId/projects/$projectId/tasks/$taskId',
        data: {'status': newStatus},
      );
      final updated = Task.fromJson(response.data['data']);
      _selectedTask = updated;
      _tasks = _tasks.map((t) => t.id == taskId ? updated : t).toList();
      notifyListeners();
    });
  }

  Future<void> loadSections(String teamId, String projectId, String taskId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects/$projectId/tasks/$taskId/sections');
      _sections = (response.data['data'] as List)
          .map((json) => TaskSection.fromJson(json))
          .toList();
      notifyListeners();
    });
  }
}
```

## Freezed Models

### Task

```dart
@freezed
class Task with _$Task {
  const factory Task({
    required String id,              // UUID
    required String projectId,       // UUID
    String? parentTaskId,            // UUID
    required String title,
    String? description,
    String? acceptanceCriteria,
    required String type,            // TaskType enum value
    required String priority,        // TaskPriority enum value
    required String status,          // TaskStatus enum value
    String? estimatedComplexity,     // TaskComplexity enum value
    String? assignedAgentRoleId,     // UUID
    String? assignedAgentRoleName,
    String? createdByUserId,         // UUID
    String? createdByUserName,
    required String source,          // TaskSource enum value
    String? branchName,
    required double totalCostUsd,
    required DateTime createdAt,
    required DateTime updatedAt,
    // included in detail response
    List<TaskSection>? sections,
    List<TaskRun>? runs,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
```

### TaskSection

```dart
@freezed
class TaskSection with _$TaskSection {
  const factory TaskSection({
    required String id,                   // UUID
    required String taskId,               // UUID
    required String type,                 // TaskSectionType enum value
    required String title,
    required String content,
    String? createdByAgentRoleId,         // UUID
    String? createdByAgentRoleName,
    String? createdByUserId,              // UUID
    String? createdByUserName,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TaskSection;

  factory TaskSection.fromJson(Map<String, dynamic> json) => _$TaskSectionFromJson(json);
}
```

### TaskRun (Summary for list views)

```dart
@freezed
class TaskRun with _$TaskRun {
  const factory TaskRun({
    required String id,              // UUID
    required String taskId,          // UUID
    required String agentRoleId,     // UUID
    required String agentRoleName,
    required String status,          // TaskRunStatus enum value
    String? model,
    double? totalCostUsd,
    int? durationMs,
    int? numTurns,
    DateTime? startedAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) = _TaskRun;

  factory TaskRun.fromJson(Map<String, dynamic> json) => _$TaskRunFromJson(json);
}
```

## Acceptance Criteria

### Task List

**Given** a project with 10 tasks of various statuses,
**When** the user navigates to the task list,
**Then** all 10 tasks are displayed with title, status badge, priority badge, type icon, assigned agent, and cost.

**Given** a task list with filters applied (status: "in_progress", "review"),
**When** the filters are active,
**Then** only tasks matching the selected statuses are displayed.

**Given** a task list with active filters,
**When** the user taps "Clear filters",
**Then** all filters are removed and the full task list is shown.

**Given** a project with no tasks,
**When** the user navigates to the task list,
**Then** an empty state with "Create your first task" is displayed.

### Create Task

**Given** a user on the create task screen with a valid title,
**When** they submit the form,
**Then** a new task is created in `draft` status via `Http.post` and the user is navigated to the task detail.

**Given** a user creating a task without a title,
**When** they submit the form,
**Then** a validation error on the title field is shown.

**Given** a user creating a task,
**When** they select type "bug" and priority "p0",
**Then** the created task has type "bug" and priority "p0".

### Task Detail

**Given** a task with 3 sections (analysis, plan, dev_report),
**When** the user views the task detail sections tab,
**Then** all 3 sections are shown, grouped by type, with rendered markdown content.

**Given** a task in "draft" status,
**When** the user views the task detail,
**Then** the "Start Analysis" status action button is visible.

**Given** a task in "review" status,
**When** the user views the task detail,
**Then** both "Approve -> Testing" and "Reject -> Rework" action buttons are visible.

**Given** a task in "done" status,
**When** the user views the task detail,
**Then** no status action buttons are visible.

### Run History

**Given** a task with 3 completed runs,
**When** the user views the run history tab,
**Then** all 3 runs are listed with agent role, status, duration, cost, and start time.

**Given** the run history tab,
**When** the user taps a run,
**Then** they are navigated to the Agent Run Screen for that run.

### Start Run

**Given** a task with no active run,
**When** the user taps "Run Agent",
**Then** a modal shows the list of available agent roles for selection.

**Given** the run agent modal with a selected role,
**When** the user confirms "Start Run",
**Then** a new TaskRun is created via `Http.post` and the user is navigated to the Agent Run Screen.

**Given** a task with an active run (status: running or waiting_for_input),
**When** the user views the task detail,
**Then** the "Run Agent" button is disabled with a tooltip "A run is already active".

### Section Viewer

**Given** a task section with markdown content including code blocks,
**When** the section content is rendered,
**Then** code blocks are displayed with syntax highlighting and a monospace font.

**Given** a task section with version > 1,
**When** the user taps "Show history",
**Then** all versions are listed with version number and timestamp.

## Implementation Notes

- Use `Http` facade for ALL API calls — never instantiate Dio directly.
- All model IDs are `String` (UUID) — no `int` IDs.
- State classes: `extends ChangeNotifier with MagicStateMixin`.
- Task list should support pagination for large task counts (cursor-based or offset).
- Status badges should use a consistent color mapping defined in a shared constant map.
- The "Run Agent" modal should show agent role descriptions to help users pick the right role.
- Task description and acceptance criteria should support markdown preview toggle in create/edit forms.
- Consider a shared `StatusBadge` widget that takes a status string and returns the colored pill.
- Pull-to-refresh should call the state's load method to fetch fresh data.
