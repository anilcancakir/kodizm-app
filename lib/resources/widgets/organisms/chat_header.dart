import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation.dart';

/// Compact top bar for the conversation chat screen.
///
/// Displays the agent role badge, conversation title, cost (with running
/// session cost preferred when available), optional session phase label,
/// and a settings gear that opens a config modal.
///
/// ## Usage
///
/// ```dart
/// ChatHeader(
///   conversation: conversation,
///   sessionPhase: state.sessionPhase,
///   runningCostUsd: state.runningCostUsd,
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
    this.runningCostUsd,
    this.firstMessagePreview,
    this.onComplete,
    this.onToggleDebug,
    super.key,
  });

  /// The conversation being displayed.
  final Conversation conversation;

  /// Current session execution phase label, if available.
  final String? sessionPhase;

  /// Live running cost from the session WebSocket channel.
  final String? runningCostUsd;

  /// Truncated first user message — shown as title fallback when
  /// [Conversation.title] is null.
  final String? firstMessagePreview;

  /// Whether the debug panel is currently expanded.
  final bool debugExpanded;

  /// Callback fired when the complete button is tapped.
  final VoidCallback? onComplete;

  /// Callback fired when the debug toggle is tapped.
  final VoidCallback? onToggleDebug;

  // -------
  // Helpers
  // -------

  String _sessionPhaseClassName(String phase) {
    return switch (phase) {
      'provisioning' => 'bg-blue-500/10 text-blue-500',
      'executing' => 'bg-emerald-500/10 text-emerald-600',
      'warm' => 'bg-amber-500/10 text-amber-600',
      'dead' => 'bg-slate-500/10 text-slate-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  IconData _sessionPhaseIcon(String phase) {
    return switch (phase) {
      'provisioning' => Icons.cloud_queue_rounded,
      'executing' => Icons.play_circle_rounded,
      'warm' => Icons.pause_circle_rounded,
      'dead' => Icons.stop_circle_rounded,
      _ => Icons.help_outline_rounded,
    };
  }

  // -------
  // Build
  // -------

  // -------
  // Config modal
  // -------

  /// Opens a bottom sheet with conversation config: status, complete action,
  /// and debug toggle.
  void _showConfigModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChatConfigSheet(
        conversation: conversation,
        debugExpanded: debugExpanded,
        onComplete: onComplete,
        onToggleDebug: onToggleDebug,
      ),
    );
  }

  // -------
  // Build
  // -------

  @override
  Widget build(BuildContext context) {
    // Prefer running session cost over static conversation cost.
    final String? costLabel;
    if (runningCostUsd != null) {
      costLabel = trans('conversation_chat.cost_format', {
        'amount': runningCostUsd!,
      });
    } else {
      final cost = conversation.totalCostUsd;
      costLabel = cost != null
          ? trans('conversation_chat.cost_format', {
              'amount': cost.toStringAsFixed(4),
            })
          : null;
    }

    return WDiv(
      className:
          'w-full h-14 px-4 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 flex flex-row items-center gap-3 axis-max',
      children: [
        // Back button
        WAnchor(
          onTap: () => MagicRoute.back(fallback: '/conversations'),
          child: WIcon(
            Icons.arrow_back_rounded,
            className: 'text-lg text-slate-500 dark:text-slate-400',
          ),
        ),

        // Title — flex-1 absorbs remaining space, min-w-0 + truncate prevents overflow
        WDiv(
          className: 'flex-1 min-w-0',
          child: WText(
            conversation.title ??
                firstMessagePreview ??
                trans('conversation_chat.title'),
            className:
                'text-sm font-semibold text-slate-800 dark:text-white truncate',
          ),
        ),

        // Cost
        if (costLabel != null)
          WText(
            costLabel,
            className: 'font-mono text-xs text-slate-500 dark:text-slate-400',
          ),

        // Session phase badge
        if (sessionPhase != null)
          WDiv(
            className:
                'px-1.5 py-0.5 rounded-full flex flex-row items-center gap-1 ${_sessionPhaseClassName(sessionPhase!)}',
            children: [
              if (sessionPhase == 'provisioning')
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                WIcon(_sessionPhaseIcon(sessionPhase!), className: 'text-xs'),
              WText(
                trans('conversation_chat.phase_${sessionPhase!}'),
                className: 'text-[11px] font-semibold',
              ),
            ],
          ),

        // Settings gear — opens config modal
        WAnchor(
          onTap: () => _showConfigModal(context),
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

// ---------------------------------------------------------------------------
// Config bottom sheet
// ---------------------------------------------------------------------------

/// Bottom sheet with conversation configuration actions: status display,
/// complete chat button, and debug panel toggle.
class _ChatConfigSheet extends StatelessWidget {
  const _ChatConfigSheet({
    required this.conversation,
    required this.debugExpanded,
    this.onComplete,
    this.onToggleDebug,
  });

  final Conversation conversation;
  final bool debugExpanded;
  final VoidCallback? onComplete;
  final VoidCallback? onToggleDebug;

  String _statusClassName(String status) {
    return switch (status) {
      'active' => 'bg-emerald-500/10 text-emerald-600',
      'paused' => 'bg-amber-500/10 text-amber-600',
      'completed' => 'bg-slate-500/10 text-slate-500',
      'failed' => 'bg-red-500/10 text-red-600',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-6 flex flex-col gap-4',
      children: [
        // Sheet handle
        WDiv(
          className: 'w-full flex items-center justify-center',
          child: WDiv(
            className: 'w-10 h-1 rounded-full bg-slate-300 dark:bg-slate-600',
          ),
        ),

        // Title
        WText(
          trans('conversation_chat.config_title'),
          className: 'text-base font-semibold text-slate-800 dark:text-white',
        ),

        // Status row
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            WText(
              trans('conversation_chat.status_label'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            WDiv(
              className:
                  'px-2 py-0.5 rounded ${_statusClassName(conversation.status)}',
              child: WText(
                trans('conversation_chat.status_${conversation.status}'),
                className: 'text-xs font-semibold',
              ),
            ),
          ],
        ),

        // Debug toggle
        WAnchor(
          onTap: () {
            onToggleDebug?.call();
            Navigator.of(context).pop();
          },
          child: WDiv(
            className: '''
              w-full flex flex-row items-center gap-3 px-4 py-3
              rounded-xl bg-slate-50 dark:bg-slate-800
            ''',
            children: [
              WIcon(
                Icons.bug_report_outlined,
                className: debugExpanded
                    ? 'text-lg text-amber-600'
                    : 'text-lg text-slate-400',
              ),
              WText(
                trans('conversation_chat.toggle_debug'),
                className: 'text-sm text-slate-700 dark:text-slate-200',
              ),
            ],
          ),
        ),

        // Complete button — only for active conversations
        if (conversation.status == 'active')
          WAnchor(
            onTap: () {
              onComplete?.call();
              Navigator.of(context).pop();
            },
            child: WDiv(
              className: '''
                w-full flex items-center justify-center
                px-4 py-3 rounded-xl bg-red-500
              ''',
              child: WText(
                trans('conversation_chat.complete_chat'),
                className: 'text-sm font-semibold text-white',
              ),
            ),
          ),
      ],
    );
  }
}
