import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// ChatErrorBlock
// ---------------------------------------------------------------------------

/// A red left-border accent card that displays an error message inline
/// within the conversation chat stream.
///
/// Uses a `border-l-4 border-red-400` left accent with a subtle red
/// background tint, an error icon, and monospace error text — matching
/// DESIGN.md semantic error colors.
///
/// ## Usage
///
/// ```dart
/// ChatErrorBlock(
///   errorText: 'Connection timed out',
/// )
/// ```
class ChatErrorBlock extends StatelessWidget {
  /// Creates a [ChatErrorBlock] displaying the given [errorText].
  const ChatErrorBlock({super.key, required this.errorText});

  /// The error message to display.
  final String errorText;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className:
          'border-l-4 border-red-400 bg-red-50 dark:bg-red-900/10 rounded-lg px-3 py-2',
      child: WDiv(
        className: 'flex flex-row items-start gap-2',
        children: [
          WIcon(Icons.error_outline, className: 'text-sm text-red-500'),
          WDiv(
            className: 'flex-1',
            child: WText(
              errorText,
              className: 'text-sm font-mono text-red-600 dark:text-red-400',
            ),
          ),
        ],
      ),
    );
  }
}
