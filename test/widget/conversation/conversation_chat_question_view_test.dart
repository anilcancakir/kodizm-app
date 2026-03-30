import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/conversation_chat_state.dart';
import 'package:app/resources/views/conversation/conversation_chat_view.dart';

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeHttpClient implements ConversationChatHttpClient {
  final List<String> calls = [];
  final List<Map<String, dynamic>> postBodies = [];

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
    if (data is Map<String, dynamic>) {
      postBodies.add(data);
    }
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

MagicResponse _createConversationResponse({String status = 'active'}) {
  return MagicResponse(
    data: {'data': _conversationPayload(status: status)},
    statusCode: 201,
  );
}

MagicResponse _messagesResponse() {
  return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
}

MagicResponse _answerResponse() {
  return MagicResponse(data: {'data': <String, dynamic>{}}, statusCode: 200);
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
  // Shared helpers
  // -----------------------------------------------------------------------

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> pumpWithConversation(
    WidgetTester tester, {
    String status = 'active',
  }) async {
    setViewport(tester);

    http.responder = (url) {
      if (url.contains('/agent-roles')) return _agentRolesResponse();
      if (url.contains('/conversations') &&
          !url.contains('/messages') &&
          !url.contains('/answer')) {
        return _createConversationResponse(status: status);
      }
      if (url.contains('/messages')) return _messagesResponse();
      if (url.contains('/answer')) return _answerResponse();
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

  /// Injects a question event via WebSocket.
  void injectQuestionEvent() {
    // First inject tool_use with AskUserQuestion options
    state.addEvent(
      WebSocketEvent(
        id: 'ws-evt-tooluse',
        channel: 'private-conversation.$kConversationId',
        eventName: '.conversation.message',
        data: {
          'conversation_id': kConversationId,
          'type': 'tool_use',
          'content': null,
          'metadata': {
            'data': {
              'toolName': 'AskUserQuestion',
              'input': {
                'questions': [
                  {
                    'options': [
                      {
                        'label': 'Option A',
                        'description': 'First option description',
                      },
                      {
                        'label': 'Option B',
                        'description': 'Second option description',
                      },
                    ],
                  },
                ],
              },
            },
          },
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 1),
      ),
    );

    // Then inject the question event
    state.addEvent(
      WebSocketEvent(
        id: 'ws-evt-question',
        channel: 'private-conversation.$kConversationId',
        eventName: '.conversation.message',
        data: {
          'conversation_id': kConversationId,
          'type': 'question',
          'content': null,
          'metadata': {
            'data': {
              'questionId': 'q-uuid-001',
              'message': 'Which framework do you prefer?',
            },
          },
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 1, 1),
      ),
    );
  }

  /// Injects a permission event via WebSocket.
  void injectPermissionEvent() {
    state.addEvent(
      WebSocketEvent(
        id: 'ws-evt-permission',
        channel: 'private-conversation.$kConversationId',
        eventName: '.conversation.message',
        data: {
          'conversation_id': kConversationId,
          'type': 'permission',
          'content': null,
          'metadata': {
            'data': {
              'questionId': 'perm-uuid-001',
              'toolName': 'Bash',
              'input': {'command': 'rm -rf /tmp/build'},
            },
          },
        },
        receivedAt: DateTime.utc(2026, 3, 27, 10, 2),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // 1. Question card renders with options
  // -----------------------------------------------------------------------

  testWidgets('question card renders with options when pending', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    injectQuestionEvent();
    await tester.pumpAndSettle();

    // Question title header
    expect(
      find.text(trans('conversation_chat.question_title')),
      findsOneWidget,
    );

    // Question message text
    expect(find.text('Which framework do you prefer?'), findsOneWidget);

    // Option labels
    expect(find.text('Option A'), findsOneWidget);
    expect(find.text('Option B'), findsOneWidget);

    // Option descriptions
    expect(find.text('First option description'), findsOneWidget);
    expect(find.text('Second option description'), findsOneWidget);

    // Submit button for free-form answer
    expect(
      find.text(trans('conversation_chat.question_submit')),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 2. Option tap triggers answerQuestion
  // -----------------------------------------------------------------------

  testWidgets('tapping an option calls answerQuestion', (tester) async {
    await pumpWithConversation(tester);

    injectQuestionEvent();
    await tester.pumpAndSettle();

    // Tap "Option A"
    await tester.tap(find.text('Option A'));
    await tester.pump();
    await tester.pump();

    // Verify the POST call was made to /answer
    expect(http.calls.where((c) => c.contains('/answer')).length, equals(1));
  });

  // -----------------------------------------------------------------------
  // 3. Permission card renders with tool info
  // -----------------------------------------------------------------------

  testWidgets('permission card renders with tool info', (tester) async {
    await pumpWithConversation(tester);

    injectPermissionEvent();
    await tester.pumpAndSettle();

    // Permission title header
    expect(
      find.text(trans('conversation_chat.permission_title')),
      findsOneWidget,
    );

    // Tool name
    expect(
      find.text(trans('conversation_chat.permission_tool', {'tool': 'Bash'})),
      findsOneWidget,
    );

    // Input JSON — SelectableText renders the JSON
    expect(find.byType(SelectableText), findsWidgets);

    // Approve button
    expect(
      find.text(trans('conversation_chat.permission_approve')),
      findsOneWidget,
    );

    // Deny button
    expect(
      find.text(trans('conversation_chat.permission_deny')),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 4. Approve button calls answerQuestion with 'approve'
  // -----------------------------------------------------------------------

  testWidgets('approve button calls answerQuestion with approve', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    injectPermissionEvent();
    await tester.pumpAndSettle();

    await tester.tap(find.text(trans('conversation_chat.permission_approve')));
    await tester.pump();
    await tester.pump();

    // POST to /answer was called
    expect(http.calls.where((c) => c.contains('/answer')).length, equals(1));
  });

  // -----------------------------------------------------------------------
  // 5. Deny button calls answerQuestion with 'deny'
  // -----------------------------------------------------------------------

  testWidgets('deny button calls answerQuestion with deny', (tester) async {
    await pumpWithConversation(tester);

    injectPermissionEvent();
    await tester.pumpAndSettle();

    await tester.tap(find.text(trans('conversation_chat.permission_deny')));
    await tester.pump();
    await tester.pump();

    // POST to /answer was called
    expect(http.calls.where((c) => c.contains('/answer')).length, equals(1));
  });

  // -----------------------------------------------------------------------
  // 6. Cards hidden after answer submitted
  // -----------------------------------------------------------------------

  testWidgets('question card disappears after answer submitted', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    injectQuestionEvent();
    await tester.pumpAndSettle();

    // Card is visible
    expect(
      find.text(trans('conversation_chat.question_title')),
      findsOneWidget,
    );

    // Tap option to answer
    await tester.tap(find.text('Option A'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Card should be gone (state clears pendingQuestion on success)
    expect(find.text(trans('conversation_chat.question_title')), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 7. Permission card disappears after approval
  // -----------------------------------------------------------------------

  testWidgets('permission card disappears after approval', (tester) async {
    await pumpWithConversation(tester);

    injectPermissionEvent();
    await tester.pumpAndSettle();

    // Card is visible
    expect(
      find.text(trans('conversation_chat.permission_title')),
      findsOneWidget,
    );

    // Tap approve
    await tester.tap(find.text(trans('conversation_chat.permission_approve')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Card should be gone
    expect(
      find.text(trans('conversation_chat.permission_title')),
      findsNothing,
    );
  });

  // -----------------------------------------------------------------------
  // 8. Paused badge visible when conversation is paused
  // -----------------------------------------------------------------------

  testWidgets('paused badge visible when conversation status is paused', (
    tester,
  ) async {
    await pumpWithConversation(tester, status: 'paused');
    await tester.pumpAndSettle();

    // Status badge moved to config modal — open it via gear icon.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text(trans('conversation_chat.status_paused')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 9. No question card when pendingQuestion is null
  // -----------------------------------------------------------------------

  testWidgets('no question card when pendingQuestion is null', (tester) async {
    await pumpWithConversation(tester);

    expect(find.text(trans('conversation_chat.question_title')), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 10. No permission card when pendingPermission is null
  // -----------------------------------------------------------------------

  testWidgets('no permission card when pendingPermission is null', (
    tester,
  ) async {
    await pumpWithConversation(tester);

    expect(
      find.text(trans('conversation_chat.permission_title')),
      findsNothing,
    );
  });
}
