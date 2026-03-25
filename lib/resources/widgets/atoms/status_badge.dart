import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Status className helpers
// ---------------------------------------------------------------------------

/// Returns the badge background + text className for a task [status] slug.
///
/// Keys match the backend task status enum values.
String statusBadgeClassName(String status) {
  return switch (status) {
    'draft' => 'bg-slate-300/15 text-slate-400',
    'analysis' => 'bg-indigo-500/15 text-indigo-500',
    'planning' => 'bg-blue-500/15 text-blue-500',
    'design' => 'bg-violet-500/15 text-violet-500',
    'in_progress' => 'bg-amber-400/15 text-amber-500',
    'review' => 'bg-orange-500/15 text-orange-500',
    'testing' => 'bg-teal-500/15 text-teal-500',
    'done' => 'bg-emerald-500/15 text-emerald-500',
    'failed' => 'bg-red-500/15 text-red-500',
    // Run lifecycle statuses
    'queued' => 'bg-slate-400/15 text-slate-400',
    'running' => 'bg-amber-400/15 text-amber-500',
    'waiting_for_input' => 'bg-orange-500/15 text-orange-500',
    'cancelled' => 'bg-slate-400/15 text-slate-400',
    _ => 'bg-slate-400/15 text-slate-400',
  };
}

/// Returns the legend dot background className for a task [status] slug.
String statusDotClassName(String status) {
  return switch (status) {
    'draft' => 'bg-slate-300',
    'analysis' => 'bg-indigo-500',
    'planning' => 'bg-blue-500',
    'design' => 'bg-violet-500',
    'in_progress' => 'bg-amber-400',
    'review' => 'bg-orange-500',
    'testing' => 'bg-teal-500',
    'done' => 'bg-emerald-500',
    'failed' => 'bg-red-500',
    // Run lifecycle statuses
    'queued' => 'bg-slate-400',
    'running' => 'bg-amber-400',
    'waiting_for_input' => 'bg-orange-500',
    'cancelled' => 'bg-slate-400',
    _ => 'bg-slate-400',
  };
}

/// Returns the human-readable i18n label for a task [status] slug.
///
/// Falls back to the raw slug if the key is not in the translation table.
String statusLabel(String status) {
  return trans('tasks.status_$status');
}

// ---------------------------------------------------------------------------
// StatusBadge widget
// ---------------------------------------------------------------------------

/// A small pill badge that renders a task status with DESIGN.md brand colours.
///
/// ## Usage
///
/// ```dart
/// StatusBadge(status: 'in_progress')
/// StatusBadge(status: 'done')
/// ```
class StatusBadge extends StatelessWidget {
  /// Creates a [StatusBadge] for the given [status] slug.
  const StatusBadge({required this.status, super.key});

  /// The task status slug (e.g. `'draft'`, `'in_progress'`, `'done'`).
  final String status;

  @override
  Widget build(BuildContext context) {
    final cn = statusBadgeClassName(status);

    return WDiv(
      className: 'px-1.5 py-0.5 rounded $cn',
      child: WText(statusLabel(status), className: 'text-[11px] font-semibold'),
    );
  }
}
