import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation.dart';
import '../../../app/models/task.dart';
import '../atoms/collapsible_section.dart';
import '../atoms/priority_badge.dart';
import '../atoms/task_type_icon.dart';
import 'pipeline_progress.dart';

// ---------------------------------------------------------------------------
// TaskDetailSidebar
// ---------------------------------------------------------------------------

/// Sidebar organism for the Jira-style task detail two-column layout.
///
/// Renders (top to bottom):
/// 1. [StatusTransitionDropdown] — current status + allowed transitions.
/// 2. Details [CollapsibleSection] — type, priority, agent, branch, cost,
///    source, complexity, created-by, created, updated.
/// 3. Pipeline [CollapsibleSection] (conditional on [isPipelineEnabled]).
/// 4. Run History [CollapsibleSection] — "Run Agent" button + run rows.
///
/// Purely presentational — all mutations flow through callbacks.
///
/// ## Usage
///
/// ```dart
/// TaskDetailSidebar(
///   task: task,
///   conversations: runs,
///   onTransition: (status) => state.transitionStatus(status),
///   onStartRun: () => showStartRunDialog(context),
///   hasActiveRun: state.hasActiveRun,
///   isPipelineEnabled: project.isPipelineEnabled,
///   onContinuePipeline: () => state.continuePipeline(),
/// )
/// ```
class TaskDetailSidebar extends StatelessWidget {
  /// Creates a [TaskDetailSidebar].
  const TaskDetailSidebar({
    super.key,
    required this.task,
    required this.conversations,
    required this.onStartRun,
    required this.hasActiveRun,
    this.isPipelineEnabled = false,
    this.onContinuePipeline,
    this.onReopen,
  });

  /// The task whose details are displayed.
  final Task task;

  /// The list of conversations (runs) associated with this task.
  final List<Conversation> conversations;

  /// Called when the user taps the "Run Agent" button.
  final VoidCallback onStartRun;

  /// Whether any conversation is currently active/running.
  final bool hasActiveRun;

  /// Whether the pipeline feature is enabled for this task's project.
  final bool isPipelineEnabled;

  /// Called when the user taps "Continue" on a waiting pipeline stage.
  final VoidCallback? onContinuePipeline;

  /// Called when the user taps "Reopen Task" on a failed pipeline task.
  final VoidCallback? onReopen;

  // -----------------------------------------------------------------------
  // Formatting helpers
  // -----------------------------------------------------------------------

  /// Formats a cost string as `$X.XXXX` or `--` when absent/unparseable.
  String _formatCost(String? cost) {
    if (cost == null) return '--';
    final value = double.tryParse(cost);
    if (value == null) return '--';
    return '\$${value.toStringAsFixed(4)}';
  }

  /// Formats a [DateTime] as "Mar 25, 2026".
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }

  /// Maps an integer complexity score to a human-readable i18n label.
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

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final createdAt = task.createdAt?.toDateTime;
    final updatedAt = task.updatedAt?.toDateTime;

    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        // -------------------------------------------------------------------
        // Details section
        // -------------------------------------------------------------------
        CollapsibleSection(
          title: trans('tasks.detail_details'),
          initiallyExpanded: true,
          child: WDiv(
            className: 'flex flex-col gap-3 pt-3',
            children: [
              // Task ID
              _SidebarInfoRow(
                label: trans('tasks.task_id_label'),
                value: task.taskId ?? '--',
              ),

              // Type
              _SidebarInfoRow(
                label: trans('tasks.detail_type'),
                valueWidget: TaskTypeIcon(type: task.type ?? 'task'),
              ),

              // Priority
              if (task.priority != null)
                _SidebarInfoRow(
                  label: trans('tasks.detail_priority'),
                  valueWidget: PriorityBadge(priority: task.priority!),
                ),

              // Agent
              _SidebarInfoRow(
                label: trans('tasks.detail_agent'),
                value: task.assignedAgentRoleName ?? trans('tasks.unassigned'),
              ),

              // Branch
              _SidebarInfoRow(
                label: trans('tasks.branch'),
                value: task.branchName ?? trans('tasks.no_branch'),
              ),

              // Validation result (pipeline tasks only)
              if (task.worktreeBranch != null &&
                  (task.status == 'failed' ||
                      task.status == 'done' ||
                      task.status == 'review'))
                WDiv(
                  className: task.status == 'failed'
                      ? 'p-3 rounded-lg bg-red-500/10'
                      : 'p-3 rounded-lg bg-emerald-500/10',
                  children: [
                    WText(
                      trans(
                        task.status == 'failed'
                            ? 'tasks.validation_no_changes'
                            : 'tasks.validation_has_commits',
                      ),
                      className: task.status == 'failed'
                          ? 'text-sm font-semibold text-red-600 dark:text-red-400'
                          : 'text-sm font-semibold text-emerald-600 dark:text-emerald-400',
                    ),
                    WSpacer(className: 'h-1'),
                    WText(
                      trans(
                        task.status == 'failed'
                            ? 'tasks.validation_no_changes_detail'
                            : 'tasks.validation_has_commits_detail',
                      ),
                      className: 'text-xs text-slate-600 dark:text-slate-400',
                    ),
                    if (task.status == 'failed') ...[
                      WSpacer(className: 'h-2'),
                      WAnchor(
                        onTap: () => onReopen?.call(),
                        child: WText(
                          trans('tasks.reopen_task'),
                          className:
                              'text-xs font-semibold text-red-600 dark:text-red-400 underline',
                        ),
                      ),
                    ],
                  ],
                ),

              // Total cost
              if (task.totalCostUsd != null)
                _SidebarInfoRow(
                  label: trans('tasks.total_cost'),
                  value: _formatCost(task.totalCostUsd),
                ),

              // Source
              if (task.source != null)
                _SidebarInfoRow(
                  label: trans('tasks.source_label'),
                  value: task.source!,
                ),

              // Complexity
              if (task.estimatedComplexity != null)
                _SidebarInfoRow(
                  label: trans('tasks.complexity_label'),
                  value: _complexityLabel(task.estimatedComplexity!),
                ),

              // Created by
              if (task.createdByUserName != null)
                _SidebarInfoRow(
                  label: trans('tasks.created_by'),
                  value: task.createdByUserName!,
                ),

              // Created at
              if (createdAt != null)
                _SidebarInfoRow(
                  label: trans('tasks.created_at_label'),
                  value: _formatDate(createdAt),
                ),

              // Updated at
              if (updatedAt != null)
                _SidebarInfoRow(
                  label: trans('tasks.updated_at_label'),
                  value: _formatDate(updatedAt),
                ),
            ],
          ),
        ),

        // -------------------------------------------------------------------
        // Pipeline section (conditional)
        // -------------------------------------------------------------------
        if (isPipelineEnabled)
          CollapsibleSection(
            title: trans('tasks.detail_pipeline'),
            initiallyExpanded: true,
            child: WDiv(
              className: 'pt-3',
              child: PipelineProgress(
                task: task,
                conversations: conversations,
                onContinue: onContinuePipeline,
              ),
            ),
          ),

        // -------------------------------------------------------------------
        // Run Agent button
        // -------------------------------------------------------------------
        WAnchor(
          onTap: hasActiveRun ? null : onStartRun,
          child: WDiv(
            className: hasActiveRun
                ? '''
                    self-start flex flex-row items-center gap-2
                    px-4 py-2.5 rounded-lg
                    bg-slate-100 dark:bg-slate-700
                    opacity-50
                  '''
                : '''
                    self-start flex flex-row items-center gap-2
                    px-4 py-2.5 rounded-lg
                    bg-amber-400
                  ''',
            children: [
              WIcon(
                Icons.play_arrow,
                className: hasActiveRun
                    ? 'text-sm text-slate-500'
                    : 'text-sm text-primary-900',
              ),
              WText(
                trans('tasks.run_agent'),
                className: hasActiveRun
                    ? 'text-sm font-semibold text-slate-500'
                    : 'text-sm font-semibold text-primary-900',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SidebarInfoRow
// ---------------------------------------------------------------------------

/// A label + value row used inside the details panel.
///
/// Provide either [value] (renders as [WText]) or [valueWidget] (renders
/// as-is). [valueWidget] takes precedence when both are supplied.
class _SidebarInfoRow extends StatelessWidget {
  const _SidebarInfoRow({required this.label, this.value, this.valueWidget});

  /// The field label (e.g. "Branch").
  final String label;

  /// The plain text value — used when [valueWidget] is null.
  final String? value;

  /// A custom widget for the value column.
  final Widget? valueWidget;

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
        if (valueWidget != null)
          valueWidget!
        else
          WDiv(
            className: 'flex-1',
            child: WText(
              value ?? '',
              className: 'text-sm text-gray-800 dark:text-gray-200',
            ),
          ),
      ],
    );
  }
}
