import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ChatSubagentBlock
// ---------------------------------------------------------------------------

/// Inline sub-agent lifecycle indicator for the conversation chat stream.
///
/// Renders a teal left-bordered block showing the sub-agent's name badge,
/// an optional description, and either a running spinner or a completion
/// summary with tool use count and duration.
///
/// ## Usage
///
/// ```dart
/// ChatSubagentBlock(
///   subagentId: 'sa_abc123',
///   description: 'Analyzing repository structure',
///   isComplete: false,
///   toolUseCount: 0,
/// )
///
/// ChatSubagentBlock(
///   subagentId: 'sa_abc123',
///   description: 'Analyzing repository structure',
///   isComplete: true,
///   toolUseCount: 12,
///   durationMs: 8500,
/// )
/// ```
class ChatSubagentBlock extends StatelessWidget {
  /// Creates a [ChatSubagentBlock] for the given sub-agent.
  const ChatSubagentBlock({
    required this.subagentId,
    required this.isComplete,
    required this.toolUseCount,
    this.description,
    this.durationMs,
    super.key,
  });

  /// The unique identifier for this sub-agent.
  final String subagentId;

  /// Optional description of the sub-agent's purpose.
  final String? description;

  /// Whether the sub-agent has finished execution.
  final bool isComplete;

  /// The number of tool invocations performed by the sub-agent.
  final int toolUseCount;

  /// Total execution time in milliseconds, populated on completion.
  final int? durationMs;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'border-l-2 border-teal-400 pl-3 py-2',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            _buildBadge(),
            if (description != null)
              WText(
                description!,
                className: 'text-xs text-slate-600 dark:text-slate-400',
              ),
          ],
        ),
        WSpacer(className: 'h-1'),
        isComplete ? _buildDone() : _buildRunning(),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Sub-widgets
  // -----------------------------------------------------------------------

  /// Renders the teal sub-agent name badge.
  Widget _buildBadge() {
    return WDiv(
      className: 'px-1.5 py-0.5 rounded bg-teal-500/15',
      child: WText(
        trans('conversation_chat.event_subagent_start', {'name': subagentId}),
        className: 'text-[10px] font-bold text-teal-500',
      ),
    );
  }

  /// Renders the running state with spinner and "Running..." label.
  Widget _buildRunning() {
    return WDiv(
      className: 'flex flex-row items-center gap-2',
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        WText(
          trans('conversation_chat.event_subagent_running'),
          className: 'text-xs text-slate-400',
        ),
      ],
    );
  }

  /// Renders the done state with tool count and optional duration.
  Widget _buildDone() {
    return WDiv(
      className: 'flex flex-row items-center gap-1',
      children: [
        WText(
          trans('conversation_chat.event_subagent_done', {
            'tools': toolUseCount.toString(),
            'duration': _formatDuration(),
          }),
          className: 'text-xs text-teal-500',
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Converts [durationMs] to a compact seconds string (e.g. 12000 -> "12s").
  String _formatDuration() {
    if (durationMs == null) return '?';
    final seconds = (durationMs! / 1000).round();
    return '${seconds}s';
  }
}
