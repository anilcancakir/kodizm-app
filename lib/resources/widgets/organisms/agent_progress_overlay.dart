import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/user.dart';
import '../../../app/state/agent_progress_state.dart';

/// Global toast overlay that renders floating agent progress notifications.
///
/// Wraps a [child] widget and overlays up to 3 toast cards in the top-right
/// corner. Each toast shows agent role, project name, status, and progress
/// message. Tapping a toast navigates to the corresponding conversation.
///
/// ## Usage
///
/// ```dart
/// AgentProgressOverlay(
///   child: MyPageContent(),
/// )
/// ```
class AgentProgressOverlay extends StatefulWidget {
  /// Creates an [AgentProgressOverlay].
  const AgentProgressOverlay({super.key, required this.child});

  /// The content widget to render beneath the toast overlay.
  final Widget child;

  @override
  State<AgentProgressOverlay> createState() => _AgentProgressOverlayState();
}

class _AgentProgressOverlayState extends State<AgentProgressOverlay> {
  late final AgentProgressState _state;

  @override
  void initState() {
    super.initState();
    _state = Magic.findOrPut<AgentProgressState>(AgentProgressState.new);

    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId != null && teamId.isNotEmpty) {
      _state.subscribeToTeam(teamId);
    }

    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Trigger rebuild when toast state changes.
  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final toasts = _state.activeToasts;

    if (toasts.isEmpty) {
      return widget.child;
    }

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 16,
          right: 16,
          child: WDiv(
            className: 'flex flex-col gap-0',
            children: toasts.map(_buildToastCard).toList(),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Toast card
  // -------------------------------------------------------------------------

  /// Builds a single toast card for the given [item].
  Widget _buildToastCard(AgentProgressItem item) {
    final containerClass = item.isBlocked
        ? 'w-80 p-3 rounded-xl shadow-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/50 mb-2'
        : 'w-80 p-3 rounded-xl shadow-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 mb-2';

    return WAnchor(
      onTap: () => MagicRoute.to(
        '/conversations/${item.projectId}/${item.conversationId}',
      ),
      child: WDiv(
        className: containerClass,
        children: [
          // Top row: role dot + project name + dismiss button.
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WDiv(
                className:
                    'w-2 h-2 rounded-full ${_roleColorClass(item.agentRoleSlug)}',
              ),
              WDiv(
                className: 'flex-1 overflow-hidden',
                child: WText(
                  item.projectName ?? '',
                  className:
                      'text-xs font-medium text-slate-700 dark:text-slate-200 truncate',
                ),
              ),
              WAnchor(
                onTap: () => _state.dismissToast(item.conversationId),
                child: WIcon(Icons.close, className: 'text-xs text-slate-400'),
              ),
            ],
          ),

          // Bottom row: status label + message.
          WDiv(
            className: 'flex flex-row items-center gap-2 mt-1',
            children: [
              WText(
                trans('agent_progress.status_${item.status}'),
                className:
                    'text-xs font-semibold ${item.isBlocked ? "text-red-600 dark:text-red-400" : "text-slate-600 dark:text-slate-300"}',
              ),
              WDiv(
                className: 'flex-1 overflow-hidden',
                child: WText(
                  item.message,
                  className:
                      'text-xs text-slate-500 dark:text-slate-400 truncate',
                ),
              ),
            ],
          ),

          // Optional percentage mini-bar.
          if (item.percentage != null)
            WDiv(
              className:
                  'mt-2 h-1 rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden',
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (item.percentage ?? 0) / 100,
                child: WDiv(
                  className:
                      'h-1 rounded-full ${item.isBlocked ? "bg-red-500" : "bg-amber-500"}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Role color map
  // -------------------------------------------------------------------------

  /// Maps an agent role slug to a background dot className.
  String _roleColorClass(String? slug) {
    return switch (slug) {
      'ba' => 'bg-indigo-500',
      'lead' => 'bg-primary-500',
      'dev' => 'bg-teal-500',
      'reviewer' => 'bg-violet-500',
      'qa' => 'bg-emerald-500',
      _ => 'bg-slate-500',
    };
  }
}
