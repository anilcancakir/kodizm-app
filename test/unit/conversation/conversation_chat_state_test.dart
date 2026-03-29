import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
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
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [ConversationChatState] without
/// hitting the network.
class _FakeHttpClient implements ConversationChatHttpClient {
  final List<_HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Set a responder that maps URL to [MagicResponse].
  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  /// Shortcut: always return the same response regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('GET', url, query: query));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('POST', url, data: data));
    return _responder(url);
  }
}

class _HttpCall {
  _HttpCall(this.method, this.url, {this.data, this.query});

  final String method;
  final String url;
  final dynamic data;
  final Map<String, dynamic>? query;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Fake WebSocket service
// ---------------------------------------------------------------------------

/// Records subscribe/unsubscribe calls for testing.
class _FakeWebSocketService implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];
  final Map<String, void Function(WebSocketEvent)> callbacks = {};

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannels.add(channel);
    callbacks[channel] = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
    callbacks.remove(channel);
  }

  /// Simulate an incoming event on a channel.
  void simulateEvent(String channel, WebSocketEvent event) {
    callbacks[channel]?.call(event);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConversationChatState', () {
    late _FakeHttpClient http;
    late _FakeWebSocketService ws;
    late ConversationChatState state;

    setUp(() {
      http = _FakeHttpClient();
      ws = _FakeWebSocketService();
      state = ConversationChatState(httpClient: http, webSocket: ws);
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
      'createConversation fetches agent role and creates conversation',
      () async {
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });

        await state.createConversation('team-uuid-001', 'proj-uuid-001');

        expect(state.conversation, isNotNull);
        expect(state.conversation!.id, equals('conv-uuid-001'));
        expect(state.conversation!.status, equals('active'));
        expect(state.error, isNull);

        // Verify HTTP calls: GET agent-roles, POST conversations.
        expect(http.calls.length, equals(2));
        expect(http.calls[0].method, equals('GET'));
        expect(http.calls[0].url, equals('/teams/team-uuid-001/agent-roles'));
        expect(http.calls[1].method, equals('POST'));
        expect(
          http.calls[1].url,
          equals('/teams/team-uuid-001/projects/proj-uuid-001/conversations'),
        );
        expect(
          (http.calls[1].data as Map<String, dynamic>)['agent_role_id'],
          equals('role-uuid-001'),
        );

        // Verify WS subscription.
        expect(
          ws.subscribedChannels,
          contains('private-conversation.conv-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 3. createConversation — no agent roles sets error
    // -----------------------------------------------------------------------

    test('createConversation sets error when no agent roles found', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        ),
      );

      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      expect(state.conversation, isNull);
      expect(state.error, isNotNull);
      expect(http.calls.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 4. createConversation — agent roles API failure sets error
    // -----------------------------------------------------------------------

    test('createConversation sets error on agent roles API failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      expect(state.conversation, isNull);
      expect(state.error, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 5. sendMessage — success with optimistic append
    // -----------------------------------------------------------------------

    test('sendMessage appends optimistic user message and posts', () async {
      // Set up conversation first.
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        if (url.contains('/messages')) {
          return MagicResponse(data: {}, statusCode: 202);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');
      http.calls.clear();

      await state.sendMessage('Hello agent');

      // Optimistic user message appended.
      expect(state.messages.length, equals(1));
      expect(state.messages.first.role, equals('user'));
      expect(state.messages.first.content, equals('Hello agent'));
      expect(state.isSending, isFalse);

      // Verify POST call.
      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
        contains('/conversations/conv-uuid-001/messages'),
      );
      expect(
        (http.calls.first.data as Map<String, dynamic>)['content'],
        equals('Hello agent'),
      );
    });

    // -----------------------------------------------------------------------
    // 6. sendMessage — guards: no conversation
    // -----------------------------------------------------------------------

    test('sendMessage does nothing when no conversation', () async {
      await state.sendMessage('Hello');

      expect(state.messages, isEmpty);
      expect(http.calls, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 7. sendMessage — guards: already sending
    // -----------------------------------------------------------------------

    test('sendMessage ignores concurrent sends', () async {
      // Set up conversation.
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        if (url.contains('/messages')) {
          return MagicResponse(data: {}, statusCode: 202);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');
      http.calls.clear();

      // Send two messages concurrently — second should be ignored.
      final first = state.sendMessage('First');
      final second = state.sendMessage('Second');
      await Future.wait([first, second]);

      // Only one POST should have been made.
      final postCalls = http.calls.where((c) => c.method == 'POST').toList();
      expect(postCalls.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 8. addEvent — .conversation.message appends assistant message
    // -----------------------------------------------------------------------

    test('addEvent with .conversation.message appends message', () async {
      // Set up conversation.
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      final wsEvent = WebSocketEvent(
        id: 'ws:msg:1',
        channel: 'private-conversation.conv-uuid-001',
        eventName: '.conversation.message',
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
      final wsEvent = WebSocketEvent(
        id: 'ws:msg:null',
        channel: 'private-conversation.conv-uuid-001',
        eventName: '.conversation.message',
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
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });
        await state.createConversation('team-uuid-001', 'proj-uuid-001');
        expect(state.conversation!.status, equals('active'));

        final wsEvent = WebSocketEvent(
          id: 'ws:status:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.status',
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
      final wsEvent = WebSocketEvent(
        id: 'ws:unknown:1',
        channel: 'private-conversation.conv-uuid-001',
        eventName: '.conversation.something_else',
        data: {'foo': 'bar'},
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(1));
      expect(
        state.rawEvents.first.eventName,
        equals('.conversation.something_else'),
      );
    });

    // -----------------------------------------------------------------------
    // 12. completeConversation — success
    // -----------------------------------------------------------------------

    test('completeConversation posts and updates status', () async {
      // Set up conversation.
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        if (url.contains('/complete')) {
          return MagicResponse(data: {}, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');
      http.calls.clear();

      await state.completeConversation();

      expect(state.conversation!.status, equals('completed'));

      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        if (url.contains('/messages')) {
          return MagicResponse(data: kMessagesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');
      http.calls.clear();

      await state.loadMessages();

      expect(state.messages.length, equals(2));
      expect(state.messages[0].id, equals('msg-uuid-001'));
      expect(state.messages[0].role, equals('user'));
      expect(state.messages[1].id, equals('msg-uuid-002'));
      expect(state.messages[1].role, equals('assistant'));

      expect(http.calls.first.method, equals('GET'));
      expect(
        http.calls.first.url,
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');
      expect(state.conversation, isNotNull);

      state.reset();

      expect(state.conversation, isNull);
      expect(state.messages, isEmpty);
      expect(state.rawEvents, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.error, isNull);
      expect(state.warmUntil, isNull);
      expect(
        ws.unsubscribedChannels,
        contains('private-conversation.conv-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 15. WS event via channel simulation
    // -----------------------------------------------------------------------

    test('WS subscribe callback routes events through addEvent', () async {
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      // Simulate WS event via the fake service.
      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:sim:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      int notifyCount = 0;
      state.addListener(() => notifyCount++);

      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      expect(notifyCount, greaterThan(0));
    });

    // -----------------------------------------------------------------------
    // 17. addEvent — .conversation.status without conversation (no crash)
    // -----------------------------------------------------------------------

    test('addEvent with .conversation.status without conversation is safe', () {
      final wsEvent = WebSocketEvent(
        id: 'ws:status:orphan',
        channel: 'private-conversation.conv-uuid-001',
        eventName: '.conversation.status',
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
        http.whenAny((url) {
          if (url.contains('/messages')) {
            return MagicResponse(data: kMessagesResponse, statusCode: 200);
          }
          // GET single conversation.
          return MagicResponse(data: kConversationResponse, statusCode: 200);
        });

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
        final getCalls = http.calls.where((c) => c.method == 'GET').toList();
        expect(getCalls.length, equals(2));
        expect(
          getCalls[0].url,
          equals(
            '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001',
          ),
        );
        expect(
          getCalls[1].url,
          equals(
            '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/messages',
          ),
        );

        // WS subscription to conversation channel.
        expect(
          ws.subscribedChannels,
          contains('private-conversation.conv-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 19. loadConversation — API failure sets error
    // -----------------------------------------------------------------------

    test('loadConversation sets error on API failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
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
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });

        await state.createConversation('team-uuid-001', 'proj-uuid-001');

        expect(state.sessionId, isNull);

        final wsEvent = WebSocketEvent(
          id: 'ws:status:with-session',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.status',
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
        expect(
          ws.subscribedChannels,
          contains('private-session.sess-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 21. session WS events — .session.cost and .session.status are handled
    // -----------------------------------------------------------------------

    test('session WS events update running cost and session phase', () async {
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });

      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      // Trigger session subscription via status event.
      state.addEvent(
        WebSocketEvent(
          id: 'ws:status:sess',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.status',
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
        'private-session.sess-uuid-001',
        WebSocketEvent(
          id: 'ws:session:cost:1',
          channel: 'private-session.sess-uuid-001',
          eventName: '.session.cost',
          data: {'running_cost_usd': '0.0042'},
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.runningCostUsd, equals('0.0042'));

      // Simulate .session.status event.
      ws.simulateEvent(
        'private-session.sess-uuid-001',
        WebSocketEvent(
          id: 'ws:session:status:1',
          channel: 'private-session.sess-uuid-001',
          eventName: '.session.status',
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
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });

        await state.createConversation('team-uuid-001', 'proj-uuid-001');

        state.addEvent(
          WebSocketEvent(
            id: 'ws:status:sess:reset',
            channel: 'private-conversation.conv-uuid-001',
            eventName: '.conversation.status',
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
        expect(
          ws.unsubscribedChannels,
          contains('private-session.sess-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 23. tool_use WS event → ChatToolUseItem in chatItems
    // -----------------------------------------------------------------------

    test('tool_use event appends ChatToolUseItem to chatItems', () async {
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:tool:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
          data: {
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'data': {
                'toolName': 'Read',
                'input': {'file_path': '/tmp/test.dart'},
              },
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:think:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
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
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });
        await state.createConversation('team-uuid-001', 'proj-uuid-001');

        // Start
        ws.simulateEvent(
          'private-conversation.conv-uuid-001',
          WebSocketEvent(
            id: 'ws:sub:start',
            channel: 'private-conversation.conv-uuid-001',
            eventName: '.conversation.message',
            data: {
              'type': 'subagent_start',
              'content': null,
              'metadata': {
                'data': {'agentId': 'sub-001', 'agentType': 'Researching'},
              },
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
          'private-conversation.conv-uuid-001',
          WebSocketEvent(
            id: 'ws:sub:stop',
            channel: 'private-conversation.conv-uuid-001',
            eventName: '.conversation.message',
            data: {
              'type': 'subagent_stop',
              'content': null,
              'metadata': {
                'data': {
                  'agentId': 'sub-001',
                  'agentType': 'Researching',
                  'durationMs': 3200,
                },
              },
              'occurred_at': '2026-03-27T10:03:05.000Z',
            },
            receivedAt: DateTime.now(),
          ),
        );

        final updated = state.chatItems[startIndex] as ChatSubagentItem;
        expect(updated.isComplete, isTrue);
        expect(updated.toolUseCount, equals(0));
        expect(updated.durationMs, equals(3200));
      },
    );

    // -----------------------------------------------------------------------
    // 26. file_change event → ChatFileChangeItem
    // -----------------------------------------------------------------------

    test('file_change event appends ChatFileChangeItem', () async {
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:file:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
          data: {
            'type': 'file_change',
            'content': null,
            'metadata': {
              'data': {
                'toolName': 'Edit',
                'filePath': 'lib/app/models/task.dart',
              },
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:err:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:result:1',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
          data: {
            'type': 'result',
            'content': 'Task completed',
            'metadata': {
              'data': {'isError': false},
            },
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

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
        http.whenAny((url) {
          if (url.contains('/agent-roles')) {
            return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
          }
          if (url.contains('/messages')) {
            return MagicResponse(data: kMessagesResponse, statusCode: 200);
          }
          return MagicResponse(data: kConversationResponse, statusCode: 201);
        });
        await state.createConversation('team-uuid-001', 'proj-uuid-001');
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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        if (url.contains('/messages')) {
          return MagicResponse(data: {}, statusCode: 202);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

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
      http.whenAny((url) {
        if (url.contains('/agent-roles')) {
          return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
        }
        return MagicResponse(data: kConversationResponse, statusCode: 201);
      });
      await state.createConversation('team-uuid-001', 'proj-uuid-001');

      ws.simulateEvent(
        'private-conversation.conv-uuid-001',
        WebSocketEvent(
          id: 'ws:think:reset',
          channel: 'private-conversation.conv-uuid-001',
          eventName: '.conversation.message',
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
  });
}
