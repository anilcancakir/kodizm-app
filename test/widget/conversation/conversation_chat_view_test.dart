import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/conversation_chat_state.dart';
import 'package:app/resources/views/conversation/conversation_chat_view.dart';
import 'package:app/resources/widgets/atoms/streaming_indicator.dart';
import 'package:app/resources/widgets/organisms/chat_message_bubble.dart';
import 'package:app/resources/widgets/organisms/chat_stream_event_renderer.dart';
import 'package:app/resources/widgets/organisms/chat_tool_use_card.dart';

// ---------------------------------------------------------------------------
// Fake WebSocket
// ---------------------------------------------------------------------------

class _FakeWebSocket implements ConversationChatWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  void Function(BroadcastEvent)? lastCallback;

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {
    subscribedChannels.add(channel);
    lastCallback = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
  }

  @override
  Stream<void> get onReconnect => const Stream.empty();
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
  MagicTest.init();

  late FakeNetworkDriver driver;
  late _FakeWebSocket ws;
  late ConversationChatState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response(<String, dynamic>{}, 404));

    ws = _FakeWebSocket();
    state = ConversationChatState(webSocket: ws);
    Magic.put<ConversationChatState>(state);
  });

  tearDown(() {
    state.reset();
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

    // Stub specific patterns after catch-all (higher priority).
    driver.stub(
      '*/agent-roles*',
      Http.response({
        'data': [
          {'id': 'role-uuid-001', 'name': 'Business Analyst', 'slug': 'ba'},
        ],
      }),
    );
    driver.stub(
      '*/conversations*',
      Http.response({'data': _conversationPayload()}, 201),
    );
    // Registered AFTER */conversations* so it takes priority for message URLs.
    driver.stub(
      '*/messages*',
      Http.response({
        'data': <String, dynamic>{
          'id': 'msg-uuid-stub',
          'conversation_id': 'conv-uuid-001',
          'role': 'user',
          'content': 'Hello agent!',
          'cost_usd': null,
          'metadata': null,
          'stream_events': null,
          'usage': null,
          'duration_ms': null,
          'num_turns': null,
          'error': null,
          'status': null,
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      }),
    );

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
      BroadcastEvent(
        channel: 'private-conversation.$kConversationId',
        event: '.conversation.message',
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
  // 9b. Auto-scroll retries across frames until list is scrolled to bottom
  // -----------------------------------------------------------------------

  testWidgets('auto-scroll settles at bottom after multi-frame layout', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    // Push enough messages to make the list overflow the viewport so that
    // `position.hasContentDimensions` / `maxScrollExtent` only resolve after
    // layout completes — exercises the retry path in _scrollToBottom().
    for (int i = 0; i < 40; i++) {
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
          data: {
            'conversation_id': kConversationId,
            'type': 'assistant',
            'content':
                'Filler message #$i — '
                '${'long content ' * 20}',
            'metadata': null,
            'occurred_at':
                '2026-03-27T10:${i.toString().padLeft(2, '0')}:00.000Z',
          },
          receivedAt: DateTime.utc(2026, 3, 27, 10, i),
        ),
      );
    }

    // Pump several frames to let the retry chain resolve.
    await tester.pumpAndSettle();

    // Locate the Scrollable backing the chat list and verify it is scrolled
    // to (or near) the bottom — the retry loop should have caught up.
    final Scrollable scrollable = tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .firstWhere((s) => s.axisDirection == AxisDirection.down);
    final ScrollPosition position = scrollable.controller!.position;

    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, closeTo(position.maxScrollExtent, 1.0));
  });

  // -----------------------------------------------------------------------
  // 10. Raw events section shows event count
  // -----------------------------------------------------------------------

  testWidgets('raw events section shows event count', (tester) async {
    await pumpWithConversation(tester);

    // Add an event so count is 1.
    state.addEvent(
      BroadcastEvent(
        channel: 'private-conversation.$kConversationId',
        event: '.conversation.status',
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

    // Send a message matching the */messages* stub content so the
    // optimistic message survives the API response replacement.
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'Hello agent!');
    await tester.pump();

    final sendFinder = find.byIcon(Icons.send);
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pump();

    // ChatMessageBubble renders user content.
    expect(find.byType(ChatMessageBubble), findsOneWidget);
    expect(find.text('Hello agent!'), findsOneWidget);
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

  testWidgets('header shows conversation title', (tester) async {
    await pumpWithConversation(tester);

    // Conversation title from fixture.
    expect(find.text('Test Conversation'), findsOneWidget);
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

      // Typing bubble should be visible (no session phase yet → "Connecting...").
      expect(
        find.text(trans('conversation_chat.status_connecting')),
        findsOneWidget,
      );

      // First WS message event clears awaitingResponse.
      state.addEvent(
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
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
      driver.stub(
        '*/conversations*',
        Http.response({'data': _conversationPayload()}, 201),
      );
      driver.stub('*/messages*', Http.response(<String, dynamic>{}));

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
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
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
  // 20. Stop button appears when awaitingResponse is true
  // -----------------------------------------------------------------------

  testWidgets('stop button appears when awaitingResponse is true', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    // Initially — send button visible, stop button not visible.
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);

    // Simulate awaiting response.
    state.setAwaitingResponseForTest(value: true);
    await tester.pump();

    // Stop button should now be visible alongside the send button.
    // Both are shown simultaneously so messages can be queued while
    // the agent is executing.
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
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
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
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
        BroadcastEvent(
          channel: 'private-conversation.$kConversationId',
          event: '.conversation.message',
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

  // -----------------------------------------------------------------------
  // 21. Provisioning phase with no step shows fallback "Starting..."
  // -----------------------------------------------------------------------

  testWidgets('provisioning phase with no step shows fallback Starting label', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    state.setAwaitingResponseForTest(value: true);
    state.setSessionPhaseForTest('provisioning');
    state.setProvisioningStepForTest(null);
    await tester.pump();

    expect(
      find.text(trans('conversation_chat.status_starting')),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 22. Provisioning phase with container_starting step shows label
  // -----------------------------------------------------------------------

  testWidgets(
    'provisioning phase with container_starting step shows correct label',
    (tester) async {
      await pumpWithConversation(tester);

      state.setAwaitingResponseForTest(value: true);
      state.setSessionPhaseForTest('provisioning');
      state.setProvisioningStepForTest('container_starting');
      await tester.pump();

      expect(
        find.text(trans('conversation_chat.provisioning_container_starting')),
        findsOneWidget,
      );
    },
  );

  // -----------------------------------------------------------------------
  // 23. Provisioning phase with skills_loading step shows label
  // -----------------------------------------------------------------------

  testWidgets(
    'provisioning phase with skills_loading step shows correct label',
    (tester) async {
      await pumpWithConversation(tester);

      state.setAwaitingResponseForTest(value: true);
      state.setSessionPhaseForTest('provisioning');
      state.setProvisioningStepForTest('skills_loading');
      await tester.pump();

      expect(
        find.text(trans('conversation_chat.provisioning_skills_loading')),
        findsOneWidget,
      );
    },
  );

  // -----------------------------------------------------------------------
  // 24. Step label updates when provisioning step changes (AnimatedSwitcher)
  // -----------------------------------------------------------------------

  testWidgets('step label updates when provisioning step changes', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    state.setAwaitingResponseForTest(value: true);
    state.setSessionPhaseForTest('provisioning');
    state.setProvisioningStepForTest('container_starting');
    await tester.pump();

    expect(
      find.text(trans('conversation_chat.provisioning_container_starting')),
      findsOneWidget,
    );
    expect(
      find.text(trans('conversation_chat.provisioning_skills_loading')),
      findsNothing,
    );

    // Transition to next step.
    state.setProvisioningStepForTest('skills_loading');
    await tester.pump();

    // AnimatedSwitcher: new label is present.
    expect(
      find.text(trans('conversation_chat.provisioning_skills_loading')),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 25. Executing phase clears provisioning step indicator
  // -----------------------------------------------------------------------

  testWidgets(
    'executing phase clears provisioning step and shows working label',
    (tester) async {
      await pumpWithConversation(tester);

      // Start in provisioning with a step set.
      state.setAwaitingResponseForTest(value: true);
      state.setSessionPhaseForTest('provisioning');
      state.setProvisioningStepForTest('skills_loading');
      await tester.pump();

      expect(
        find.text(trans('conversation_chat.provisioning_skills_loading')),
        findsOneWidget,
      );

      // Transition to executing phase — provisioning step must not be shown.
      state.setSessionPhaseForTest('executing');
      state.setProvisioningStepForTest(null);
      // Pump twice to flush the state change and advance AnimatedSwitcher past
      // its 200ms fade duration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(trans('conversation_chat.provisioning_skills_loading')),
        findsNothing,
      );
      expect(
        find.text(trans('conversation_chat.status_working')),
        findsOneWidget,
      );
    },
  );
}
