/// A single streaming event emitted during a task run execution.
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
    required this.taskRunId,
    required this.type,
    required this.data,
    required this.isQuestion,
    required this.occurredAt,
    this.contentText,
    this.filePath,
  });

  // -------

  /// The unique identifier of this event (UUID).
  final String id;

  /// The identifier of the parent task run (UUID).
  final String taskRunId;

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

  // -------

  /// Parses a [StreamEvent] from a JSON-decoded map.
  factory StreamEvent.fromMap(Map<String, dynamic> map) {
    return StreamEvent(
      id: map['id'] as String,
      taskRunId: map['task_run_id'] as String,
      type: map['type'] as String,
      data: map['data'] as Map<String, dynamic>,
      contentText: map['content_text'] as String?,
      filePath: map['file_path'] as String?,
      isQuestion: map['is_question'] as bool,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
    );
  }
}
