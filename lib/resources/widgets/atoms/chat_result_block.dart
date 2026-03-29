import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ChatResultBlock
// ---------------------------------------------------------------------------

/// Renders a compact result indicator for a completed chat operation.
///
/// Displays a success (emerald) or error (red) state with an icon and label.
/// When [isError] is `true` and [content] is provided, the error details are
/// shown below the indicator row in monospace font.
///
/// ## Usage
///
/// ```dart
/// // Success result
/// const ChatResultBlock(isError: false)
///
/// // Error result with details
/// ChatResultBlock(
///   isError: true,
///   content: 'TypeError: Cannot read property "id" of undefined',
/// )
/// ```
class ChatResultBlock extends StatelessWidget {
  /// Creates a [ChatResultBlock].
  const ChatResultBlock({super.key, required this.isError, this.content});

  /// Whether this result represents an error.
  final bool isError;

  /// Optional error content displayed below the indicator when [isError] is
  /// `true`. Ignored for success results.
  final String? content;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (isError) {
      return _buildError();
    }

    return _buildSuccess();
  }

  // -----------------------------------------------------------------------
  // Renderers
  // -----------------------------------------------------------------------

  /// Builds the success indicator row.
  Widget _buildSuccess() {
    return WDiv(
      className:
          'flex flex-row items-center gap-2 bg-emerald-50 dark:bg-emerald-900/10 rounded-lg px-3 py-2',
      children: [
        WIcon(Icons.check_circle, className: 'text-sm text-emerald-500'),
        WText(
          trans('conversation_chat.event_result_success'),
          className: 'text-xs text-emerald-600 dark:text-emerald-400',
        ),
      ],
    );
  }

  /// Builds the error indicator row, optionally with content below.
  Widget _buildError() {
    return WDiv(
      className:
          'flex flex-col gap-1 bg-red-50 dark:bg-red-900/10 rounded-lg px-3 py-2',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(Icons.cancel, className: 'text-sm text-red-500'),
            WText(
              trans('conversation_chat.event_result_error'),
              className: 'text-xs text-red-600 dark:text-red-400',
            ),
          ],
        ),
        if (isError && content != null)
          WText(content!, className: 'text-xs font-mono text-red-400'),
      ],
    );
  }
}
