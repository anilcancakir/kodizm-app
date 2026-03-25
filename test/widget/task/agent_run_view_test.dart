import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/models/file_change.dart';
import 'package:app/app/models/stream_event.dart';
import 'package:app/app/models/task_run_detail.dart';
import 'package:app/app/services/websocket_service.dart';
import 'package:app/app/state/agent_run_state.dart';
import 'package:app/resources/views/task/agent_run_view.dart';
import 'package:app/resources/widgets/atoms/status_badge.dart';
import 'package:app/resources/widgets/organisms/terminal_event_list.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final TaskRunDetail kRunningDetail = TaskRunDetail(
  id: 'run-uuid-001',
  taskId: 'task-uuid-001',
  agentRoleId: 'role-uuid-001',
  agentRoleName: 'Developer',
  agentRoleSlug: 'developer',
  status: 'running',
  prompt: 'Implement the login screen',
  model: 'claude-sonnet-4-6',
  sessionId: 'sess-abc-123',
  createdAt: DateTime.utc(2026, 3, 25, 10, 0),
  startedAt: DateTime.utc(2026, 3, 25, 10, 0),
);

final TaskRunDetail kCompletedDetail = TaskRunDetail(
  id: 'run-uuid-001',
  taskId: 'task-uuid-001',
  agentRoleId: 'role-uuid-001',
  agentRoleName: 'Developer',
  agentRoleSlug: 'developer',
  status: 'completed',
  prompt: 'Implement the login screen',
  model: 'claude-sonnet-4-6',
  sessionId: 'sess-abc-123',
  durationMs: 45000,
  totalCostUsd: 0.47,
  createdAt: DateTime.utc(2026, 3, 25, 10, 0),
  startedAt: DateTime.utc(2026, 3, 25, 10, 0),
  completedAt: DateTime.utc(2026, 3, 25, 10, 0, 45),
);

final List<StreamEvent> kEvents = [
  StreamEvent(
    id: 'evt-1',
    taskRunId: 'run-uuid-001',
    type: 'system',
    data: const {},
    contentText: 'Agent container started',
    isQuestion: false,
    occurredAt: DateTime.utc(2026, 3, 25, 10, 0, 1),
  ),
  StreamEvent(
    id: 'evt-2',
    taskRunId: 'run-uuid-001',
    type: 'assistant',
    data: const {},
    contentText: 'Analyzing the codebase...',
    isQuestion: false,
    occurredAt: DateTime.utc(2026, 3, 25, 10, 0, 5),
  ),
];

final List<FileChange> kFileChanges = [
  const FileChange(filePath: 'lib/main.dart', operation: 'M'),
  const FileChange(filePath: 'lib/login.dart', operation: 'A'),
  const FileChange(filePath: 'lib/old.dart', operation: 'D'),
];

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeAgentRunHttpClient implements AgentRunHttpClient {
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
// Fake WebSocket service
// ---------------------------------------------------------------------------

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService()
    : super(
        channelFactory: (_) => throw UnimplementedError(),
        configProvider: (key, [defaultValue]) => defaultValue,
      );

  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannels.add(channel);
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
// Test helpers
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeAgentRunHttpClient http;
  late AgentRunState state;
  late _FakeWebSocketService fakeWs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeAgentRunHttpClient();
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
      return MagicResponse(data: <String, dynamic>{}, statusCode: 404);
    };

    state = AgentRunState(httpClient: http);
    Magic.put<AgentRunState>(state);

    fakeWs = _FakeWebSocketService();
    Magic.singleton('websocket', () => fakeWs);
  });

  tearDown(() {
    state.reset();
    Magic.delete<AgentRunState>();
  });

  // -----------------------------------------------------------------------
  // Helper: pre-populate state then pump
  // -----------------------------------------------------------------------

  Future<void> pumpWithRunningState(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Directly set state fields via public API simulation.
    // Load a running detail into state by faking the HTTP response.
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

    // Pre-load run detail.
    await state.loadRunDetail(
      'team-uuid-001',
      'proj-uuid-001',
      'task-uuid-001',
      'run-uuid-001',
    );

    // Add some events.
    for (final event in kEvents) {
      state.addStreamEvent(event);
    }
    state.refreshUI();

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  Future<void> pumpWithCompletedState(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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
      return MagicResponse(
        data: {
          'data': {
            'id': 'run-uuid-001',
            'task_id': 'task-uuid-001',
            'agent_role_id': 'role-uuid-001',
            'agent_role': {'name': 'Developer', 'slug': 'developer'},
            'status': 'completed',
            'prompt': 'Implement the login screen',
            'model': 'claude-sonnet-4-6',
            'session_id': 'sess-abc-123',
            'total_cost_usd': 0.47,
            'duration_ms': 45000,
            'created_at': '2026-03-25T10:00:00.000Z',
            'started_at': '2026-03-25T10:00:00.000Z',
            'completed_at': '2026-03-25T10:00:45.000Z',
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

    for (final event in kEvents) {
      state.addStreamEvent(event);
    }
    state.refreshUI();

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  Future<void> pumpWithFileChanges(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    // Add file change events.
    state.addStreamEvent(
      StreamEvent(
        id: 'fc-1',
        taskRunId: 'run-uuid-001',
        type: 'file_change',
        data: const {'operation': 'M'},
        filePath: 'lib/main.dart',
        isQuestion: false,
        occurredAt: DateTime.utc(2026, 3, 25, 10, 0, 10),
      ),
    );
    state.addStreamEvent(
      StreamEvent(
        id: 'fc-2',
        taskRunId: 'run-uuid-001',
        type: 'file_change',
        data: const {'operation': 'A'},
        filePath: 'lib/login.dart',
        isQuestion: false,
        occurredAt: DateTime.utc(2026, 3, 25, 10, 0, 11),
      ),
    );
    state.addStreamEvent(
      StreamEvent(
        id: 'fc-3',
        taskRunId: 'run-uuid-001',
        type: 'file_change',
        data: const {'operation': 'D'},
        filePath: 'lib/old.dart',
        isQuestion: false,
        occurredAt: DateTime.utc(2026, 3, 25, 10, 0, 12),
      ),
    );
    state.refreshUI();

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  // -----------------------------------------------------------------------
  // 1. Loading state renders CircularProgressIndicator
  // -----------------------------------------------------------------------

  testWidgets('loading state renders CircularProgressIndicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Don't pre-populate — state should start in loading/empty.
    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();

    // The view shows loading indicator when no runDetail is loaded.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 2. Run detail rendered in sidebar
  // -----------------------------------------------------------------------

  testWidgets('run detail rendered in sidebar', (tester) async {
    await pumpWithRunningState(tester);

    // Agent role name visible.
    expect(find.text('Developer'), findsWidgets);

    // Model visible.
    expect(find.text('claude-sonnet-4-6'), findsWidgets);

    // Run Info section title.
    expect(find.text(trans('agent_run.run_info')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 3. Events rendered in terminal
  // -----------------------------------------------------------------------

  testWidgets('events rendered in terminal', (tester) async {
    await pumpWithRunningState(tester);

    // TerminalEventList widget should be present.
    expect(find.byType(TerminalEventList), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 4. Cancel button visible when status is running
  // -----------------------------------------------------------------------

  testWidgets('cancel button visible when status is running', (tester) async {
    await pumpWithRunningState(tester);

    expect(find.text(trans('agent_run.cancel_run')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 5. Cancel button NOT visible when status is completed
  // -----------------------------------------------------------------------

  testWidgets('cancel button NOT visible when status is completed', (
    tester,
  ) async {
    await pumpWithCompletedState(tester);

    expect(find.text(trans('agent_run.cancel_run')), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 6. File changes panel shows operation badges
  // -----------------------------------------------------------------------

  testWidgets('file changes panel shows operation badges', (tester) async {
    await pumpWithFileChanges(tester);

    // File changes section title with count.
    expect(
      find.text(trans('agent_run.file_changes_count', {'count': '3'})),
      findsOneWidget,
    );

    // Operation badges.
    expect(find.text('A'), findsWidgets);
    expect(find.text('M'), findsWidgets);
    expect(find.text('D'), findsWidgets);

    // File paths.
    expect(find.text('lib/main.dart'), findsWidgets);
    expect(find.text('lib/login.dart'), findsWidgets);
    expect(find.text('lib/old.dart'), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 7. Elapsed time displays
  // -----------------------------------------------------------------------

  testWidgets('elapsed time displays for completed run', (tester) async {
    await pumpWithCompletedState(tester);

    // Elapsed label should be present.
    expect(find.text(trans('agent_run.elapsed_time')), findsOneWidget);

    // Completed run with durationMs=45000 → 0 m 45 s.
    expect(find.textContaining('45'), findsWidgets);
  });

  // -----------------------------------------------------------------------
  // 8. Back button navigates to task detail
  // -----------------------------------------------------------------------

  testWidgets('back button is rendered', (tester) async {
    await pumpWithRunningState(tester);

    // Back button icon exists.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 9. Title renders from i18n
  // -----------------------------------------------------------------------

  testWidgets('title renders from i18n', (tester) async {
    await pumpWithRunningState(tester);

    expect(find.text(trans('agent_run.title')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 10. Status badge is rendered
  // -----------------------------------------------------------------------

  testWidgets('status badge is rendered in sidebar', (tester) async {
    await pumpWithRunningState(tester);

    expect(find.byType(StatusBadge), findsWidgets);
  });
}
