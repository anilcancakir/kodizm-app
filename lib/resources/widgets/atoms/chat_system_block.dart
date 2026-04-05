import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ChatSystemBlock
// ---------------------------------------------------------------------------

/// A centered, muted inline notice for system-level events in the chat stream.
///
/// Displays an icon and text in a compact pill — used for interruption
/// notices (`[Request interrupted by user]`) and other platform messages.
///
/// ## Usage
///
/// ```dart
/// ChatSystemBlock(content: trans('conversation_chat.event_interrupted'))
/// ```
class ChatSystemBlock extends StatelessWidget {
  /// Creates a [ChatSystemBlock] displaying the given [content].
  const ChatSystemBlock({super.key, required this.content});

  /// The system message text to display.
  final String content;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center justify-center py-2',
      child: WDiv(
        className:
            'flex flex-row items-center gap-2 bg-amber-50 dark:bg-amber-900/10 border border-amber-200 dark:border-amber-800 rounded-full px-4 py-1.5',
        children: [
          WIcon(Icons.front_hand_outlined, className: 'text-sm text-amber-500'),
          WText(
            content,
            className: 'text-xs font-medium text-amber-700 dark:text-amber-400',
          ),
        ],
      ),
    );
  }
}
