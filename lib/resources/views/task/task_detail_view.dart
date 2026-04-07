import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/agent_role.dart';
import '../../../app/models/conversation.dart';
import '../../../app/models/task.dart';
import '../../../app/models/task_section.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';
import '../../../app/state/task_state.dart';
import '../../widgets/atoms/collapsible_section.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/organisms/markdown_viewer.dart';
import '../../widgets/organisms/task_activity_feed.dart';
import '../../widgets/organisms/task_detail_sidebar.dart';

/// Task detail view — Jira-style two-column layout with mobile-first responsive
/// design. Desktop (>=1024px) shows main content left, sidebar right. Mobile
/// stacks everything vertically.
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
    'planning': ['in_progress', 'failed'],
    'in_progress': ['review', 'failed'],
    'review': ['in_progress', 'done', 'failed'],
    'failed': ['draft'],
    'done': [],
  };

  // ---------------------------------------------------------------------------
  // Transition label keys — keyed by target status.
  // ---------------------------------------------------------------------------

  static const Map<String, String> _transitionLabelKeys = {
    'analysis': 'tasks.transition_start_analysis',
    'planning': 'tasks.transition_start_planning',
    'in_progress': 'tasks.transition_start_development',
    'review': 'tasks.transition_submit_review',
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

  @override
  void dispose() {
    TaskState.instance.unsubscribePipelineEvents();
    super.dispose();
  }

  /// Fetches task, sections, and runs in parallel, then subscribes to
  /// real-time pipeline events if the project has pipeline enabled.
  Future<void> _fetchAll() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await Future.wait([
      TaskState.instance.fetchTask(teamId, widget.projectId, widget.taskId),
      TaskState.instance.fetchSections(teamId, widget.projectId, widget.taskId),
      TaskState.instance.fetchConversations(
        teamId,
        widget.projectId,
        widget.taskId,
      ),
    ]);

    // Subscribe to real-time pipeline events after data is loaded.
    if (ProjectState.instance.selectedProject?.isPipelineEnabled ?? false) {
      TaskState.instance.subscribeToPipelineEvents(
        teamId,
        widget.projectId,
        widget.taskId,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Transition helpers
  // -----------------------------------------------------------------------

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
  // Status transition modal
  // -----------------------------------------------------------------------

  Future<void> _showStatusTransitionModal(
    BuildContext context,
    String currentStatus,
  ) async {
    final targets = _allowedTransitions[currentStatus] ?? [];
    if (targets.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _StatusTransitionDialog(
        currentStatus: currentStatus,
        targets: targets,
        transitionLabelKeys: _transitionLabelKeys,
        onTransition: (target) {
          Navigator.of(dialogContext).pop();
          _onTransitionTap(target);
        },
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Start-run modal
  // -----------------------------------------------------------------------

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
        onRunStarted: (conversationId) {
          if (context.mounted) {
            MagicRoute.to(
              '/projects/${widget.projectId}/chats/$conversationId',
            );
          }
        },
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Pipeline continue
  // -----------------------------------------------------------------------

  void _onContinuePipeline() {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    TaskState.instance.continuePipeline(
      teamId,
      widget.projectId,
      widget.taskId,
    );
  }

  // -----------------------------------------------------------------------
  // Formatting helpers
  // -----------------------------------------------------------------------

  bool _hasActiveRun(List<Conversation> conversations) {
    return conversations.any(
      (c) => c.status == 'active' || c.status == 'running',
    );
  }

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
        final runs = TaskState.instance.conversations;

        if (task == null) {
          return const WDiv(
            className: 'w-full flex items-center justify-center py-16',
            child: CircularProgressIndicator(),
          );
        }

        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            _buildHeader(task),
            if (MediaQuery.sizeOf(context).width >= 1024)
              _buildDesktopBody(task, sections, runs)
            else
              _buildMobileBody(task, sections, runs),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Header (shared mobile + desktop)
  // -----------------------------------------------------------------------

  Widget _buildHeader(Task task) {
    final status = task.status ?? 'draft';
    final hasTransitions = (_allowedTransitions[status] ?? []).isNotEmpty;

    return MagicStarterPageHeader(
      title: task.title ?? '',
      leading: WAnchor(
        onTap: () => MagicRoute.to('/projects/${widget.projectId}/tasks'),
        child: WIcon(
          Icons.arrow_back,
          className: 'text-base text-slate-500 dark:text-slate-400',
        ),
      ),
      actions: [
        WAnchor(
          onTap: hasTransitions
              ? () => _showStatusTransitionModal(context, status)
              : null,
          child: WDiv(
            className:
                'flex flex-row items-center gap-1 px-3 py-1.5 rounded-lg ${statusBadgeClassName(status)}',
            children: [
              WText(statusLabel(status), className: 'text-sm font-semibold'),
              if (hasTransitions)
                WIcon(Icons.arrow_drop_down, className: 'text-base'),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Desktop body
  // -----------------------------------------------------------------------

  Widget _buildDesktopBody(
    Task task,
    List<TaskSection> sections,
    List<Conversation> runs,
  ) {
    return WDiv(
      className: 'flex flex-col gap-6',
      children: [
        // Two-column row
        WDiv(
          className: 'flex flex-row gap-6',
          children: [
            // Main column
            WDiv(
              className: 'flex-1 flex flex-col gap-6',
              children: [
                _buildInfoSection(task),
                _buildStatusActionsSection(task),
                _buildSectionsCard(sections),
              ],
            ),

            // Sidebar
            WDiv(
              className: 'w-96 flex-shrink-0 flex flex-col gap-4',
              children: [
                TaskDetailSidebar(
                  task: task,
                  conversations: runs,
                  onStartRun: () => _showStartRunDialog(context),
                  hasActiveRun: _hasActiveRun(runs),
                  isPipelineEnabled:
                      ProjectState
                          .instance
                          .selectedProject
                          ?.isPipelineEnabled ??
                      false,
                  onContinuePipeline: _onContinuePipeline,
                ),
              ],
            ),
          ],
        ),

        // Activity feed — full width below two-column row
        TaskActivityFeed(
          sections: sections,
          conversations: runs,
          projectId: widget.projectId,
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Mobile body
  // -----------------------------------------------------------------------

  Widget _buildMobileBody(
    Task task,
    List<TaskSection> sections,
    List<Conversation> runs,
  ) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        // Description + AC card
        _buildInfoSection(task),

        // Status actions
        _buildStatusActionsSection(task),

        // Sections
        _buildSectionsCard(sections),

        // Activity feed
        TaskActivityFeed(
          sections: sections,
          conversations: runs,
          projectId: widget.projectId,
        ),

        // Sidebar below activity feed on mobile
        TaskDetailSidebar(
          task: task,
          conversations: runs,
          onStartRun: () => _showStartRunDialog(context),
          hasActiveRun: _hasActiveRun(runs),
          isPipelineEnabled:
              ProjectState.instance.selectedProject?.isPipelineEnabled ?? false,
          onContinuePipeline: _onContinuePipeline,
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section builders
  // -----------------------------------------------------------------------

  Widget _buildInfoSection(Task task) {
    return MagicStarterCard(
      title: trans('tasks.task_info'),
      child: WDiv(
        className: 'flex flex-col gap-4',
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

          // Assigned agent — quick reference in the main content area
          WDiv(
            className: 'flex flex-row items-start gap-2',
            children: [
              WText(
                trans('tasks.assigned_to'),
                className:
                    'text-xs font-semibold text-slate-500 dark:text-slate-400 w-24 pt-0.5',
              ),
              WDiv(
                className: 'flex-1',
                child: WText(
                  task.assignedAgentRoleName ?? trans('tasks.unassigned'),
                  className: 'text-sm text-gray-800 dark:text-gray-200',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActionsSection(Task task) {
    final currentStatus = task.status ?? 'draft';
    final transitions = _allowedTransitions[currentStatus] ?? [];

    return MagicStarterCard(
      title: trans('tasks.status_actions'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (transitions.isEmpty)
            WText(
              trans('tasks.status_done'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            )
          else
            WDiv(
              className: 'wrap gap-2',
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
      ),
    );
  }

  String _transitionButtonClassName(String from, String to) {
    if (to == 'failed') {
      return 'bg-red-500/15 text-red-500 px-3 py-1.5 rounded-lg text-sm font-medium';
    }
    if (to == 'draft') {
      return '''
        bg-slate-200 dark:bg-slate-700
        text-slate-600 dark:text-slate-300
        px-3 py-1.5 rounded-lg text-sm font-medium
      ''';
    }
    return 'bg-amber-400 text-primary-900 px-3 py-1.5 rounded-lg text-sm font-medium';
  }

  Widget _buildSectionsCard(List<TaskSection> sections) {
    return MagicStarterCard(
      title: trans('tasks.sections'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (sections.isEmpty)
            WText(
              trans('tasks.no_sections'),
              className: 'text-sm text-slate-400 dark:text-slate-500',
            )
          else
            for (final section in sections)
              CollapsibleSection(
                key: Key(section.id),
                title: section.title,
                initiallyExpanded: false,
                trailing: WDiv(
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
                child: WDiv(
                  className: 'pt-3',
                  child: MarkdownViewer(data: section.content),
                ),
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

    final conversation = await TaskState.instance.startRun(
      widget.teamId,
      widget.projectId,
      widget.taskId,
      role.id,
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    if (conversation != null) {
      widget.onRunStarted(conversation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final starting = TaskState.instance.startingRun;

    return MagicStarterDialogShell(
      title: trans('tasks.select_agent_role'),
      body: ListenableBuilder(
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

                return WAnchor(
                  onTap: () => setState(() => _selectedRole = role),
                  child: WDiv(
                    className:
                        '''
                      p-3 rounded-lg
                      ${isSelected ? 'bg-amber-400/10 border border-amber-400' : 'bg-slate-50 dark:bg-gray-800'}
                    ''',
                    children: [
                      WText(
                        role.name,
                        className:
                            '''
                          text-sm font-medium
                          ${isSelected ? 'text-amber-600 dark:text-amber-400' : 'text-slate-800 dark:text-slate-200'}
                        ''',
                      ),
                      if (role.description != null)
                        WText(
                          role.description!,
                          className:
                              'text-xs text-slate-500 dark:text-slate-400 mt-0.5',
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      footerBuilder: (dialogContext) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: WDiv(
              className: MagicStarter.modalTheme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          WAnchor(
            onTap: (_selectedRole != null && !starting) ? _submit : null,
            child: WDiv(
              className: (_selectedRole != null && !starting)
                  ? MagicStarter.modalTheme.primaryButtonClassName
                  : '${MagicStarter.modalTheme.primaryButtonClassName} opacity-50',
              child: WText(
                starting
                    ? trans('tasks.starting_run')
                    : trans('tasks.start_run'),
                className: 'text-inherit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status transition dialog
// ---------------------------------------------------------------------------

/// Modal dialog that lists available status transitions as tappable rows.
///
/// Each row shows the transition label with a colour-coded status indicator.
/// Tapping a row fires [onTransition] and the parent closes the dialog.
class _StatusTransitionDialog extends StatelessWidget {
  const _StatusTransitionDialog({
    required this.currentStatus,
    required this.targets,
    required this.transitionLabelKeys,
    required this.onTransition,
  });

  /// Current task status slug.
  final String currentStatus;

  /// List of valid target status slugs.
  final List<String> targets;

  /// Map of status slug → i18n key for the transition label.
  final Map<String, String> transitionLabelKeys;

  /// Called with the selected target status slug.
  final void Function(String target) onTransition;

  @override
  Widget build(BuildContext context) {
    return MagicStarterDialogShell(
      title: trans('tasks.update_status'),
      body: WDiv(
        className: 'w-96 flex flex-col gap-3',
        children: [
          for (final target in targets)
            WAnchor(
              onTap: () => onTransition(target),
              child: WDiv(
                className: _targetButtonClassName(target),
                child: WText(
                  trans(
                    transitionLabelKeys[target] ??
                        'tasks.transition_start_analysis',
                  ),
                  className: 'text-sm font-semibold',
                ),
              ),
            ),
        ],
      ),
      footerBuilder: (dialogContext) => WDiv(
        className: 'flex flex-row w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: WDiv(
              className: MagicStarter.modalTheme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns DESIGN.md-compliant button className by target status.
  String _targetButtonClassName(String target) {
    const base = 'w-full text-center px-4 py-2.5 rounded-lg';
    return switch (target) {
      'failed' => '$base bg-red-500 text-white',
      'draft' =>
        '$base border border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300',
      'done' => '$base bg-emerald-500 text-white',
      _ => '$base bg-amber-400 text-primary-900',
    };
  }
}
