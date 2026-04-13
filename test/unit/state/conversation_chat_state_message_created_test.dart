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
const String kMessageId = 'msg-system-dispatch-001';

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
        'title': 'Test Conversation',
        'status': 'active',
        'model': 'claude-sonnet-4-6',
        'total_cost_usd': '0.00',
        'total_input_tokens': 0,
        'total_output_tokens': 0,
        'messages_count': 0,
        'last_activity_at': '2026-04-13T10:00:00.000Z',
        'started_at': '2026-04-13T09:55:00.000Z',
        'completed_at': null,
        'created_at': '2026-04-13T09:55:00.000Z',
        'updated_at': '2026-04-13T10:00:00.000Z',
        'is_executing': false,
      },
    },
    statusCode: 200,
  );
}

MagicResponse _messagesResponse() {
  return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
}

BroadcastEvent _messageCreatedEvent({
  String messageId = kMessageId,
  String content = 'Run the test suite now.',
}) {
  final channel = 'conversation.$kConversationId';
  return BroadcastEvent(
    channel: channel,
    event: '.conversation.message',
    data: {
      'conversation_id': kConversationId,
      'type': 'message_created',
      'content': content,
      'metadata': {
        'kind': 'system_dispatch',
        'message': {
          'id': messageId,
          'conversation_id': kConversationId,
          'role': 'user',
          'content': content,
          'status': 'sent',
          'metadata': {'kind': 'system_dispatch'},
          'created_at': '2026-04-13T10:01:00.000Z',
        },
      },
      'occurred_at': '2026-04-13T10:01:00.000Z',
    },
    receivedAt: DateTime.utc(2026, 4, 13, 10, 1),
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

  Future<void> loadConversation() async {
    driver.stub('*/conversations/*', _loadConversationResponse());
    driver.stub('*/messages', _messagesResponse());
    await state.loadConversation(kTeamId, kProjectId, kConversationId);
  }

  group('message_created WebSocket event', () {
    // -----------------------------------------------------------------------
    // Appends a ChatMessageItem from the broadcast payload
    // -----------------------------------------------------------------------

    test('appends ChatMessageItem with correct id and kind metadata', () async {
      await loadConversation();
      expect(state.chatItems, isEmpty);

      final channel = 'conversation.$kConversationId';
      ws.emit(channel, _messageCreatedEvent());

      final messageItems = state.chatItems.whereType<ChatMessageItem>();
      expect(messageItems.length, equals(1));

      final item = messageItems.first;
      expect(item.message.id, equals(kMessageId));
      expect(item.message.metadata?['kind'], equals('system_dispatch'));
    });

    // -----------------------------------------------------------------------
    // Dedup: same event twice — only one item in timeline
    // -----------------------------------------------------------------------

    test(
      'dispatching the same event twice does not duplicate the ChatMessageItem',
      () async {
        await loadConversation();

        final channel = 'conversation.$kConversationId';
        ws.emit(channel, _messageCreatedEvent());
        ws.emit(channel, _messageCreatedEvent());

        final messageItems = state.chatItems.whereType<ChatMessageItem>();
        expect(messageItems.length, equals(1));
      },
    );

    // -----------------------------------------------------------------------
    // Dedup: id already present — not duplicated
    // -----------------------------------------------------------------------

    test(
      'dispatching a message_created whose id already exists is not duplicated',
      () async {
        await loadConversation();

        final channel = 'conversation.$kConversationId';

        // First dispatch seeds the item.
        ws.emit(channel, _messageCreatedEvent(messageId: kMessageId));
        expect(state.chatItems.whereType<ChatMessageItem>().length, equals(1));

        // Second dispatch with same id must not add a duplicate.
        ws.emit(channel, _messageCreatedEvent(messageId: kMessageId));
        expect(state.chatItems.whereType<ChatMessageItem>().length, equals(1));
      },
    );
  });
}
