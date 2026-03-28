import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation_message.dart';
import 'markdown_viewer.dart';

/// A chat message bubble displaying user or assistant content.
///
/// User messages are right-aligned with amber background.
/// Assistant messages are left-aligned with white background, rendered
/// as Markdown via [MarkdownViewer], with optional cost/duration footer.
///
/// ## Usage
///
/// ```dart
/// ChatMessageBubble(message: conversationMessage)
/// ```
class ChatMessageBubble extends StatelessWidget {
  /// Creates a [ChatMessageBubble] for the given [message].
  const ChatMessageBubble({required this.message, super.key});

  /// The conversation message to render.
  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return WDiv(
      className: 'flex ${isUser ? 'flex-row-reverse' : 'flex-row'} mb-3',
      children: [
        WDiv(
          className: isUser ? _userBubbleClassName : _assistantBubbleClassName,
          children: [
            // Content
            if (isUser)
              WText(
                message.content,
                className: 'text-sm text-slate-900 dark:text-slate-100',
              )
            else
              MarkdownViewer(data: message.content),

            // Footer — cost + duration for assistant messages
            if (!isUser && _hasFooterData)
              WDiv(
                className: 'flex flex-row items-center gap-2 mt-2',
                children: [
                  if (message.costUsd != null)
                    WText(
                      trans('conversation_chat.cost_format', {
                        'amount': message.costUsd!.toStringAsFixed(4),
                      }),
                      className: 'text-xs text-slate-400',
                    ),
                  if (message.durationMs != null)
                    WText(
                      '${message.durationMs}ms',
                      className: 'text-xs text-slate-400 font-mono',
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Whether the message has cost or duration data for the footer.
  bool get _hasFooterData =>
      message.costUsd != null || message.durationMs != null;

  /// className for user message bubbles.
  static const String _userBubbleClassName = '''
    ml-12 p-3 rounded-2xl rounded-br-md
    bg-amber-50 dark:bg-amber-900/20
  ''';

  /// className for assistant message bubbles.
  static const String _assistantBubbleClassName = '''
    mr-12 p-3 rounded-2xl rounded-bl-md
    bg-white dark:bg-slate-800
    border border-slate-200 dark:border-slate-700
  ''';
}
