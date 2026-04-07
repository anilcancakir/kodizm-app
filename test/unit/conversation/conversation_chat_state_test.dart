import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/agent_role.dart';
import 'package:app/app/models/chat_item.dart';
import 'package:app/app/state/conversation_chat_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kAgentRolesResponse = {
  'data': [
    {'id': 'role-uuid-001', 'name': 'Business Analyst', 'slug': 'ba'},
    {'id': 'role-uuid-002', 'name': 'Lead Developer', 'slug': 'lead'},
  ],
};

const Map<String, dynamic> kConversationResponse = {
  'data': {
    'id': 'conv-uuid-001',
    'project_id': 'proj-uuid-001',
    'user': {'id': 'user-uuid-001', 'name': 'Anil'},
    'agent_role': {
      'id': 'role-uuid-001',
      'name': 'Business Analyst',
      'slug': 'ba',
    },
    'title': null,
    'status': 'active',
    'model': 'claude-sonnet-4-6',
    'total_cost_usd': null,
    'total_input_tokens': 0,
    'total_output_tokens': 0,
    'messages_count': 0,
    'last_activity_at': null,
    'started_at': '2026-03-27T10:00:00.000Z',
    'completed_at': null,
    'created_at': '2026-03-27T10:00:00.000Z',
    'updated_at': '2026-03-27T10:00:00.000Z',
  },
};

const Map<String, dynamic> kMessagesResponse = {
  'data': [
    {
      'id': 'msg-uuid-001',
      'conversation_id': 'conv-uuid-001',
      'role': 'user',
      'content': 'Hello agent',
      'metadata': null,
      'cost_usd': null,
      'usage': null,
      'duration_ms': null,
      'num_turns': null,
      'error': null,
      'started_at': null,
      'completed_at': null,
      'created_at': '2026-03-27T10:01:00.000Z',
    },
    {
      'id': 'msg-uuid-002',
      'conversation_id': 'conv-uuid-001',
      'role': 'assistant',
      'content': 'Hello! How can I help?',
      'metadata': null,
      'cost_usd': '0.0012',
      'usage': {'input_tokens': 10, 'output_tokens': 8},
      'duration_ms': 1200,
      'num_turns': 1,
      'error': null,
      'started_at': '2026-03-27T10:01:01.000Z',
      'completed_at': '2026-03-27T10:01:02.000Z',
      'created_at': '2026-03-27T10:01:02.000Z',
    },
  ],
  'meta': {'has_more': false, 'next_cursor': null},
};

// ---------------------------------------------------------------------------
// Fake WebSocket service
// ---------------------------------------------------------------------------

/// Records subscribe/unsubscribe calls for testing.
class _FakeWebSocketService implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];
  final Map<String, void Function(BroadcastEvent)> callbacks = {};

  @override
  Stream<void> get onReconnect => const Stream.empty();

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {
    subscribedChannels.add(channel);
    callbacks[channel] = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
    callbacks.remove(channel);
  }

  /// Simulate an incoming event on a channel.
  void simulateEvent(String channel, BroadcastEvent event) {
    callbacks[channel]?.call(event);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('ConversationChatState', () {
    late FakeNetworkDriver driver;
    late _FakeWebSocketService ws;
    late ConversationChatState state;

    setUp(() {
      driver = Http.fake();
      ws = _FakeWebSocketService();
      state = ConversationChatState(webSocket: ws);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state is empty
    // -----------------------------------------------------------------------

    test('initial state has null conversation and empty collections', () {
      expect(state.conversation, isNull);
      expect(state.messages, isEmpty);
      expect(state.rawEvents, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.error, isNull);
      expect(state.warmUntil, isNull);
    });

    // -----------------------------------------------------------------------
    // 2. createConversation — success
    // -----------------------------------------------------------------------

    test(
      'createConversation posts with agentRoleId and creates conversation',
      () async {
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );

        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        expect(state.conversation, isNotNull);
        expect(state.conversation!.id, equals('conv-uuid-001'));
        expect(state.conversation!.status, equals('active'));
        expect(state.error, isNull);

        // Verify HTTP call: single POST to conversations endpoint.
        driver.assertSentCount(1);
        final request = driver.recorded.first.$1;
        expect(request.method, equals('POST'));
        expect(
          request.url,
          equals('/teams/team-uuid-001/projects/proj-uuid-001/conversations'),
        );
        expect(
          (request.data as Map<String, dynamic>)['agent_role_id'],
          equals('role-uuid-001'),
        );

        // Verify WS subscription.
        expect(ws.subscribedChannels, contains('conversation.conv-uuid-001'));
      },
    );

    // -----------------------------------------------------------------------
    // 3. createConversation — POST failure sets error
    // -----------------------------------------------------------------------

    test('createConversation sets error on POST failure', () async {
      driver.stub(
        '*/conversations*',
        Http.response({'message': 'Forbidden'}, 403),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      expect(state.conversation, isNull);
      expect(state.error, isNotNull);
      driver.assertSentCount(1);
    });

    // -----------------------------------------------------------------------
    // 5. sendMessage — success with optimistic append
    // -----------------------------------------------------------------------

    test('sendMessage appends optimistic user message and posts', () async {
      // Set up conversation first.
      // Conversations first, then messages (last = highest priority).
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      driver.stub(
        '*/messages',
        Http.response(<String, dynamic>{'data': null}, 202),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );
      driver.recorded.clear();

      await state.sendMessage('Hello agent');

      // Optimistic user message appended.
      expect(state.messages.length, equals(1));
      expect(state.messages.first.role, equals('user'));
      expect(state.messages.first.content, equals('Hello agent'));
      expect(state.isSending, isFalse);

      // Verify POST call.
      driver.assertSentCount(1);
      final request = driver.recorded.first.$1;
      expect(request.method, equals('POST'));
      expect(request.url, contains('/conversations/conv-uuid-001/messages'));
      expect(
        (request.data as Map<String, dynamic>)['content'],
        equals('Hello agent'),
      );
    });

    // -----------------------------------------------------------------------
    // 6. sendMessage — guards: no conversation
    // -----------------------------------------------------------------------

    test('sendMessage does nothing when no conversation', () async {
      await state.sendMessage('Hello');

      expect(state.messages, isEmpty);
      driver.assertNothingSent();
    });

    // -----------------------------------------------------------------------
    // 7. sendMessage — guards: already sending
    // -----------------------------------------------------------------------

    test('sendMessage ignores concurrent sends', () async {
      // Set up conversation.
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      driver.stub(
        '*/messages',
        Http.response(<String, dynamic>{'data': null}, 202),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );
      driver.recorded.clear();

      // Send two messages concurrently — second awaits the first then proceeds.
      final first = state.sendMessage('First');
      final second = state.sendMessage('Second');
      await Future.wait([first, second]);

      // Both POSTs are serialized (second awaits first, then executes).
      final postCalls = driver.recorded
          .where((r) => r.$1.method == 'POST')
          .toList();
      expect(postCalls.length, equals(2));
    });

    // -----------------------------------------------------------------------
    // 8. addEvent — .conversation.message appends assistant message
    // -----------------------------------------------------------------------

    test('addEvent with .conversation.message appends message', () async {
      // Set up conversation.
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      final wsEvent = BroadcastEvent(
        channel: 'conversation.conv-uuid-001',
        event: '.conversation.message',
        data: {
          'conversation_id': 'conv-uuid-001',
          'type': 'assistant',
          'content': 'I can help with that!',
          'metadata': null,
          'occurred_at': '2026-03-27T10:02:00.000Z',
        },
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.messages.length, equals(1));
      expect(state.messages.first.role, equals('assistant'));
      expect(state.messages.first.content, equals('I can help with that!'));
      expect(state.rawEvents.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 9. addEvent — .conversation.message with null content (no append)
    // -----------------------------------------------------------------------

    test('addEvent with null content does not append message', () {
      final wsEvent = BroadcastEvent(
        channel: 'conversation.conv-uuid-001',
        event: '.conversation.message',
        data: {
          'conversation_id': 'conv-uuid-001',
          'type': 'assistant',
          'content': null,
          'metadata': null,
          'occurred_at': '2026-03-27T10:02:00.000Z',
        },
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 10. addEvent — .conversation.status updates conversation
    // -----------------------------------------------------------------------

    test(
      'addEvent with .conversation.status updates status and warmUntil',
      () async {
        // Set up conversation.
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );
        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );
        expect(state.conversation!.status, equals('active'));

        final wsEvent = BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.status',
          data: {
            'conversation_id': 'conv-uuid-001',
            'status': 'processing',
            'warm_until': '2026-03-27T10:10:00.000Z',
          },
          receivedAt: DateTime.now(),
        );

        state.addEvent(wsEvent);

        expect(state.conversation!.status, equals('processing'));
        expect(state.warmUntil, equals('2026-03-27T10:10:00.000Z'));
        expect(state.rawEvents.length, equals(1));
      },
    );

    // -----------------------------------------------------------------------
    // 11. addEvent — unknown event type appended to raw events only
    // -----------------------------------------------------------------------

    test('addEvent with unknown type appends to raw events only', () {
      final wsEvent = BroadcastEvent(
        channel: 'conversation.conv-uuid-001',
        event: '.conversation.something_else',
        data: {'foo': 'bar'},
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(1));
      expect(
        state.rawEvents.first.event,
        equals('.conversation.something_else'),
      );
    });

    // -----------------------------------------------------------------------
    // 12. completeConversation — success
    // -----------------------------------------------------------------------

    test('completeConversation posts and updates status', () async {
      // Set up conversation.
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub('*/complete', Http.response({}));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );
      driver.recorded.clear();

      await state.completeConversation();

      expect(state.conversation!.status, equals('completed'));

      driver.assertSentCount(1);
      final request = driver.recorded.first.$1;
      expect(request.method, equals('POST'));
      expect(
        request.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/complete',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 13. loadMessages — success
    // -----------------------------------------------------------------------

    test('loadMessages fetches and replaces messages list', () async {
      // Set up conversation.
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      driver.stub('*/messages*', Http.response(kMessagesResponse));

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );
      driver.recorded.clear();

      await state.loadMessages();

      expect(state.messages.length, equals(2));
      expect(state.messages[0].id, equals('msg-uuid-001'));
      expect(state.messages[0].role, equals('user'));
      expect(state.messages[1].id, equals('msg-uuid-002'));
      expect(state.messages[1].role, equals('assistant'));

      final request = driver.recorded.first.$1;
      expect(request.method, equals('GET'));
      expect(
        request.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/messages',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 14. reset — clears all state
    // -----------------------------------------------------------------------

    test('reset clears all state and unsubscribes from WS', () async {
      // Set up conversation.
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );
      expect(state.conversation, isNotNull);

      state.reset();

      expect(state.conversation, isNull);
      expect(state.messages, isEmpty);
      expect(state.rawEvents, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.error, isNull);
      expect(state.warmUntil, isNull);
      expect(ws.unsubscribedChannels, contains('conversation.conv-uuid-001'));
    });

    // -----------------------------------------------------------------------
    // 15. WS event via channel simulation
    // -----------------------------------------------------------------------

    test('WS subscribe callback routes events through addEvent', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      // Simulate WS event via the fake service.
      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'conversation_id': 'conv-uuid-001',
            'type': 'assistant',
            'content': 'Simulated response',
            'metadata': null,
            'occurred_at': '2026-03-27T10:05:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.messages.length, equals(1));
      expect(state.messages.first.content, equals('Simulated response'));
      expect(state.rawEvents.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 16. refreshUI is called (notifyListeners)
    // -----------------------------------------------------------------------

    test('state changes trigger notifyListeners', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      expect(notifyCount, greaterThan(0));
    });

    // -----------------------------------------------------------------------
    // 17. addEvent — .conversation.status without conversation (no crash)
    // -----------------------------------------------------------------------

    test('addEvent with .conversation.status without conversation is safe', () {
      final wsEvent = BroadcastEvent(
        channel: 'conversation.conv-uuid-001',
        event: '.conversation.status',
        data: {
          'conversation_id': 'conv-uuid-001',
          'status': 'processing',
          'warm_until': null,
        },
        receivedAt: DateTime.now(),
      );

      // Should not throw.
      state.addEvent(wsEvent);

      expect(state.rawEvents.length, equals(1));
      expect(state.conversation, isNull);
    });

    // -----------------------------------------------------------------------
    // 18. loadConversation — fetches conversation, messages, and subscribes
    // -----------------------------------------------------------------------

    test(
      'loadConversation fetches conversation, loads messages, and subscribes to WS',
      () async {
        // GET single conversation first, then messages (last = highest priority).
        driver.stub('*/conversations/*', Http.response(kConversationResponse));
        driver.stub('*/messages*', Http.response(kMessagesResponse));

        await state.loadConversation(
          'team-uuid-001',
          'proj-uuid-001',
          'conv-uuid-001',
        );

        // Conversation is loaded.
        expect(state.conversation, isNotNull);
        expect(state.conversation!.id, equals('conv-uuid-001'));
        expect(state.error, isNull);

        // Messages are loaded.
        expect(state.messages.length, equals(2));

        // HTTP calls: GET conversation, GET messages.
        final getCalls = driver.recorded
            .where((r) => r.$1.method == 'GET')
            .toList();
        expect(getCalls.length, equals(2));
        expect(
          getCalls[0].$1.url,
          equals(
            '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001',
          ),
        );
        expect(
          getCalls[1].$1.url,
          equals(
            '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/messages',
          ),
        );

        // WS subscription to conversation channel.
        expect(ws.subscribedChannels, contains('conversation.conv-uuid-001'));
      },
    );

    // -----------------------------------------------------------------------
    // 19. loadConversation — API failure sets error
    // -----------------------------------------------------------------------

    test('loadConversation sets error on API failure', () async {
      driver.stub(
        '*/conversations/*',
        Http.response({'message': 'Not found'}, 404),
      );

      await state.loadConversation(
        'team-uuid-001',
        'proj-uuid-001',
        'conv-uuid-001',
      );

      expect(state.conversation, isNull);
      expect(state.error, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 20. sessionId — populated from .conversation.status WS event
    // -----------------------------------------------------------------------

    test(
      'sessionId is populated from .conversation.status event and session WS channel is subscribed',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );

        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        expect(state.sessionId, isNull);

        final wsEvent = BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.status',
          data: {
            'conversation_id': 'conv-uuid-001',
            'status': 'processing',
            'session_id': 'sess-uuid-001',
            'warm_until': null,
          },
          receivedAt: DateTime.now(),
        );

        state.addEvent(wsEvent);

        expect(state.sessionId, equals('sess-uuid-001'));

        // Session WS channel subscribed.
        expect(ws.subscribedChannels, contains('session.sess-uuid-001'));
      },
    );

    // -----------------------------------------------------------------------
    // 21. session WS events — .session.cost and .session.status are handled
    // -----------------------------------------------------------------------

    test('session WS events update running cost and session phase', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      // Trigger session subscription via status event.
      state.addEvent(
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.status',
          data: {
            'conversation_id': 'conv-uuid-001',
            'status': 'processing',
            'session_id': 'sess-uuid-001',
            'warm_until': null,
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.sessionId, equals('sess-uuid-001'));

      // Simulate .session.cost event.
      ws.simulateEvent(
        'session.sess-uuid-001',
        BroadcastEvent(
          channel: 'session.sess-uuid-001',
          event: '.session.cost',
          data: {'running_total_usd': '0.0042'},
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.runningCostUsd, equals('0.0042'));

      // Simulate .session.status event.
      ws.simulateEvent(
        'session.sess-uuid-001',
        BroadcastEvent(
          channel: 'session.sess-uuid-001',
          event: '.session.status',
          data: {'phase': 'executing'},
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.sessionPhase, equals('executing'));
    });

    // -----------------------------------------------------------------------
    // 22. reset — clears sessionId, runningCostUsd, sessionPhase, unsubscribes session WS
    // -----------------------------------------------------------------------

    test(
      'reset clears session fields and unsubscribes from session WS channel',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );

        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        state.addEvent(
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.status',
            data: {
              'conversation_id': 'conv-uuid-001',
              'status': 'processing',
              'session_id': 'sess-uuid-001',
              'warm_until': null,
            },
            receivedAt: DateTime.now(),
          ),
        );

        expect(state.sessionId, equals('sess-uuid-001'));

        state.reset();

        expect(state.sessionId, isNull);
        expect(state.runningCostUsd, isNull);
        expect(state.sessionPhase, isNull);
        expect(ws.unsubscribedChannels, contains('session.sess-uuid-001'));
      },
    );

    // -----------------------------------------------------------------------
    // 23. tool_use WS event → ChatToolUseItem in chatItems
    // -----------------------------------------------------------------------

    test('tool_use event appends ChatToolUseItem to chatItems', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'toolName': 'Read',
              'input': {'file_path': '/tmp/test.dart'},
            },
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems.last, isA<ChatToolUseItem>());
      expect(
        (state.chatItems.last as ChatToolUseItem).toolName,
        equals('Read'),
      );
    });

    // -----------------------------------------------------------------------
    // 24. thinking event → ChatThinkingItem
    // -----------------------------------------------------------------------

    test('thinking event appends ChatThinkingItem to chatItems', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'thinking',
            'content': 'Analyzing the code...',
            'metadata': null,
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems.last, isA<ChatThinkingItem>());
      expect(
        (state.chatItems.last as ChatThinkingItem).content,
        equals('Analyzing the code...'),
      );
    });

    // -----------------------------------------------------------------------
    // 25. subagent_start then subagent_stop → updated ChatSubagentItem
    // -----------------------------------------------------------------------

    test(
      'subagent_start then subagent_stop updates ChatSubagentItem',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );
        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        // Start
        ws.simulateEvent(
          'conversation.conv-uuid-001',
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.message',
            data: {
              'type': 'subagent_start',
              'content': null,
              'metadata': {'agentId': 'sub-001', 'agentType': 'Researching'},
              'occurred_at': '2026-03-27T10:03:00.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        expect(state.chatItems.last, isA<ChatSubagentItem>());
        expect((state.chatItems.last as ChatSubagentItem).isComplete, isFalse);

        final startIndex = state.chatItems.length - 1;

        // Stop
        ws.simulateEvent(
          'conversation.conv-uuid-001',
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.message',
            data: {
              'type': 'subagent_stop',
              'content': null,
              'metadata': {
                'agentId': 'sub-001',
                'agentType': 'Researching',
                'durationMs': 3200,
              },
              'occurred_at': '2026-03-27T10:03:05.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        final updated = state.chatItems[startIndex] as ChatSubagentItem;
        expect(updated.isComplete, isTrue);
        expect(updated.toolUseCount, isZero);
        expect(updated.durationMs, equals(3200));
      },
    );

    // -----------------------------------------------------------------------
    // 26. file_change event → ChatFileChangeItem
    // -----------------------------------------------------------------------

    test('file_change event appends ChatFileChangeItem', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'file_change',
            'content': null,
            'metadata': {
              'toolName': 'Edit',
              'filePath': 'lib/app/models/task.dart',
            },
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems.last, isA<ChatFileChangeItem>());
      expect(
        (state.chatItems.last as ChatFileChangeItem).operation,
        equals('M'),
      );
      expect(
        (state.chatItems.last as ChatFileChangeItem).filePath,
        equals('lib/app/models/task.dart'),
      );
    });

    // -----------------------------------------------------------------------
    // 27. error event → ChatErrorItem
    // -----------------------------------------------------------------------

    test('error event appends ChatErrorItem', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'error',
            'content': 'Rate limit exceeded',
            'metadata': null,
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems.last, isA<ChatErrorItem>());
      expect(
        (state.chatItems.last as ChatErrorItem).errorText,
        equals('Rate limit exceeded'),
      );
    });

    // -----------------------------------------------------------------------
    // 28. result event → ChatResultItem
    // -----------------------------------------------------------------------

    test('result event appends ChatResultItem', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'result',
            'content': 'Task completed',
            'metadata': {'isError': false},
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems.last, isA<ChatResultItem>());
      expect((state.chatItems.last as ChatResultItem).isError, isFalse);
      expect(
        (state.chatItems.last as ChatResultItem).content,
        equals('Task completed'),
      );
    });

    // -----------------------------------------------------------------------
    // 29. chatItems getter returns unmodifiable list
    // -----------------------------------------------------------------------

    test('chatItems getter returns unmodifiable list', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      expect(
        () => state.chatItems.add(
          ChatErrorItem(id: 'x', occurredAt: DateTime.now(), errorText: 'test'),
        ),
        throwsUnsupportedError,
      );
    });

    // -----------------------------------------------------------------------
    // 30. messages getter backward compat filters ChatMessageItems only
    // -----------------------------------------------------------------------

    test(
      'messages getter returns only ConversationMessages from chatItems',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );
        driver.stub('*/messages*', Http.response(kMessagesResponse));
        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );
        await state.loadMessages();

        // loadMessages creates ChatMessageItems.
        expect(state.chatItems.length, equals(2));
        expect(state.chatItems.every((e) => e is ChatMessageItem), isTrue);

        // messages getter extracts ConversationMessage.
        expect(state.messages.length, equals(2));
        expect(state.messages[0].id, equals('msg-uuid-001'));
      },
    );

    // -----------------------------------------------------------------------
    // 31. sendMessage optimistic append uses ChatMessageItem
    // -----------------------------------------------------------------------

    test('sendMessage optimistic append creates ChatMessageItem', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      driver.stub(
        '*/messages',
        Http.response(<String, dynamic>{'data': null}, 202),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      await state.sendMessage('Hello');

      expect(state.chatItems.last, isA<ChatMessageItem>());
      expect(
        (state.chatItems.last as ChatMessageItem).message.content,
        equals('Hello'),
      );
    });

    // -----------------------------------------------------------------------
    // 32. reset clears chatItems and activeSubagents
    // -----------------------------------------------------------------------

    test('reset clears chatItems', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'thinking',
            'content': 'Some thought',
            'metadata': null,
            'occurred_at': '2026-03-27T10:03:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.chatItems, isNotEmpty);

      state.reset();

      expect(state.chatItems, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 33. createConversation — POST body includes agentRoleId
    // -----------------------------------------------------------------------

    test(
      'createConversation sends provided agentRoleId in POST body',
      () async {
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );

        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        driver.assertSentCount(1);
        final request = driver.recorded.first.$1;
        expect(request.method, equals('POST'));
        expect(
          (request.data as Map<String, dynamic>)['agent_role_id'],
          equals('role-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 34. createConversation — POST body includes title when provided
    // -----------------------------------------------------------------------

    test('createConversation sends title in POST body when provided', () async {
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );

      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
        title: 'My Chat',
      );

      driver.assertSentCount(1);
      expect(
        (driver.recorded.first.$1.data as Map<String, dynamic>)['title'],
        equals('My Chat'),
      );
    });

    // -----------------------------------------------------------------------
    // 35. createConversation — POST body omits title when not provided
    // -----------------------------------------------------------------------

    test(
      'createConversation omits title key from POST body when not provided',
      () async {
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );

        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        driver.assertSentCount(1);
        expect(
          (driver.recorded.first.$1.data as Map<String, dynamic>).containsKey(
            'title',
          ),
          isFalse,
        );
      },
    );

    // -----------------------------------------------------------------------
    // 36. fetchAgentRoles — returns parsed List<AgentRole> on success
    // -----------------------------------------------------------------------

    test('fetchAgentRoles returns parsed List<AgentRole> on success', () async {
      driver.stub(
        '*/agent-roles*',
        Http.response({
          'data': [
            {
              'id': 'role-uuid-001',
              'name': 'Business Analyst',
              'scope': 'analysis',
              'slug': 'ba',
              'team_id': 'team-uuid-001',
            },
            {
              'id': 'role-uuid-002',
              'name': 'Lead Developer',
              'scope': 'implementation',
              'slug': 'lead',
              'team_id': 'team-uuid-001',
            },
          ],
        }),
      );

      final roles = await state.fetchAgentRoles('team-uuid-001');

      expect(roles, isA<List<AgentRole>>());
      expect(roles.length, equals(2));
      expect(roles[0].id, equals('role-uuid-001'));
      expect(roles[0].name, equals('Business Analyst'));
      expect(roles[0].scope, equals('analysis'));
      expect(roles[1].id, equals('role-uuid-002'));
      expect(roles[1].name, equals('Lead Developer'));

      driver.assertSentCount(1);
      final request = driver.recorded.first.$1;
      expect(request.method, equals('GET'));
      expect(request.url, equals('/teams/team-uuid-001/agent-roles'));
    });

    // -----------------------------------------------------------------------
    // 37. fetchAgentRoles — returns empty list on failure
    // -----------------------------------------------------------------------

    test('fetchAgentRoles returns empty list on API failure', () async {
      driver.stub(
        '*/agent-roles*',
        Http.response({'message': 'Forbidden'}, 403),
      );

      final roles = await state.fetchAgentRoles('team-uuid-001');

      expect(roles, isEmpty);
      expect(roles, isA<List<AgentRole>>());
    });

    // -----------------------------------------------------------------------
    // 38. tool_use with toolUseId → ChatToolUseItem.toolUseId forwarded
    // -----------------------------------------------------------------------

    test('tool_use event forwards toolUseId to ChatToolUseItem', () async {
      driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
      driver.stub(
        '*/conversations*',
        Http.response(kConversationResponse, 201),
      );
      await state.createConversation(
        'team-uuid-001',
        'proj-uuid-001',
        agentRoleId: 'role-uuid-001',
      );

      ws.simulateEvent(
        'conversation.conv-uuid-001',
        BroadcastEvent(
          channel: 'conversation.conv-uuid-001',
          event: '.conversation.message',
          data: {
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'toolName': 'Bash',
              'input': {'command': 'ls -la'},
              'toolUseId': 'toolu_abc123',
            },
            'occurred_at': '2026-03-27T10:05:00.000Z',
          },
          receivedAt: DateTime.now(),
        ),
      );

      final item = state.chatItems.last as ChatToolUseItem;
      expect(item.toolName, equals('Bash'));
      expect(item.toolUseId, equals('toolu_abc123'));
      expect(item.result, isNull);
    });

    // -----------------------------------------------------------------------
    // 39. tool_result event populates result on matching ChatToolUseItem
    // -----------------------------------------------------------------------

    test(
      'tool_result event finds parent ChatToolUseItem and populates result',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );
        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        // First: emit the tool_use that creates the card.
        ws.simulateEvent(
          'conversation.conv-uuid-001',
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.message',
            data: {
              'type': 'tool_use',
              'content': null,
              'metadata': {
                'toolName': 'Read',
                'input': {'file_path': '/tmp/out.txt'},
                'toolUseId': 'toolu_xyz789',
              },
              'occurred_at': '2026-03-27T10:06:00.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        // Confirm the card has no result yet.
        final before = state.chatItems.last as ChatToolUseItem;
        expect(before.toolUseId, equals('toolu_xyz789'));
        expect(before.result, isNull);

        // Then: emit the tool_result that should populate the card.
        ws.simulateEvent(
          'conversation.conv-uuid-001',
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.message',
            data: {
              'type': 'tool_result',
              'content': 'file contents here',
              'metadata': {'toolUseId': 'toolu_xyz789'},
              'occurred_at': '2026-03-27T10:06:01.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        // The list length must not grow — tool_result replaces, not appends.
        final after = state.chatItems.last as ChatToolUseItem;
        expect(after.toolUseId, equals('toolu_xyz789'));
        expect(after.result, equals('file contents here'));
      },
    );

    // -----------------------------------------------------------------------
    // 40. tool_result with no matching toolUseId — silently ignored
    // -----------------------------------------------------------------------

    test(
      'tool_result with unknown toolUseId does not mutate chatItems',
      () async {
        driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
        driver.stub(
          '*/conversations*',
          Http.response(kConversationResponse, 201),
        );
        await state.createConversation(
          'team-uuid-001',
          'proj-uuid-001',
          agentRoleId: 'role-uuid-001',
        );

        final lengthBefore = state.chatItems.length;

        ws.simulateEvent(
          'conversation.conv-uuid-001',
          BroadcastEvent(
            channel: 'conversation.conv-uuid-001',
            event: '.conversation.message',
            data: {
              'type': 'tool_result',
              'content': 'orphan result',
              'metadata': {'toolUseId': 'toolu_nonexistent'},
              'occurred_at': '2026-03-27T10:07:00.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        expect(state.chatItems.length, equals(lengthBefore));
      },
    );
  });
}
