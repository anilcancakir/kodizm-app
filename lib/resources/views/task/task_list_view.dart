import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_role.dart';
import '../../../app/models/task.dart';
import '../../../app/models/user.dart';
import '../../../app/state/task_state.dart';
import '../../widgets/atoms/priority_badge.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/atoms/task_type_icon.dart';
import '../../widgets/organisms/agent_role_picker_modal.dart';
import '../../widgets/organisms/task_creation_method_modal.dart';
import 'package:magic_starter/magic_starter.dart';

/// Task list view — displays all tasks for a given project.
///
/// Fetches tasks via [TaskState.instance] on init, renders filter chips for
/// status/type/priority, sort controls, and a pull-to-refresh task list.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/tasks');
/// // or construct directly:
/// TaskListView(projectId: 'proj-uuid-001')
/// ```
class TaskListView extends StatefulWidget {
  /// Creates the [TaskListView] for the given [projectId].
  const TaskListView({required this.projectId, super.key});

  /// The ID of the project whose tasks are shown.
  final String projectId;

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  /// Active sort field — defaults to priority.
  TaskSortField _sortField = TaskSortField.priority;

  /// Active status filter chips (empty = no filter).
  final Set<String> _statusFilter = {};

  /// Active type filter chips (empty = no filter).
  final Set<String> _typeFilter = {};

  /// Active priority filter chips (empty = no filter).
  final Set<String> _priorityFilter = {};

  // -----------------------------------------------------------------------
  // Available filter options
  // -----------------------------------------------------------------------

  static const List<String> _statusOptions = [
    'draft',
    'analysis',
    'planning',
    'design',
    'in_progress',
    'review',
    'testing',
    'done',
    'failed',
  ];

  static const List<String> _typeOptions = ['story', 'task', 'bug', 'spike'];

  static const List<String> _priorityOptions = ['p0', 'p1', 'p2', 'p3'];

  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await TaskState.instance.fetchTasks(
      teamId,
      widget.projectId,
      statusFilter: _statusFilter.isEmpty ? null : _statusFilter.toList(),
      typeFilter: _typeFilter.isEmpty ? null : _typeFilter.toList(),
      priorityFilter: _priorityFilter.isEmpty ? null : _priorityFilter.toList(),
    );
  }

  void _onSortChanged(TaskSortField field) {
    if (field == _sortField) return;
    setState(() => _sortField = field);
    TaskState.instance.sortTasks(field);
  }

  void _toggleStatusFilter(String value) {
    setState(() {
      if (_statusFilter.contains(value)) {
        _statusFilter.remove(value);
      } else {
        _statusFilter.add(value);
      }
    });
    _fetchTasks();
  }

  void _toggleTypeFilter(String value) {
    setState(() {
      if (_typeFilter.contains(value)) {
        _typeFilter.remove(value);
      } else {
        _typeFilter.add(value);
      }
    });
    _fetchTasks();
  }

  void _togglePriorityFilter(String value) {
    setState(() {
      if (_priorityFilter.contains(value)) {
        _priorityFilter.remove(value);
      } else {
        _priorityFilter.add(value);
      }
    });
    _fetchTasks();
  }

  void _clearFilters() {
    setState(() {
      _statusFilter.clear();
      _typeFilter.clear();
      _priorityFilter.clear();
    });
    _fetchTasks();
  }

  // -----------------------------------------------------------------------
  // Create task flow
  // -----------------------------------------------------------------------

  /// Shows the creation method modal and routes accordingly.
  ///
  /// `'manual'` → navigates to the form page.
  /// `'chat'`   → fetches agent roles, shows picker, navigates to chat.
  Future<void> _handleCreateTask() async {
    final result = await TaskCreationMethodModal.show(context);
    if (!mounted || result == null) return;

    switch (result) {
      case 'manual':
        MagicRoute.to('/projects/${widget.projectId}/tasks/create');
      case 'chat':
        _openChatWithBa();
    }
  }

  /// Fetches agent roles, shows the [AgentRolePickerModal], then navigates
  /// to the chat view with the selected role.
  Future<void> _openChatWithBa() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null || teamId.isEmpty) return;

    await TaskState.instance.fetchAgentRoles(teamId);
    if (!mounted) return;

    final roles = TaskState.instance.agentRoles;
    final AgentRole? selected = await AgentRolePickerModal.show(context, roles);

    if (!mounted || selected == null) return;

    MagicRoute.to(
      '/projects/${widget.projectId}/chat?agentRoleId=${selected.id}',
    );
  }

  /// Whether any filter chip is currently active.
  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty ||
      _typeFilter.isNotEmpty ||
      _priorityFilter.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: trans('tasks.title'),
          subtitle: trans('tasks.list_subtitle'),
          leading: WAnchor(
            onTap: () => MagicRoute.to('/projects/${widget.projectId}'),
            child: WDiv(
              className: '''
                flex flex-row items-center gap-1
                px-2 py-1 rounded-lg
                text-slate-500 dark:text-slate-400
              ''',
              children: [
                WIcon(
                  Icons.arrow_back,
                  className: 'text-base text-slate-500 dark:text-slate-400',
                ),
              ],
            ),
          ),
          actions: [
            WAnchor(
              onTap: _handleCreateTask,
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-amber-400
                ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('tasks.create_task'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // Filter chips
        // -----------------------------------------------------------------
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            // Status filters
            _FilterChipRow(
              label: trans('tasks.filter_status'),
              options: _statusOptions,
              activeValues: _statusFilter,
              labelBuilder: (v) => trans('tasks.status_$v'),
              onToggle: _toggleStatusFilter,
            ),
            // Type filters
            _FilterChipRow(
              label: trans('tasks.filter_type'),
              options: _typeOptions,
              activeValues: _typeFilter,
              labelBuilder: (v) => trans('tasks.type_$v'),
              onToggle: _toggleTypeFilter,
            ),
            // Priority filters
            _FilterChipRow(
              label: trans('tasks.filter_priority'),
              options: _priorityOptions,
              activeValues: _priorityFilter,
              labelBuilder: (v) => trans('tasks.priority_$v'),
              onToggle: _togglePriorityFilter,
            ),
            // Clear all filters chip
            if (_hasActiveFilters)
              WAnchor(
                onTap: _clearFilters,
                child: WDiv(
                  className: '''
                    self-start
                    px-3 py-1 rounded-full
                    bg-red-500/10 text-red-500
                    border border-red-500/20
                  ''',
                  child: WText(
                    trans('tasks.clear_filters'),
                    className: 'text-xs font-medium text-red-500',
                  ),
                ),
              ),
          ],
        ),

        // -----------------------------------------------------------------
        // Sort controls
        // -----------------------------------------------------------------
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WText(
              trans('tasks.sort_by'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            _SortButton(
              label: trans('tasks.sort_priority'),
              isActive: _sortField == TaskSortField.priority,
              onTap: () => _onSortChanged(TaskSortField.priority),
            ),
            _SortButton(
              label: trans('tasks.sort_status'),
              isActive: _sortField == TaskSortField.status,
              onTap: () => _onSortChanged(TaskSortField.status),
            ),
            _SortButton(
              label: trans('tasks.sort_created'),
              isActive: _sortField == TaskSortField.createdAt,
              onTap: () => _onSortChanged(TaskSortField.createdAt),
            ),
            _SortButton(
              label: trans('tasks.sort_updated'),
              isActive: _sortField == TaskSortField.updatedAt,
              onTap: () => _onSortChanged(TaskSortField.updatedAt),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // State-driven content
        // -----------------------------------------------------------------
        ListenableBuilder(
          listenable: TaskState.instance,
          builder: (context, _) => TaskState.instance.renderState(
            (tasks) => _TaskList(
              tasks: tasks,
              projectId: widget.projectId,
              onRefresh: _fetchTasks,
            ),
            onLoading: const _LoadingView(),
            onError: (msg) => _ErrorView(message: msg),
            onEmpty: _EmptyView(onCreateTap: _handleCreateTask),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip row
// ---------------------------------------------------------------------------

/// A horizontal scrollable row of filter chips for a single filter dimension.
///
/// Each chip toggles its value in [activeValues]. Active chips use the amber
/// accent style; inactive chips use the muted border style.
class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.label,
    required this.options,
    required this.activeValues,
    required this.labelBuilder,
    required this.onToggle,
  });

  final String label;
  final List<String> options;
  final Set<String> activeValues;
  final String Function(String value) labelBuilder;
  final void Function(String value) onToggle;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'wrap items-center gap-2',
      children: [
        WText(
          label,
          className:
              'text-xs font-medium text-slate-500 dark:text-slate-400 w-14',
        ),
        for (final option in options)
          WAnchor(
            onTap: () => onToggle(option),
            child: WDiv(
              className: activeValues.contains(option)
                  ? '''
                    px-2.5 py-1 rounded-full
                    bg-amber-400/20 text-amber-600
                    dark:text-amber-400
                    border border-amber-400/30
                  '''
                  : '''
                    px-2.5 py-1 rounded-full
                    bg-white dark:bg-gray-800
                    text-slate-500
                    border border-slate-200 dark:border-slate-700
                  ''',
              child: WText(
                labelBuilder(option),
                className: activeValues.contains(option)
                    ? 'text-xs font-medium text-amber-600 dark:text-amber-400'
                    : 'text-xs font-medium text-slate-500 dark:text-slate-400',
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sort button atom
// ---------------------------------------------------------------------------

/// A pill-shaped toggle button for selecting the active sort field.
class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeClass = isActive
        ? 'bg-primary text-white dark:bg-primary-700'
        : 'bg-white text-slate-600 dark:bg-gray-800 dark:text-slate-300 border border-slate-200 dark:border-gray-700';

    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: 'px-3 py-1 rounded-full text-sm font-medium $activeClass',
        child: WText(
          label,
          className: isActive
              ? 'text-sm font-medium text-white'
              : 'text-sm font-medium text-slate-600 dark:text-slate-300',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

/// Full-width centred spinner shown while tasks are loading.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

/// Centred error state with icon, title, and raw error [message].
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          trans('tasks.failed_to_load'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        WText(message, className: 'text-sm text-slate-500 dark:text-slate-400'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state view
// ---------------------------------------------------------------------------

/// Centred empty state with CTA button shown when the task list is empty.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-5',
      children: [
        WDiv(
          className: '''
            w-16 h-16 rounded-2xl
            flex items-center justify-center
            bg-slate-100 dark:bg-gray-800
          ''',
          child: WIcon(
            Icons.checklist_outlined,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          trans('tasks.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('tasks.empty_subtitle'),
          className:
              'text-sm text-slate-500 dark:text-slate-400 max-w-xs text-center',
        ),
        WAnchor(
          onTap: onCreateTap,
          child: WDiv(
            className: '''
              flex flex-row items-center gap-2
              px-4 py-2.5 rounded-lg
              bg-amber-400 shadow-xs
            ''',
            children: [
              WIcon(Icons.add, className: 'text-sm text-primary-900'),
              WText(
                trans('tasks.create_task'),
                className: 'text-sm font-medium text-primary-900',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Task list (with refresh)
// ---------------------------------------------------------------------------

/// Scrollable, pull-to-refresh list of [_TaskCard] widgets.
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.projectId,
    required this.onRefresh,
  });

  final List<Task> tasks;
  final String projectId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
        itemBuilder: (context, index) =>
            _TaskCard(task: tasks[index], projectId: projectId),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task card organism
// ---------------------------------------------------------------------------

/// Surface-variant card for a single task entry in the list.
///
/// Row 1: type icon + title + status badge.
/// Row 2: priority badge + agent role + cost + relative time.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.projectId});

  final Task task;
  final String projectId;

  // -----------------------------------------------------------------------

  /// Formats a relative time label from a [DateTime].
  String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return trans('time.just_now');
    if (diff.inHours < 1) {
      return trans('time.minutes_ago', {'minutes': diff.inMinutes.toString()});
    }
    if (diff.inDays < 1) {
      return trans('time.hours_ago', {'hours': diff.inHours.toString()});
    }
    return trans('time.days_ago', {'days': diff.inDays.toString()});
  }

  /// Formats the [totalCostUsd] as `$X.XX` or `--` when absent.
  String _formatCost(String? cost) {
    if (cost == null) return '--';
    final value = double.tryParse(cost);
    if (value == null) return '--';
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final roleName = task.assignedAgentRoleName ?? trans('tasks.unassigned');
    final updatedAt = task.updatedAt?.toDateTime;

    return WAnchor(
      onTap: () => MagicRoute.to('/projects/$projectId/tasks/${task.id}'),
      child: WDiv(
        className: '''
          rounded-xl bg-white dark:bg-gray-800
          border border-slate-200 dark:border-gray-700
          shadow-sm p-4
          flex flex-col gap-3
        ''',
        children: [
          // ---------------------------------------------------------------
          // Row 1: type icon + title + status badge
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              TaskTypeIcon(type: task.type ?? 'task'),
              WDiv(
                className: 'flex-1',
                child: WText(
                  task.title ?? '',
                  className:
                      'text-sm font-semibold text-gray-900 dark:text-white',
                ),
              ),
              if (task.status != null) StatusBadge(status: task.status!),
            ],
          ),

          // ---------------------------------------------------------------
          // Row 2: priority + role + cost + time
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              if (task.priority != null)
                PriorityBadge(priority: task.priority!),
              WDiv(className: 'flex-1'),
              WText(
                roleName,
                className: 'text-xs text-slate-500 dark:text-slate-400',
              ),
              WDiv(className: 'w-px h-3 bg-slate-200 dark:bg-slate-700'),
              WText(
                _formatCost(task.totalCostUsd),
                className: 'text-xs text-slate-500 dark:text-slate-400',
              ),
              WDiv(className: 'w-px h-3 bg-slate-200 dark:bg-slate-700'),
              WText(
                _relativeTime(updatedAt),
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
