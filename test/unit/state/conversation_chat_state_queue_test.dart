import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/chat_item.dart';
import 'package:app/app/state/conversation_chat_state.dart';

// ---------------------------------------------------------------------------
// Fake WebSocket
// ---------------------------------------------------------------------------

class _FakeWebSocket implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];
  final Map<String, void Function(BroadcastEvent)> _callbacks = {};
  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnect => _reconnectController.stream;

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {
    subscribedChannels.add(channel);
    _callbacks[channel] = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
    _callbacks.remove(channel);
  }

  void emit(String channel, BroadcastEvent event) {
    _callbacks[channel]?.call(event);
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kTeamId = 'team-uuid-001';
const String kProjectId = 'proj-uuid-001';
const String kConversationId = 'conv-uuid-001';

MagicResponse _executingConversationResponse() {
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
        'is_executing': true,
      },
    },
    statusCode: 200,
  );
}

MagicResponse _messagesResponse() {
  return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
}

MagicResponse _queuedMessageResponse({String messageId = 'msg-1'}) {
  return MagicResponse(
    data: {
      'data': {
        'id': messageId,
        'conversation_id': kConversationId,
        'role': 'user',
        'content': 'hello',
        'status': 'queued',
        'created_at': '2026-03-27T10:01:00.000Z',
      },
    },
    statusCode: 200,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late FakeNetworkDriver driver;
  late _FakeWebSocket ws;
  late ConversationChatState state;

  setUp(() {
    driver = Http.fake();
    ws = _FakeWebSocket();
    state = ConversationChatState(webSocket: ws);
  });

  /// Helper: load an executing conversation so isAgentRunning is true.
  Future<void> loadExecutingConversation() async {
    driver.stub('*/conversations/*', _executingConversationResponse());
    driver.stub('*/messages', _messagesResponse());

    await state.loadConversation(kTeamId, kProjectId, kConversationId);
  }

  // -----------------------------------------------------------------------
  // sendMessage while isAgentRunning adds to queuedMessageIds
  // -----------------------------------------------------------------------

  group('queued message support', () {
    test('sendMessage while isAgentRunning adds to queuedMessageIds '
        'when API returns status=queued', () async {
      await loadExecutingConversation();
      expect(state.isAgentRunning, isTrue);

      // Stub the POST /messages call to return queued.
      driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-1'));

      await state.sendMessage('hello');

      expect(state.queuedCount, equals(1));
      expect(state.queuedMessageIds, contains('msg-1'));
    });

    // ---------------------------------------------------------------------
    // message_status WebSocket event updates message status in timeline
    // ---------------------------------------------------------------------

    test(
      'message_status WebSocket event updates message status in timeline',
      () async {
        await loadExecutingConversation();
        final channel = 'conversation.$kConversationId';

        // Stub the POST /messages call to return queued message.
        driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-1'));

        await state.sendMessage('hello');
        expect(state.queuedMessageIds, contains('msg-1'));

        // Simulate message_status WS event.
        ws.emit(
          channel,
          BroadcastEvent(
            channel: channel,
            event: '.conversation.message',
            data: {
              'conversation_id': kConversationId,
              'type': 'message_status',
              'content': null,
              'metadata': {
                'message_id': 'msg-1',
                'message_status': 'delivering',
              },
              'occurred_at': '2026-03-27T10:02:00.000Z',
            },
            receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
          ),
        );

        // Message should have updated status and be removed from queued set.
        final messageItem = state.chatItems
            .whereType<ChatMessageItem>()
            .where((item) => item.message.id == 'msg-1')
            .firstOrNull;
        expect(messageItem, isNotNull);
        expect(messageItem!.message.status, equals('delivering'));
        expect(state.queuedMessageIds, isNot(contains('msg-1')));
      },
    );

    // ---------------------------------------------------------------------
    // cancelQueuedMessage removes from queuedMessageIds and POSTs
    // ---------------------------------------------------------------------

    test(
      'cancelQueuedMessage removes from queuedMessageIds and POSTs to cancel endpoint',
      () async {
        await loadExecutingConversation();

        // Send a queued message first.
        driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-1'));

        await state.sendMessage('hello');
        expect(state.queuedMessageIds, contains('msg-1'));

        // Stub the cancel endpoint.
        driver.stub(
          '*/cancel',
          MagicResponse(data: <String, dynamic>{}, statusCode: 200),
        );
        await state.cancelQueuedMessage('msg-1');

        expect(state.queuedMessageIds, isEmpty);
        driver.assertSent((r) => r.url.toString().contains('/cancel'));

        // The ChatMessageItem should have status 'cancelled'.
        final messageItem = state.chatItems
            .whereType<ChatMessageItem>()
            .where((item) => item.message.id == 'msg-1')
            .firstOrNull;
        expect(messageItem, isNotNull);
        expect(messageItem!.message.status, equals('cancelled'));
      },
    );

    // ---------------------------------------------------------------------
    // queuedCount getter returns correct count
    // ---------------------------------------------------------------------

    test('queuedCount getter returns correct count', () async {
      await loadExecutingConversation();

      // First message returns msg-1.
      driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-1'));
      await state.sendMessage('first');

      // Second message returns msg-2.
      driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-2'));
      await state.sendMessage('second');
      expect(state.queuedCount, equals(2));

      // Cancel one.
      driver.stub(
        '*/cancel',
        MagicResponse(data: <String, dynamic>{}, statusCode: 200),
      );
      await state.cancelQueuedMessage('msg-1');
      expect(state.queuedCount, equals(1));
    });

    // ---------------------------------------------------------------------
    // reset clears queuedMessageIds
    // ---------------------------------------------------------------------

    test('reset clears queuedMessageIds', () async {
      await loadExecutingConversation();

      driver.stub('*/messages', _queuedMessageResponse(messageId: 'msg-1'));

      await state.sendMessage('hello');
      expect(state.queuedCount, equals(1));

      state.reset();
      expect(state.queuedCount, equals(0));
    });
  });
}
