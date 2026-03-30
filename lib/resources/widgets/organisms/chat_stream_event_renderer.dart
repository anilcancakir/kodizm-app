import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/chat_item.dart';
import '../atoms/chat_error_block.dart';
import '../atoms/chat_file_change_row.dart';
import '../atoms/chat_result_block.dart';
import '../atoms/chat_thinking_block.dart';
import '../molecules/chat_subagent_block.dart';
import 'chat_message_bubble.dart';
import 'chat_tool_use_card.dart';

// ---------------------------------------------------------------------------
// ChatStreamEventRenderer
// ---------------------------------------------------------------------------

/// Master dispatcher that routes a [ChatItem] to the correct sub-widget.
///
/// Used as the single entry point for the conversation chat [ListView.builder].
/// Exhaustive switch on the sealed [ChatItem] hierarchy guarantees compile-time
/// safety when new item types are added.
///
/// ## Usage
/// ```dart
/// ChatStreamEventRenderer(
///   item: chatItem,
///   agentRoleSlug: 'ba',
///   agentRoleName: 'Business Analyst',
///   userName: 'Anil',
/// )
/// ```
class ChatStreamEventRenderer extends StatelessWidget {
  /// Creates a [ChatStreamEventRenderer] for the given [item].
  const ChatStreamEventRenderer({
    required this.item,
    this.agentRoleSlug,
    this.agentRoleName,
    this.userName,
    super.key,
  });

  // -------

  /// The chat item to render. Sealed type ensures exhaustive dispatch.
  final ChatItem item;

  /// Agent role slug forwarded to [ChatMessageBubble] for avatar colouring.
  final String? agentRoleSlug;

  /// Agent role display name forwarded to [ChatMessageBubble].
  final String? agentRoleName;

  /// Display name of the logged-in user forwarded to [ChatMessageBubble].
  final String? userName;

  // -------

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      ChatMessageItem(:final message) => ChatMessageBubble(
        message: message,
        agentRoleSlug: agentRoleSlug,
        agentRoleName: agentRoleName,
        userName: userName,
      ),
      ChatToolUseItem(:final toolName, :final input, :final result) => WDiv(
        className: 'pl-9 mb-2',
        child: ChatToolUseCard(
          toolName: toolName,
          input: input,
          result: result,
        ),
      ),
      ChatThinkingItem(:final content, :final durationMs) => WDiv(
        className: 'pl-9 mb-2',
        child: ChatThinkingBlock(content: content, durationMs: durationMs),
      ),
      ChatSubagentItem(
        :final subagentId,
        :final description,
        :final isComplete,
        :final toolUseCount,
        :final durationMs,
        :final children,
      ) =>
        WDiv(
          className: 'pl-9 mb-2',
          child: ChatSubagentBlock(
            subagentId: subagentId,
            description: description,
            isComplete: isComplete,
            toolUseCount: toolUseCount,
            durationMs: durationMs,
            children: children,
          ),
        ),
      ChatFileChangeItem(:final operation, :final filePath) => WDiv(
        className: 'pl-9 mb-2',
        child: ChatFileChangeRow(operation: operation, filePath: filePath),
      ),
      ChatErrorItem(:final errorText) => WDiv(
        className: 'pl-9 mb-2',
        child: ChatErrorBlock(errorText: errorText),
      ),
      ChatResultItem(:final isError, :final content) => WDiv(
        className: 'pl-9 mb-2',
        child: ChatResultBlock(isError: isError, content: content),
      ),
    };
  }
}
