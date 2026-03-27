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

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeHttpClient implements ConversationChatHttpClient {
  final List<_HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('GET', url));
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
  _HttpCall(this.method, this.url, {this.data});

  final String method;
  final String url;
  final dynamic data;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Fake WebSocket service
// ---------------------------------------------------------------------------

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

  void simulateEvent(String channel, WebSocketEvent event) {
    callbacks[channel]?.call(event);
  }
}

// ---------------------------------------------------------------------------
// WebSocket event fixtures
// ---------------------------------------------------------------------------

WebSocketEvent _toolUseEvent() => WebSocketEvent(
  id: 'ws:tool:1',
  channel: 'private-conversation.conv-uuid-001',
  eventName: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'tool_use',
    'content': null,
    'metadata': {
      'type': 'tool_use',
      'session_id': 'sess-001',
      'data': {
        'toolUseId': 'toolu_xxx',
        'toolName': 'AskUserQuestion',
        'input': {
          'questions': [
            {
              'question': 'Which framework?',
              'header': 'Framework Selection',
              'multiSelect': false,
              'options': [
                {'label': 'Flutter', 'description': 'Cross-platform'},
                {'label': 'React Native', 'description': 'JS-based'},
              ],
            },
          ],
        },
      },
    },
    'occurred_at': '2026-03-27T10:03:00.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 3),
);

WebSocketEvent _questionEvent() => WebSocketEvent(
  id: 'ws:question:1',
  channel: 'private-conversation.conv-uuid-001',
  eventName: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'question',
    'content': null,
    'metadata': {
      'type': 'question',
      'session_id': 'sess-001',
      'data': {
        'questionId': 'q-uuid-001',
        'message': 'Which framework do you prefer?',
        'requestedSchema': null,
      },
    },
    'occurred_at': '2026-03-27T10:03:01.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 3, 1),
);

WebSocketEvent _permissionEvent() => WebSocketEvent(
  id: 'ws:permission:1',
  channel: 'private-conversation.conv-uuid-001',
  eventName: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'permission',
    'content': null,
    'metadata': {
      'type': 'permission',
      'session_id': 'sess-001',
      'data': {
        'questionId': 'p-uuid-001',
        'toolName': 'Bash',
        'input': {'command': 'rm -rf /tmp/build'},
      },
    },
    'occurred_at': '2026-03-27T10:04:00.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 4),
);

WebSocketEvent _nonAskToolUseEvent() => WebSocketEvent(
  id: 'ws:tool:2',
  channel: 'private-conversation.conv-uuid-001',
  eventName: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'tool_use',
    'content': null,
    'metadata': {
      'type': 'tool_use',
      'session_id': 'sess-001',
      'data': {
        'toolUseId': 'toolu_yyy',
        'toolName': 'Bash',
        'input': {'command': 'ls -la'},
      },
    },
    'occurred_at': '2026-03-27T10:05:00.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 5),
);

// ---------------------------------------------------------------------------
// Helper: set up state with active conversation
// ---------------------------------------------------------------------------

Future<ConversationChatState> _setupWithConversation(
  _FakeHttpClient http,
  _FakeWebSocketService ws,
) async {
  http.whenAny((url) {
    if (url.contains('/agent-roles')) {
      return MagicResponse(data: kAgentRolesResponse, statusCode: 200);
    }
    if (url.contains('/answer')) {
      return MagicResponse(data: {}, statusCode: 200);
    }
    if (url.contains('/messages')) {
      return MagicResponse(data: {}, statusCode: 202);
    }
    return MagicResponse(data: kConversationResponse, statusCode: 201);
  });

  final state = ConversationChatState(httpClient: http, webSocket: ws);
  await state.createConversation('team-uuid-001', 'proj-uuid-001');
  http.calls.clear();

  return state;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConversationChatState – question/permission detection', () {
    late _FakeHttpClient http;
    late _FakeWebSocketService ws;
    late ConversationChatState state;

    setUp(() async {
      http = _FakeHttpClient();
      ws = _FakeWebSocketService();
      state = await _setupWithConversation(http, ws);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. Initial pending state is null
    // -----------------------------------------------------------------------

    test('initial pending question and permission are null', () {
      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      expect(state.isAnswering, isFalse);
    });

    // -----------------------------------------------------------------------
    // 2. tool_use with AskUserQuestion stores pending options
    // -----------------------------------------------------------------------

    test('tool_use with AskUserQuestion stores pending options', () {
      state.addEvent(_toolUseEvent());

      // Options are stored internally but not yet surfaced as a question.
      // The question event correlates them.
      expect(state.pendingQuestion, isNull);
      // The tool_use should NOT be appended as a chat message.
      expect(state.messages, isEmpty);
      // Raw events are still recorded.
      expect(state.rawEvents.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 3. question event stores pending question with correlated options
    // -----------------------------------------------------------------------

    test('question event stores pending question with correlated options', () {
      // First: tool_use with options.
      state.addEvent(_toolUseEvent());
      // Then: question event.
      state.addEvent(_questionEvent());

      expect(state.pendingQuestion, isNotNull);
      expect(state.pendingQuestion!['questionId'], equals('q-uuid-001'));
      expect(
        state.pendingQuestion!['message'],
        equals('Which framework do you prefer?'),
      );
      expect(state.pendingQuestion!['options'], isNotNull);
      expect(state.pendingQuestion!['options'], isList);

      // Should NOT append as a chat message.
      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(2));
    });

    // -----------------------------------------------------------------------
    // 4. question event without preceding tool_use has null options
    // -----------------------------------------------------------------------

    test('question event without tool_use has null options', () {
      state.addEvent(_questionEvent());

      expect(state.pendingQuestion, isNotNull);
      expect(state.pendingQuestion!['questionId'], equals('q-uuid-001'));
      expect(state.pendingQuestion!['options'], isNull);
    });

    // -----------------------------------------------------------------------
    // 5. permission event stores pending permission
    // -----------------------------------------------------------------------

    test('permission event stores pending permission', () {
      state.addEvent(_permissionEvent());

      expect(state.pendingPermission, isNotNull);
      expect(state.pendingPermission!['questionId'], equals('p-uuid-001'));
      expect(state.pendingPermission!['toolName'], equals('Bash'));
      expect(state.pendingPermission!['input'], isMap);
      expect(
        (state.pendingPermission!['input'] as Map)['command'],
        equals('rm -rf /tmp/build'),
      );

      // Should NOT append as a chat message.
      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 6. non-AskUserQuestion tool_use is not stored as pending options
    // -----------------------------------------------------------------------

    test('non-AskUserQuestion tool_use does not store pending options', () {
      state.addEvent(_nonAskToolUseEvent());

      // Should not affect pending state.
      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      // Non-ask tool_use with null content should not append a message.
      expect(state.messages, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 7. answerQuestion success clears pending state
    // -----------------------------------------------------------------------

    test('answerQuestion posts answer and clears pending state', () async {
      state.addEvent(_toolUseEvent());
      state.addEvent(_questionEvent());
      expect(state.pendingQuestion, isNotNull);

      await state.answerQuestion('q-uuid-001', 'Flutter');

      // Pending state cleared.
      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      expect(state.isAnswering, isFalse);

      // Verify POST call.
      final answerCalls = http.calls
          .where((c) => c.method == 'POST' && c.url.contains('/answer'))
          .toList();
      expect(answerCalls.length, equals(1));
      expect(
        answerCalls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/answer',
        ),
      );
      final body = answerCalls.first.data as Map<String, dynamic>;
      expect(body['question_id'], equals('q-uuid-001'));
      expect(body['answer_text'], equals('Flutter'));
    });

    // -----------------------------------------------------------------------
    // 8. answerQuestion failure sets error
    // -----------------------------------------------------------------------

    test('answerQuestion failure sets error', () async {
      // Override responder to fail on answer.
      http.whenAny((url) {
        if (url.contains('/answer')) {
          return MagicResponse(
            data: {'message': 'Server Error'},
            statusCode: 500,
          );
        }
        return MagicResponse(data: {}, statusCode: 200);
      });

      state.addEvent(_questionEvent());
      await state.answerQuestion('q-uuid-001', 'Flutter');

      expect(state.error, isNotNull);
      expect(state.isAnswering, isFalse);
    });

    // -----------------------------------------------------------------------
    // 9. answerQuestion guards: no conversation
    // -----------------------------------------------------------------------

    test('answerQuestion does nothing without a conversation', () async {
      final noConvState = ConversationChatState(
        httpClient: http,
        webSocket: ws,
      );

      await noConvState.answerQuestion('q-uuid-001', 'Flutter');

      // No POST calls should have been made.
      expect(http.calls, isEmpty);
      noConvState.dispose();
    });

    // -----------------------------------------------------------------------
    // 10. answerQuestion guards: already answering
    // -----------------------------------------------------------------------

    test('answerQuestion ignores concurrent calls', () async {
      state.addEvent(_questionEvent());

      final first = state.answerQuestion('q-uuid-001', 'Flutter');
      final second = state.answerQuestion('q-uuid-001', 'React');
      await Future.wait([first, second]);

      final answerCalls = http.calls
          .where((c) => c.method == 'POST' && c.url.contains('/answer'))
          .toList();
      expect(answerCalls.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 11. reset clears pending question/permission state
    // -----------------------------------------------------------------------

    test('reset clears pending question and permission state', () {
      state.addEvent(_toolUseEvent());
      state.addEvent(_questionEvent());
      state.addEvent(_permissionEvent());

      expect(state.pendingQuestion, isNotNull);
      expect(state.pendingPermission, isNotNull);

      state.reset();

      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      expect(state.isAnswering, isFalse);
    });

    // -----------------------------------------------------------------------
    // 12. paused status handled automatically
    // -----------------------------------------------------------------------

    test('paused status from status event updates conversation', () {
      final statusEvent = WebSocketEvent(
        id: 'ws:status:paused',
        channel: 'private-conversation.conv-uuid-001',
        eventName: '.conversation.status',
        data: {
          'conversation_id': 'conv-uuid-001',
          'status': 'paused',
          'warm_until': '2026-03-27T10:15:00.000Z',
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 10),
      );

      state.addEvent(statusEvent);

      expect(state.conversation!.status, equals('paused'));
      expect(state.warmUntil, equals('2026-03-27T10:15:00.000Z'));
    });
  });
}
