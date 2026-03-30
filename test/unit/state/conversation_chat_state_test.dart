import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/conversation_chat_state.dart';

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeHttpClient implements ConversationChatHttpClient {
  final List<String> calls = [];

  MagicResponse Function(String url)? responder;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add('GET $url');
    return responder?.call(url) ??
        MagicResponse(data: <String, dynamic>{}, statusCode: 404);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add('POST $url');
    return responder?.call(url) ??
        MagicResponse(data: <String, dynamic>{}, statusCode: 200);
  }
}

// ---------------------------------------------------------------------------
// Fake WebSocket — tracks subscribe/unsubscribe calls
// ---------------------------------------------------------------------------

class _FakeWebSocket implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];
  final Map<String, void Function(WebSocketEvent)> _callbacks = {};

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannels.add(channel);
    _callbacks[channel] = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
    _callbacks.remove(channel);
  }

  /// Whether a callback is currently registered for [channel].
  bool hasCallback(String channel) => _callbacks.containsKey(channel);

  /// Emit a fake event to the registered callback for [channel].
  void emit(String channel, WebSocketEvent event) {
    _callbacks[channel]?.call(event);
  }
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

WebSocketEvent _textEvent({String content = 'Hello!'}) {
  return WebSocketEvent(
    id: 'ws-evt-${DateTime.now().microsecondsSinceEpoch}',
    channel: 'private-conversation.$kConversationId',
    eventName: '.conversation.message',
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpClient http;
  late _FakeWebSocket ws;
  late ConversationChatState state;

  setUp(() {
    http = _FakeHttpClient();
    ws = _FakeWebSocket();
    state = ConversationChatState(httpClient: http, webSocket: ws);
  });

  tearDown(() {
    state.reset();
  });

  /// Helper: create a conversation so the state is in "active" mode.
  Future<void> createConversation() async {
    http.responder = (url) {
      if (url.contains('/conversations') && !url.contains('/messages')) {
        return _createConversationResponse();
      }
      if (url.contains('/messages')) return _messagesResponse();
      return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
    };

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

      expect(
        ws.subscribedChannels,
        contains('private-conversation.$kConversationId'),
      );
    });

    test('resubscribe re-subscribes to conversation channel', () async {
      await createConversation();
      ws.subscribedChannels.clear();

      state.resubscribe();

      expect(
        ws.subscribedChannels,
        contains('private-conversation.$kConversationId'),
      );
    });

    test('resubscribe is a no-op when conversation is null', () {
      state.resubscribe();

      expect(ws.subscribedChannels, isEmpty);
    });

    test(
      'unsubscribeChannels unsubscribes from conversation channel',
      () async {
        await createConversation();

        state.unsubscribeChannels();

        expect(
          ws.unsubscribedChannels,
          contains('private-conversation.$kConversationId'),
        );
      },
    );

    test('reset unsubscribes and clears conversation data', () async {
      await createConversation();

      state.reset();

      expect(
        ws.unsubscribedChannels,
        contains('private-conversation.$kConversationId'),
      );
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
          WebSocketEvent(
            id: 'ws-status-1',
            channel: 'private-conversation.$kConversationId',
            eventName: '.conversation.status',
            data: {
              'conversation_id': kConversationId,
              'status': 'active',
              'session_id': 'session-uuid-001',
            },
            receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
          ),
        );

        ws.subscribedChannels.clear();
        state.resubscribe();

        expect(
          ws.subscribedChannels,
          containsAll([
            'private-conversation.$kConversationId',
            'private-session.session-uuid-001',
          ]),
        );
      },
    );
  });

  // -----------------------------------------------------------------------
  // Route-change subscription resilience (the core bug fix)
  // -----------------------------------------------------------------------

  group('route-change subscription resilience', () {
    test('resubscribe followed by unsubscribeChannels simulates the old bug — '
        'events stop arriving', () async {
      await createConversation();

      // Simulate route change: new widget calls resubscribe, old widget
      // calls unsubscribeChannels (the OLD broken behavior).
      state.resubscribe();
      state.unsubscribeChannels();

      // The WS callback should be gone because unsubscribe ran after.
      expect(ws.hasCallback('private-conversation.$kConversationId'), isFalse);
    });

    test(
      'resubscribe without unsubscribeChannels keeps events flowing (the fix)',
      () async {
        await createConversation();

        // Simulate the FIXED behavior: new widget calls resubscribe,
        // old widget does NOT call unsubscribeChannels in dispose.
        state.resubscribe();

        // The WS callback should still be active.
        expect(ws.hasCallback('private-conversation.$kConversationId'), isTrue);

        // Events should still be processed.
        ws.emit(
          'private-conversation.$kConversationId',
          _textEvent(content: 'After route change'),
        );

        expect(state.chatItems, hasLength(1));
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
        WebSocketEvent(
          id: 'ws-null',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
        WebSocketEvent(
          id: 'ws-status',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.status',
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
        WebSocketEvent(
          id: 'ws-think',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
        WebSocketEvent(
          id: 'ws-result',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
        WebSocketEvent(
          id: 'ws-system',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
        WebSocketEvent(
          id: 'ws-tu',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
        WebSocketEvent(
          id: 'ws-tr',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
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
      http.responder = (url) {
        if (url.contains('/conversations') && !url.contains('/messages')) {
          return _loadConversationResponse();
        }
        if (url.contains('/messages')) return _messagesResponse();
        return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
      };

      await state.loadConversation(kTeamId, kProjectId, kConversationId);

      expect(state.conversation, isNotNull);
      expect(state.conversation?.id, kConversationId);
      expect(
        ws.subscribedChannels,
        contains('private-conversation.$kConversationId'),
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
      expect(http.calls, isEmpty);
    });

    test('guards against concurrent sends', () async {
      await createConversation();

      http.responder = (url) {
        return MagicResponse(data: <String, dynamic>{}, statusCode: 200);
      };

      // Start first send.
      final first = state.sendMessage('Hello');
      // isSending should be true now — second send should be blocked.
      final second = state.sendMessage('World');
      await Future.wait([first, second]);

      // Only one POST to messages endpoint.
      final messagePosts = http.calls
          .where((c) => c.contains('/messages'))
          .toList();
      expect(messagePosts, hasLength(1));
    });

    test('optimistic message appended immediately', () async {
      await createConversation();

      http.responder = (url) {
        return MagicResponse(data: <String, dynamic>{}, statusCode: 200);
      };

      await state.sendMessage('Quick question');

      expect(state.chatItems, hasLength(1));
      expect(state.isSending, isFalse);
      expect(state.awaitingResponse, isTrue);
    });
  });
}
