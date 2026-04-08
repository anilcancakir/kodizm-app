import 'dart:convert';

import 'package:magic/magic.dart';

/// Task model.
///
/// Represents a Kodizm task within a project. Extends the Magic ORM [Model]
/// with [HasTimestamps] and [InteractsWithPersistence] mixins to provide full
/// persistence and timestamp tracking.
///
/// List-shape fields (always present from `TaskResource`) and detail-shape
/// fields (conditionally present from `TaskDetailResource`) are both supported;
/// detail-only accessors return `null` when the expanded payload was not
/// included in the API response.
///
/// ## Usage
///
/// ```dart
/// // Hydrate from API list response
/// final task = Task.fromMap(responseData);
/// Log.debug(task.title);
///
/// // Access nested relation (detail view only)
/// final roleName = task.assignedAgentRoleName;
///
/// // Find a task by ID
/// final task = await Task.find('task-uuid-001');
/// ```
class Task extends Model with HasTimestamps, InteractsWithPersistence {
  /// The table associated with the model.
  @override
  String get table => 'tasks';

  /// The API resource for remote operations.
  @override
  String get resource => 'tasks';

  /// Whether the primary key is auto-incrementing.
  ///
  /// Set to false because this app uses string UUIDs as primary keys.
  @override
  bool get incrementing => false;

  /// The attributes that are mass assignable.
  @override
  List<String> get fillable => [
    'project_id',
    'parent_task_id',
    'title',
    'type',
    'priority',
    'status',
    'estimated_complexity',
    'assigned_agent_role_id',
    'created_by_user_id',
    'source',
    'design_needed',
    'retry_count',
    'branch_name',
    'task_number',
    'task_id',
    'total_cost_usd',
    'description',
    'acceptance_criteria',
  ];

  /// The attributes that should be cast.
  @override
  Map<String, String> get casts => {};

  // ---------------------------------------------------------------------------
  // Typed Accessors — list shape (always present)
  // ---------------------------------------------------------------------------

  /// Get the task's ID.
  @override
  String get id => getAttribute('id')?.toString() ?? '';

  /// Get the ID of the project this task belongs to.
  String? get projectId => getAttribute('project_id') as String?;

  /// Set the project ID.
  set projectId(String? value) => setAttribute('project_id', value);

  /// Get the optional ID of the parent task (for sub-tasks).
  String? get parentTaskId => getAttribute('parent_task_id') as String?;

  /// Set the parent task ID.
  set parentTaskId(String? value) => setAttribute('parent_task_id', value);

  /// Get the task title.
  String? get title => getAttribute('title') as String?;

  /// Set the task title.
  set title(String? value) => setAttribute('title', value);

  /// Get the task type (e.g. `'feature'`, `'bug'`, `'chore'`).
  String? get type => getAttribute('type') as String?;

  /// Set the task type.
  set type(String? value) => setAttribute('type', value);

  /// Get the task priority (e.g. `'low'`, `'medium'`, `'high'`, `'critical'`).
  String? get priority => getAttribute('priority') as String?;

  /// Set the task priority.
  set priority(String? value) => setAttribute('priority', value);

  /// Get the task status (e.g. `'draft'`, `'in_progress'`, `'done'`).
  String? get status => getAttribute('status') as String?;

  /// Set the task status.
  set status(String? value) => setAttribute('status', value);

  /// Get the optional estimated complexity score.
  int? get estimatedComplexity => getAttribute('estimated_complexity') as int?;

  /// Set the estimated complexity score.
  set estimatedComplexity(int? value) =>
      setAttribute('estimated_complexity', value);

  /// Get the optional ID of the agent role assigned to this task.
  String? get assignedAgentRoleId =>
      getAttribute('assigned_agent_role_id') as String?;

  /// Set the assigned agent role ID.
  set assignedAgentRoleId(String? value) =>
      setAttribute('assigned_agent_role_id', value);

  /// Get the ID of the user who created this task.
  String? get createdByUserId => getAttribute('created_by_user_id') as String?;

  /// Set the created-by user ID.
  set createdByUserId(String? value) =>
      setAttribute('created_by_user_id', value);

  /// Get the source of the task (e.g. `'manual'`, `'ai'`).
  String? get source => getAttribute('source') as String?;

  /// Set the task source.
  set source(String? value) => setAttribute('source', value);

  /// Get whether the task requires a design artifact.
  ///
  /// Returns `false` when the attribute is absent.
  bool get designNeeded => (getAttribute('design_needed') as bool?) ?? false;

  /// Set the design needed flag.
  set designNeeded(bool value) => setAttribute('design_needed', value);

  /// Get the number of retry attempts for this task.
  int? get retryCount => getAttribute('retry_count') as int?;

  /// Set the retry count.
  set retryCount(int? value) => setAttribute('retry_count', value);

  /// Get the optional Git branch name associated with this task.
  String? get branchName => getAttribute('branch_name') as String?;

  /// Set the branch name.
  set branchName(String? value) => setAttribute('branch_name', value);

  /// Get the project-scoped task number (e.g. 1, 2, 3).
  int? get taskNumber => getAttribute('task_number') as int?;

  /// Get the formatted task identifier (e.g. "KDZ-1").
  String? get taskId => getAttribute('task_id') as String?;

  /// Get the optional total cost in USD accumulated by agent runs for this task.
  String? get totalCostUsd => getAttribute('total_cost_usd') as String?;

  /// Set the total cost in USD.
  set totalCostUsd(String? value) => setAttribute('total_cost_usd', value);

  /// Get the allowed status transitions for this task (detail view only).
  List<String> get allowedTransitions {
    final raw = getAttribute('allowed_transitions');
    if (raw is List) return raw.cast<String>();
    return [];
  }

  /// Get the workspace path inside the container (pipeline tasks only).
  String? get worktreePath => getAttribute('worktree_path') as String?;

  /// Get the workspace branch name (pipeline tasks only).
  String? get worktreeBranch => getAttribute('worktree_branch') as String?;

  // ---------------------------------------------------------------------------
  // Typed Accessors — detail shape (conditionally present)
  // ---------------------------------------------------------------------------

  /// Get the optional long-form task description (detail view only).
  String? get description => getAttribute('description') as String?;

  /// Set the task description.
  set description(String? value) => setAttribute('description', value);

  /// Get the optional acceptance criteria text (detail view only).
  String? get acceptanceCriteria =>
      getAttribute('acceptance_criteria') as String?;

  /// Set the acceptance criteria.
  set acceptanceCriteria(String? value) =>
      setAttribute('acceptance_criteria', value);

  // ---------------------------------------------------------------------------
  // Computed (API-only) Accessors — detail shape
  // ---------------------------------------------------------------------------

  /// Get the name of the assigned agent role from the nested relation.
  ///
  /// Returns `null` when the `assigned_agent_role` relation was not loaded
  /// in the API response.
  String? get assignedAgentRoleName {
    final role = getAttribute('assigned_agent_role') as Map<String, dynamic>?;
    return role?['name'] as String?;
  }

  /// Get the name of the user who created this task from the nested relation.
  ///
  /// Returns `null` when the `created_by_user` relation was not loaded
  /// in the API response.
  String? get createdByUserName {
    final user = getAttribute('created_by_user') as Map<String, dynamic>?;
    return user?['name'] as String?;
  }

  /// Pull requests associated with this task (detail view only).
  ///
  /// Returns an empty list when the `pull_requests` relation was not loaded
  /// in the API response.
  List<Map<String, dynamic>> get pullRequests {
    final data = getAttribute('pull_requests');
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Get the total number of sub-tasks (detail view only).
  int? get subTasksCount => getAttribute('sub_tasks_count') as int?;

  /// Get the total number of sections (detail view only).
  int? get sectionsCount => getAttribute('sections_count') as int?;

  /// Get the total number of linked conversations (detail view only).
  int? get linkedConversationsCount =>
      getAttribute('linked_conversations_count') as int?;

  // ---------------------------------------------------------------------------
  // Static Helpers
  // ---------------------------------------------------------------------------

  /// Find a task by ID.
  ///
  /// Returns `null` if no task with the given [id] exists.
  ///
  /// ```dart
  /// final task = await Task.find('task-uuid-001');
  /// ```
  static Future<Task?> find(dynamic id) =>
      InteractsWithPersistence.findById<Task>(id, Task.new);

  /// Get all tasks.
  ///
  /// ```dart
  /// final tasks = await Task.all();
  /// ```
  static Future<List<Task>> all() =>
      InteractsWithPersistence.allModels<Task>(Task.new);

  // ---------------------------------------------------------------------------
  // Factory Methods
  // ---------------------------------------------------------------------------

  /// Create a [Task] from a [Map].
  ///
  /// Uses [setRawAttributes] to hydrate the model directly from raw API data,
  /// bypassing mass-assignment protection. The [exists] flag is set based on
  /// whether the map contains an `id` key.
  ///
  /// ```dart
  /// final task = Task.fromMap({'id': 'task-uuid-001', 'title': 'My Task', ...});
  /// ```
  static Task fromMap(Map<String, dynamic> map) {
    return Task()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }

  /// Create a [Task] from a JSON string.
  ///
  /// Decodes [json] and delegates to [fromMap].
  ///
  /// ```dart
  /// final task = Task.fromJson('{"id":"task-uuid-001","title":"My Task"}');
  /// ```
  static Task fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return Task.fromMap(map);
  }
}
