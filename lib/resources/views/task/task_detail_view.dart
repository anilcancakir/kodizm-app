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
import '../../widgets/organisms/agent_role_picker_modal.dart';
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
/// MagicRoute.to('/tasks/$projectId/$taskId');
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
      ProjectState.instance.fetchProject(teamId, widget.projectId),
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
    List<String> allowedTransitions,
  ) async {
    final targets = allowedTransitions;
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

    final roles = TaskState.instance.agentRoles;
    final mainAgent = roles.cast<AgentRole?>().firstWhere(
      (r) => r?.slug == 'main-agent',
      orElse: () => null,
    );

    // Fallback: if main-agent not found, show full picker.
    if (mainAgent == null) {
      final selected = await AgentRolePickerModal.show(context, roles);
      if (selected == null || !context.mounted) return;
      await _startRunWithRole(context, teamId, selected.id);
      return;
    }

    // Show confirm dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _RunConfirmDialog(),
    );

    if (confirmed != true || !context.mounted) return;
    await _startRunWithRole(context, teamId, mainAgent.id);
  }

  /// Starts a run with the given [roleId] and navigates to the conversation.
  Future<void> _startRunWithRole(
    BuildContext context,
    String teamId,
    String roleId,
  ) async {
    final conversation = await TaskState.instance.startRun(
      teamId,
      widget.projectId,
      widget.taskId,
      roleId,
    );

    if (!context.mounted) return;

    if (conversation != null) {
      MagicRoute.to(
        '/conversations/${widget.projectId}/chats/${conversation.id}',
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(trans('tasks.start_run_failed'))));
    }
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

        return MagicTitle(
          title: task.title ?? '',
          child: WDiv(
            className: 'p-4 lg:p-6 flex flex-col gap-6',
            children: [
              _buildHeader(task),
              if (MediaQuery.sizeOf(context).width >= 1024)
                _buildDesktopBody(task, sections, runs)
              else
                _buildMobileBody(task, sections, runs),
            ],
          ),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Header (shared mobile + desktop)
  // -----------------------------------------------------------------------

  Widget _buildHeader(Task task) {
    final status = task.status ?? 'draft';
    final allowedTransitions = task.allowedTransitions;
    final hasTransitions = allowedTransitions.isNotEmpty;

    return MagicStarterPageHeader(
      title: task.title ?? '',
      subtitle: task.taskId,
      inlineActions: true,
      leading: WAnchor(
        onTap: () => MagicRoute.to('/tasks/${widget.projectId}'),
        child: WIcon(
          Icons.arrow_back,
          className: 'text-base text-slate-500 dark:text-slate-400',
        ),
      ),
      titleSuffix: WAnchor(
        onTap: hasTransitions
            ? () => _showStatusTransitionModal(
                context,
                status,
                allowedTransitions,
              )
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
                _buildDescriptionCard(task),
                ..._buildSectionCards(sections),
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
                  onReopen: () => _onTransitionTap('draft'),
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
      className: 'flex flex-col gap-6',
      children: [
        // Details sidebar first on mobile
        TaskDetailSidebar(
          task: task,
          conversations: runs,
          onStartRun: () => _showStartRunDialog(context),
          hasActiveRun: _hasActiveRun(runs),
          isPipelineEnabled:
              ProjectState.instance.selectedProject?.isPipelineEnabled ?? false,
          onContinuePipeline: _onContinuePipeline,
          onReopen: () => _onTransitionTap('draft'),
        ),

        // Description
        _buildDescriptionCard(task),

        // Sections — each as its own card
        ..._buildSectionCards(sections),

        // Activity feed
        TaskActivityFeed(
          sections: sections,
          conversations: runs,
          projectId: widget.projectId,
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Section builders
  // -----------------------------------------------------------------------

  Widget _buildDescriptionCard(Task task) {
    return MagicStarterCard(
      title: trans('tasks.description_label'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (task.description?.isNotEmpty ?? false)
            MarkdownViewer(data: task.description!)
          else
            WText(
              trans('tasks.no_description'),
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),

          // Acceptance Criteria
          if (task.acceptanceCriteria != null &&
              task.acceptanceCriteria!.isNotEmpty)
            WDiv(
              className:
                  'flex flex-col gap-2 pt-4 border-t border-slate-200 dark:border-slate-700',
              children: [
                WText(
                  trans('tasks.acceptance_criteria'),
                  className:
                      'text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wide',
                ),
                MarkdownViewer(data: task.acceptanceCriteria!),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSectionCards(List<TaskSection> sections) {
    if (sections.isEmpty) return [];

    return [
      for (final section in sections)
        MagicStarterCard(
          child: CollapsibleSection(
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
        ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Run confirm dialog
// ---------------------------------------------------------------------------

/// Simple confirm dialog that initiates a task run with the main agent.
///
/// Returns `true` when the user confirms, `false` or `null` when cancelled.
class _RunConfirmDialog extends StatelessWidget {
  /// Creates a [_RunConfirmDialog].
  const _RunConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;
    return MagicStarterDialogShell(
      title: trans('tasks.confirm_run'),
      body: WDiv(
        className: 'w-full flex flex-col gap-3',
        child: WText(
          trans('tasks.confirm_run_description'),
          className:
              'text-sm text-slate-600 dark:text-slate-300 leading-relaxed',
        ),
      ),
      footerBuilder: (dialogContext) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(false),
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(true),
            child: WDiv(
              className: theme.primaryButtonClassName,
              child: WText(trans('tasks.run_agent'), className: 'text-inherit'),
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
