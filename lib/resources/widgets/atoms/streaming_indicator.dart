import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A simple pulsing indicator shown when the assistant is typing/thinking.
///
/// Uses [CircularProgressIndicator] (allowed exception per CLAUDE.md)
/// wrapped in a [SizedBox] for sizing, plus a [WText] label.
///
/// ## Usage
///
/// ```dart
/// const StreamingIndicator()
/// ```
class StreamingIndicator extends StatelessWidget {
  /// Creates a [StreamingIndicator].
  const StreamingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center gap-2 p-3',
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        WText(
          trans('conversation_chat.streaming'),
          className: 'text-xs text-slate-400 dark:text-slate-500',
        ),
      ],
    );
  }
}
