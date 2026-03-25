import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/services/websocket_service.dart';

// ---------------------------------------------------------------------------
// Fake WebSocket infrastructure
// ---------------------------------------------------------------------------

/// Minimal fake implementing [WebSocketChannel] for unit tests.
///
/// Uses [Fake] (via `noSuchMethod`) to avoid implementing unused
/// [StreamChannelMixin] members. Only `stream`, `sink`, and `ready` are wired.
class FakeWebSocketChannel extends Fake implements WebSocketChannel {
  FakeWebSocketChannel() : _readyCompleter = Completer<void>() {
    _readyCompleter.complete();
  }

  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final List<dynamic> sentMessages = [];
  bool closeCalled = false;

  final Completer<void> _readyCompleter;

  /// Push a raw string frame from the "server" side.
  void addServerMessage(String message) => _incoming.add(message);

  /// Simulate the server closing the connection.
  void closeFromServer() => _incoming.close();

  // -- WebSocketChannel interface -------------------------------------------

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  void dispose() {
    _incoming.close();
  }
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);
  final FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel.sentMessages.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    _channel.closeCalled = true;
  }

  @override
  Future get done => Future.value();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WebSocketService', () {
    late FakeWebSocketChannel fakeChannel;
    late WebSocketService service;

    setUp(() {
      fakeChannel = FakeWebSocketChannel();
      service = WebSocketService(
        channelFactory: (_) => fakeChannel,
        configProvider: (String key, [dynamic defaultValue]) {
          final config = <String, dynamic>{
            'websocket.url': 'ws://localhost:8080',
            'websocket.app_key': 'test-key',
            'websocket.auth_endpoint': '/broadcasting/auth',
            'websocket.reconnect_max_delay_seconds': 30,
          };
          return config[key] ?? defaultValue;
        },
      );
    });

    tearDown(() {
      service.disconnect();
      fakeChannel.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. Connection lifecycle
    // -----------------------------------------------------------------------

    test('connect sets isConnected after connection_established', () async {
      expect(service.isConnected, isFalse);

      final connectFuture = service.connect();

      // Simulate Pusher connection_established response.
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );

      await connectFuture;

      expect(service.isConnected, isTrue);
      expect(service.socketId, equals('12345.67890'));
    });

    test('disconnect clears connection state and subscriptions', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      service.subscribe('test-channel', (_) {});
      expect(service.isConnected, isTrue);

      service.disconnect();

      expect(service.isConnected, isFalse);
      expect(service.socketId, isNull);
    });

    // -----------------------------------------------------------------------
    // 2. Event deduplication — duplicate event ID dropped
    // -----------------------------------------------------------------------

    test('duplicate event ID is dropped and not dispatched twice', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      final received = <WebSocketEvent>[];
      service.subscribe('project.1', received.add);

      final payload = jsonEncode({
        'event': 'App\\Events\\TaskUpdated',
        'channel': 'project.1',
        'data': jsonEncode({'task_id': 'uuid-1', 'status': 'done'}),
      });

      // Send the same payload twice — same data produces same composite ID.
      fakeChannel.addServerMessage(payload);
      await Future<void>.delayed(Duration.zero);

      fakeChannel.addServerMessage(payload);
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 3. Ring buffer eviction — 101st unique ID evicts 1st
    // -----------------------------------------------------------------------

    test('ring buffer evicts oldest ID after 100 entries', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      final received = <WebSocketEvent>[];
      service.subscribe('ch', received.add);

      // Send 101 unique events to fill and overflow the ring buffer.
      for (var i = 0; i < 101; i++) {
        fakeChannel.addServerMessage(
          jsonEncode({
            'event': 'evt',
            'channel': 'ch',
            'data': jsonEncode({'i': i}),
          }),
        );
        await Future<void>.delayed(Duration.zero);
      }

      // All 101 unique events should have been dispatched.
      expect(received.length, equals(101));

      // Now resend the very first event — its ID was evicted from the buffer,
      // so it should be dispatched again.
      received.clear();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'evt',
          'channel': 'ch',
          'data': jsonEncode({'i': 0}),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 4. Subscribe adds to active channels map
    // -----------------------------------------------------------------------

    test('subscribe adds channel to active subscriptions', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      service.subscribe('public-channel', (_) {});

      expect(service.activeChannels, contains('public-channel'));

      // Verify pusher:subscribe was sent.
      final subscribeMsgs = fakeChannel.sentMessages
          .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
          .where((m) => m['event'] == 'pusher:subscribe')
          .toList();
      expect(subscribeMsgs, isNotEmpty);
      expect(subscribeMsgs.last['data']['channel'], equals('public-channel'));
    });

    // -----------------------------------------------------------------------
    // 5. Unsubscribe removes from active channels map
    // -----------------------------------------------------------------------

    test('unsubscribe removes channel from active subscriptions', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      service.subscribe('test-channel', (_) {});
      expect(service.activeChannels, contains('test-channel'));

      service.unsubscribe('test-channel');

      expect(service.activeChannels, isNot(contains('test-channel')));

      // Verify pusher:unsubscribe was sent.
      final unsubMsgs = fakeChannel.sentMessages
          .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
          .where((m) => m['event'] == 'pusher:unsubscribe')
          .toList();
      expect(unsubMsgs, isNotEmpty);
      expect(unsubMsgs.last['data']['channel'], equals('test-channel'));
    });

    // -----------------------------------------------------------------------
    // 6. backoffDelay pure method
    // -----------------------------------------------------------------------

    test('backoffDelay returns exponential backoff capped at max', () {
      expect(service.backoffDelay(0), equals(const Duration(seconds: 1)));
      expect(service.backoffDelay(1), equals(const Duration(seconds: 2)));
      expect(service.backoffDelay(2), equals(const Duration(seconds: 4)));
      expect(service.backoffDelay(3), equals(const Duration(seconds: 8)));
      expect(service.backoffDelay(5), equals(const Duration(seconds: 30)));
      expect(service.backoffDelay(10), equals(const Duration(seconds: 30)));
    });

    // -----------------------------------------------------------------------
    // 7. Pusher payload parsing dispatches correct WebSocketEvent
    // -----------------------------------------------------------------------

    test(
      'application event is parsed and dispatched to channel listener',
      () async {
        final connectFuture = service.connect();
        fakeChannel.addServerMessage(
          jsonEncode({
            'event': 'pusher:connection_established',
            'data': jsonEncode({'socket_id': '12345.67890'}),
          }),
        );
        await connectFuture;

        final received = <WebSocketEvent>[];
        service.subscribe('project.abc', received.add);

        fakeChannel.addServerMessage(
          jsonEncode({
            'event': 'App\\Events\\TaskCreated',
            'channel': 'project.abc',
            'data': jsonEncode({'task_id': 'task-1', 'title': 'Build feature'}),
          }),
        );
        await Future<void>.delayed(Duration.zero);

        expect(received.length, equals(1));
        expect(received.first.eventName, equals('App\\Events\\TaskCreated'));
        expect(received.first.channel, equals('project.abc'));
        expect(received.first.data['task_id'], equals('task-1'));
      },
    );

    // -----------------------------------------------------------------------
    // 8. Pusher ping/pong protocol
    // -----------------------------------------------------------------------

    test('responds to pusher:ping with pusher:pong', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      fakeChannel.addServerMessage(jsonEncode({'event': 'pusher:ping'}));
      await Future<void>.delayed(Duration.zero);

      final pongMsgs = fakeChannel.sentMessages
          .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
          .where((m) => m['event'] == 'pusher:pong')
          .toList();
      expect(pongMsgs, isNotEmpty);
    });

    // -----------------------------------------------------------------------
    // 9. Events on unsubscribed channels are not dispatched
    // -----------------------------------------------------------------------

    test('events on unsubscribed channels are silently ignored', () async {
      final connectFuture = service.connect();
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'pusher:connection_established',
          'data': jsonEncode({'socket_id': '12345.67890'}),
        }),
      );
      await connectFuture;

      final received = <WebSocketEvent>[];
      service.subscribe('channel-a', received.add);

      // Event arrives on a different channel.
      fakeChannel.addServerMessage(
        jsonEncode({
          'event': 'App\\Events\\Foo',
          'channel': 'channel-b',
          'data': jsonEncode({'x': 1}),
        }),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 10. Stream close before handshake completes the future with error
    // -----------------------------------------------------------------------

    test('stream close before handshake errors the connect future', () async {
      final connectFuture = service.connect();

      // Server closes before sending connection_established.
      fakeChannel.closeFromServer();

      expect(connectFuture, throwsStateError);
    });
  });
}
