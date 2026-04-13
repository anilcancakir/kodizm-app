import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/realtime/realtime_channel_manager.dart';
import 'package:app/app/state/task_state.dart';

// ---------------------------------------------------------------------------
// Controllable broadcast channel for testing
// ---------------------------------------------------------------------------

/// A [BroadcastChannel] whose [events] stream is backed by a controllable
/// [StreamController]. Allows tests to emit [BroadcastEvent] objects directly.
class _ControllableBroadcastChannel implements BroadcastChannel {
  _ControllableBroadcastChannel(this._name);

  final String _name;

  final StreamController<BroadcastEvent> _controller =
      StreamController<BroadcastEvent>.broadcast();

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

  /// Emit a [BroadcastEvent] on this channel.
  void emit(BroadcastEvent event) => _controller.add(event);

  /// Close the underlying stream controller.
  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Test broadcast driver with controllable private channels
// ---------------------------------------------------------------------------

/// A [FakeBroadcastDriver] that returns controllable channels from [private]
/// and exposes a controllable [onReconnect] stream.
class _TestBroadcastDriver extends FakeBroadcastDriver {
  final Map<String, _ControllableBroadcastChannel> _privateChannels = {};

  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnect => _reconnectController.stream;

  @override
  BroadcastChannel private(String name) {
    final channelName = 'private-$name';
    super.private(name); // record the subscription
    return _privateChannels.putIfAbsent(
      channelName,
      () => _ControllableBroadcastChannel(channelName),
    );
  }

  /// Retrieve (or lazily create) a controllable channel for [name].
  ///
  /// [name] is the channel name WITHOUT the `private-` prefix, matching what
  /// is passed to [Echo.private].
  _ControllableBroadcastChannel channelFor(String name) {
    final channelName = 'private-$name';
    return _privateChannels.putIfAbsent(
      channelName,
      () => _ControllableBroadcastChannel(channelName),
    );
  }

  @override
  void leave(String name) {
    // Attempt both the bare name and the private-prefixed name so that callers
    // using Echo.leave('project.X') correctly remove 'private-project.X'.
    super.leave(name);
    super.leave('private-$name');
  }

  /// Trigger a simulated reconnect event.
  void triggerReconnect() => _reconnectController.add(null);

  /// Assert that [channel] is currently in the subscribed channels list.
  void assertSubscribed(String channel) {
    if (!subscribedChannels.contains(channel)) {
      throw AssertionError(
        'Expected "$channel" to be subscribed. Subscribed: $subscribedChannels',
      );
    }
  }

  /// Assert that [channel] is NOT in the subscribed channels list.
  void assertNotSubscribed(String channel) {
    if (subscribedChannels.contains(channel)) {
      throw AssertionError('Expected "$channel" to not be subscribed.');
    }
  }

  /// Dispose all controllable channels and the reconnect controller.
  void disposeAll() {
    for (final ch in _privateChannels.values) {
      ch.dispose();
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
// Helpers
// ---------------------------------------------------------------------------

BroadcastEvent _taskStatusChangedEvent(String projectId) => BroadcastEvent(
  channel: 'private-project.$projectId',
  event: '.task.status.changed',
  data: {'project_id': projectId},
  receivedAt: DateTime.now(),
);

BroadcastEvent _otherEvent(String projectId) => BroadcastEvent(
  channel: 'private-project.$projectId',
  event: '.other.event',
  data: {},
  receivedAt: DateTime.now(),
);

BroadcastEvent _conversationStatusEvent(String projectId) => BroadcastEvent(
  channel: 'private-project.$projectId',
  event: '.conversation.status',
  data: {'project_id': projectId},
  receivedAt: DateTime.now(),
);

BroadcastEvent _pipelineStageWaitingEvent(String projectId) => BroadcastEvent(
  channel: 'private-project.$projectId',
  event: '.pipeline.stage.waiting',
  data: {'project_id': projectId},
  receivedAt: DateTime.now(),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late _TestBroadcastDriver driver;
  late _TestBroadcastManager broadcastManager;
  late RealtimeChannelManager channelManager;
  late TaskState state;

  setUp(() {
    driver = _TestBroadcastDriver();
    broadcastManager = _TestBroadcastManager(driver);
    channelManager = RealtimeChannelManager(broadcaster: broadcastManager);
    Magic.app.setInstance('log', FakeLogManager());
    state = TaskState(manager: channelManager);

    // Default HTTP stub so fetchTasks inside event handlers does not throw.
    Http.fake(
      (MagicRequest req) => MagicResponse(
        data: {'data': <Map<String, dynamic>>[]},
        statusCode: 200,
      ),
    );
  });

  tearDown(() {
    state.unsubscribeFromProjectEvents();
    state.unsubscribePipelineEvents();
    state.dispose();
    channelManager.dispose();
    driver.disposeAll();
    Magic.app.removeInstance('log');
    Http.unfake();
  });

  group('TaskState.subscribeToProjectEvents', () {
    // -----------------------------------------------------------------------
    // 1. subscribe registers a private channel subscription
    // -----------------------------------------------------------------------

    test('subscribes to private project channel on Echo', () {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');

      driver.assertSubscribed('private-project.proj-uuid-001');
    });

    // -----------------------------------------------------------------------
    // 2. .task.status.changed event triggers fetchTasks
    // -----------------------------------------------------------------------

    test(
      '.task.status.changed event triggers fetchTasks for the project',
      () async {
        state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');

        Http.unfake();
        int fetchCount = 0;
        Http.fake((MagicRequest req) {
          if (req.url.contains('/tasks')) fetchCount++;
          return MagicResponse(
            data: {'data': <Map<String, dynamic>>[]},
            statusCode: 200,
          );
        });

        final channel = driver.channelFor('project.proj-uuid-001');
        channel.emit(_taskStatusChangedEvent('proj-uuid-001'));

        // Allow the async listener to process.
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, greaterThan(0));
      },
    );

    // -----------------------------------------------------------------------
    // 3. unrelated events do NOT trigger fetchTasks
    // -----------------------------------------------------------------------

    test('unrelated event does not trigger fetchTasks', () async {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');

      Http.unfake();
      int fetchCount = 0;
      Http.fake((MagicRequest req) {
        if (req.url.contains('/tasks')) fetchCount++;
        return MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        );
      });

      final channel = driver.channelFor('project.proj-uuid-001');
      channel.emit(_otherEvent('proj-uuid-001'));

      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, equals(0));
    });

    // -----------------------------------------------------------------------
    // 4. reconnect triggers fetchTasks
    // -----------------------------------------------------------------------

    test('reconnect event triggers fetchTasks for the project', () async {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');

      Http.unfake();
      int fetchCount = 0;
      Http.fake((MagicRequest req) {
        if (req.url.contains('/tasks')) fetchCount++;
        return MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        );
      });

      driver.triggerReconnect();

      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, greaterThan(0));
    });

    // -----------------------------------------------------------------------
    // 5. re-subscribe cleans up previous subscription before creating new one
    // -----------------------------------------------------------------------

    test('re-subscribing to a different project leaves the old channel', () {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');
      driver.assertSubscribed('private-project.proj-uuid-001');

      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-002');

      // Old channel should have been left.
      driver.assertNotSubscribed('private-project.proj-uuid-001');
      // New channel should be subscribed.
      driver.assertSubscribed('private-project.proj-uuid-002');
    });
  });

  group('TaskState.unsubscribeFromProjectEvents', () {
    // -----------------------------------------------------------------------
    // 6. unsubscribe leaves the Echo channel
    // -----------------------------------------------------------------------

    test('leaves the Echo channel on unsubscribe', () {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');
      driver.assertSubscribed('private-project.proj-uuid-001');

      state.unsubscribeFromProjectEvents();

      driver.assertNotSubscribed('private-project.proj-uuid-001');
    });

    // -----------------------------------------------------------------------
    // 7. events after unsubscribe do NOT trigger fetchTasks
    // -----------------------------------------------------------------------

    test('events after unsubscribe do not trigger fetchTasks', () async {
      state.subscribeToProjectEvents('team-uuid-001', 'proj-uuid-001');

      final channel = driver.channelFor('project.proj-uuid-001');

      state.unsubscribeFromProjectEvents();

      Http.unfake();
      int fetchCount = 0;
      Http.fake((MagicRequest req) {
        if (req.url.contains('/tasks')) fetchCount++;
        return MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        );
      });

      channel.emit(_taskStatusChangedEvent('proj-uuid-001'));

      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, equals(0));
    });

    // -----------------------------------------------------------------------
    // 8. unsubscribe without prior subscribe is a no-op
    // -----------------------------------------------------------------------

    test('calling unsubscribe without prior subscribe does not throw', () {
      expect(() => state.unsubscribeFromProjectEvents(), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // Pipeline subscription: .conversation.status on project channel
  // -------------------------------------------------------------------------

  group('TaskState.subscribeToPipelineEvents — conversation status', () {
    test('.conversation.status event triggers fetchConversations', () async {
      state.subscribeToPipelineEvents(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      Http.unfake();
      int conversationFetchCount = 0;
      Http.fake((MagicRequest req) {
        if (req.url.contains('/conversations')) conversationFetchCount++;
        return MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        );
      });

      final channel = driver.channelFor('project.proj-uuid-001');
      channel.emit(_conversationStatusEvent('proj-uuid-001'));

      await Future<void>.delayed(Duration.zero);

      expect(conversationFetchCount, greaterThan(0));
    });

    test(
      '.pipeline.stage.waiting event still triggers fetchTask (regression)',
      () async {
        state.subscribeToPipelineEvents(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
        );

        Http.unfake();
        int taskFetchCount = 0;
        Http.fake((MagicRequest req) {
          if (req.url.contains('/tasks/task-uuid-001') &&
              !req.url.contains('/conversations')) {
            taskFetchCount++;
          }
          return MagicResponse(
            data: {'data': <String, dynamic>{}},
            statusCode: 200,
          );
        });

        final channel = driver.channelFor('project.proj-uuid-001');
        channel.emit(_pipelineStageWaitingEvent('proj-uuid-001'));

        await Future<void>.delayed(Duration.zero);

        expect(taskFetchCount, greaterThan(0));
      },
    );
  });
}
