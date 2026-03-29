import 'package:flutter/foundation.dart';

import 'package:app/app/models/conversation_message.dart';

/// A sealed union of every renderable item in a conversation chat timeline.
///
/// Each subclass represents a distinct event type emitted by the sidecar bridge
/// (text, tool_use, thinking, subagent, file_change, error, result) or a
/// persisted [ConversationMessage] loaded from the API.
///
/// ## Usage
/// ```dart
/// final label = switch (chatItem) {
///   ChatMessageItem()    => 'message',
///   ChatToolUseItem()    => 'tool_use',
///   ChatThinkingItem()   => 'thinking',
///   ChatSubagentItem()   => 'subagent',
///   ChatFileChangeItem() => 'file_change',
///   ChatErrorItem()      => 'error',
///   ChatResultItem()     => 'result',
/// };
/// ```
@immutable
sealed class ChatItem {
  /// The unique identifier for this chat item.
  String get id;

  /// The UTC timestamp when this item occurred.
  DateTime get occurredAt;
}

// -------

/// A chat item wrapping a persisted [ConversationMessage] from the API.
///
/// Delegates [id] and [occurredAt] to the underlying message so that
/// persisted history and live-streamed events share a common timeline.
///
/// ## Usage
/// ```dart
/// final item = ChatMessageItem.fromConversationMessage(message);
/// print(item.message.content);
/// ```
final class ChatMessageItem extends ChatItem {
  /// Creates a [ChatMessageItem] wrapping the given [message].
  ChatMessageItem({required this.message});

  /// The underlying conversation message.
  final ConversationMessage message;

  @override
  String get id => message.id;

  @override
  DateTime get occurredAt => message.createdAt;

  // -------

  /// Creates a [ChatMessageItem] from an existing [ConversationMessage].
  factory ChatMessageItem.fromConversationMessage(ConversationMessage message) {
    return ChatMessageItem(message: message);
  }
}

// -------

/// A chat item representing a tool invocation by the agent.
///
/// Rendered as a one-shot event showing the tool name and optional input.
/// No tool_result correlation is available from the sidecar bridge.
///
/// ## Usage
/// ```dart
/// final item = ChatToolUseItem(
///   id: 'evt_123',
///   occurredAt: DateTime.now().toUtc(),
///   toolName: 'Read',
///   input: {'file_path': '/tmp/test.dart'},
/// );
/// ```
final class ChatToolUseItem extends ChatItem {
  /// Creates a [ChatToolUseItem] with the given [toolName] and optional [input].
  ChatToolUseItem({
    required this.id,
    required this.occurredAt,
    required this.toolName,
    this.input,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// The name of the tool being invoked (e.g. `'Read'`, `'Bash'`, `'Edit'`).
  final String toolName;

  /// The input payload passed to the tool. May be null when input is not provided.
  final dynamic input;
}

// -------

/// A chat item representing an extended thinking block from the agent.
///
/// [content] is null when the thinking content is redacted or not provided
/// (the UI should hide the expand chevron in that case). [durationMs] is null
/// when the thinking duration is unknown.
///
/// ## Usage
/// ```dart
/// final item = ChatThinkingItem(
///   id: 'evt_456',
///   occurredAt: DateTime.now().toUtc(),
///   content: 'Analyzing the codebase structure...',
///   durationMs: 2400,
/// );
/// ```
final class ChatThinkingItem extends ChatItem {
  /// Creates a [ChatThinkingItem] with optional [content] and [durationMs].
  ChatThinkingItem({
    required this.id,
    required this.occurredAt,
    this.content,
    this.durationMs,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// The thinking text content. Null when not provided or redacted.
  final String? content;

  /// Duration of the thinking block in milliseconds. Null when unknown.
  final int? durationMs;
}

// -------

/// A chat item representing a sub-agent lifecycle event.
///
/// Created on `subagent_start` with [isComplete] `false`, then updated or
/// replaced on `subagent_stop` with [isComplete] `true`, populated
/// [toolUseCount], and [durationMs].
///
/// ## Usage
/// ```dart
/// final started = ChatSubagentItem(
///   id: 'evt_789',
///   occurredAt: DateTime.now().toUtc(),
///   subagentId: 'sub-uuid-1',
///   description: 'Researching architecture',
///   isComplete: false,
///   toolUseCount: 0,
/// );
/// ```
final class ChatSubagentItem extends ChatItem {
  /// Creates a [ChatSubagentItem] with the given sub-agent lifecycle fields.
  ChatSubagentItem({
    required this.id,
    required this.occurredAt,
    required this.subagentId,
    required this.isComplete,
    required this.toolUseCount,
    this.description,
    this.durationMs,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// The unique identifier of the sub-agent.
  final String subagentId;

  /// A human-readable description of what the sub-agent is doing.
  final String? description;

  /// Whether the sub-agent has completed its work.
  final bool isComplete;

  /// The number of tool invocations performed by the sub-agent.
  final int toolUseCount;

  /// Wall-clock duration of the sub-agent's execution in milliseconds.
  /// Populated on the stop event; null on the start event.
  final int? durationMs;
}

// -------

/// A chat item representing a file change detected during the session.
///
/// [operation] uses Git-style single-letter codes: `'A'` (added),
/// `'M'` (modified), `'D'` (deleted).
///
/// ## Usage
/// ```dart
/// final item = ChatFileChangeItem(
///   id: 'evt_300',
///   occurredAt: DateTime.now().toUtc(),
///   operation: 'M',
///   filePath: 'lib/app/models/task.dart',
/// );
/// ```
final class ChatFileChangeItem extends ChatItem {
  /// Creates a [ChatFileChangeItem] with the given [operation] and [filePath].
  ChatFileChangeItem({
    required this.id,
    required this.occurredAt,
    required this.operation,
    required this.filePath,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// The type of file operation: `'A'` (added), `'M'` (modified), `'D'` (deleted).
  final String operation;

  /// The relative file path affected by the change.
  final String filePath;
}

// -------

/// A chat item representing an error emitted by the sidecar bridge.
///
/// ## Usage
/// ```dart
/// final item = ChatErrorItem(
///   id: 'evt_400',
///   occurredAt: DateTime.now().toUtc(),
///   errorText: 'Rate limit exceeded',
/// );
/// ```
final class ChatErrorItem extends ChatItem {
  /// Creates a [ChatErrorItem] with the given [errorText].
  ChatErrorItem({
    required this.id,
    required this.occurredAt,
    required this.errorText,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// The error message text.
  final String errorText;
}

// -------

/// A chat item representing a final result event from the agent.
///
/// [isError] indicates whether the result represents a failure.
/// [content] may be null when no result text is provided.
///
/// ## Usage
/// ```dart
/// final item = ChatResultItem(
///   id: 'evt_500',
///   occurredAt: DateTime.now().toUtc(),
///   isError: false,
///   content: 'Task completed successfully.',
/// );
/// ```
final class ChatResultItem extends ChatItem {
  /// Creates a [ChatResultItem] with the given [isError] flag and optional [content].
  ChatResultItem({
    required this.id,
    required this.occurredAt,
    required this.isError,
    this.content,
  });

  @override
  final String id;

  @override
  final DateTime occurredAt;

  /// Whether this result represents an error outcome.
  final bool isError;

  /// The result text content. Null when no content is provided.
  final String? content;
}
