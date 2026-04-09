import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// StickyProgressBar
// ---------------------------------------------------------------------------

/// Compact sticky bar showing real-time agent progress at the top of the chat.
///
/// Renders nothing when [status] is null. Shows a role-coloured dot, a status
/// label, an optional truncated message, and an optional progress track.
///
/// ## Usage
///
/// ```dart
/// StickyProgressBar(
///   status: 'implementing',
///   message: 'Writing unit tests',
///   percentage: 45,
///   agentRoleSlug: 'dev',
///   agentRoleName: 'Developer',
/// )
/// ```
class StickyProgressBar extends StatelessWidget {
  const StickyProgressBar({
    super.key,
    this.status,
    this.message,
    this.percentage,
    this.agentRoleSlug,
    this.agentRoleName,
  });

  /// Progress status slug (e.g. `'implementing'`, `'blocked'`). `null` → hidden.
  final String? status;

  /// Human-readable progress message text. Optional.
  final String? message;

  /// Completion percentage 0–100. `null` → indeterminate (no track shown).
  final int? percentage;

  /// Agent role slug for dot colour (e.g. `'ba'`, `'dev'`).
  final String? agentRoleSlug;

  /// Agent role display name. Reserved for future use.
  final String? agentRoleName;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();

    final isBlocked = status == 'blocked';

    final containerClassName = isBlocked
        ? '''
          flex flex-row items-center gap-3 px-4 py-2.5
          bg-red-50 dark:bg-red-900/20
          border-b border-red-200 dark:border-red-800/50
        '''
        : '''
          flex flex-row items-center gap-3 px-4 py-2.5
          bg-slate-50 dark:bg-slate-800/50
          border-b border-slate-200 dark:border-slate-700/50
        ''';

    return WDiv(
      className: containerClassName,
      children: [
        // Agent role coloured dot
        WDiv(
          className: 'w-2 h-2 rounded-full ${_roleColorClass(agentRoleSlug)}',
        ),

        // Status label
        WText(
          trans('agent_progress.status_${status ?? "unknown"}'),
          className: 'text-xs font-semibold text-slate-600 dark:text-slate-300',
        ),

        // Message — fills remaining space with truncation
        if (message?.isNotEmpty ?? false)
          WDiv(
            className: 'flex-1 overflow-hidden',
            child: WText(
              message!,
              className: 'text-xs text-slate-500 dark:text-slate-400 truncate',
            ),
          ),

        // Percentage progress track
        if (percentage != null) _buildProgressTrack(context),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Progress track
  // -----------------------------------------------------------------------

  /// Renders a narrow pill-shaped progress track with a filled portion
  /// proportional to [percentage].
  ///
  /// `FractionallySizedBox` is used here as an acceptable exception —
  /// Wind UI className cannot express dynamic fractional widths.
  Widget _buildProgressTrack(BuildContext context) {
    final fraction = ((percentage ?? 0).clamp(0, 100) / 100.0);

    return WDiv(
      className:
          'w-20 h-1.5 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden',
      child: FractionallySizedBox(
        widthFactor: fraction,
        alignment: Alignment.centerLeft,
        child: WDiv(
          className: 'h-full rounded-full ${_progressColorClass(status)}',
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Color helpers
  // -----------------------------------------------------------------------

  /// Maps an agent role slug to a dot background className.
  String _roleColorClass(String? slug) => switch (slug) {
    'ba' => 'bg-indigo-500',
    'lead' => 'bg-primary-500',
    'dev' => 'bg-teal-500',
    'reviewer' => 'bg-violet-500',
    'qa' => 'bg-emerald-500',
    _ => 'bg-slate-500',
  };

  /// Maps a progress status to a fill colour className for the track.
  String _progressColorClass(String? status) => switch (status) {
    'blocked' => 'bg-red-500',
    _ => 'bg-teal-500',
  };
}
