import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/chat_item.dart';
import '../atoms/chat_error_block.dart';
import '../atoms/chat_file_change_row.dart';
import '../atoms/chat_thinking_block.dart';
import '../organisms/chat_tool_use_card.dart';

// ---------------------------------------------------------------------------
// ChatSubagentBlock
// ---------------------------------------------------------------------------

/// Inline sub-agent lifecycle block for the conversation chat stream.
///
/// Renders a teal left-bordered block showing the sub-agent's name badge,
/// an optional description, a running spinner or completion summary, and a
/// collapsible list of nested child events (tool_use, thinking, file_change).
///
/// When [isComplete] is `false` (running), the children section is expanded
/// by default. When `true` (done), it collapses to a summary line.
///
/// ## Usage
///
/// ```dart
/// ChatSubagentBlock(
///   subagentId: 'sa_abc123',
///   description: 'Explore',
///   isComplete: false,
///   toolUseCount: 5,
///   children: [chatToolUseItem1, chatToolUseItem2],
/// )
/// ```
class ChatSubagentBlock extends StatefulWidget {
  /// Creates a [ChatSubagentBlock] for the given sub-agent.
  const ChatSubagentBlock({
    required this.subagentId,
    required this.isComplete,
    required this.toolUseCount,
    this.description,
    this.durationMs,
    this.children = const [],
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

  /// Nested [ChatItem]s produced by this sub-agent during execution.
  final List<ChatItem> children;

  @override
  State<ChatSubagentBlock> createState() => _ChatSubagentBlockState();
}

class _ChatSubagentBlockState extends State<ChatSubagentBlock> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ChatSubagentBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-collapse when the subagent completes.
    if (!oldWidget.isComplete && widget.isComplete) {
      _expanded = false;
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'border-l-2 border-teal-400 pl-3 py-2',
      children: [
        WAnchor(
          onTap: widget.children.isNotEmpty
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              _buildBadge(),
              if (widget.description != null)
                WText(
                  widget.description!,
                  className: 'text-xs text-slate-600 dark:text-slate-400',
                ),
              if (widget.children.isNotEmpty) ...[
                WDiv(className: 'flex-1'),
                WIcon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  className: 'text-sm text-slate-400',
                ),
              ],
            ],
          ),
        ),
        WSpacer(className: 'h-1'),
        widget.isComplete ? _buildDone() : _buildRunning(),
        if (_expanded && widget.children.isNotEmpty) ...[
          WSpacer(className: 'h-2'),
          _buildChildren(),
        ],
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
        trans('conversation_chat.event_subagent_start', {
          'name': widget.subagentId,
        }),
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
            'tools': widget.toolUseCount.toString(),
            'duration': _formatDuration(),
          }),
          className: 'text-xs text-teal-500',
        ),
      ],
    );
  }

  /// Renders the nested child events inside the subagent block.
  Widget _buildChildren() {
    return WDiv(
      className: 'flex flex-col gap-1',
      children: [for (final child in widget.children) _buildChildItem(child)],
    );
  }

  /// Route a single child [ChatItem] to its renderer.
  Widget _buildChildItem(ChatItem item) {
    return switch (item) {
      ChatToolUseItem(:final toolName, :final input, :final result) =>
        ChatToolUseCard(toolName: toolName, input: input, result: result),
      ChatThinkingItem(:final content, :final durationMs) => ChatThinkingBlock(
        content: content,
        durationMs: durationMs,
      ),
      ChatFileChangeItem(:final operation, :final filePath) =>
        ChatFileChangeRow(operation: operation, filePath: filePath),
      ChatErrorItem(:final errorText) => ChatErrorBlock(errorText: errorText),
      _ => WSpacer(className: 'h-0'),
    };
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Converts [durationMs] to a compact seconds string (e.g. 12000 -> "12s").
  String _formatDuration() {
    if (widget.durationMs == null) return '?';
    final seconds = (widget.durationMs! / 1000).round();
    return '${seconds}s';
  }
}
