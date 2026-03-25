import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Priority className helper
// ---------------------------------------------------------------------------

/// Returns the badge background + text className for a task [priority] slug.
///
/// Priority levels follow the P0–P3 convention (P0 = Critical, P3 = Low).
String priorityBadgeClassName(String priority) {
  return switch (priority) {
    'p0' => 'bg-red-500/15 text-red-500',
    'p1' => 'bg-amber-500/15 text-amber-500',
    'p2' => 'bg-blue-500/15 text-blue-500',
    'p3' => 'bg-slate-400/15 text-slate-400',
    _ => 'bg-slate-400/15 text-slate-400',
  };
}

// ---------------------------------------------------------------------------
// PriorityBadge widget
// ---------------------------------------------------------------------------

/// A small pill badge that renders a task priority with DESIGN.md brand colours.
///
/// ## Usage
///
/// ```dart
/// PriorityBadge(priority: 'p0') // Critical
/// PriorityBadge(priority: 'p2') // Medium
/// ```
class PriorityBadge extends StatelessWidget {
  /// Creates a [PriorityBadge] for the given [priority] slug.
  const PriorityBadge({required this.priority, super.key});

  /// The task priority slug (e.g. `'p0'`, `'p1'`, `'p2'`, `'p3'`).
  final String priority;

  @override
  Widget build(BuildContext context) {
    final cn = priorityBadgeClassName(priority);

    return WDiv(
      className: 'px-1.5 py-0.5 rounded $cn',
      child: WText(
        trans('tasks.priority_$priority'),
        className: 'text-[11px] font-semibold',
      ),
    );
  }
}
