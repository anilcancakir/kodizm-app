import 'package:magic/magic.dart';

import '../models/agent_role.dart';
import '../models/conversation.dart';
import '../models/task.dart';
import '../models/task_section.dart';

// ---------------------------------------------------------------------------
// Sort support
// ---------------------------------------------------------------------------

/// Fields by which the task list can be sorted locally.
enum TaskSortField {
  /// Sort by task priority (critical → high → medium → low).
  priority,

  /// Sort by task status (alphabetically).
  status,

  /// Sort by creation timestamp (oldest first).
  createdAt,

  /// Sort by last updated timestamp (most recent first).
  updatedAt,
}

// ---------------------------------------------------------------------------
// TaskState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for task CRUD, filters, sorting, and related
/// operations.
///
/// Manages the list of tasks for a project, a single selected task, task
/// sections, task runs, and available agent roles.
///
/// The primary state (`rxState`) holds the `List<Task>` for the active
/// project. Secondary state fields ([selectedTask], [sections], [runs],
/// [agentRoles], [startingRun]) are managed independently with manual
/// [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final tasks = TaskState.instance;
///
/// // Fetch all tasks for a project (with optional filters).
/// await tasks.fetchTasks(
///   'team-uuid-001',
///   'proj-uuid-001',
///   statusFilter: ['draft', 'in_progress'],
/// );
/// final list = tasks.rxState; // List<Task>?
///
/// // Fetch a single task.
/// await tasks.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');
/// final selected = tasks.selectedTask;
///
/// // Sort the in-memory list.
/// tasks.sortTasks(TaskSortField.priority);
/// ```
class TaskState extends MagicController with MagicStateMixin<List<Task>> {
  /// Creates a [TaskState].
  TaskState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static TaskState get instance => Magic.findOrPut(TaskState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  Task? _selectedTask;
  List<TaskSection> _sections = [];
  List<Conversation> _conversations = [];
  List<AgentRole> _agentRoles = [];
  bool _startingRun = false;

  /// The currently selected task (set by [fetchTask]).
  Task? get selectedTask => _selectedTask;

  /// The sections belonging to the selected task (set by [fetchSections]).
  List<TaskSection> get sections => _sections;

  /// The conversations belonging to the selected task (set by [fetchConversations]).
  List<Conversation> get conversations => _conversations;

  /// The agent roles available for the active team (set by [fetchAgentRoles]).
  List<AgentRole> get agentRoles => _agentRoles;

  /// Whether a new run is being dispatched via [startRun].
  bool get startingRun => _startingRun;

  // ---------------------------------------------------------------------------
  // Task list operations
  // ---------------------------------------------------------------------------

  /// Fetch all tasks for the given [teamId] and [projectId].
  ///
  /// Optional filter and sort query parameters:
  /// - [statusFilter] — comma-separated status slugs (e.g. `['draft', 'in_progress']`)
  /// - [typeFilter] — comma-separated type slugs (e.g. `['bug', 'feature']`)
  /// - [priorityFilter] — comma-separated priority slugs (e.g. `['high', 'critical']`)
  /// - [sort] — API sort token (e.g. `'-updated_at'`)
  ///
  /// Sets loading, then populates `rxState` with the parsed task list on
  /// success, or transitions to error on failure.
  Future<void> fetchTasks(
    String teamId,
    String projectId, {
    List<String>? statusFilter,
    List<String>? typeFilter,
    List<String>? priorityFilter,
    String? sort,
  }) async {
    final Map<String, dynamic> query = {};

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query['status'] = statusFilter.join(',');
    }
    if (typeFilter != null && typeFilter.isNotEmpty) {
      query['type'] = typeFilter.join(',');
    }
    if (priorityFilter != null && priorityFilter.isNotEmpty) {
      query['priority'] = priorityFilter.join(',');
    }
    if (sort != null) {
      query['sort'] = sort;
    }

    await fetchList<Task>(
      '/teams/$teamId/projects/$projectId/tasks',
      Task.fromMap,
      query: query.isEmpty ? null : query,
    );
  }

  /// Fetch a single task and store it as [selectedTask].
  ///
  /// Does **not** affect the primary list state. Calls [refreshUI] after
  /// updating [_selectedTask].
  Future<void> fetchTask(String teamId, String projectId, String taskId) async {
    final response = await Http.get(
      '/teams/$teamId/projects/$projectId/tasks/$taskId',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedTask = Task.fromMap(data);
    } else {
      _selectedTask = null;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new task under the given [teamId] and [projectId].
  ///
  /// Returns the created [Task] on success, or `null` on failure.
  Future<Task?> createTask(
    String teamId,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/tasks',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> taskData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return Task.fromMap(taskData);
    }

    return null;
  }

  /// Update an existing task.
  ///
  /// Returns the updated [Task] on success (and stores it as [selectedTask]),
  /// or `null` on failure.
  Future<Task?> updateTask(
    String teamId,
    String projectId,
    String taskId,
    Map<String, dynamic> data,
  ) async {
    final response = await Http.put(
      '/teams/$teamId/projects/$projectId/tasks/$taskId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> taskData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedTask = Task.fromMap(taskData);
      refreshUI();
      return _selectedTask;
    }

    return null;
  }

  /// Delete a task.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteTask(
    String teamId,
    String projectId,
    String taskId,
  ) async {
    final response = await Http.delete(
      '/teams/$teamId/projects/$projectId/tasks/$taskId',
    );

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // Status transition
  // ---------------------------------------------------------------------------

  /// Transition a task to a new [newStatus].
  ///
  /// Sends a PUT with `{status: newStatus}` and updates [selectedTask].
  /// Returns the updated [Task] on success, or `null` on failure.
  Future<Task?> transitionStatus(
    String teamId,
    String projectId,
    String taskId,
    String newStatus,
  ) async {
    final response = await Http.put(
      '/teams/$teamId/projects/$projectId/tasks/$taskId',
      data: {'status': newStatus},
    );

    if (response.successful) {
      final Map<String, dynamic> taskData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedTask = Task.fromMap(taskData);
      refreshUI();
      return _selectedTask;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  /// Fetch all sections for the given task and store them in [sections].
  ///
  /// Calls [refreshUI] after updating [_sections].
  Future<void> fetchSections(
    String teamId,
    String projectId,
    String taskId,
  ) async {
    final response = await Http.get(
      '/teams/$teamId/projects/$projectId/tasks/$taskId/sections',
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _sections = items
          .map((item) => TaskSection.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      _sections = [];
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Conversations (formerly Runs)
  // ---------------------------------------------------------------------------

  /// Fetch all conversations for the given task and store them in [conversations].
  ///
  /// Calls [refreshUI] after updating [_conversations].
  Future<void> fetchConversations(
    String teamId,
    String projectId,
    String taskId,
  ) async {
    final response = await Http.get(
      '/teams/$teamId/projects/$projectId/conversations',
      query: {'task_id': taskId},
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _conversations = items
          .map((item) => Conversation.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      _conversations = [];
    }

    refreshUI();
  }

  /// Dispatch a new autonomous conversation run for the given task.
  ///
  /// Sets [startingRun] to `true` during the request. Returns the created
  /// [Conversation] on success, or `null` on failure.
  Future<Conversation?> startRun(
    String teamId,
    String projectId,
    String taskId,
    String agentRoleId,
  ) async {
    _startingRun = true;
    refreshUI();

    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/tasks/$taskId/run',
      data: {'agent_role_id': agentRoleId},
    );

    _startingRun = false;

    if (response.successful) {
      final Map<String, dynamic> convData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      refreshUI();
      return Conversation.fromMap(convData);
    }

    refreshUI();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Agent roles
  // ---------------------------------------------------------------------------

  /// Fetch the available agent roles for the given [teamId].
  ///
  /// Stores results in [agentRoles] and calls [refreshUI].
  Future<void> fetchAgentRoles(String teamId) async {
    final response = await Http.get('/teams/$teamId/agent-roles');

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _agentRoles = items
          .map((item) => AgentRole.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      _agentRoles = [];
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  /// Sort the in-memory task list by the given [field].
  ///
  /// - [TaskSortField.priority] sorts critical → high → medium → low.
  /// - [TaskSortField.status] sorts alphabetically by status slug.
  /// - [TaskSortField.createdAt] sorts oldest first.
  /// - [TaskSortField.updatedAt] sorts most recently updated first.
  ///
  /// No-ops when `rxState` is null or empty. Calls [setSuccess] to notify
  /// listeners.
  void sortTasks(TaskSortField field) {
    final tasks = rxState;
    if (tasks == null || tasks.isEmpty) return;

    const priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};

    final sorted = List<Task>.from(tasks);

    switch (field) {
      case TaskSortField.priority:
        sorted.sort((a, b) {
          final aOrder = priorityOrder[a.priority] ?? 99;
          final bOrder = priorityOrder[b.priority] ?? 99;
          return aOrder.compareTo(bOrder);
        });
      case TaskSortField.status:
        sorted.sort((a, b) => (a.status ?? '').compareTo(b.status ?? ''));
      case TaskSortField.createdAt:
        sorted.sort((a, b) {
          final aDate = a.createdAt?.toDateTime ?? DateTime(0);
          final bDate = b.createdAt?.toDateTime ?? DateTime(0);
          return aDate.compareTo(bDate); // Oldest first.
        });
      case TaskSortField.updatedAt:
        sorted.sort((a, b) {
          final aDate = a.updatedAt?.toDateTime ?? DateTime(0);
          final bDate = b.updatedAt?.toDateTime ?? DateTime(0);
          return bDate.compareTo(aDate); // Most recent first.
        });
    }

    setSuccess(sorted);
  }
}
