import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/conversation_list_state.dart';

// ---------------------------------------------------------------------------
// Test broadcast infrastructure — controllable channel events
// ---------------------------------------------------------------------------

class _TestBroadcastChannel implements BroadcastChannel {
  _TestBroadcastChannel(this._name, this._controller);

  final String _name;
  final StreamController<BroadcastEvent> _controller;

  @override
  String get name => _name;

  @override
  Stream<BroadcastEvent> get events => _controller.stream;

  @override
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) => this;

  @override
  void stopListening(String event) {}
}

class _TestBroadcastDriver extends FakeBroadcastDriver {
  final Map<String, StreamController<BroadcastEvent>> _channelControllers = {};
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnect => _reconnectController.stream;

  @override
  BroadcastChannel private(String name) {
    // Call super to record 'private-$name' in FakeBroadcastDriver._subscribedChannels.
    super.private(name);
    _channelControllers.putIfAbsent(
      'private-$name',
      StreamController<BroadcastEvent>.broadcast,
    );
    return _TestBroadcastChannel(
      'private-$name',
      _channelControllers['private-$name']!,
    );
  }

  /// Override leave to remove the `private-` prefixed channel name from the
  /// parent's subscribed channels list, matching how [private] stores it.
  @override
  void leave(String name) => super.leave('private-$name');

  /// Emit a [BroadcastEvent] to all listeners on [channelName].
  ///
  /// [channelName] should be the raw name without the `private-` prefix — e.g.
  /// `'project.proj-uuid-001'`. The driver will look up the `private-` prefixed
  /// controller internally.
  void emit(String channelName, BroadcastEvent event) {
    _channelControllers['private-$channelName']?.add(event);
  }

  /// Trigger a simulated reconnect.
  void simulateReconnect() => _reconnectController.add(null);

  void dispose() {
    for (final ctrl in _channelControllers.values) {
      ctrl.close();
    }
    _reconnectController.close();
  }
}

class _TestBroadcastManager extends BroadcastManager {
  _TestBroadcastManager(this._driver);

  final _TestBroadcastDriver _driver;

  @override
  BroadcastDriver connection([String? name]) => _driver;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kTeamId = 'team-uuid-001';
const String kProjectId = 'proj-uuid-001';

const Map<String, dynamic> kConversationA = {
  'id': 'conv-uuid-001',
  'project_id': kProjectId,
  'user': {'id': 'user-uuid-001', 'name': 'Alice'},
  'agent_role': {
    'id': 'role-uuid-001',
    'name': 'Business Analyst',
    'slug': 'ba',
  },
  'title': 'Alpha conversation',
  'status': 'active',
  'model': 'claude-sonnet-4-6',
  'total_cost_usd': '0.00',
  'total_input_tokens': 0,
  'total_output_tokens': 0,
  'messages_count': 0,
  'last_activity_at': '2026-01-01T10:00:00.000Z',
  'started_at': '2026-01-01T09:55:00.000Z',
  'completed_at': null,
  'created_at': '2026-01-01T09:55:00.000Z',
  'updated_at': '2026-01-01T10:00:00.000Z',
};

BroadcastEvent _makeEvent(String eventName) => BroadcastEvent(
  event: eventName,
  channel: 'private-project.$kProjectId',
  data: const {},
  receivedAt: DateTime(2026),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late _TestBroadcastDriver driver;
  late ConversationListState state;

  setUp(() {
    driver = _TestBroadcastDriver();
    Magic.app.setInstance('broadcasting', _TestBroadcastManager(driver));
    state = ConversationListState();
  });

  tearDown(() {
    state.unsubscribeFromProjectEvents();
    state.dispose();
    driver.dispose();
    Magic.app.removeInstance('broadcasting');
    Http.unfake();
  });

  group('ConversationListState — subscription lifecycle', () {
    // -----------------------------------------------------------------------
    // subscribe registers channel
    // -----------------------------------------------------------------------

    test(
      'subscribeToProjectEvents subscribes to the private project channel',
      () async {
        Http.fake(
          (_) => MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
        );

        state.subscribeToProjectEvents(kTeamId, kProjectId);

        expect(
          driver.subscribedChannels,
          contains('private-project.$kProjectId'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // unsubscribe removes channel
    // -----------------------------------------------------------------------

    test('unsubscribeFromProjectEvents leaves the channel', () async {
      Http.fake(
        (_) => MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
      );

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      state.unsubscribeFromProjectEvents();

      expect(
        driver.subscribedChannels,
        isNot(contains('private-project.$kProjectId')),
      );
    });

    // -----------------------------------------------------------------------
    // double-subscribe replaces previous subscription (no leak)
    // -----------------------------------------------------------------------

    test(
      'calling subscribeToProjectEvents twice does not double-subscribe',
      () async {
        Http.fake(
          (_) => MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
        );

        state.subscribeToProjectEvents(kTeamId, kProjectId);
        state.subscribeToProjectEvents(kTeamId, kProjectId);

        final count = driver.subscribedChannels
            .where((ch) => ch == 'private-project.$kProjectId')
            .length;
        expect(count, equals(1));
      },
    );
  });

  group('ConversationListState — event-driven reload', () {
    // -----------------------------------------------------------------------
    // .conversation.status triggers reload
    // -----------------------------------------------------------------------

    test('.conversation.status event triggers loadConversations', () async {
      int loadCount = 0;

      Http.fake((_) {
        loadCount++;
        return MagicResponse(
          data: {
            'data': [kConversationA],
          },
          statusCode: 200,
        );
      });

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      final loadsBefore = loadCount;

      driver.emit('project.$kProjectId', _makeEvent('.conversation.status'));
      // Allow async listener to run.
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, greaterThan(loadsBefore));
    });

    // -----------------------------------------------------------------------
    // .conversation.title triggers reload
    // -----------------------------------------------------------------------

    test('.conversation.title event triggers loadConversations', () async {
      int loadCount = 0;

      Http.fake((_) {
        loadCount++;
        return MagicResponse(
          data: {
            'data': [kConversationA],
          },
          statusCode: 200,
        );
      });

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      final loadsBefore = loadCount;

      driver.emit('project.$kProjectId', _makeEvent('.conversation.title'));
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, greaterThan(loadsBefore));
    });

    // -----------------------------------------------------------------------
    // unrelated event does NOT trigger reload
    // -----------------------------------------------------------------------

    test('unrelated event does not trigger loadConversations', () async {
      int loadCount = 0;

      Http.fake((_) {
        loadCount++;
        return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
      });

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      final loadsBefore = loadCount;

      driver.emit('project.$kProjectId', _makeEvent('.other.event'));
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, equals(loadsBefore));
    });

    // -----------------------------------------------------------------------
    // reconnect triggers reload
    // -----------------------------------------------------------------------

    test('reconnect triggers loadConversations', () async {
      int loadCount = 0;

      Http.fake((_) {
        loadCount++;
        return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
      });

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      final loadsBefore = loadCount;

      driver.simulateReconnect();
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, greaterThan(loadsBefore));
    });

    // -----------------------------------------------------------------------
    // no reload after unsubscribe
    // -----------------------------------------------------------------------

    test('events after unsubscribe do not trigger loadConversations', () async {
      int loadCount = 0;

      Http.fake((_) {
        loadCount++;
        return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
      });

      state.subscribeToProjectEvents(kTeamId, kProjectId);
      state.unsubscribeFromProjectEvents();
      final loadsBefore = loadCount;

      driver.emit('project.$kProjectId', _makeEvent('.conversation.status'));
      await Future<void>.delayed(Duration.zero);

      expect(loadCount, equals(loadsBefore));
    });
  });
}
