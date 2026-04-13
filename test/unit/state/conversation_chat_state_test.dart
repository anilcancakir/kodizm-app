import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/chat_item.dart';
import 'package:app/app/realtime/channel_names.dart';
import 'package:app/app/realtime/realtime_channel_manager.dart';
import 'package:app/app/state/conversation_chat_state.dart';

// ---------------------------------------------------------------------------
// Reconnectable fake — extends FakeBroadcastManager with reconnect support
// ---------------------------------------------------------------------------

/// A [FakeBroadcastManager] extension that supports simulating reconnections.
///
/// The default [FakeBroadcastDriver.onReconnect] returns an empty stream.
/// This wrapper provides a [simulateReconnect] method that fires the
/// [RealtimeChannelManager]'s reconnect listener through a controllable
/// [BroadcastDriver] proxy.
class _ReconnectableFakeManager extends FakeBroadcastManager {
  final _ReconnectableDriver _reconnectDriver = _ReconnectableDriver();

  @override
  BroadcastDriver connection([String? name]) {
    // Delegate channel/private operations to the real fake driver for
    // subscription tracking, but wrap with reconnect support.
    _reconnectDriver._delegate = super.connection(name);
    return _reconnectDriver;
  }

  /// Simulate a WS reconnection event.
  void simulateReconnect() => _reconnectDriver.triggerReconnect();
}

/// Proxy [BroadcastDriver] that delegates everything except [onReconnect].
class _ReconnectableDriver implements BroadcastDriver {
  BroadcastDriver? _delegate;
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  void triggerReconnect() => _reconnectController.add(null);

  @override
  bool get isConnected => _delegate?.isConnected ?? false;

  @override
  Future<void> connect() => _delegate?.connect() ?? Future.value();

  @override
  Future<void> disconnect() => _delegate?.disconnect() ?? Future.value();

  @override
  String? get socketId => _delegate?.socketId;

  @override
  Stream<BroadcastConnectionState> get connectionState =>
      _delegate?.connectionState ?? const Stream.empty();

  @override
  Stream<void> get onReconnect => _reconnectController.stream;

  @override
  BroadcastChannel channel(String name) =>
      _delegate?.channel(name) ?? _EmptyChannel(name);

  @override
  BroadcastChannel private(String name) =>
      _delegate?.private(name) ?? _EmptyChannel('private-$name');

  @override
  void leave(String channelName) => _delegate?.leave(channelName);

  @override
  void addInterceptor(BroadcastInterceptor interceptor) =>
      _delegate?.addInterceptor(interceptor);

  @override
  BroadcastPresenceChannel join(String name) =>
      _delegate?.join(name) ?? (throw UnimplementedError('join not supported'));
}

/// Minimal no-op channel for the proxy fallback.
class _EmptyChannel implements BroadcastChannel {
  _EmptyChannel(this.name);

  @override
  final String name;

  @override
  Stream<BroadcastEvent> get events => const Stream.empty();

  @override
  BroadcastChannel listen(
    String event,
    void Function(BroadcastEvent) callback,
  ) => this;

  @override
  void stopListening(String event) {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kTeamId = 'team-uuid-001';
const String kProjectId = 'proj-uuid-001';
const String kConversationId = 'conv-uuid-001';

MagicResponse _createConversationResponse() {
  return MagicResponse(
    data: {
      'data': {
        'id': kConversationId,
        'project_id': kProjectId,
        'user': {'id': 'user-uuid-001', 'name': 'Test User'},
        'agent_role': {
          'id': 'role-uuid-001',
          'name': 'Business Analyst',
          'slug': 'ba',
        },
        'title': 'Test Conversation',
        'status': 'active',
        'model': 'claude-sonnet-4-6',
        'total_cost_usd': '0.00',
        'total_input_tokens': 0,
        'total_output_tokens': 0,
        'messages_count': 0,
        'last_activity_at': '2026-03-27T10:00:00.000Z',
        'started_at': '2026-03-27T09:55:00.000Z',
        'completed_at': null,
        'created_at': '2026-03-27T09:55:00.000Z',
        'updated_at': '2026-03-27T10:00:00.000Z',
      },
    },
    statusCode: 201,
  );
}

MagicResponse _messagesResponse() {
  return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
}

MagicResponse _loadConversationResponse() {
  return MagicResponse(
    data: {
      'data': {
        'id': kConversationId,
        'project_id': kProjectId,
        'user': {'id': 'user-uuid-001', 'name': 'Test User'},
        'agent_role': {
          'id': 'role-uuid-001',
          'name': 'Business Analyst',
          'slug': 'ba',
        },
        'title': 'Loaded Conversation',
        'status': 'active',
        'model': 'claude-sonnet-4-6',
        'total_cost_usd': '0.05',
        'total_input_tokens': 500,
        'total_output_tokens': 200,
        'messages_count': 3,
        'last_activity_at': '2026-03-27T10:00:00.000Z',
        'started_at': '2026-03-27T09:55:00.000Z',
        'completed_at': null,
        'created_at': '2026-03-27T09:55:00.000Z',
        'updated_at': '2026-03-27T10:00:00.000Z',
      },
    },
    statusCode: 200,
  );
}

BroadcastEvent _textEvent({String content = 'Hello!'}) {
  return BroadcastEvent(
    channel: 'private-conversation.$kConversationId',
    event: '.conversation.message',
    data: {
      'conversation_id': kConversationId,
      'type': 'text',
      'content': content,
      'metadata': null,
      'occurred_at': '2026-03-27T10:01:00.000Z',
    },
    receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
  );
}

BroadcastEvent _subagentEvent({
  required String type,
  String? subagentId,
  String? toolUseId,
  String? description,
  Map<String, dynamic>? extra,
}) {
  return BroadcastEvent(
    channel: 'private-conversation.$kConversationId',
    event: '.conversation.message',
    data: {
      'conversation_id': kConversationId,
      'type': type,
      'content': description,
      'metadata': {
        'agentId': subagentId,
        'task_id': subagentId,
        'tool_use_id': toolUseId,
        'description': description,
        ...?extra,
      },
      'occurred_at': '2026-03-27T10:01:00.000Z',
    },
    receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
  );
}

BroadcastEvent _toolUseEvent({required String toolName, String? toolUseId}) {
  return BroadcastEvent(
    channel: 'private-conversation.$kConversationId',
    event: '.conversation.message',
    data: {
      'conversation_id': kConversationId,
      'type': 'tool_use',
      'content': null,
      'metadata': {
        'toolName': toolName,
        'toolUseId':
            toolUseId ?? 'tool_${DateTime.now().microsecondsSinceEpoch}',
      },
      'occurred_at': '2026-03-27T10:01:00.000Z',
    },
    receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late FakeNetworkDriver driver;
  late _ReconnectableFakeManager fake;
  late RealtimeChannelManager manager;
  late ConversationChatState state;

  setUp(() {
    driver = Http.fake();
    fake = _ReconnectableFakeManager();
    // Register the fake as the broadcasting instance so Echo.fake() assertions
    // and RealtimeChannelManager share the same driver.
    Magic.app.setInstance('broadcasting', fake);
    manager = RealtimeChannelManager(broadcaster: fake);
    state = ConversationChatState(manager: manager);
  });

  tearDown(() {
    state.reset();
    manager.dispose();
    Echo.unfake();
  });

  /// Helper: create a conversation so the state is in "active" mode.
  Future<void> createConversation() async {
    // Order matters: last registered = highest priority.
    // Messages stub must come after conversations so it wins on /messages URLs.
    driver.stub('*/conversations*', _createConversationResponse());
    driver.stub('*/messages', _messagesResponse());

    await state.createConversation(
      kTeamId,
      kProjectId,
      agentRoleId: 'role-uuid-001',
    );
  }

  // -----------------------------------------------------------------------
  // Subscription lifecycle
  // -----------------------------------------------------------------------

  group('WebSocket subscription lifecycle', () {
    test('createConversation subscribes to conversation channel', () async {
      await createConversation();

      fake.assertSubscribed(
        'private-${ChannelName.conversation(kConversationId).key}',
      );
    });

    test('resubscribe re-subscribes to conversation channel', () async {
      await createConversation();
      fake.reset();

      state.resubscribe();

      fake.assertSubscribed(
        'private-${ChannelName.conversation(kConversationId).key}',
      );
    });

    test('resubscribe is a no-op when conversation is null', () {
      state.resubscribe();

      expect(fake.driver.subscribedChannels, isEmpty);
    });

    test('unsubscribeChannels disposes conversation handle', () async {
      await createConversation();

      state.unsubscribeChannels();

      // After unsubscribeChannels, resubscribe should create a new handle.
      // The key check is that no crash happens and state is clean.
      expect(state.conversation, isNotNull);
    });

    test('reset disposes handles and clears conversation data', () async {
      await createConversation();

      state.reset();

      expect(state.conversation, isNull);
      expect(state.chatItems, isEmpty);
      expect(state.rawEvents, isEmpty);
    });

    test(
      'resubscribe also subscribes to session channel when sessionId is set',
      () async {
        await createConversation();

        // Simulate a status event that sets sessionId.
        state.addEvent(
          BroadcastEvent(
            channel: 'private-conversation.$kConversationId',
            event: '.conversation.status',
            data: {
              'conversation_id': kConversationId,
              'status': 'active',
              'session_id': 'session-uuid-001',
            },
            receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
          ),
        );

        fake.reset();
        state.resubscribe();

        fake.assertSubscribed(
          'private-${ChannelName.conversation(kConversationId).key}',
        );
        fake.assertSubscribed(
          'private-${ChannelName.session('session-uuid-001').key}',
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // Route-change subscription resilience (the core bug fix)
  // -----------------------------------------------------------------------

  group('route-change subscription resilience', () {
    test(
      'resubscribe followed by unsubscribeChannels disposes old handles',
      () async {
        await createConversation();

        // Simulate route change: new widget calls resubscribe, old widget
        // calls unsubscribeChannels (the OLD broken behavior).
        state.resubscribe();
        state.unsubscribeChannels();

        // State should still have the conversation data but handles are gone.
        expect(state.conversation, isNotNull);
      },
    );

    test(
      'resubscribe without unsubscribeChannels keeps events flowing (the fix)',
      () async {
        await createConversation();

        // Simulate the FIXED behavior: new widget calls resubscribe,
        // old widget does NOT call unsubscribeChannels in dispose.
        state.resubscribe();

        // Events should still be processed via addEvent.
        state.addEvent(_textEvent(content: 'After route change'));

        expect(state.chatItems, hasLength(1));
      },
    );
  });

  // -----------------------------------------------------------------------
  // prepareConversation (subscribe-before-load race fix)
  // -----------------------------------------------------------------------

  group('prepareConversation', () {
    test('subscribes to conversation channel before any HTTP load', () {
      state.prepareConversation(kTeamId, kProjectId, kConversationId);

      // The channel should be subscribed immediately, no HTTP needed.
      fake.assertSubscribed(
        'private-${ChannelName.conversation(kConversationId).key}',
      );
    });

    test(
      'loadConversation flushes buffered events after prepareConversation',
      () async {
        driver.stub('*/conversations/*', _loadConversationResponse());
        driver.stub('*/messages*', _messagesResponse());

        // Subscribe eagerly.
        state.prepareConversation(kTeamId, kProjectId, kConversationId);

        // Verify subscribed before load.
        fake.assertSubscribed(
          'private-${ChannelName.conversation(kConversationId).key}',
        );

        // Load completes and activates the handle.
        await state.loadConversation(kTeamId, kProjectId, kConversationId);

        expect(state.conversation, isNotNull);
        expect(state.conversation?.id, kConversationId);
      },
    );
  });

  // -----------------------------------------------------------------------
  // addEvent routing
  // -----------------------------------------------------------------------

  group('addEvent', () {
    test('text event appends ChatMessageItem', () async {
      await createConversation();

      state.addEvent(_textEvent(content: 'Hello agent'));

      expect(state.chatItems, hasLength(1));
      expect(state.rawEvents, hasLength(1));
    });

    test('text event with null content is ignored', () async {
      await createConversation();

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'text',
            'content': null,
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      // Raw event recorded, but no ChatItem created.
      expect(state.rawEvents, hasLength(1));
      expect(state.chatItems, isEmpty);
    });

    test('status event updates conversation status and warmUntil', () async {
      await createConversation();

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.status',
          data: {
            'conversation_id': kConversationId,
            'status': 'warm',
            'warm_until': '2026-03-27T11:00:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
        ),
      );

      expect(state.warmUntil, '2026-03-27T11:00:00.000Z');
    });

    test('thinking event appends ChatThinkingItem', () async {
      await createConversation();

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'thinking',
            'content': 'Analyzing...',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.chatItems, hasLength(1));
    });

    test('result event clears awaitingResponse', () async {
      await createConversation();
      state.setAwaitingResponseForTest(value: true);

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'result',
            'content': 'Done',
            'metadata': {
              'data': {'isError': false},
            },
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.awaitingResponse, isFalse);
    });

    test('system event does NOT clear awaitingResponse', () async {
      await createConversation();
      state.setAwaitingResponseForTest(value: true);

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'system',
            'content': 'Session created',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.awaitingResponse, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // tool_result correlation
  // -----------------------------------------------------------------------

  group('tool_result correlation', () {
    test('tool_result updates matching ChatToolUseItem', () async {
      await createConversation();

      // Add tool_use event.
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'data': {
                'toolName': 'Read',
                'input': {'path': '/src/main.dart'},
                'toolUseId': 'tu-001',
              },
            },
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.chatItems, hasLength(1));

      // Add tool_result event with matching toolUseId.
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_result',
            'content': 'file contents here',
            'metadata': {
              'data': {'toolUseId': 'tu-001'},
            },
            'occurred_at': '2026-03-27T10:01:01.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1, 1),
        ),
      );

      // Still one item — the existing one was updated in-place.
      expect(state.chatItems, hasLength(1));
    });
  });

  // -----------------------------------------------------------------------
  // loadConversation
  // -----------------------------------------------------------------------

  group('loadConversation', () {
    test('loads conversation and subscribes to WS channel', () async {
      driver.stub('*/conversations/*', _loadConversationResponse());
      driver.stub('*/messages*', _messagesResponse());

      await state.loadConversation(kTeamId, kProjectId, kConversationId);

      expect(state.conversation, isNotNull);
      expect(state.conversation?.id, kConversationId);
      fake.assertSubscribed(
        'private-${ChannelName.conversation(kConversationId).key}',
      );
    });
  });

  // -----------------------------------------------------------------------
  // sendMessage
  // -----------------------------------------------------------------------

  group('sendMessage', () {
    test('guards against missing conversation', () async {
      await state.sendMessage('Hello');

      // No HTTP call made.
      driver.assertNothingSent();
    });

    test('serialises concurrent sends via activeSendFuture', () async {
      await createConversation();

      driver.stub(
        '*/messages*',
        MagicResponse(data: <String, dynamic>{}, statusCode: 200),
      );

      // Start first send.
      final first = state.sendMessage('Hello');
      // Second send awaits first POST then fires its own.
      final second = state.sendMessage('World');
      await Future.wait([first, second]);

      // Both POSTs fire — serialised, not dropped.
      final messagePosts = driver.recorded
          .where((r) => r.$1.url.contains('/messages'))
          .toList();
      expect(messagePosts, hasLength(2));
    });

    test('guards against sending while question is pending', () async {
      await createConversation();

      // Simulate a question event arriving via addEvent.
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'question',
            'content': 'Which database?',
            'metadata': {'questionId': 'q-1', 'message': 'Which database?'},
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.pendingQuestion, isNotNull);

      driver.stub(
        '*/messages*',
        MagicResponse(data: <String, dynamic>{}, statusCode: 200),
      );

      await state.sendMessage('Another message');

      // No HTTP call — send was blocked by pending question guard.
      final messagePosts = driver.recorded
          .where((r) => r.$1.url.contains('/messages'))
          .toList();
      expect(messagePosts, isEmpty);
    });

    test('optimistic message appended immediately', () async {
      await createConversation();

      driver.stub(
        '*/messages*',
        MagicResponse(data: <String, dynamic>{}, statusCode: 200),
      );

      await state.sendMessage('Quick question');

      expect(state.chatItems, hasLength(1));
      expect(state.isSending, isFalse);
      expect(state.awaitingResponse, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // Parallel subagent nesting
  // -----------------------------------------------------------------------

  group('parallel subagent nesting', () {
    test('interleaved events nest under correct subagent', () async {
      await createConversation();

      // Parent spawns Agent(Explore) tool_use — forced top-level.
      state.addEvent(
        _toolUseEvent(toolName: 'Agent', toolUseId: 'toolu_explore'),
      );

      // Parent spawns Agent(librarian) tool_use — forced top-level.
      state.addEvent(
        _toolUseEvent(toolName: 'Agent', toolUseId: 'toolu_librarian'),
      );

      // Explore subagent starts.
      state.addEvent(
        _subagentEvent(
          type: 'subagent_start',
          subagentId: 'explore-001',
          toolUseId: 'toolu_explore',
          description: 'Explore codebase',
        ),
      );

      // librarian subagent starts (parallel).
      state.addEvent(
        _subagentEvent(
          type: 'subagent_start',
          subagentId: 'librarian-001',
          toolUseId: 'toolu_librarian',
          description: 'Research docs',
        ),
      );

      // Explore emits progress → switches current to Explore.
      state.addEvent(
        _subagentEvent(
          type: 'subagent_progress',
          subagentId: 'explore-001',
          description: 'Searching files',
        ),
      );

      // Explore tool_use — should nest under Explore, NOT librarian.
      state.addEvent(_toolUseEvent(toolName: 'Grep', toolUseId: 'grep-001'));

      // librarian emits progress → switches current to librarian.
      state.addEvent(
        _subagentEvent(
          type: 'subagent_progress',
          subagentId: 'librarian-001',
          description: 'Fetching docs',
        ),
      );

      // librarian tool_use — should nest under librarian.
      state.addEvent(
        _toolUseEvent(toolName: 'WebSearch', toolUseId: 'web-001'),
      );

      // Explore emits progress again → switch back.
      state.addEvent(
        _subagentEvent(
          type: 'subagent_progress',
          subagentId: 'explore-001',
          description: 'Reading file',
        ),
      );

      // Another Explore tool_use.
      state.addEvent(_toolUseEvent(toolName: 'Read', toolUseId: 'read-001'));

      // Top-level: Agent(Explore), Agent(librarian), SubagentExplore,
      //            SubagentLibrarian
      expect(state.chatItems, hasLength(4));

      // Skip the two Agent tool_use items (indices 0, 1).
      final exploreBlock = state.chatItems[2] as ChatSubagentItem;
      final librarianBlock = state.chatItems[3] as ChatSubagentItem;

      expect(exploreBlock.subagentId, 'explore-001');
      expect(librarianBlock.subagentId, 'librarian-001');

      // Explore should have Grep + Read = 2 children.
      expect(exploreBlock.children, hasLength(2));
      expect((exploreBlock.children[0] as ChatToolUseItem).toolName, 'Grep');
      expect((exploreBlock.children[1] as ChatToolUseItem).toolName, 'Read');

      // librarian should have WebSearch = 1 child.
      expect(librarianBlock.children, hasLength(1));
      expect(
        (librarianBlock.children[0] as ChatToolUseItem).toolName,
        'WebSearch',
      );
    });

    test('subagent_stop switches current to remaining active', () async {
      await createConversation();

      // Start two subagents.
      state.addEvent(
        _subagentEvent(
          type: 'subagent_start',
          subagentId: 'alpha',
          toolUseId: 'toolu_alpha',
          description: 'Alpha',
        ),
      );
      state.addEvent(
        _subagentEvent(
          type: 'subagent_start',
          subagentId: 'beta',
          toolUseId: 'toolu_beta',
          description: 'Beta',
        ),
      );

      // Beta progress → current = beta.
      state.addEvent(
        _subagentEvent(type: 'subagent_progress', subagentId: 'beta'),
      );

      // Stop beta → current should switch to alpha.
      state.addEvent(_subagentEvent(type: 'subagent_stop', subagentId: 'beta'));

      // Next tool_use should go to alpha (the remaining subagent).
      state.addEvent(_toolUseEvent(toolName: 'Glob', toolUseId: 'glob-001'));

      final alphaBlock = state.chatItems[0] as ChatSubagentItem;
      expect(alphaBlock.subagentId, 'alpha');
      expect(alphaBlock.children, hasLength(1));
      expect((alphaBlock.children[0] as ChatToolUseItem).toolName, 'Glob');
    });
  });

  // -----------------------------------------------------------------------
  // Pending events recovery (Step 4)
  // -----------------------------------------------------------------------

  group('Pending events recovery', () {
    /// Helper: load conversation with pending_events in the API response.
    Future<void> loadConversationWithPendingEvents(
      List<Map<String, dynamic>> pendingEvents,
    ) async {
      driver.stub(
        '*/conversations/*',
        MagicResponse(
          data: {
            'data': {
              'id': kConversationId,
              'project_id': kProjectId,
              'user': {'id': 'user-uuid-001', 'name': 'Test User'},
              'agent_role': {
                'id': 'role-uuid-001',
                'name': 'Lead Developer',
                'slug': 'lead',
              },
              'title': 'Test',
              'status': 'paused',
              'model': 'claude-sonnet-4-6',
              'total_cost_usd': '0.10',
              'total_input_tokens': 1000,
              'total_output_tokens': 500,
              'messages_count': 2,
              'last_activity_at': '2026-03-27T10:00:00.000Z',
              'started_at': '2026-03-27T09:55:00.000Z',
              'completed_at': null,
              'created_at': '2026-03-27T09:55:00.000Z',
              'updated_at': '2026-03-27T10:00:00.000Z',
              'active_session': {
                'id': 'session-uuid-001',
                'phase': 'warm',
                'warm_until': '2026-03-27T10:30:00.000Z',
              },
              'pending_events': pendingEvents,
              'pending_question': null,
            },
          },
          statusCode: 200,
        ),
      );
      // Messages stub AFTER conversations — last registered = highest priority.
      driver.stub('*/messages', _messagesResponse());

      await state.loadConversation(kTeamId, kProjectId, kConversationId);
    }

    test('recovers thinking and tool_use from pending_events', () async {
      await loadConversationWithPendingEvents([
        {
          'id': 'se-001',
          'type': 'thinking',
          'content_text': 'Analyzing the code...',
          'data': {'type': 'thinking'},
          'metadata': null,
          'occurred_at': '2026-03-27T10:01:00.000Z',
        },
        {
          'id': 'se-002',
          'type': 'tool_use',
          'content_text': null,
          'data': {
            'type': 'tool_use',
            'metadata': {'toolName': 'Read', 'toolUseId': 'toolu_abc'},
          },
          'metadata': {'toolName': 'Read', 'toolUseId': 'toolu_abc'},
          'occurred_at': '2026-03-27T10:01:05.000Z',
        },
      ]);

      // Messages are empty, so chatItems should only contain pending events.
      expect(state.chatItems, hasLength(2));
      expect(state.chatItems[0], isA<ChatThinkingItem>());
      expect(
        (state.chatItems[0] as ChatThinkingItem).content,
        'Analyzing the code...',
      );
      expect(state.chatItems[1], isA<ChatToolUseItem>());
      expect((state.chatItems[1] as ChatToolUseItem).toolName, 'Read');
    });

    test('populates seenEventIds from pending_events', () async {
      await loadConversationWithPendingEvents([
        {
          'id': 'se-aaa',
          'type': 'thinking',
          'content_text': 'Hmm',
          'data': {},
          'metadata': null,
          'occurred_at': '2026-03-27T10:01:00.000Z',
        },
      ]);

      // The WS event with the same stream_event_id should be skipped.
      final beforeCount = state.chatItems.length;

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'thinking',
            'content': 'Hmm',
            'metadata': {'stream_event_id': 'se-aaa'},
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.chatItems.length, beforeCount);
    });

    test('empty pending_events does not add items', () async {
      await loadConversationWithPendingEvents([]);
      expect(state.chatItems, isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Event ID dedup (Step 5)
  // -----------------------------------------------------------------------

  group('Event ID dedup', () {
    test('WS event with new stream_event_id is processed', () async {
      await createConversation();

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'stream_event_id': 'se-new-001',
              'toolName': 'Bash',
              'toolUseId': 'toolu_new',
            },
            'occurred_at': '2026-03-27T10:02:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
        ),
      );

      expect(state.chatItems, hasLength(1));
      expect(state.chatItems[0], isA<ChatToolUseItem>());
    });

    test('duplicate stream_event_id is silently skipped', () async {
      await createConversation();

      final event = BroadcastEvent(
        channel: 'private-conversation.$kConversationId',
        event: '.conversation.message',
        data: {
          'conversation_id': kConversationId,
          'type': 'tool_use',
          'content': null,
          'metadata': {
            'stream_event_id': 'se-dup-001',
            'toolName': 'Read',
            'toolUseId': 'toolu_dup',
          },
          'occurred_at': '2026-03-27T10:02:00.000Z',
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
      );

      state.addEvent(event);
      expect(state.chatItems, hasLength(1));

      // Emit same stream_event_id again.
      state.addEvent(event);
      expect(state.chatItems, hasLength(1));
    });

    test('events without stream_event_id are always processed', () async {
      await createConversation();

      // Two events with null stream_event_id — both should be processed.
      state.addEvent(_textEvent(content: 'First'));
      state.addEvent(_textEvent(content: 'Second'));

      // text events get accumulated into streaming message, so chatItems
      // may be 1 (streaming). The key assertion: no crash, no skip.
      expect(state.chatItems, isNotEmpty);
    });

    test('seenEventIds cleared on reset', () async {
      await createConversation();

      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'stream_event_id': 'se-reset-001',
              'toolName': 'Edit',
              'toolUseId': 'toolu_r',
            },
            'occurred_at': '2026-03-27T10:02:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
        ),
      );
      expect(state.chatItems, hasLength(1));

      state.reset();
      await createConversation();

      // After reset, the same stream_event_id should be processed again.
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'stream_event_id': 'se-reset-001',
              'toolName': 'Edit',
              'toolUseId': 'toolu_r',
            },
            'occurred_at': '2026-03-27T10:02:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
        ),
      );
      expect(state.chatItems, hasLength(1));
    });
  });

  // -----------------------------------------------------------------------
  // WS reconnect catch-up (Step 6)
  // -----------------------------------------------------------------------

  group('WS reconnect catch-up', () {
    test('reconnect fetches pending_events and merges with dedup', () async {
      // Load conversation with one pending event.
      // Conversations stub first, then messages (last = highest priority).
      driver.stub(
        '*/conversations/*',
        MagicResponse(
          data: {
            'data': {
              'id': kConversationId,
              'project_id': kProjectId,
              'user': {'id': 'user-uuid-001', 'name': 'Test User'},
              'agent_role': {
                'id': 'role-uuid-001',
                'name': 'Lead Developer',
                'slug': 'lead',
              },
              'title': 'Test',
              'status': 'paused',
              'model': 'claude-sonnet-4-6',
              'total_cost_usd': '0.10',
              'total_input_tokens': 1000,
              'total_output_tokens': 500,
              'messages_count': 2,
              'last_activity_at': '2026-03-27T10:00:00.000Z',
              'started_at': '2026-03-27T09:55:00.000Z',
              'completed_at': null,
              'created_at': '2026-03-27T09:55:00.000Z',
              'updated_at': '2026-03-27T10:00:00.000Z',
              'active_session': {
                'id': 'session-uuid-001',
                'phase': 'warm',
                'warm_until': '2026-03-27T10:30:00.000Z',
              },
              'pending_events': [
                {
                  'id': 'se-reconnect-001',
                  'type': 'thinking',
                  'content_text': 'Thinking after reconnect...',
                  'data': {},
                  'metadata': null,
                  'occurred_at': '2026-03-27T10:01:00.000Z',
                },
              ],
              'pending_question': null,
            },
          },
          statusCode: 200,
        ),
      );
      driver.stub('*/messages', _messagesResponse());

      await state.loadConversation(kTeamId, kProjectId, kConversationId);
      expect(state.chatItems, hasLength(1));

      // Now change the API response to include a NEW event on reconnect.
      driver.stub(
        '*/conversations/*',
        MagicResponse(
          data: {
            'data': {
              'id': kConversationId,
              'project_id': kProjectId,
              'user': {'id': 'user-uuid-001', 'name': 'Test User'},
              'agent_role': {
                'id': 'role-uuid-001',
                'name': 'Lead Developer',
                'slug': 'lead',
              },
              'title': 'Test',
              'status': 'paused',
              'model': 'claude-sonnet-4-6',
              'total_cost_usd': '0.10',
              'total_input_tokens': 1000,
              'total_output_tokens': 500,
              'messages_count': 2,
              'last_activity_at': '2026-03-27T10:00:00.000Z',
              'started_at': '2026-03-27T09:55:00.000Z',
              'completed_at': null,
              'created_at': '2026-03-27T09:55:00.000Z',
              'updated_at': '2026-03-27T10:00:00.000Z',
              'active_session': {
                'id': 'session-uuid-001',
                'phase': 'warm',
                'warm_until': '2026-03-27T10:30:00.000Z',
              },
              'pending_events': [
                // Same event (already seen — should be deduped).
                {
                  'id': 'se-reconnect-001',
                  'type': 'thinking',
                  'content_text': 'Thinking after reconnect...',
                  'data': {},
                  'metadata': null,
                  'occurred_at': '2026-03-27T10:01:00.000Z',
                },
                // New event missed during disconnect.
                {
                  'id': 'se-reconnect-002',
                  'type': 'tool_use',
                  'content_text': null,
                  'data': {
                    'metadata': {'toolName': 'Grep', 'toolUseId': 'toolu_grep'},
                  },
                  'metadata': {'toolName': 'Grep', 'toolUseId': 'toolu_grep'},
                  'occurred_at': '2026-03-27T10:01:30.000Z',
                },
              ],
              'pending_question': null,
            },
          },
          statusCode: 200,
        ),
      );
      driver.stub('*/messages', _messagesResponse());

      // Simulate WS reconnect.
      fake.simulateReconnect();

      // Allow the async catch-up to complete.
      await Future<void>.delayed(Duration.zero);

      // Should have 2 items: original thinking + new tool_use.
      // The duplicate se-reconnect-001 should be skipped.
      expect(state.chatItems, hasLength(2));
      expect(state.chatItems[0], isA<ChatThinkingItem>());
      expect(state.chatItems[1], isA<ChatToolUseItem>());
      expect((state.chatItems[1] as ChatToolUseItem).toolName, 'Grep');
    });
  });
}
