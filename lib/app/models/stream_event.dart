/// A single streaming event emitted during a session execution.
///
/// Maps directly to `StreamEventResource` from the Kodizm API.
/// Events are received over WebSocket and represent real-time agent output.
///
/// ## Usage
/// ```dart
/// final event = StreamEvent.fromMap(wsPayload);
/// if (event.type == 'assistant_delta') {
///   buffer.write(event.contentText ?? '');
/// }
/// ```
class StreamEvent {
  // -------

  /// Creates a [StreamEvent] with all fields.
  const StreamEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.data,
    required this.isQuestion,
    required this.occurredAt,
    this.contentText,
    this.filePath,
    this.subagentId,
    this.parentEventId,
    this.model,
    this.turnNumber,
    this.metadata,
  });

  // -------

  /// The unique identifier of this event (UUID).
  final String id;

  /// The identifier of the parent session (UUID).
  final String sessionId;

  /// The event type string (e.g. `'system'`, `'assistant_delta'`, `'tool_result'`).
  /// Preserved as-is from the API — no transformation applied.
  final String type;

  /// Arbitrary metadata payload accompanying this event.
  final Map<String, dynamic> data;

  /// Optional text content for delta/message events. Null for non-text events.
  final String? contentText;

  /// Optional file path associated with this event. Null when not applicable.
  final String? filePath;

  /// Whether this event represents an agent question requiring user input.
  final bool isQuestion;

  /// UTC timestamp when the event occurred on the server.
  final DateTime occurredAt;

  final String? subagentId;
  final String? parentEventId;
  final String? model;
  final int? turnNumber;
  final Map<String, dynamic>? metadata;

  // -------

  /// Parses a [StreamEvent] from a JSON-decoded map.
  factory StreamEvent.fromMap(Map<String, dynamic> map) {
    return StreamEvent(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      type: map['type'] as String,
      data: map['data'] as Map<String, dynamic>,
      contentText: map['content_text'] as String?,
      filePath: map['file_path'] as String?,
      isQuestion: map['is_question'] as bool,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      subagentId: map['subagent_id'] as String?,
      parentEventId: map['parent_event_id'] as String?,
      model: map['model'] as String?,
      turnNumber: map['turn_number'] as int?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
