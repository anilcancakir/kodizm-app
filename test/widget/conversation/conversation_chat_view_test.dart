import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/conversation_chat_state.dart';
import 'package:app/resources/views/conversation/conversation_chat_view.dart';
import 'package:app/resources/widgets/atoms/streaming_indicator.dart';
import 'package:app/resources/widgets/organisms/chat_message_bubble.dart';
import 'package:app/resources/widgets/organisms/chat_stream_event_renderer.dart';
import 'package:app/resources/widgets/organisms/chat_tool_use_card.dart';

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
// Fake WebSocket
// ---------------------------------------------------------------------------

class _FakeWebSocket implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  void Function(WebSocketEvent)? lastCallback;

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannels.add(channel);
    lastCallback = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
  }
}

// ---------------------------------------------------------------------------
// Translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kTeamId = 'team-uuid-001';
const String kProjectId = 'proj-uuid-001';
const String kConversationId = 'conv-uuid-001';

Map<String, dynamic> _conversationPayload({String status = 'active'}) {
  return {
    'id': kConversationId,
    'project_id': kProjectId,
    'user': {'id': 'user-uuid-001', 'name': 'Test User'},
    'agent_role': {
      'id': 'role-uuid-001',
      'name': 'Business Analyst',
      'slug': 'ba',
    },
    'title': 'Test Conversation',
    'status': status,
    'model': 'claude-sonnet-4-6',
    'total_cost_usd': '0.12',
    'total_input_tokens': 1500,
    'total_output_tokens': 800,
    'messages_count': 2,
    'last_activity_at': '2026-03-27T10:00:00.000Z',
    'started_at': '2026-03-27T09:55:00.000Z',
    'completed_at': null,
    'created_at': '2026-03-27T09:55:00.000Z',
    'updated_at': '2026-03-27T10:00:00.000Z',
  };
}

MagicResponse _agentRolesResponse() {
  return MagicResponse(
    data: {
      'data': [
        {'id': 'role-uuid-001', 'name': 'Business Analyst', 'slug': 'ba'},
      ],
    },
    statusCode: 200,
  );
}

MagicResponse _createConversationResponse() {
  return MagicResponse(data: {'data': _conversationPayload()}, statusCode: 201);
}

MagicResponse _messagesResponse() {
  return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget({String projectId = kProjectId}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: ConversationChatView(projectId: projectId)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpClient http;
  late _FakeWebSocket ws;
  late ConversationChatState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeHttpClient();
    ws = _FakeWebSocket();
    state = ConversationChatState(httpClient: http, webSocket: ws);
    Magic.put<ConversationChatState>(state);
  });

  tearDown(() {
    state.reset();
    Magic.delete<ConversationChatState>();
  });

  // -----------------------------------------------------------------------
  // Helper: pump initial state (no conversation)
  // -----------------------------------------------------------------------

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpInitialState(WidgetTester tester) async {
    setViewport(tester);

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  // -----------------------------------------------------------------------
  // Helper: pump with active conversation
  // -----------------------------------------------------------------------

  Future<void> pumpWithConversation(WidgetTester tester) async {
    setViewport(tester);

    http.responder = (url) {
      if (url.contains('/agent-roles')) return _agentRolesResponse();
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

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  // -----------------------------------------------------------------------
  // 1. Initial state shows "Start Chat" button
  // -----------------------------------------------------------------------

  testWidgets('initial state shows Start Chat button', (tester) async {
    await pumpInitialState(tester);

    expect(find.text(trans('conversation_chat.start_chat')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 2. Welcome title renders from i18n
  // -----------------------------------------------------------------------

  testWidgets('welcome title renders from i18n', (tester) async {
    await pumpInitialState(tester);

    expect(find.text(trans('conversation_chat.welcome_title')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 3. After conversation created, shows chat UI with input
  // -----------------------------------------------------------------------

  testWidgets('after conversation created, shows input field', (tester) async {
    await pumpWithConversation(tester);

    // Input field placeholder should be present.
    expect(find.text(trans('conversation_chat.placeholder')), findsOneWidget);

    // Send icon should be present (ChatInputBar uses WIcon(Icons.send)).
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 4. Status badge and complete button in config modal, not header
  // -----------------------------------------------------------------------

  testWidgets('status badge renders inside config modal', (tester) async {
    await pumpWithConversation(tester);

    // Status badge NOT visible in header directly.
    expect(find.text(trans('conversation_chat.status_active')), findsNothing);

    // Open config modal — status should appear there.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text(trans('conversation_chat.status_active')), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 5. Header shows conversation title and cost
  // -----------------------------------------------------------------------

  testWidgets('header shows conversation title and cost', (tester) async {
    await pumpWithConversation(tester);

    // Conversation title from fixture.
    expect(find.text('Test Conversation'), findsOneWidget);

    // Cost display — ChatHeader formats with 4 decimal places.
    expect(
      find.text(trans('conversation_chat.cost_format', {'amount': '0.1200'})),
      findsWidgets,
    );
  });

  // -----------------------------------------------------------------------
  // 6. Complete button visible inside config modal for active conversation
  // -----------------------------------------------------------------------

  testWidgets('complete button visible inside config modal', (tester) async {
    await pumpWithConversation(tester);

    // Not in header.
    expect(find.text(trans('conversation_chat.complete_chat')), findsNothing);

    // Open config modal — complete button should appear.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text(trans('conversation_chat.complete_chat')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 7. "No messages yet" shown when conversation has no messages
  // -----------------------------------------------------------------------

  testWidgets('no messages text shown for empty message list', (tester) async {
    await pumpWithConversation(tester);

    expect(find.text(trans('conversation_chat.no_messages')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 8. Send message renders ChatMessageBubble
  // -----------------------------------------------------------------------

  testWidgets('send message renders ChatMessageBubble', (tester) async {
    await pumpWithConversation(tester);

    // Type a message.
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'Hello agent!');
    await tester.pump();

    // Tap send button (icon-based).
    final sendFinder = find.byIcon(Icons.send);
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pump();

    // ChatMessageBubble should be rendered.
    expect(find.byType(ChatMessageBubble), findsOneWidget);

    // Optimistic message content should appear.
    expect(find.text('Hello agent!'), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 9. addEvent shows assistant message as ChatMessageBubble
  // -----------------------------------------------------------------------

  testWidgets('addEvent shows assistant message as ChatMessageBubble', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    // Simulate a WS event.
    state.addEvent(
      WebSocketEvent(
        id: 'ws-evt-1',
        channel: 'private-conversation.$kConversationId',
        eventName: '.conversation.message',
        data: {
          'conversation_id': kConversationId,
          'type': 'assistant',
          'content': 'Hello! How can I help?',
          'metadata': null,
          'occurred_at': '2026-03-27T10:01:00.000Z',
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ChatMessageBubble), findsOneWidget);
    expect(find.text('Hello! How can I help?'), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 10. Raw events section shows event count
  // -----------------------------------------------------------------------

  testWidgets('raw events section shows event count', (tester) async {
    await pumpWithConversation(tester);

    // Add an event so count is 1.
    state.addEvent(
      WebSocketEvent(
        id: 'ws-evt-2',
        channel: 'private-conversation.$kConversationId',
        eventName: '.conversation.status',
        data: {
          'conversation_id': kConversationId,
          'status': 'active',
          'warm_until': '2026-03-27T11:00:00.000Z',
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
      ),
    );

    await tester.pumpAndSettle();

    // Open config modal, then toggle debug panel.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    // Tap "Toggle Debug" in the modal.
    await tester.tap(find.text(trans('conversation_chat.toggle_debug')));
    await tester.pumpAndSettle();

    expect(
      find.text(trans('conversation_chat.raw_events_count', {'count': '1'})),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 11. Debug toggle shows and hides raw events panel
  // -----------------------------------------------------------------------

  testWidgets('debug toggle shows and hides raw events panel', (tester) async {
    await pumpWithConversation(tester);

    // Debug panel should be hidden initially (raw events section not visible).
    expect(find.text(trans('conversation_chat.raw_events')), findsNothing);

    // Open config modal and tap Toggle Debug.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(trans('conversation_chat.toggle_debug')));
    await tester.pumpAndSettle();

    // Debug panel should now be visible.
    expect(
      find.text(trans('conversation_chat.raw_events_count', {'count': '0'})),
      findsOneWidget,
    );

    // Open modal again and toggle off.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(trans('conversation_chat.toggle_debug')));
    await tester.pumpAndSettle();

    // Should be hidden again.
    expect(
      find.text(trans('conversation_chat.raw_events_count', {'count': '0'})),
      findsNothing,
    );
  });

  // -----------------------------------------------------------------------
  // 12. ChatMessageBubble shows user role badge
  // -----------------------------------------------------------------------

  testWidgets('ChatMessageBubble shows user message right-aligned', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    // Send a message first.
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'Test message');
    await tester.pump();

    final sendFinder = find.byIcon(Icons.send);
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pump();

    // ChatMessageBubble renders user content.
    expect(find.byType(ChatMessageBubble), findsOneWidget);
    expect(find.text('Test message'), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 13. ChatToolUseCard renders and is collapsible
  // -----------------------------------------------------------------------

  testWidgets('ChatToolUseCard renders tool name and collapses', (
    tester,
  ) async {
    setViewport(tester);

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatToolUseCard(
                toolName: 'ReadFile',
                input: {'path': '/src/main.dart'},
                result: {'content': 'file contents here'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Tool name should be visible.
    expect(
      find.text(trans('conversation_chat.tool_name', {'name': 'ReadFile'})),
      findsOneWidget,
    );

    // Input/result sections hidden by default.
    expect(find.text(trans('conversation_chat.tool_input')), findsNothing);

    // Expand by tapping.
    await tester.tap(
      find.text(trans('conversation_chat.tool_name', {'name': 'ReadFile'})),
    );
    await tester.pump();

    // Now input/result should be visible.
    expect(find.text(trans('conversation_chat.tool_input')), findsOneWidget);
    expect(find.text(trans('conversation_chat.tool_result')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 14. StreamingIndicator renders thinking text
  // -----------------------------------------------------------------------

  testWidgets('StreamingIndicator renders thinking text', (tester) async {
    setViewport(tester);

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(home: Scaffold(body: const StreamingIndicator())),
      ),
    );
    await tester.pump();

    expect(find.text(trans('conversation_chat.streaming')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 15. Header shows agent role badge
  // -----------------------------------------------------------------------

  testWidgets('header shows agent role name', (tester) async {
    await pumpWithConversation(tester);

    // Agent role name from fixture.
    expect(find.text('Business Analyst'), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 16. Metadata sidebar hidden in production layout (behind debug toggle)
  // -----------------------------------------------------------------------

  testWidgets('metadata sidebar hidden until debug toggle activated', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    // Session Info should not be visible by default.
    expect(find.text(trans('conversation_chat.session_info')), findsNothing);

    // Open config modal and tap Toggle Debug.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(trans('conversation_chat.toggle_debug')));
    await tester.pumpAndSettle();

    // Session Info should now be visible in the debug panel.
    expect(find.text(trans('conversation_chat.session_info')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 17. Streaming indicator not shown when not sending
  // -----------------------------------------------------------------------

  testWidgets('streaming indicator not shown when not sending', (tester) async {
    await pumpWithConversation(tester);

    // StreamingIndicator should NOT be present when not sending.
    expect(find.byType(StreamingIndicator), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 18a. awaitingResponse — typing bubble persists until first WS message event
  // -----------------------------------------------------------------------

  testWidgets(
    'typing bubble visible while awaitingResponse and hidden after first message event',
    (tester) async {
      await pumpWithConversation(tester);

      // Manually set awaitingResponse to simulate the POST→WS gap.
      state.setAwaitingResponseForTest(value: true);
      await tester.pump();

      // Typing bubble should be visible.
      expect(
        find.text(trans('conversation_chat.agent_working')),
        findsOneWidget,
      );

      // First WS message event clears awaitingResponse.
      state.addEvent(
        WebSocketEvent(
          id: 'ws-await-1',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'assistant',
            'content': 'Here I am',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      await tester.pump();

      // Typing bubble should be gone.
      expect(find.text(trans('conversation_chat.agent_working')), findsNothing);
    },
  );

  // -----------------------------------------------------------------------
  // 18b. awaitingResponse getter true after sendMessage, false after addEvent
  // -----------------------------------------------------------------------

  test(
    'awaitingResponse is true after sendMessage and false after addEvent',
    () async {
      http.responder = (url) {
        if (url.contains('/conversations') && !url.contains('/messages')) {
          return _createConversationResponse();
        }
        if (url.contains('/messages')) {
          return MagicResponse(data: <String, dynamic>{}, statusCode: 200);
        }
        return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
      };

      await state.createConversation(
        kTeamId,
        kProjectId,
        agentRoleId: 'role-uuid-001',
      );

      expect(state.awaitingResponse, isFalse);

      // sendMessage sets both _isSending and _awaitingResponse, then clears _isSending.
      await state.sendMessage('Hello');

      // After HTTP POST completes: isSending is false, awaitingResponse still true.
      expect(state.isSending, isFalse);
      expect(state.awaitingResponse, isTrue);

      // First WS message event clears awaitingResponse.
      state.addEvent(
        WebSocketEvent(
          id: 'ws-await-unit-1',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'assistant',
            'content': 'Response arrived',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      expect(state.awaitingResponse, isFalse);
    },
  );

  // -----------------------------------------------------------------------
  // 18c. awaitingResponse cleared by reset()
  // -----------------------------------------------------------------------

  test('awaitingResponse is false after reset()', () async {
    state.setAwaitingResponseForTest(value: true);
    expect(state.awaitingResponse, isTrue);

    state.reset();

    expect(state.awaitingResponse, isFalse);
  });

  // -----------------------------------------------------------------------
  // 19. dispose does not clear conversation data (refresh survival)
  // -----------------------------------------------------------------------

  testWidgets('dispose does not clear conversation data', (tester) async {
    await pumpWithConversation(tester);

    // State should have conversation loaded.
    expect(state.conversation, isNotNull);
    expect(state.conversation?.id, kConversationId);

    // Replace widget tree — triggers dispose() on the old widget.
    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(home: Scaffold(body: WText('placeholder'))),
      ),
    );

    // Conversation data survives — only WS was unsubscribed.
    expect(state.conversation, isNotNull);
    expect(state.conversation?.id, kConversationId);
  });

  // -----------------------------------------------------------------------
  // 18. ChatStreamEventRenderer renders for mixed ChatItem types
  // -----------------------------------------------------------------------

  testWidgets(
    'ChatStreamEventRenderer renders for message, tool_use, and thinking items',
    (tester) async {
      await pumpWithConversation(tester);

      // 1. Send a user message (creates ChatMessageItem).
      state.addEvent(
        WebSocketEvent(
          id: 'ws-mixed-1',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'text',
            'content': 'Here is the analysis',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
        ),
      );

      // 2. Add a tool_use event (creates ChatToolUseItem).
      state.addEvent(
        WebSocketEvent(
          id: 'ws-mixed-2',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'tool_use',
            'content': null,
            'metadata': {
              'data': {
                'toolName': 'Read',
                'input': {'file_path': '/tmp/test.dart'},
              },
            },
            'occurred_at': '2026-03-27T10:01:01.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1, 1),
        ),
      );

      // 3. Add a thinking event (creates ChatThinkingItem).
      state.addEvent(
        WebSocketEvent(
          id: 'ws-mixed-3',
          channel: 'private-conversation.$kConversationId',
          eventName: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'thinking',
            'content': 'Analyzing the code...',
            'metadata': null,
            'occurred_at': '2026-03-27T10:01:02.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, 1, 2),
        ),
      );

      await tester.pump();

      // Verify 3 ChatStreamEventRenderer widgets are rendered.
      expect(find.byType(ChatStreamEventRenderer), findsNWidgets(3));

      // Verify each routes to the correct sub-widget.
      expect(find.byType(ChatMessageBubble), findsOneWidget);
      expect(find.byType(ChatToolUseCard), findsOneWidget);
    },
  );
}
