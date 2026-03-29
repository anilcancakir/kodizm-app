import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ChatThinkingBlock
// ---------------------------------------------------------------------------

/// A collapsible thinking indicator for the conversation chat stream.
///
/// Displays a `✻ Thinking (Xs)` header that can be expanded to reveal
/// the full thinking content when [content] is non-null. When [content]
/// is `null`, the block is rendered as a non-expandable indicator without
/// a chevron or tap handler.
///
/// [durationMs] is formatted as seconds with one decimal place
/// (e.g. `2300` → `"2.3s"`). When `null`, the plain "Thinking" label is shown.
///
/// ## Usage
///
/// ```dart
/// // Expandable with content and duration
/// ChatThinkingBlock(
///   content: 'I am reasoning about the architecture...',
///   durationMs: 2300,
/// )
///
/// // Non-expandable indicator (no content)
/// ChatThinkingBlock(durationMs: 500)
/// ```
class ChatThinkingBlock extends StatefulWidget {
  /// Creates a [ChatThinkingBlock].
  const ChatThinkingBlock({super.key, this.content, this.durationMs});

  /// The thinking content to display when expanded.
  ///
  /// When `null`, the block is non-expandable (no chevron, no tap handler).
  final String? content;

  /// Duration of the thinking phase in milliseconds.
  ///
  /// Formatted as seconds with one decimal (e.g. `2300` → `"2.3s"`).
  /// When `null`, the plain "Thinking" label is shown without duration.
  final int? durationMs;

  @override
  State<ChatThinkingBlock> createState() => _ChatThinkingBlockState();
}

class _ChatThinkingBlockState extends State<ChatThinkingBlock> {
  bool _expanded = false;

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Formats [durationMs] to seconds with one decimal place.
  String _formatDuration(int durationMs) {
    final seconds = (durationMs / 1000).toStringAsFixed(1);
    return '${seconds}s';
  }

  /// Returns the translated header label, with or without duration.
  String get _headerLabel {
    if (widget.durationMs != null) {
      return trans('conversation_chat.event_thinking_duration', {
        'duration': _formatDuration(widget.durationMs!),
      });
    }
    return trans('conversation_chat.event_thinking');
  }

  /// Whether this block is expandable (content is non-null).
  bool get _isExpandable => widget.content != null;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'bg-violet-50 dark:bg-violet-900/10 rounded-lg px-3 py-2',
      children: [
        _buildHeader(),
        if (_expanded && _isExpandable) _buildContent(),
      ],
    );
  }

  /// Builds the collapsed header row with icon, label, and optional chevron.
  Widget _buildHeader() {
    final header = WDiv(
      className: 'flex flex-row items-center gap-2',
      children: [
        WText('✻', className: 'text-sm text-violet-400'),
        WText(
          _headerLabel,
          className: 'text-sm text-violet-500 dark:text-violet-400',
        ),
        if (_isExpandable)
          WIcon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            className: 'text-sm text-violet-400',
          ),
      ],
    );

    if (!_isExpandable) return header;

    return WAnchor(
      onTap: () => setState(() => _expanded = !_expanded),
      child: header,
    );
  }

  /// Builds the expanded thinking content area.
  Widget _buildContent() {
    return WDiv(
      className: 'pt-2',
      child: WText(
        widget.content!,
        className: 'text-violet-500/70 italic text-sm',
      ),
    );
  }
}
