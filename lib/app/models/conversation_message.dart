import 'package:app/app/models/message_attachment.dart';

/// A single message within a conversation between a user and an agent.
///
/// Maps directly to `ConversationMessageResource` from the Kodizm API.
/// Covers both user-authored messages (`role: 'user'`) and agent responses
/// (`role: 'assistant'`), including cost, token usage, and timing metadata.
/// Attachment-only messages may have a `null` [content] field.
///
/// ## Usage
/// ```dart
/// final message = ConversationMessage.fromMap(json['message']);
/// if (message.role == 'assistant') {
///   display(message.content);
/// }
/// if (message.hasAttachments) {
///   renderAttachments(message.attachments);
/// }
/// ```
class ConversationMessage {
  // -------

  /// Creates a [ConversationMessage] with all fields.
  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.createdAt,
    this.content,
    this.metadata,
    this.streamEvents,
    this.costUsd,
    this.usage,
    this.durationMs,
    this.numTurns,
    this.error,
    this.status,
    this.startedAt,
    this.completedAt,
    this.attachments = const [],
  });

  // -------

  /// The unique identifier of this message (UUID).
  final String id;

  /// The identifier of the parent conversation (UUID).
  final String conversationId;

  /// The role of the message author (e.g. `'user'`, `'assistant'`).
  final String role;

  /// The text content of the message.
  ///
  /// Nullable — attachment-only messages may carry no text content.
  final String? content;

  /// Arbitrary metadata payload for this message. Null for most messages.
  final Map<String, dynamic>? metadata;

  /// Stream events (tool_use, thinking, etc.) captured during this turn.
  final List<dynamic>? streamEvents;

  /// Cost of this message in USD. Null for user messages or unprocessed messages.
  /// Parsed from the API string representation.
  final double? costUsd;

  /// Raw token usage breakdown from the LLM provider. Null for user messages.
  final Map<String, dynamic>? usage;

  /// Wall-clock processing duration in milliseconds. Null for incomplete messages.
  final int? durationMs;

  /// Number of conversational turns for this message. Null if not computed.
  final int? numTurns;

  /// Error message if processing failed. Null on success.
  final String? error;

  /// Status of the message (e.g. 'queued', 'processing', 'completed', 'failed'). Null if not set.
  final String? status;

  /// UTC timestamp when message processing started. Null for user messages.
  final DateTime? startedAt;

  /// UTC timestamp when message processing completed. Null if still in progress.
  final DateTime? completedAt;

  /// UTC timestamp when this message record was created.
  final DateTime createdAt;

  /// Files attached to this message.
  ///
  /// Defaults to an empty list when the API returns no attachments.
  final List<MessageAttachment> attachments;

  // -------

  /// Returns `true` when this message has one or more [attachments].
  bool get hasAttachments => attachments.isNotEmpty;

  // -------

  /// Parses a [ConversationMessage] from a JSON-decoded map.
  ///
  /// [costUsd] is parsed from an API string value when present.
  /// [content] is nullable — messages with only attachments may omit it.
  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    final costString = map['cost_usd'] as String?;

    return ConversationMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      streamEvents: map['stream_events'] as List<dynamic>?,
      costUsd: costString != null ? double.parse(costString) : null,
      usage: map['usage'] as Map<String, dynamic>?,
      durationMs: map['duration_ms'] as int?,
      numTurns: map['num_turns'] as int?,
      error: map['error'] as String?,
      status: map['status'] as String?,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      attachments:
          (map['attachments'] as List<dynamic>?)
              ?.map((a) => MessageAttachment.fromMap(a as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  // -------

  /// Returns a copy of this [ConversationMessage] with the specified fields replaced.
  ///
  /// All fields not provided retain their current values.
  /// To explicitly set [status] to null, pass `null` — the sentinel pattern handles it.
  /// To explicitly set [content] to null, pass `null` — it will clear the content.
  ConversationMessage copyWith({
    String? role,
    Object? content = _unset,
    double? costUsd,
    Object? status = _unset,
    DateTime? completedAt,
    List<MessageAttachment>? attachments,
  }) {
    return ConversationMessage(
      id: id,
      conversationId: conversationId,
      role: role ?? this.role,
      content: identical(content, _unset) ? this.content : content as String?,
      metadata: metadata,
      costUsd: costUsd ?? this.costUsd,
      usage: usage,
      durationMs: durationMs,
      numTurns: numTurns,
      error: error,
      status: identical(status, _unset) ? this.status : status as String?,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      attachments: attachments ?? this.attachments,
    );
  }

  static const Object _unset = Object();
}
