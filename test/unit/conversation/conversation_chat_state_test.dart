import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
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
  });
}
