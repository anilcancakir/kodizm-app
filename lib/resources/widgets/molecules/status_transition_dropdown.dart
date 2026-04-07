import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/status_badge.dart';

// ---------------------------------------------------------------------------
// Transition label i18n key map
// ---------------------------------------------------------------------------

/// Maps a target status slug to its i18n transition label key.
///
/// Mirrors the private `_transitionLabelKeys` in `task_detail_view.dart`
/// and the backend `TaskStatus.php` allowed-transition labels.
const Map<String, String> _transitionLabelKeys = {
  'analysis': 'tasks.transition_start_analysis',
  'planning': 'tasks.transition_start_planning',
  'in_progress': 'tasks.transition_start_development',
  'review': 'tasks.transition_submit_review',
  'done': 'tasks.transition_approve_done',
  'failed': 'tasks.transition_mark_failed',
  'draft': 'tasks.transition_reopen',
};

// ---------------------------------------------------------------------------
// StatusTransitionDropdown
// ---------------------------------------------------------------------------

/// A status lozenge with an optional dropdown arrow that opens a popup menu
/// of valid status transitions for the current task status.
///
/// When no transitions are available (e.g. `done`), the arrow is hidden and
/// tapping is a no-op. The parent is responsible for executing the API call
/// — this widget only fires the [onTransition] callback.
///
/// ## Usage
///
/// ```dart
/// StatusTransitionDropdown(
///   currentStatus: 'in_progress',
///   allowedTransitions: {
///     'in_progress': ['review', 'failed'],
///     'done': [],
///   },
///   onTransition: (targetStatus) => state.transitionStatus(targetStatus),
/// )
/// ```
class StatusTransitionDropdown extends StatelessWidget {
  /// Creates a [StatusTransitionDropdown].
  const StatusTransitionDropdown({
    required this.currentStatus,
    required this.allowedTransitions,
    required this.onTransition,
    super.key,
  });

  /// The current task status slug (e.g. `'draft'`, `'in_progress'`).
  final String currentStatus;

  /// Full allowed-transitions map — keys are source statuses, values are
  /// lists of reachable target statuses.
  final Map<String, List<String>> allowedTransitions;

  /// Called with the selected target status slug when the user picks a
  /// transition from the popup menu.
  final void Function(String targetStatus) onTransition;

  // -------

  /// Returns the list of valid target statuses for [currentStatus].
  List<String> get _targets => allowedTransitions[currentStatus] ?? [];

  @override
  Widget build(BuildContext context) {
    final hasTransitions = _targets.isNotEmpty;

    return WAnchor(
      onTap: hasTransitions ? () => _openMenu(context) : null,
      child: WDiv(
        className: 'flex flex-row items-center gap-1',
        children: [
          // Status badge
          _StatusLozenge(status: currentStatus),

          // Dropdown arrow — hidden when no transitions available
          if (hasTransitions)
            WIcon(Icons.arrow_drop_down, className: 'text-slate-400 text-base'),
        ],
      ),
    );
  }

  // -------

  /// Opens a [showMenu] popup anchored to the widget's render position.
  void _openMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      items: _targets.map((target) {
        final labelKey =
            _transitionLabelKeys[target] ?? 'tasks.transition_start_analysis';
        return PopupMenuItem<String>(
          value: target,
          child: WText(trans(labelKey), className: _menuItemClassName(target)),
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        onTransition(selected);
      }
    });
  }

  // -------

  /// Returns the className for a popup menu item text based on [target] status.
  String _menuItemClassName(String target) {
    return switch (target) {
      'done' => 'text-emerald-600 text-sm',
      'failed' => 'text-red-500 text-sm',
      'in_progress' => 'text-amber-600 text-sm',
      'review' => 'text-orange-600 text-sm',
      'analysis' => 'text-indigo-600 text-sm',
      'planning' => 'text-blue-600 text-sm',
      'draft' => 'text-slate-500 text-sm',
      _ => 'text-slate-700 text-sm',
    };
  }
}

// ---------------------------------------------------------------------------
// _StatusLozenge (private atom)
// ---------------------------------------------------------------------------

/// Renders the coloured status pill using [statusBadgeClassName] from
/// [status_badge.dart].
class _StatusLozenge extends StatelessWidget {
  const _StatusLozenge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cn = statusBadgeClassName(status);

    return WDiv(
      className: 'px-2.5 py-1 rounded-md $cn',
      child: WText(
        trans('tasks.status_$status'),
        className: 'text-xs font-semibold',
      ),
    );
  }
}
