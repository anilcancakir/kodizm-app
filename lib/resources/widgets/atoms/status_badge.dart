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
    'in_progress' => 'bg-amber-400/15 text-amber-500',
    'review' => 'bg-orange-500/15 text-orange-500',
    'done' => 'bg-emerald-500/15 text-emerald-500',
    'failed' => 'bg-red-500/15 text-red-500',
    // Run / conversation lifecycle statuses
    'active' => 'bg-emerald-500/15 text-emerald-500',
    'paused' => 'bg-amber-400/15 text-amber-500',
    'completed' => 'bg-slate-400/15 text-slate-400',
    'queued' => 'bg-slate-400/15 text-slate-400',
    'running' => 'bg-amber-400/15 text-amber-500',
    'waiting_for_input' => 'bg-orange-500/15 text-orange-500',
    'cancelled' => 'bg-slate-400/15 text-slate-400',
    'pending' => 'bg-slate-400/15 text-slate-400',
    'timed_out' => 'bg-red-500/15 text-red-500',
    _ => 'bg-slate-400/15 text-slate-400',
  };
}

/// Returns the legend dot background className for a task [status] slug.
String statusDotClassName(String status) {
  return switch (status) {
    'draft' => 'bg-slate-300',
    'analysis' => 'bg-indigo-500',
    'planning' => 'bg-blue-500',
    'in_progress' => 'bg-amber-400',
    'review' => 'bg-orange-500',
    'done' => 'bg-emerald-500',
    'failed' => 'bg-red-500',
    // Run / conversation lifecycle statuses
    'active' => 'bg-emerald-500',
    'paused' => 'bg-amber-400',
    'completed' => 'bg-slate-400',
    'queued' => 'bg-slate-400',
    'running' => 'bg-amber-400',
    'waiting_for_input' => 'bg-orange-500',
    'cancelled' => 'bg-slate-400',
    'pending' => 'bg-slate-400',
    'timed_out' => 'bg-red-500',
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

/// A small pill badge that renders a task/conversation status with DESIGN.md
/// brand colours. Active status includes a pulsing dot animation.
///
/// ## Usage
///
/// ```dart
/// StatusBadge(status: 'in_progress')
/// StatusBadge(status: 'done')
/// StatusBadge(status: 'active')
/// ```
class StatusBadge extends StatelessWidget {
  /// Creates a [StatusBadge] for the given [status] slug.
  const StatusBadge({required this.status, super.key});

  /// The status slug (e.g. `'draft'`, `'active'`, `'completed'`).
  final String status;

  /// Whether this status represents an actively running state.
  bool get _isActive => status == 'active' || status == 'running';

  @override
  Widget build(BuildContext context) {
    final cn = statusBadgeClassName(status);

    return WDiv(
      className: 'flex flex-row items-center gap-1 px-1.5 py-0.5 rounded $cn',
      children: [
        if (_isActive) const _PulsingDot(),
        WText(statusLabel(status), className: 'text-[11px] font-semibold'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing dot animation for active statuses
// ---------------------------------------------------------------------------

/// A small dot with a pulse animation indicating an active/running state.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: WDiv(className: 'w-1.5 h-1.5 rounded-full bg-emerald-500'),
    );
  }
}
