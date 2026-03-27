import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/conversation_chat_state.dart';
import 'package:app/resources/views/conversation/conversation_chat_view.dart';
import 'package:app/resources/widgets/atoms/status_badge.dart';

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
    'title': null,
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

    await state.createConversation(kTeamId, kProjectId);

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
  // 2. Title renders from i18n
  // -----------------------------------------------------------------------

  testWidgets('title renders from i18n', (tester) async {
    await pumpInitialState(tester);

    expect(find.text(trans('conversation_chat.title')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 3. After conversation created, shows chat UI with input
  // -----------------------------------------------------------------------

  testWidgets('after conversation created, shows input field', (tester) async {
    await pumpWithConversation(tester);

    // Input field placeholder should be present.
    expect(find.text(trans('conversation_chat.placeholder')), findsOneWidget);

    // Send button should be present.
    expect(find.text(trans('conversation_chat.send')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 4. Status badge renders for active conversation
  // -----------------------------------------------------------------------

  testWidgets('status badge renders for active conversation', (tester) async {
    await pumpWithConversation(tester);

    expect(find.byType(StatusBadge), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 5. Metadata sidebar shows conversation info
  // -----------------------------------------------------------------------

  testWidgets('metadata sidebar shows conversation info', (tester) async {
    await pumpWithConversation(tester);

    // Session Info section title.
    expect(find.text(trans('conversation_chat.session_info')), findsOneWidget);

    // Model label.
    expect(find.text('claude-sonnet-4-6'), findsWidgets);

    // Agent role name.
    expect(find.text('Business Analyst'), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 6. Complete button visible for active conversation
  // -----------------------------------------------------------------------

  testWidgets('complete button visible for active conversation', (
    tester,
  ) async {
    await pumpWithConversation(tester);

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
  // 8. Send message adds user message to list
  // -----------------------------------------------------------------------

  testWidgets('send message adds user message to list', (tester) async {
    await pumpWithConversation(tester);

    // Type a message.
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'Hello agent!');
    await tester.pump();

    // Tap send button.
    final sendFinder = find.text(trans('conversation_chat.send'));
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pump();

    // Optimistic message should appear.
    expect(find.text('Hello agent!'), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 9. addEvent shows assistant message in list (real-time simulation)
  // -----------------------------------------------------------------------

  testWidgets('addEvent shows assistant message in list', (tester) async {
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

    expect(
      find.text(trans('conversation_chat.raw_events_count', {'count': '1'})),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 11. Message bubble shows role badge
  // -----------------------------------------------------------------------

  testWidgets('message bubble shows role badge for user', (tester) async {
    await pumpWithConversation(tester);

    // Send a message first.
    final inputFinder = find.byType(TextField);
    await tester.enterText(inputFinder, 'Test message');
    await tester.pump();

    final sendFinder = find.text(trans('conversation_chat.send'));
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pump();

    // User role badge should appear.
    expect(find.text(trans('conversation_chat.user_role')), findsWidgets);
  });
}
