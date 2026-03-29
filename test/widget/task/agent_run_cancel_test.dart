import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/services/websocket_service.dart';
import 'package:app/app/state/agent_run_state.dart';
import 'package:app/resources/views/task/agent_run_view.dart';

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeHttpClient implements AgentRunHttpClient, SessionAgentHttpClient {
  MagicResponse Function(String url)? responder;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return responder?.call(url) ??
        MagicResponse(data: <String, dynamic>{}, statusCode: 404);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return responder?.call(url) ??
        MagicResponse(data: <String, dynamic>{}, statusCode: 200);
  }
}

// ---------------------------------------------------------------------------
// Fake WebSocket service
// ---------------------------------------------------------------------------

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService()
    : super(
        channelFactory: (_) => throw UnimplementedError(),
        configProvider: (key, [defaultValue]) => defaultValue,
      );

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {}

  @override
  void unsubscribe(String channel) {}
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
// Helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget({
  String projectId = 'proj-uuid-001',
  String taskId = 'task-uuid-001',
  String runId = 'run-uuid-001',
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: AgentRunView(projectId: projectId, taskId: taskId, runId: runId),
      ),
    ),
  );
}

/// Configures [http] to respond with a running run detail.
void _configureRunningResponder(_FakeHttpClient http) {
  http.responder = (url) {
    if (url.contains('/stream-events')) {
      return MagicResponse(
        data: {
          'data': <dynamic>[],
          'meta': {'has_more': false, 'next_cursor': null},
        },
        statusCode: 200,
      );
    }
    if (url.contains('/questions')) {
      return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
    }
    if (url.contains('/v1/sessions/')) {
      return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
    }
    return MagicResponse(
      data: {
        'data': {
          'id': 'run-uuid-001',
          'task_id': 'task-uuid-001',
          'agent_role_id': 'role-uuid-001',
          'agent_role': {'name': 'Developer', 'slug': 'developer'},
          'status': 'running',
          'prompt': 'Implement the login screen',
          'model': 'claude-sonnet-4-6',
          'session_id': 'sess-abc-123',
          'created_at': '2026-03-25T10:00:00.000Z',
          'started_at': '2026-03-25T10:00:00.000Z',
        },
      },
      statusCode: 200,
    );
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpClient http;
  late AgentRunState state;
  late _FakeWebSocketService fakeWs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUpAll(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  setUp(() {
    http = _FakeHttpClient();
    _configureRunningResponder(http);

    state = AgentRunState(httpClient: http, sessionHttpClient: http);
    Magic.put<AgentRunState>(state);

    fakeWs = _FakeWebSocketService();
    Magic.singleton('websocket', () => fakeWs);
  });

  tearDown(() {
    state.reset();
    Magic.delete<AgentRunState>();
  });

  // -------------------------------------------------------------------------
  // 1. Cancel button shows MagicStarterConfirmDialog with danger variant
  // -------------------------------------------------------------------------

  testWidgets('cancel button shows MagicStarterConfirmDialog with danger variant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await state.loadRunDetail(
      'team-uuid-001',
      'proj-uuid-001',
      'task-uuid-001',
      'run-uuid-001',
    );
    state.refreshUI();

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();

    // Cancel button should be visible.
    expect(find.text(trans('agent_run.cancel_run')), findsWidgets);

    // Tap cancel button — tap first match (the button on the view, before dialog opens).
    await tester.tap(find.text(trans('agent_run.cancel_run')).first);
    await tester.pumpAndSettle();

    // MagicStarterConfirmDialog should appear.
    expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);

    // Title from i18n key.
    expect(find.text(trans('agent_run.cancel_confirm_title')), findsOneWidget);

    // Description from i18n key.
    expect(
      find.text(trans('agent_run.cancel_confirm_message')),
      findsOneWidget,
    );

    // Confirm action label — both cancel_run and cancel_confirm_action map to "Cancel Run".
    expect(find.text(trans('agent_run.cancel_confirm_action')), findsWidgets);

    // Cancel button inside the dialog.
    expect(find.text(trans('common.cancel')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Dismissing the confirm dialog leaves the view intact
  // -------------------------------------------------------------------------

  testWidgets(
    'cancelling the confirm dialog dismisses without navigating away',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );
      state.refreshUI();

      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      // Open the cancel dialog.
      await tester.tap(find.text(trans('agent_run.cancel_run')).first);
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);

      // Tap the cancel button in the dialog.
      await tester.tap(find.text(trans('common.cancel')));
      await tester.pumpAndSettle();

      // Dialog is closed.
      expect(find.byType(MagicStarterConfirmDialog), findsNothing);

      // Run view is still visible.
      expect(find.text(trans('agent_run.title')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 3. Confirming the cancel dialog triggers cancelRun on state
  // -------------------------------------------------------------------------

  testWidgets(
    'confirming the cancel dialog triggers a POST to cancel the run',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<String> postCalls = [];
      http.responder = (url) {
        if (url.contains('/stream-events')) {
          return MagicResponse(
            data: {
              'data': <dynamic>[],
              'meta': {'has_more': false, 'next_cursor': null},
            },
            statusCode: 200,
          );
        }
        if (url.contains('/questions')) {
          return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
        }
        if (url.contains('/v1/sessions/')) {
          return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
        }
        if (url.contains('/cancel')) {
          postCalls.add(url);
          return MagicResponse(data: {'data': {}}, statusCode: 200);
        }
        return MagicResponse(
          data: {
            'data': {
              'id': 'run-uuid-001',
              'task_id': 'task-uuid-001',
              'agent_role_id': 'role-uuid-001',
              'agent_role': {'name': 'Developer', 'slug': 'developer'},
              'status': 'running',
              'prompt': 'Implement the login screen',
              'model': 'claude-sonnet-4-6',
              'session_id': 'sess-abc-123',
              'created_at': '2026-03-25T10:00:00.000Z',
              'started_at': '2026-03-25T10:00:00.000Z',
            },
          },
          statusCode: 200,
        );
      };

      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );
      state.refreshUI();

      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      // Open the cancel dialog.
      await tester.tap(find.text(trans('agent_run.cancel_run')).first);
      await tester.pumpAndSettle();

      expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);

      // Tap the confirm button — find it inside the dialog context.
      // Both cancel_run and cancel_confirm_action translate to "Cancel Run",
      // so we tap the last one (in the dialog footer).
      await tester.tap(
        find.text(trans('agent_run.cancel_confirm_action')).last,
      );
      await tester.pumpAndSettle();

      // A POST to cancel should have been made.
      expect(postCalls, isNotEmpty);
      expect(postCalls.first, contains('/cancel'));
    },
  );
}
