import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation.dart';

/// Compact top bar for the conversation chat screen.
///
/// Displays the agent role badge, conversation title, status indicator, cost,
/// optional session phase label, a complete button (active conversations only),
/// and a debug panel toggle.
///
/// ## Usage
///
/// ```dart
/// ChatHeader(
///   conversation: conversation,
///   sessionPhase: state.sessionPhase,
///   debugExpanded: _debugExpanded,
///   onComplete: _handleComplete,
///   onToggleDebug: _handleToggleDebug,
/// )
/// ```
class ChatHeader extends StatelessWidget {
  /// Creates a [ChatHeader].
  const ChatHeader({
    required this.conversation,
    required this.debugExpanded,
    this.sessionPhase,
    this.onComplete,
    this.onToggleDebug,
    super.key,
  });

  /// The conversation being displayed.
  final Conversation conversation;

  /// Current session execution phase label, if available.
  final String? sessionPhase;

  /// Whether the debug panel is currently expanded.
  final bool debugExpanded;

  /// Callback fired when the complete button is tapped.
  final VoidCallback? onComplete;

  /// Callback fired when the debug toggle is tapped.
  final VoidCallback? onToggleDebug;

  // -------
  // Helpers
  // -------

  String _roleClassName(String? slug) {
    return switch (slug) {
      'ba' => 'bg-indigo-500/10 text-indigo-500',
      'lead' => 'bg-primary-500/10 text-primary-500',
      'dev' => 'bg-teal-500/10 text-teal-500',
      'reviewer' => 'bg-violet-500/10 text-violet-500',
      'qa' => 'bg-emerald-500/10 text-emerald-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  String _statusClassName(String status) {
    return switch (status) {
      'active' => 'bg-emerald-500/10 text-emerald-600',
      'paused' => 'bg-amber-500/10 text-amber-600',
      'completed' => 'bg-slate-500/10 text-slate-500',
      'failed' => 'bg-red-500/10 text-red-600',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  // -------
  // Build
  // -------

  @override
  Widget build(BuildContext context) {
    final cost = conversation.totalCostUsd;
    final costLabel = cost != null
        ? trans('conversation_chat.cost_format', {
            'amount': cost.toStringAsFixed(4),
          })
        : null;

    return WDiv(
      className:
          'w-full h-14 px-4 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 flex flex-row items-center gap-3 axis-max',
      children: [
        // Back button
        WAnchor(
          onTap: () => MagicRoute.back(),
          child: WIcon(
            Icons.arrow_back_rounded,
            className: 'text-lg text-slate-500 dark:text-slate-400',
          ),
        ),

        // Agent role badge
        WDiv(
          className:
              'px-2 py-0.5 rounded-full ${_roleClassName(conversation.agentRoleSlug)}',
          child: WText(
            conversation.agentRoleName ?? trans('common.unknown'),
            className: 'text-xs font-semibold',
          ),
        ),

        // Title — flex-1 absorbs remaining space, min-w-0 + truncate prevents overflow
        WDiv(
          className: 'flex-1 min-w-0',
          child: WText(
            conversation.title ?? trans('conversation_chat.title'),
            className:
                'text-sm font-semibold text-slate-800 dark:text-white truncate',
          ),
        ),

        // Status badge
        WDiv(
          className:
              'px-1.5 py-0.5 rounded ${_statusClassName(conversation.status)}',
          child: WText(
            trans('conversation_chat.status_${conversation.status}'),
            className: 'text-[11px] font-semibold',
          ),
        ),

        // Cost
        if (costLabel != null)
          WText(
            costLabel,
            className: 'font-mono text-xs text-slate-500 dark:text-slate-400',
          ),

        // Session phase
        if (sessionPhase != null)
          WText(
            trans('conversation_chat.session_phase', {'phase': sessionPhase!}),
            className: 'text-[11px] text-slate-400',
          ),

        // Complete button — only for active conversations
        if (conversation.status == 'active')
          WAnchor(
            onTap: onComplete,
            child: WDiv(
              className: 'px-3 py-1 bg-red-500 rounded-full',
              child: WText(
                trans('conversation_chat.complete_chat'),
                className: 'text-xs text-white font-medium',
              ),
            ),
          ),

        // Debug toggle
        WAnchor(
          onTap: onToggleDebug,
          child: WDiv(
            className: debugExpanded
                ? 'p-1.5 rounded-lg bg-amber-400/15'
                : 'p-1.5 rounded-lg bg-slate-100 dark:bg-slate-800',
            child: WIcon(
              Icons.settings_outlined,
              className: debugExpanded
                  ? 'text-lg text-amber-600'
                  : 'text-lg text-slate-400',
            ),
          ),
        ),
      ],
    );
  }
}
