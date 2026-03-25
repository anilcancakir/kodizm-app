import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Task type icon helper
// ---------------------------------------------------------------------------

/// Returns the [IconData] for a task [type] slug.
IconData taskTypeIconData(String type) {
  return switch (type) {
    'story' => Icons.auto_stories,
    'task' => Icons.check_circle,
    'bug' => Icons.bug_report,
    'spike' => Icons.bolt,
    _ => Icons.help_outline,
  };
}

// ---------------------------------------------------------------------------
// TaskTypeIcon widget
// ---------------------------------------------------------------------------

/// An inline icon + label pair that represents the type of a task.
///
/// Renders a Wind UI [WIcon] alongside a [WText] label sourced from i18n.
///
/// ## Usage
///
/// ```dart
/// TaskTypeIcon(type: 'story')
/// TaskTypeIcon(type: 'bug')
/// ```
class TaskTypeIcon extends StatelessWidget {
  /// Creates a [TaskTypeIcon] for the given task [type] slug.
  const TaskTypeIcon({required this.type, super.key});

  /// The task type slug (e.g. `'story'`, `'task'`, `'bug'`, `'spike'`).
  final String type;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center gap-1',
      children: [
        WIcon(
          taskTypeIconData(type),
          className: 'text-sm text-slate-400 dark:text-slate-500',
        ),
        WText(
          trans('tasks.type_$type'),
          className: 'text-xs text-slate-500 dark:text-slate-400',
        ),
      ],
    );
  }
}
