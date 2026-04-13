import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/realtime/realtime_channel_manager.dart';
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
// WebSocket event fixtures
// ---------------------------------------------------------------------------

BroadcastEvent _questionEvent() => BroadcastEvent(
  channel: 'private-conversation.conv-uuid-001',
  event: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'question',
    'content': null,
    'metadata': {
      'questionId': 'q-uuid-001',
      'message': 'Which framework do you prefer?',
      'requestedSchema': null,
    },
    'occurred_at': '2026-03-27T10:03:01.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 3, 1),
);

BroadcastEvent _permissionEvent() => BroadcastEvent(
  channel: 'private-conversation.conv-uuid-001',
  event: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'permission',
    'content': null,
    'metadata': {
      'questionId': 'p-uuid-001',
      'toolName': 'Bash',
      'input': {'command': 'rm -rf /tmp/build'},
    },
    'occurred_at': '2026-03-27T10:04:00.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 4),
);

BroadcastEvent _nonAskToolUseEvent() => BroadcastEvent(
  channel: 'private-conversation.conv-uuid-001',
  event: '.conversation.message',
  data: {
    'conversation_id': 'conv-uuid-001',
    'type': 'tool_use',
    'content': null,
    'metadata': {
      'toolUseId': 'toolu_yyy',
      'toolName': 'Bash',
      'input': {'command': 'ls -la'},
    },
    'occurred_at': '2026-03-27T10:05:00.000Z',
  },
  receivedAt: DateTime.utc(2026, 3, 27, 10, 5),
);

// ---------------------------------------------------------------------------
// Helper: set up state with active conversation
// ---------------------------------------------------------------------------

Future<ConversationChatState> _setupWithConversation(
  FakeNetworkDriver driver,
  RealtimeChannelManager manager,
) async {
  driver.stub('*/agent-roles*', Http.response(kAgentRolesResponse));
  driver.stub('*/answer', Http.response({}));
  driver.stub('*/messages', Http.response({}, 202));
  driver.stub('*/conversations*', Http.response(kConversationResponse, 201));

  final state = ConversationChatState(manager: manager);
  await state.createConversation(
    'team-uuid-001',
    'proj-uuid-001',
    agentRoleId: 'role-uuid-001',
  );
  driver.recorded.clear();

  return state;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('ConversationChatState – question/permission detection', () {
    late FakeNetworkDriver driver;
    late FakeBroadcastManager fake;
    late RealtimeChannelManager manager;
    late ConversationChatState state;

    setUp(() async {
      driver = Http.fake();
      fake = Echo.fake();
      manager = RealtimeChannelManager(broadcaster: fake);
      state = await _setupWithConversation(driver, manager);
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
    // 2. question event stores pending question with null options (MCP path)
    // -----------------------------------------------------------------------

    test('question event stores pending question', () {
      state.addEvent(_questionEvent());

      expect(state.pendingQuestion, isNotNull);
      expect(state.pendingQuestion!['questionId'], equals('q-uuid-001'));
      expect(
        state.pendingQuestion!['message'],
        equals('Which framework do you prefer?'),
      );
      // Options come from MCP pendingQuestionPayload, not from tool_use events.
      expect(state.pendingQuestion!['options'], isNull);

      // Should NOT append as a chat message.
      expect(state.messages, isEmpty);
      expect(state.rawEvents.length, equals(1));
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
    // 6. tool_use event does not affect question/permission state
    // -----------------------------------------------------------------------

    test('tool_use event does not affect question or permission state', () {
      state.addEvent(_nonAskToolUseEvent());

      // Should not affect pending state.
      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      // tool_use with null content should not append a message.
      expect(state.messages, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 7. answerQuestion success clears pending state
    // -----------------------------------------------------------------------

    test('answerQuestion posts answer and clears pending state', () async {
      state.addEvent(_questionEvent());
      expect(state.pendingQuestion, isNotNull);

      await state.answerQuestion('q-uuid-001', 'Flutter');

      // Pending state cleared.
      expect(state.pendingQuestion, isNull);
      expect(state.pendingPermission, isNull);
      expect(state.isAnswering, isFalse);

      // Verify POST call.
      driver.assertSent((r) => r.method == 'POST' && r.url.contains('/answer'));

      final answerRequest = driver.recorded
          .where((r) => r.$1.method == 'POST' && r.$1.url.contains('/answer'))
          .first
          .$1;
      expect(
        answerRequest.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/conversations/conv-uuid-001/answer',
        ),
      );
      final body = answerRequest.data as Map<String, dynamic>;
      expect(body['question_id'], equals('q-uuid-001'));
      expect(body['answer_text'], equals('Flutter'));
    });

    // -----------------------------------------------------------------------
    // 8. answerQuestion failure sets error
    // -----------------------------------------------------------------------

    test('answerQuestion failure sets error', () async {
      // Override responder to fail on answer.
      driver.stub('*/answer', Http.response({'message': 'Server Error'}, 500));

      state.addEvent(_questionEvent());
      await state.answerQuestion('q-uuid-001', 'Flutter');

      expect(state.error, isNotNull);
      expect(state.isAnswering, isFalse);
    });

    // -----------------------------------------------------------------------
    // 9. answerQuestion guards: no conversation
    // -----------------------------------------------------------------------

    test('answerQuestion does nothing without a conversation', () async {
      final noConvState = ConversationChatState(manager: manager);

      await noConvState.answerQuestion('q-uuid-001', 'Flutter');

      // No POST calls should have been made.
      driver.assertNotSent(
        (r) => r.method == 'POST' && r.url.contains('/answer'),
      );
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

      final answerCalls = driver.recorded
          .where((r) => r.$1.method == 'POST' && r.$1.url.contains('/answer'))
          .toList();
      expect(answerCalls.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 11. reset clears pending question/permission state
    // -----------------------------------------------------------------------

    test('reset clears pending question and permission state', () {
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
      final statusEvent = BroadcastEvent(
        channel: 'private-conversation.conv-uuid-001',
        event: '.conversation.status',
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
