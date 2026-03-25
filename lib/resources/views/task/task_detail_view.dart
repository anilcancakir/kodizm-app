import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_role.dart';
import '../../../app/models/task.dart';
import '../../../app/models/task_run.dart';
import '../../../app/models/task_section.dart';
import '../../../app/models/user.dart';
import '../../../app/state/task_state.dart';
import '../../widgets/atoms/priority_badge.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/atoms/task_type_icon.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';
import '../../widgets/organisms/markdown_viewer.dart';

/// Task detail view — displays full task info, status transitions, sections,
/// run history, and a start-run modal.
///
/// Fetches task, sections, and runs in parallel on [initState]. All state is
/// driven by [TaskState.instance] via a [ListenableBuilder].
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/tasks/$taskId');
/// // or construct directly:
/// TaskDetailView(projectId: 'proj-uuid-001', taskId: 'task-uuid-001')
/// ```
class TaskDetailView extends StatefulWidget {
  /// Creates the [TaskDetailView] for the given [projectId] and [taskId].
  const TaskDetailView({
    required this.projectId,
    required this.taskId,
    super.key,
  });

  /// The ID of the project this task belongs to.
  final String projectId;

  /// The ID of the task to display.
  final String taskId;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  // ---------------------------------------------------------------------------
  // Transition map — mirrors backend TaskStatus.php allowed transitions.
  // ---------------------------------------------------------------------------

  static const Map<String, List<String>> _allowedTransitions = {
    'draft': ['analysis', 'failed'],
    'analysis': ['planning', 'failed'],
    'planning': ['design', 'in_progress', 'failed'],
    'design': ['in_progress', 'failed'],
    'in_progress': ['review', 'failed'],
    'review': ['testing', 'in_progress', 'failed'],
    'testing': ['done', 'in_progress', 'failed'],
    'failed': ['draft'],
    'done': [],
  };

  // ---------------------------------------------------------------------------
  // Transition label keys — keyed by target status.
  // ---------------------------------------------------------------------------

  static const Map<String, String> _transitionLabelKeys = {
    'analysis': 'tasks.transition_start_analysis',
    'planning': 'tasks.transition_start_planning',
    'design': 'tasks.transition_start_design',
    'in_progress': 'tasks.transition_start_development',
    'review': 'tasks.transition_submit_review',
    'testing': 'tasks.transition_approve_testing',
    'done': 'tasks.transition_approve_done',
    'failed': 'tasks.transition_mark_failed',
    'draft': 'tasks.transition_reopen',
  };

  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  /// Fetches task, sections, and runs in parallel.
  Future<void> _fetchAll() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await Future.wait([
      TaskState.instance.fetchTask(teamId, widget.projectId, widget.taskId),
      TaskState.instance.fetchSections(teamId, widget.projectId, widget.taskId),
      TaskState.instance.fetchRuns(teamId, widget.projectId, widget.taskId),
    ]);
  }

  // -----------------------------------------------------------------------
  // Transition helpers
  // -----------------------------------------------------------------------

  /// Handles a status transition button tap.
  Future<void> _onTransitionTap(String newStatus) async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await TaskState.instance.transitionStatus(
      teamId,
      widget.projectId,
      widget.taskId,
      newStatus,
    );
  }

  // -----------------------------------------------------------------------
  // Start-run modal
  // -----------------------------------------------------------------------

  /// Opens the agent role picker dialog to start a new run.
  Future<void> _showStartRunDialog(BuildContext context) async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await TaskState.instance.fetchAgentRoles(teamId);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _StartRunDialog(
        projectId: widget.projectId,
        taskId: widget.taskId,
        teamId: teamId,
        onRunStarted: (runId) {
          if (context.mounted) {
            MagicRoute.to(
              '/projects/${widget.projectId}/tasks/${widget.taskId}/runs/$runId',
            );
          }
        },
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Formatting helpers
  // -----------------------------------------------------------------------

  /// Formats a [DateTime] as "Mar 25, 2026".
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }

  /// Formats a cost double as `$X.XXXX` or `--` when absent.
  String _formatCost(String? cost) {
    if (cost == null) return '--';
    final value = double.tryParse(cost);
    if (value == null) return '--';
    return '\$${value.toStringAsFixed(4)}';
  }

  /// Whether any active run prevents starting a new one.
  bool _hasActiveRun(List<TaskRun> runs) {
    return runs.any(
      (r) => r.status == 'running' || r.status == 'waiting_for_input',
    );
  }

  /// Maps a section [type] slug to a human-readable label via i18n.
  String _sectionTypeLabel(String type) {
    final key = 'tasks.section_type_${type.replaceAll('-', '_')}';
    return trans(key);
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TaskState.instance,
      builder: (context, _) {
        final task = TaskState.instance.selectedTask;
        final sections = TaskState.instance.sections;
        final runs = TaskState.instance.runs;

        if (task == null) {
          return const WDiv(
            className: 'w-full flex items-center justify-center py-16',
            child: CircularProgressIndicator(),
          );
        }

        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            // -----------------------------------------------------------
            // Header
            // -----------------------------------------------------------
            PageHeader(
              title: task.title ?? '',
              leading: WAnchor(
                onTap: () =>
                    MagicRoute.to('/projects/${widget.projectId}/tasks'),
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
                if (task.status != null) StatusBadge(status: task.status!),
                if (task.priority != null)
                  PriorityBadge(priority: task.priority!),
                TaskTypeIcon(type: task.type ?? 'task'),
              ],
            ),

            // -----------------------------------------------------------
            // Status Actions
            // -----------------------------------------------------------
            _buildStatusActionsSection(task),

            // -----------------------------------------------------------
            // Task Info
            // -----------------------------------------------------------
            _buildInfoSection(task),

            // -----------------------------------------------------------
            // Sections
            // -----------------------------------------------------------
            _buildSectionsSection(sections),

            // -----------------------------------------------------------
            // Run History + Start Run button
            // -----------------------------------------------------------
            _buildRunHistorySection(context, runs),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Section builders
  // -----------------------------------------------------------------------

  /// Builds the status transition action card.
  Widget _buildStatusActionsSection(Task task) {
    final currentStatus = task.status ?? 'draft';
    final transitions = _allowedTransitions[currentStatus] ?? [];

    return SectionCard(
      title: trans('tasks.status_actions'),
      children: [
        if (transitions.isEmpty)
          WText(
            trans('tasks.status_done'),
            className: 'text-sm text-slate-500 dark:text-slate-400',
          )
        else
          WDiv(
            className: 'flex flex-row flex-wrap gap-2',
            children: [
              for (final targetStatus in transitions)
                WAnchor(
                  onTap: () => _onTransitionTap(targetStatus),
                  child: WDiv(
                    className: _transitionButtonClassName(
                      currentStatus,
                      targetStatus,
                    ),
                    child: WText(
                      trans(
                        _transitionLabelKeys[targetStatus] ??
                            'tasks.transition_start_analysis',
                      ),
                      className: 'text-sm font-medium',
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// Returns the className string for a transition button.
  String _transitionButtonClassName(String from, String to) {
    if (to == 'failed') {
      return 'bg-red-500/15 text-red-500 px-3 py-1.5 rounded-lg text-sm font-medium';
    }
    if (to == 'draft') {
      // Reopen from failed.
      return '''
        bg-slate-200 dark:bg-slate-700
        text-slate-600 dark:text-slate-300
        px-3 py-1.5 rounded-lg text-sm font-medium
      ''';
    }
    return 'bg-amber-400 text-primary-900 px-3 py-1.5 rounded-lg text-sm font-medium';
  }

  /// Builds the task info section card.
  Widget _buildInfoSection(Task task) {
    final createdAt = task.createdAt?.toDateTime;
    final updatedAt = task.updatedAt?.toDateTime;

    return SectionCard(
      title: trans('tasks.task_info'),
      children: [
        // Description
        WDiv(
          className: 'flex flex-col gap-2',
          children: [
            WText(
              trans('tasks.description_label'),
              className:
                  'text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide',
            ),
            if (task.description != null && task.description!.isNotEmpty)
              MarkdownViewer(data: task.description!)
            else
              WText(
                trans('tasks.no_description'),
                className: 'text-sm text-slate-400 dark:text-slate-500',
              ),
          ],
        ),

        // Acceptance Criteria
        if (task.acceptanceCriteria != null &&
            task.acceptanceCriteria!.isNotEmpty)
          WDiv(
            className: 'flex flex-col gap-2',
            children: [
              WText(
                trans('tasks.acceptance_criteria'),
                className:
                    'text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide',
              ),
              MarkdownViewer(data: task.acceptanceCriteria!),
            ],
          ),

        // Metadata row grid
        WDiv(
          className: 'flex flex-col gap-3',
          children: [
            // Assigned To
            _InfoRow(
              label: trans('tasks.assigned_to'),
              value: task.assignedAgentRoleName ?? trans('tasks.unassigned'),
            ),

            // Branch
            _InfoRow(
              label: trans('tasks.branch'),
              value: task.branchName ?? trans('tasks.no_branch'),
            ),

            // Total cost
            if (task.totalCostUsd != null)
              _InfoRow(
                label: trans('tasks.total_cost'),
                value: _formatCost(task.totalCostUsd),
              ),

            // Created by
            if (task.createdByUserName != null)
              _InfoRow(
                label: trans('tasks.created_by'),
                value: task.createdByUserName!,
              ),

            // Source
            if (task.source != null)
              _InfoRow(label: trans('tasks.source_label'), value: task.source!),

            // Complexity
            if (task.estimatedComplexity != null)
              _InfoRow(
                label: trans('tasks.complexity_label'),
                value: _complexityLabel(task.estimatedComplexity!),
              ),

            // Created At
            if (createdAt != null)
              _InfoRow(
                label: trans('tasks.created_at_label'),
                value: _formatDate(createdAt),
              ),

            // Updated At
            if (updatedAt != null)
              _InfoRow(
                label: trans('tasks.updated_at_label'),
                value: _formatDate(updatedAt),
              ),
          ],
        ),
      ],
    );
  }

  /// Maps an integer complexity score to a human-readable label.
  String _complexityLabel(int complexity) {
    return switch (complexity) {
      1 => trans('tasks.complexity_xs'),
      2 => trans('tasks.complexity_s'),
      3 => trans('tasks.complexity_m'),
      4 => trans('tasks.complexity_l'),
      5 => trans('tasks.complexity_xl'),
      _ => complexity.toString(),
    };
  }

  /// Builds the task sections card.
  Widget _buildSectionsSection(List<TaskSection> sections) {
    return SectionCard(
      title: trans('tasks.sections'),
      children: [
        if (sections.isEmpty)
          WText(
            trans('tasks.no_sections'),
            className: 'text-sm text-slate-400 dark:text-slate-500',
          )
        else
          for (final section in sections)
            WDiv(
              className: '''
                flex flex-col gap-3
                border-b border-slate-100 dark:border-slate-700 pb-4
              ''',
              children: [
                // Header row: type badge + title + version badge
                WDiv(
                  className: 'flex flex-row items-center gap-2',
                  children: [
                    WDiv(
                      className:
                          'px-1.5 py-0.5 rounded bg-indigo-500/10 text-indigo-500',
                      child: WText(
                        _sectionTypeLabel(section.type),
                        className: 'text-[11px] font-semibold text-indigo-500',
                      ),
                    ),
                    WDiv(
                      className: 'flex-1',
                      child: WText(
                        section.title,
                        className:
                            'text-sm font-semibold text-gray-900 dark:text-white',
                      ),
                    ),
                    WDiv(
                      className:
                          'px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700',
                      child: WText(
                        trans('tasks.version_label', {
                          'version': section.version.toString(),
                        }),
                        className:
                            'text-[11px] font-medium text-slate-500 dark:text-slate-400',
                      ),
                    ),
                  ],
                ),
                // Content
                MarkdownViewer(data: section.content),
              ],
            ),
      ],
    );
  }

  /// Builds the run history card with the start-run button.
  Widget _buildRunHistorySection(BuildContext context, List<TaskRun> runs) {
    final hasActive = _hasActiveRun(runs);

    return SectionCard(
      title: trans('tasks.run_history'),
      children: [
        // Start Run button
        WAnchor(
          onTap: hasActive ? null : () => _showStartRunDialog(context),
          child: WDiv(
            className: hasActive
                ? '''
                  self-start flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-slate-100 dark:bg-slate-700
                  opacity-50
                '''
                : '''
                  self-start flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-amber-400
                ''',
            children: [
              WIcon(
                Icons.play_arrow,
                className: hasActive
                    ? 'text-sm text-slate-500'
                    : 'text-sm text-primary-900',
              ),
              WText(
                trans('tasks.run_agent'),
                className: hasActive
                    ? 'text-sm font-semibold text-slate-500'
                    : 'text-sm font-semibold text-primary-900',
              ),
            ],
          ),
        ),

        // Run list or empty state
        if (runs.isEmpty)
          WText(
            trans('tasks.no_runs'),
            className: 'text-sm text-slate-400 dark:text-slate-500',
          )
        else
          WDiv(
            className: 'flex flex-col gap-3',
            children: [
              for (final run in runs)
                _RunRow(
                  run: run,
                  projectId: widget.projectId,
                  taskId: widget.taskId,
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info row molecule
// ---------------------------------------------------------------------------

/// A simple label + value row used inside the task info card.
class _InfoRow extends StatelessWidget {
  /// Creates an [_InfoRow] with a [label] and [value].
  const _InfoRow({required this.label, required this.value});

  /// The field label (e.g. "Assigned To").
  final String label;

  /// The field value (e.g. "Developer").
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-start gap-2',
      children: [
        WText(
          label,
          className:
              'text-xs font-semibold text-slate-500 dark:text-slate-400 w-24 pt-0.5',
        ),
        WDiv(
          className: 'flex-1',
          child: WText(
            value,
            className: 'text-sm text-gray-800 dark:text-gray-200',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Run row molecule
// ---------------------------------------------------------------------------

/// A single row in the run history list.
///
/// Displays: agent role name, status badge, cost, duration (in seconds),
/// and started-at date.
class _RunRow extends StatelessWidget {
  /// Creates a [_RunRow] for the given [run].
  const _RunRow({
    required this.run,
    required this.projectId,
    required this.taskId,
  });

  /// The run to display.
  final TaskRun run;

  /// The project ID for navigation.
  final String projectId;

  /// The task ID for navigation.
  final String taskId;

  // -----------------------------------------------------------------------

  /// Formats a cost double as `$X.XX` or `--`.
  String _formatCost(double? cost) {
    if (cost == null) return '--';
    return '\$${cost.toStringAsFixed(2)}';
  }

  /// Formats duration milliseconds as `Xs` or `--`.
  String _formatDuration(int? ms) {
    if (ms == null) return '--';
    return '${(ms / 1000).round()}s';
  }

  /// Formats [DateTime] as `Mar 25, 2026`.
  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () =>
          MagicRoute.to('/projects/$projectId/tasks/$taskId/runs/${run.id}'),
      child: WDiv(
        className: '''
          flex flex-row items-center gap-3
          p-3 rounded-lg
          bg-slate-50 dark:bg-gray-700/50
        ''',
        children: [
          // Agent role name
          WDiv(
            className: 'flex-1',
            child: WText(
              run.agentRoleName ?? trans('common.unknown'),
              className: 'text-sm font-semibold text-gray-900 dark:text-white',
            ),
          ),
          // Status badge
          StatusBadge(status: run.status),
          // Cost
          WText(
            _formatCost(run.totalCostUsd),
            className: 'text-xs text-slate-500 dark:text-slate-400',
          ),
          // Duration
          WText(
            _formatDuration(run.durationMs),
            className: 'text-xs text-slate-500 dark:text-slate-400',
          ),
          // Started at
          WText(
            _formatDate(run.startedAt),
            className: 'text-xs text-slate-400 dark:text-slate-500',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start run dialog
// ---------------------------------------------------------------------------

/// Modal dialog for selecting an agent role and starting a new task run.
///
/// Reads available roles from [TaskState.instance.agentRoles]. On confirm,
/// calls [TaskState.instance.startRun] and invokes [onRunStarted] on success.
class _StartRunDialog extends StatefulWidget {
  /// Creates a [_StartRunDialog].
  const _StartRunDialog({
    required this.projectId,
    required this.taskId,
    required this.teamId,
    required this.onRunStarted,
  });

  /// The project ID.
  final String projectId;

  /// The task ID.
  final String taskId;

  /// The team ID used for the API call.
  final String teamId;

  /// Callback invoked when the run is successfully started, with the new run ID.
  final void Function(String runId) onRunStarted;

  @override
  State<_StartRunDialog> createState() => _StartRunDialogState();
}

class _StartRunDialogState extends State<_StartRunDialog> {
  /// The currently selected agent role.
  AgentRole? _selectedRole;

  /// Submits the run to the API and closes the dialog.
  Future<void> _submit() async {
    final role = _selectedRole;
    if (role == null) return;

    final run = await TaskState.instance.startRun(
      widget.teamId,
      widget.projectId,
      widget.taskId,
      role.id,
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    if (run != null) {
      widget.onRunStarted(run.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final starting = TaskState.instance.startingRun;

    return AlertDialog(
      title: Text(trans('tasks.select_agent_role')),
      content: ListenableBuilder(
        listenable: TaskState.instance,
        builder: (context, _) {
          final currentRoles = TaskState.instance.agentRoles;

          return WDiv(
            className: 'w-96',
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: currentRoles.length,
              separatorBuilder: (_, _) => const WSpacer(className: 'h-1'),
              itemBuilder: (context, index) {
                final role = currentRoles[index];
                final isSelected = _selectedRole?.id == role.id;

                return ListTile(
                  title: Text(role.name),
                  subtitle: role.description != null
                      ? Text(role.description!)
                      : null,
                  selected: isSelected,
                  onTap: () => setState(() => _selectedRole = role),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(trans('common.cancel')),
        ),
        TextButton(
          onPressed: (_selectedRole != null && !starting) ? _submit : null,
          child: Text(
            starting ? trans('tasks.starting_run') : trans('tasks.start_run'),
          ),
        ),
      ],
    );
  }
}
