import 'dart:convert';

/// A parsed WebSocket event received over the Pusher protocol.
///
/// Reverb (and Pusher-compatible servers) wrap payloads as:
/// ```json
/// {"event":"App\\Events\\Foo","channel":"private-x","data":"{\"key\":\"val\"}"}
/// ```
/// The `data` field is a JSON-encoded string that must be decoded separately.
///
/// ## Usage
/// ```dart
/// final raw = jsonDecode(message) as Map<String, dynamic>;
/// final event = WebSocketEvent.fromPusherPayload(raw);
/// Log.debug('Received ${event.eventName} on ${event.channel}');
/// ```
class WebSocketEvent {
  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [WebSocketEvent] with all required fields.
  const WebSocketEvent({
    required this.id,
    required this.channel,
    required this.eventName,
    required this.data,
    required this.receivedAt,
  });

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  /// Composite identifier: `'$channel:$eventName:${data.hashCode}'`.
  ///
  /// Pusher protocol messages carry no native message ID, so this hash
  /// provides a stable, deterministic key for deduplication within a session.
  final String id;

  /// The Pusher channel this event was broadcast on (e.g. `private-project.1`).
  final String channel;

  /// The fully-qualified event class name (e.g. `App\Events\TaskUpdated`).
  final String eventName;

  /// Decoded event payload. Pusher wraps this as a JSON-encoded string;
  /// [fromPusherPayload] decodes it automatically.
  final Map<String, dynamic> data;

  /// UTC timestamp set at the moment this event was received locally.
  final DateTime receivedAt;

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  /// Parses a raw Pusher protocol envelope into a [WebSocketEvent].
  ///
  /// Expects the envelope shape:
  /// ```json
  /// {
  ///   "event": "App\\Events\\Foo",
  ///   "channel": "private-x",
  ///   "data": "{\"key\":\"val\"}"
  /// }
  /// ```
  ///
  /// The `data` value is decoded from its JSON-encoded string form.
  factory WebSocketEvent.fromPusherPayload(Map<String, dynamic> json) {
    final channel = json['channel'] as String;
    final eventName = json['event'] as String;
    final rawData = json['data'] as String;
    final data = jsonDecode(rawData) as Map<String, dynamic>;

    return WebSocketEvent(
      id: '$channel:$eventName:${data.hashCode}',
      channel: channel,
      eventName: eventName,
      data: data,
      receivedAt: DateTime.now(),
    );
  }
}
