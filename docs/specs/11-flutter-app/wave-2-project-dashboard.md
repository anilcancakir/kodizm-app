# Wave 2 — Project & Dashboard Screens

> Spec: 11-Flutter App
> Dependencies: Wave 1 complete, 02-Project Management complete (backend project CRUD + SSH key endpoints)

## Deliverables

- [ ] ProjectListScreen (for current team)
- [ ] ProjectDetailScreen (settings, SSH key, git status)
- [ ] ProjectCreateScreen
- [ ] DashboardScreen (stats, active runs overview, quick actions)
- [ ] ProjectState (ChangeNotifier + MagicStateMixin) — CRUD operations via Http facade
- [ ] Freezed models: Project (with UUID `String` id)

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## Project Screens

### Project List Screen (`/projects`)

- Lists all projects for the current team
- Each project card shows:
  - Name
  - Repository URL (truncated, or "No repo connected")
  - Tech stack badge
  - Task count summary (e.g., "5 tasks, 2 active")
  - Git status indicator (connected/not connected/error)
- Sort: by name (default), by last updated
- "Create Project" FAB or button
- Pull-to-refresh
- Tap project -> navigate to `/projects/{projectId}`
- Empty state: "Create your first project"

### Create Project Screen (`/projects/create`)

- Fields:
  - Name: `string|required|max:255`
  - Description: `text|nullable` (multiline)
  - Repository URL: `string|nullable` — e.g., `git@github.com:org/repo.git`
  - Tech Stack: `string|nullable` — dropdown or text (e.g., `laravel-flutter`, `next-js`, custom)
  - Default Branch: `string` — default `main` (text input)
- Submit: POST `/api/teams/{team}/projects` via `Http`
- On success: navigate to project detail
- After creation with repo URL: prompt user to set up deploy key (show SSH public key)
- On error: show validation errors

### Project Detail Screen (`/projects/{projectId}`)

- **Header**: Project name, description, tech stack badge

#### Info Tab
- Repository URL (copyable)
- Default branch
- Tech stack
- Execution mode badge (manual / semi_auto / full_auto)
- Created at

#### SSH Key Section
- Display SSH public key (copyable text block) for deploy key setup
- "Generate New Key" button -> POST `/api/teams/{team}/projects/{project}/generate-ssh-key` with confirmation dialog
- Instructions: "Add this key as a deploy key in your GitHub/GitLab repository settings"

#### Git Status Section
- Fetch from GET `/api/teams/{team}/projects/{project}/repo-status`
- Status indicators: Connected (green), Not configured (grey), Error (red with message)
- Last clone/pull timestamp
- "Clone/Pull" action button

#### Recent Tasks Section
- Last 5 tasks for this project (quick view)
- "View all tasks" link -> navigate to task list

#### Settings Section (owner/admin only)
- Edit project name, description, repo URL, tech stack, default branch
- Delete project (with confirmation, owner only)

## Dashboard Screen (`/dashboard`)

The dashboard is the home screen after team selection. It provides an overview of the team's activity.

### Layout

```
+--------------------------------------------------------------+
|  Dashboard -- Team Name                    Balance: $42.50    |
+--------------------------------------------------------------+
|                                                               |
|  +--------------+  +--------------+  +---------------------+ |
|  | Active Runs  |  |  Tasks       |  |  Monthly Usage      | |
|  |     3        |  |    47        |  |  $123.45            | |
|  |  running     |  |  12 active   |  |  Mar 2026           | |
|  +--------------+  +--------------+  +---------------------+ |
|                                                               |
|  Active Runs                                    [View All ->] |
|  +----------------------------------------------------------+ |
|  | Developer -- auth-refactor (#42)    Running  2m 34s       | |
|  | QA -- payment-flow (#39)            Running  5m 12s       | |
|  | BA -- chat session                  Waiting  1m 45s       | |
|  +----------------------------------------------------------+ |
|                                                               |
|  Tasks by Status                                              |
|  +----------------------------------------------------------+ |
|  |  [=========] draft: 5                                     | |
|  |  [====] in_progress: 3                                    | |
|  |  [==] review: 2                                           | |
|  |  [==============] done: 8                                 | |
|  +----------------------------------------------------------+ |
|                                                               |
|  Recent Runs                                    [View All ->] |
|  +----------------------------------------------------------+ |
|  | Developer -- login (#35)   Completed  $0.47  3m           | |
|  | QA -- signup (#33)         Failed     $0.12  1m           | |
|  +----------------------------------------------------------+ |
|                                                               |
|  Quick Actions                                                |
|  +--------------+  +--------------+                           |
|  | + Create Task|  | BA Chat      |                           |
|  +--------------+  +--------------+                           |
+--------------------------------------------------------------+
```

### Data Source

- GET `/api/teams/{team}/dashboard` via `Http` facade
- Returns: active_runs, tasks_summary (total + by_status), recent_runs, balance, monthly_usage

### Real-Time Updates via WebSocket

- Subscribe to `private-team.{teamId}` channel on dashboard mount
- Event handlers:

| Event | Dashboard Action |
|-------|-----------------|
| `.run.started` | Add to active runs list |
| `.run.completed` | Move from active to recent runs, update stats |
| `.run.question` | Update active run status to "waiting", show notification |
| `.balance.updated` | Update balance display |

### Balance Display
- Shown in header: `Balance: $42.50`
- Color coding: green (> $10), yellow ($1-$10), red (< $1)
- Tap -> navigates to usage details

### Quick Actions
- **Create Task**: shows project picker modal -> navigates to create task screen
- **BA Chat**: shows project picker modal -> navigates to BA chat screen

## State Management

### ProjectState (ChangeNotifier + MagicStateMixin)

```dart
class ProjectState extends ChangeNotifier with MagicStateMixin {
  List<Project> _projects = [];
  Project? _selectedProject;

  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;

  Future<void> loadProjects(String teamId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects');
      _projects = (response.data['data'] as List)
          .map((json) => Project.fromJson(json))
          .toList();
      notifyListeners();
    });
  }

  Future<void> loadProject(String teamId, String projectId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects/$projectId');
      _selectedProject = Project.fromJson(response.data['data']);
      notifyListeners();
    });
  }

  Future<Project> createProject(String teamId, Map<String, dynamic> data) async {
    return await run(() async {
      final response = await Http.post('/teams/$teamId/projects', data: data);
      final project = Project.fromJson(response.data['data']);
      _projects.add(project);
      notifyListeners();
      return project;
    });
  }

  Future<void> updateProject(String teamId, String projectId, Map<String, dynamic> data) async {
    await run(() async {
      final response = await Http.put('/teams/$teamId/projects/$projectId', data: data);
      final updated = Project.fromJson(response.data['data']);
      _selectedProject = updated;
      _projects = _projects.map((p) => p.id == projectId ? updated : p).toList();
      notifyListeners();
    });
  }

  Future<void> deleteProject(String teamId, String projectId) async {
    await run(() async {
      await Http.delete('/teams/$teamId/projects/$projectId');
      _projects.removeWhere((p) => p.id == projectId);
      _selectedProject = null;
      notifyListeners();
    });
  }
}
```

### DashboardState (ChangeNotifier + MagicStateMixin)

```dart
class DashboardState extends ChangeNotifier with MagicStateMixin {
  DashboardData? _data;

  DashboardData? get data => _data;

  Future<void> loadDashboard(String teamId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/dashboard');
      _data = DashboardData.fromJson(response.data['data']);
      notifyListeners();
    });
  }

  /// Called from WebSocket event handlers to update dashboard in real-time
  void onRunStarted(ActiveRun run) {
    if (_data == null) return;
    _data = _data!.copyWith(
      activeRuns: [..._data!.activeRuns, run],
    );
    notifyListeners();
  }

  void onRunCompleted(String taskRunId, double costUsd) { /* ... */ }
  void onBalanceUpdated(double newBalance) { /* ... */ }
}
```

## Freezed Models

### Project

```dart
@freezed
class Project with _$Project {
  const factory Project({
    required String id,           // UUID
    required String teamId,       // UUID
    required String name,
    required String slug,
    String? description,
    String? repositoryUrl,
    required String defaultBranch,
    String? techStack,
    String? sshPublicKey,
    required String executionMode,
    Map<String, dynamic>? settings,
    required DateTime createdAt,
    required DateTime updatedAt,
    // computed
    int? taskCount,
    int? activeRunCount,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}
```

### DashboardData

```dart
@freezed
class DashboardData with _$DashboardData {
  const factory DashboardData({
    required List<ActiveRun> activeRuns,
    required TasksSummary tasksSummary,
    required List<RecentRun> recentRuns,
    required double balance,
    required MonthlyUsage monthlyUsage,
  }) = _DashboardData;

  factory DashboardData.fromJson(Map<String, dynamic> json) => _$DashboardDataFromJson(json);
}

@freezed
class ActiveRun with _$ActiveRun {
  const factory ActiveRun({
    required String taskRunId,      // UUID
    required String taskId,         // UUID
    required String taskTitle,
    required String agentRole,
    required String status,
    required DateTime startedAt,
    double? costUsd,
  }) = _ActiveRun;

  factory ActiveRun.fromJson(Map<String, dynamic> json) => _$ActiveRunFromJson(json);
}

@freezed
class TasksSummary with _$TasksSummary {
  const factory TasksSummary({
    required int total,
    required Map<String, int> byStatus,
  }) = _TasksSummary;

  factory TasksSummary.fromJson(Map<String, dynamic> json) => _$TasksSummaryFromJson(json);
}

@freezed
class RecentRun with _$RecentRun {
  const factory RecentRun({
    required String taskRunId,      // UUID
    required String taskId,         // UUID
    required String taskTitle,
    required String agentRole,
    required String status,
    required double costUsd,
    int? durationMs,
    DateTime? completedAt,
  }) = _RecentRun;

  factory RecentRun.fromJson(Map<String, dynamic> json) => _$RecentRunFromJson(json);
}

@freezed
class MonthlyUsage with _$MonthlyUsage {
  const factory MonthlyUsage({
    required double totalCostUsd,
    required String period,
    required int runCount,
  }) = _MonthlyUsage;

  factory MonthlyUsage.fromJson(Map<String, dynamic> json) => _$MonthlyUsageFromJson(json);
}
```

## Acceptance Criteria

### Project List

**Given** a team with 3 projects,
**When** the user navigates to `/projects`,
**Then** all 3 projects are listed with name, repo status, tech stack, and task counts.

**Given** a team with no projects,
**When** the user navigates to `/projects`,
**Then** an empty state with "Create your first project" is displayed.

### Create Project

**Given** a user on the create project screen,
**When** they fill in name, description, repo URL, tech stack, and submit,
**Then** the project is created via `Http.post` and the user is navigated to the project detail screen.

**Given** a project created with a repository URL,
**When** the project detail screen loads,
**Then** the SSH public key section is displayed with instructions to add it as a deploy key.

### Project Detail

**Given** a project with a connected git repo,
**When** the user views the project detail,
**Then** the git status shows "Connected" (green) with the last sync timestamp.

**Given** a project with no repo configured,
**When** the user views the project detail,
**Then** the git status shows "Not configured" (grey).

**Given** an admin user on the project detail screen,
**When** they tap "Generate New Key",
**Then** a confirmation dialog warns that the old key will be invalidated. On confirm, a new SSH keypair is generated and the public key display updates.

### SSH Key

**Given** a project with an SSH public key,
**When** the user views the SSH key section,
**Then** the full public key is displayed in a copyable text block with a copy button.

### Dashboard

**Given** a team with 2 active runs,
**When** the user navigates to the dashboard,
**Then** both active runs are displayed with agent role, task title, status, and elapsed time.

**Given** a team dashboard is open,
**When** a new run starts (`.run.started` WebSocket event),
**Then** the active runs section updates in real-time to include the new run.

**Given** a team dashboard is open,
**When** a run completes (`.run.completed` WebSocket event),
**Then** the run moves from active to recent, and the balance display updates.

**Given** a team with tasks in various statuses,
**When** the user views the tasks by status chart,
**Then** the chart shows correct counts per status with color coding.

**Given** a team dashboard with balance $5.00,
**When** the balance is displayed,
**Then** it shows `$5.00` in yellow (between $1 and $10).

### Quick Actions

**Given** the dashboard quick actions,
**When** the user taps "Create Task",
**Then** a project picker modal appears. After selecting a project, the user is navigated to the create task screen for that project.

## Implementation Notes

- Use `Http` facade for ALL API calls — never instantiate Dio directly.
- All model IDs are `String` (UUID) — no `int` IDs.
- State classes: `extends ChangeNotifier with MagicStateMixin`.
- `MagicStateMixin.run()` handles setting `isLoading = true`, catching errors, and calling `notifyListeners()`.
- Project list should use `RefreshIndicator` for pull-to-refresh.
- SSH public key display should use a monospace font with a "Copy to clipboard" icon button.
- Git status polling: do NOT auto-poll. Fetch on screen load, user can manually refresh.
- Dashboard data should auto-refresh when returning to the screen.
- Tasks by status chart: use a simple horizontal stacked bar — no charting library needed for MVP.
- Active runs: show elapsed time as a live counter (Timer.periodic).
- WebSocket subscription for team channel should be managed at the dashboard level (subscribe on mount, unsubscribe on dispose).
