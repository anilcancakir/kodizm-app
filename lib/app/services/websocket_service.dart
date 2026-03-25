import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:magic/magic.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../events/websocket_event.dart';

/// Pusher-compatible WebSocket client for Laravel Reverb.
///
/// Manages a single WebSocket connection, channel subscriptions, event
/// deduplication, and auto-reconnect with exponential backoff.
///
/// ## Usage
/// ```dart
/// final ws = App.make<WebSocketService>('websocket');
/// await ws.connect();
/// ws.subscribe('private-project.abc', (event) {
///   Log.debug('Got ${event.eventName}: ${event.data}');
/// });
/// ```
class WebSocketService {
  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [WebSocketService].
  ///
  /// [channelFactory] overrides WebSocket connection creation for testing.
  /// [configProvider] overrides `Config.get` resolution for testing.
  WebSocketService({
    WebSocketChannel Function(Uri uri)? channelFactory,
    dynamic Function(String key, [dynamic defaultValue])? configProvider,
  }) : _channelFactory = channelFactory ?? _defaultChannelFactory,
       _configProvider = configProvider ?? _defaultConfigProvider;

  static WebSocketChannel _defaultChannelFactory(Uri uri) =>
      WebSocketChannel.connect(uri);

  static dynamic _defaultConfigProvider(String key, [dynamic defaultValue]) =>
      Config.get(key, defaultValue);

  // ---------------------------------------------------------------------------
  // Dependencies
  // ---------------------------------------------------------------------------

  final WebSocketChannel Function(Uri uri) _channelFactory;
  final dynamic Function(String key, [dynamic defaultValue]) _configProvider;

  // ---------------------------------------------------------------------------
  // Connection state
  // ---------------------------------------------------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _streamSubscription;
  bool _isConnected = false;
  String? _socketId;
  Completer<void>? _connectionCompleter;

  /// Whether the WebSocket connection is established and ready.
  bool get isConnected => _isConnected;

  /// The Pusher socket_id received from `pusher:connection_established`.
  String? get socketId => _socketId;

  // ---------------------------------------------------------------------------
  // Channel subscriptions
  // ---------------------------------------------------------------------------

  final Map<String, Set<void Function(WebSocketEvent)>> _subscriptions = {};

  /// The set of currently subscribed channel names.
  Set<String> get activeChannels => _subscriptions.keys.toSet();

  // ---------------------------------------------------------------------------
  // Event deduplication — ring buffer
  // ---------------------------------------------------------------------------

  static const int _maxDedupSize = 100;
  final Queue<String> _dedupQueue = Queue<String>();
  final Set<String> _dedupSet = {};

  // ---------------------------------------------------------------------------
  // Reconnect state
  // ---------------------------------------------------------------------------

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// Connects to the Reverb WebSocket server.
  ///
  /// Reads `websocket.url` and `websocket.app_key` from config, opens the
  /// connection, and waits for `pusher:connection_established` before
  /// completing the returned future.
  Future<void> connect() async {
    if (_isConnected) return;

    final url = _configProvider('websocket.url') as String;
    final appKey = _configProvider('websocket.app_key') as String;
    final uri = Uri.parse('$url/app/$appKey');

    _channel = _channelFactory(uri);
    await _channel!.ready;

    _connectionCompleter = Completer<void>();

    _streamSubscription = _channel!.stream.listen(
      _onMessage,
      onDone: _onDone,
      onError: _onError,
    );

    return _connectionCompleter!.future;
  }

  /// Closes the WebSocket connection and resets all state.
  ///
  /// Cancels any pending reconnect timer and clears active subscriptions.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;

    _streamSubscription?.cancel();
    _streamSubscription = null;

    _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _socketId = null;
    _subscriptions.clear();

    _dedupQueue.clear();
    _dedupSet.clear();

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
    _connectionCompleter = null;
  }

  // ---------------------------------------------------------------------------
  // Channel management
  // ---------------------------------------------------------------------------

  /// Subscribes to [channel] and registers [onEvent] as a listener.
  ///
  /// For private channels (prefixed `private-`), authenticates via HTTP POST
  /// to the broadcasting auth endpoint before sending the Pusher subscribe
  /// frame. For public channels, sends the subscribe frame immediately.
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    _subscriptions.putIfAbsent(channel, () => {});
    _subscriptions[channel]!.add(onEvent);

    if (channel.startsWith('private-')) {
      _authenticateAndSubscribe(channel);
    } else {
      _sendSubscribe(channel);
    }
  }

  /// Unsubscribes from [channel] and removes all listeners.
  ///
  /// Sends a `pusher:unsubscribe` frame to the server.
  void unsubscribe(String channel) {
    _subscriptions.remove(channel);
    _sendUnsubscribe(channel);
  }

  // ---------------------------------------------------------------------------
  // Backoff delay (pure, testable)
  // ---------------------------------------------------------------------------

  /// Computes the reconnect delay for the given [attempt] using exponential
  /// backoff capped at the configured maximum.
  ///
  /// Formula: `min(2^attempt, maxDelay)` seconds.
  Duration backoffDelay(int attempt) {
    final maxDelay =
        _configProvider('websocket.reconnect_max_delay_seconds', 30) as int;
    final seconds = min(pow(2, attempt).toInt(), maxDelay);
    return Duration(seconds: seconds);
  }

  // ---------------------------------------------------------------------------
  // Pusher protocol handling (private)
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    final json = jsonDecode(raw as String) as Map<String, dynamic>;
    final event = json['event'] as String?;

    switch (event) {
      case 'pusher:connection_established':
        _handleConnectionEstablished(json);
      case 'pusher:ping':
        _sendPong();
      case 'pusher:subscription_succeeded':
        _handleSubscriptionSucceeded(json);
      case 'pusher:error':
        _handleError(json);
      default:
        _handleApplicationEvent(json);
    }
  }

  void _handleConnectionEstablished(Map<String, dynamic> json) {
    final data = jsonDecode(json['data'] as String) as Map<String, dynamic>;
    _socketId = data['socket_id'] as String;
    _isConnected = true;
    _reconnectAttempt = 0;

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
  }

  void _handleSubscriptionSucceeded(Map<String, dynamic> json) {
    final channel = json['channel'] as String?;
    Log.debug('WebSocket: subscription succeeded for $channel');
  }

  void _handleError(Map<String, dynamic> json) {
    final rawData = json['data'];
    Log.error('WebSocket: pusher error — $rawData');

    // Pusher wraps error code inside a JSON-encoded data string.
    if (rawData is String) {
      try {
        final data = jsonDecode(rawData) as Map<String, dynamic>;
        final code = data['code'] as int?;
        if (code != null && code >= 4000) {
          _scheduleReconnect();
        }
      } catch (_) {
        // Malformed data — log already emitted above.
      }
    }
  }

  void _handleApplicationEvent(Map<String, dynamic> json) {
    final channel = json['channel'] as String?;
    if (channel == null) return;

    final listeners = _subscriptions[channel];
    if (listeners == null || listeners.isEmpty) return;

    // Build a deterministic dedup key from the raw payload strings.
    // WebSocketEvent.id uses Map.hashCode which is identity-based and
    // therefore unsuitable for cross-message deduplication.
    final eventName = json['event'] as String;
    final rawData = json['data'] as String;
    final dedupKey = '$channel:$eventName:$rawData';

    if (_dedupSet.contains(dedupKey)) return;
    _addToDedupBuffer(dedupKey);

    final event = WebSocketEvent.fromPusherPayload(json);
    for (final listener in listeners) {
      listener(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Deduplication ring buffer
  // ---------------------------------------------------------------------------

  void _addToDedupBuffer(String id) {
    _dedupQueue.add(id);
    _dedupSet.add(id);

    if (_dedupQueue.length > _maxDedupSize) {
      final evicted = _dedupQueue.removeFirst();
      _dedupSet.remove(evicted);
    }
  }

  // ---------------------------------------------------------------------------
  // Reconnect
  // ---------------------------------------------------------------------------

  void _onDone() {
    // Complete pending connection future if handshake never finished.
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(
        StateError('WebSocket closed before connection established'),
      );
      _connectionCompleter = null;
    }

    if (!_isConnected) return;
    _isConnected = false;
    _socketId = null;
    _scheduleReconnect();
  }

  void _onError(Object error) {
    Log.error('WebSocket: stream error — $error');

    // Complete pending connection future if handshake never finished.
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(error);
      _connectionCompleter = null;
    }

    // Guard: if disconnect() was called intentionally, do not reconnect.
    if (!_isConnected) return;
    _isConnected = false;
    _socketId = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = backoffDelay(_reconnectAttempt);
    _reconnectAttempt++;

    _reconnectTimer = Timer(delay, () async {
      try {
        final previousChannels = _subscriptions.keys.toList();
        _streamSubscription?.cancel();
        _channel = null;
        _isConnected = false;

        await connect();

        // Resubscribe to all previously active channels.
        for (final channel in previousChannels) {
          if (channel.startsWith('private-')) {
            _authenticateAndSubscribe(channel);
          } else {
            _sendSubscribe(channel);
          }
        }
      } catch (e) {
        Log.error('WebSocket: reconnect failed — $e');
        _scheduleReconnect();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Wire protocol helpers
  // ---------------------------------------------------------------------------

  void _sendSubscribe(String channel) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channel},
    });
  }

  void _sendUnsubscribe(String channel) {
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channel},
    });
  }

  void _sendPong() {
    _send({'event': 'pusher:pong', 'data': <String, dynamic>{}});
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  // ---------------------------------------------------------------------------
  // Private channel authentication
  // ---------------------------------------------------------------------------

  Future<void> _authenticateAndSubscribe(String channel) async {
    if (_socketId == null) {
      Log.error(
        'WebSocket: cannot auth private channel $channel — not connected',
      );
      return;
    }

    try {
      final authEndpoint =
          _configProvider('websocket.auth_endpoint', '/broadcasting/auth')
              as String;

      final response = await Http.post(
        authEndpoint,
        data: {'socket_id': _socketId, 'channel_name': channel},
      );

      final authData = response.data as Map<String, dynamic>;
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channel, 'auth': authData['auth']},
      });
    } catch (e) {
      Log.error('WebSocket: auth failed for $channel — $e');
    }
  }
}
