import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/models/stream_event.dart';
import 'package:app/app/state/agent_run_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kRunDetail = {
  'id': 'run-uuid-001',
  'task_id': 'task-uuid-001',
  'agent_role_id': 'role-uuid-001',
  'agent_role': {
    'id': 'role-uuid-001',
    'name': 'Business Analyst',
    'slug': 'ba',
  },
  'status': 'running',
  'prompt': 'Analyse the login feature requirements.',
  'model': 'claude-sonnet-4-6',
  'session_id': null,
  'container_name': 'agent-run-001',
  'total_cost_usd': null,
  'usage': null,
  'duration_ms': null,
  'num_turns': null,
  'error': null,
  'ai_token_id': 'token-uuid-001',
  'worktree_path': '/tmp/worktrees/run-001',
  'worktree_branch': 'agent/task-001',
  'warm_until': null,
  'started_at': '2025-06-10T08:01:00.000Z',
  'completed_at': null,
  'created_at': '2025-06-10T08:00:55.000Z',
  'updated_at': '2025-06-10T08:01:00.000Z',
};

const Map<String, dynamic> kStreamEventA = {
  'id': 'evt-uuid-001',
  'task_run_id': 'run-uuid-001',
  'type': 'system',
  'data': {'session_id': 'sess-001', 'model': 'claude-sonnet-4-6'},
  'content_text': 'Session started',
  'file_path': null,
  'is_question': false,
  'occurred_at': '2025-06-10T08:01:01.000Z',
};

const Map<String, dynamic> kStreamEventB = {
  'id': 'evt-uuid-002',
  'task_run_id': 'run-uuid-001',
  'type': 'assistant',
  'data': {'content': 'Analysing requirements...'},
  'content_text': 'Analysing requirements...',
  'file_path': null,
  'is_question': false,
  'occurred_at': '2025-06-10T08:01:05.000Z',
};

const Map<String, dynamic> kStreamEventFileChange = {
  'id': 'evt-uuid-003',
  'task_run_id': 'run-uuid-001',
  'type': 'file_change',
  'data': {'operation': 'M'},
  'content_text': null,
  'file_path': 'lib/main.dart',
  'is_question': false,
  'occurred_at': '2025-06-10T08:01:10.000Z',
};

const Map<String, dynamic> kQuestionPending = {
  'id': 'question-uuid-001',
  'task_run_id': 'run-uuid-001',
  'stream_event_id': null,
  'question_text': 'Should I continue with the refactor?',
  'answer_text': null,
  'answered_by_user_id': null,
  'answered_at': null,
  'created_at': '2025-06-10T08:02:00.000Z',
};

const Map<String, dynamic> kQuestionAnswered = {
  'id': 'question-uuid-002',
  'task_run_id': 'run-uuid-001',
  'stream_event_id': 'evt-uuid-010',
  'question_text': 'Which database engine?',
  'answer_text': 'PostgreSQL',
  'answered_by_user_id': 'user-uuid-001',
  'answered_at': '2025-06-10T08:03:00.000Z',
  'created_at': '2025-06-10T08:02:30.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [AgentRunState] without hitting the
/// network. Each method records the call and returns a pre-configured
/// [MagicResponse].
class _FakeAgentRunHttpClient implements AgentRunHttpClient {
  final List<_HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Set a responder that maps URL to [MagicResponse].
  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  /// Shortcut: always return the same response regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('GET', url, query: query));
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
  _HttpCall(this.method, this.url, {this.data, this.query});

  final String method;
  final String url;
  final dynamic data;
  final Map<String, dynamic>? query;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AgentRunState', () {
    late _FakeAgentRunHttpClient http;
    late AgentRunState state;

    setUp(() {
      http = _FakeAgentRunHttpClient();
      state = AgentRunState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state is empty
    // -----------------------------------------------------------------------

    test('initial state has null runDetail and empty collections', () {
      expect(state.runDetail, isNull);
      expect(state.events, isEmpty);
      expect(state.fileChanges, isEmpty);
      expect(state.turnCount, equals(0));
      expect(state.currentCost, equals(0.0));
    });

    // -----------------------------------------------------------------------
    // 2. loadRunDetail — success
    // -----------------------------------------------------------------------

    test('loadRunDetail parses TaskRunDetail from response', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );

      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      expect(state.runDetail, isNotNull);
      expect(state.runDetail!.id, equals('run-uuid-001'));
      expect(state.runDetail!.status, equals('running'));
      expect(state.runDetail!.agentRoleName, equals('Business Analyst'));

      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/runs/run-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 3. loadRunDetail — error sets runDetail to null
    // -----------------------------------------------------------------------

    test('loadRunDetail sets runDetail to null on error', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
      );

      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-999',
      );

      expect(state.runDetail, isNull);
    });

    // -----------------------------------------------------------------------
    // 4. loadExistingEvents — single page
    // -----------------------------------------------------------------------

    test('loadExistingEvents loads events from single page', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kStreamEventA, kStreamEventB],
            'meta': {'has_more': false, 'next_cursor': null},
          },
          statusCode: 200,
        ),
      );

      await state.loadExistingEvents('run-uuid-001');

      expect(state.events.length, equals(2));
      expect(state.events[0].id, equals('evt-uuid-001'));
      expect(state.events[1].id, equals('evt-uuid-002'));

      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(
        http.calls.first.url,
        equals('/task-runs/run-uuid-001/stream-events'),
      );
    });

    // -----------------------------------------------------------------------
    // 5. loadExistingEvents — multi-page cursor pagination
    // -----------------------------------------------------------------------

    test('loadExistingEvents paginates through all pages', () async {
      int callCount = 0;
      http.whenAny((url) {
        callCount++;
        if (callCount == 1) {
          return MagicResponse(
            data: {
              'data': [kStreamEventA],
              'meta': {'has_more': true, 'next_cursor': 'cursor-page-2'},
            },
            statusCode: 200,
          );
        }
        return MagicResponse(
          data: {
            'data': [kStreamEventB],
            'meta': {'has_more': false, 'next_cursor': null},
          },
          statusCode: 200,
        );
      });

      await state.loadExistingEvents('run-uuid-001');

      expect(state.events.length, equals(2));
      expect(http.calls.length, equals(2));

      // First call has no after_id.
      expect(http.calls[0].query?['after_id'], isNull);

      // Second call uses the cursor.
      expect(http.calls[1].query?['after_id'], equals('cursor-page-2'));
    });

    // -----------------------------------------------------------------------
    // 6. loadExistingEvents — dedup by ID
    // -----------------------------------------------------------------------

    test('loadExistingEvents deduplicates events by ID', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kStreamEventA],
            'meta': {'has_more': false, 'next_cursor': null},
          },
          statusCode: 200,
        ),
      );

      // Load the same event twice.
      await state.loadExistingEvents('run-uuid-001');
      await state.loadExistingEvents('run-uuid-001');

      expect(state.events.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 7. loadExistingEvents — with afterId parameter
    // -----------------------------------------------------------------------

    test('loadExistingEvents passes afterId as query param', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': <Map<String, dynamic>>[],
            'meta': {'has_more': false, 'next_cursor': null},
          },
          statusCode: 200,
        ),
      );

      await state.loadExistingEvents('run-uuid-001', afterId: 'evt-uuid-099');

      expect(http.calls.first.query?['after_id'], equals('evt-uuid-099'));
    });

    // -----------------------------------------------------------------------
    // 8. addEvent — .agent.system updates runDetail
    // -----------------------------------------------------------------------

    test('addEvent with .agent.system updates sessionId and model', () async {
      // Set up runDetail first.
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      final wsEvent = WebSocketEvent(
        id: 'ws:system:1',
        channel: 'private-task-run.run-uuid-001',
        eventName: '.agent.system',
        data: {'session_id': 'sess-new-001', 'model': 'claude-opus-4-6'},
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.runDetail!.sessionId, equals('sess-new-001'));
      expect(state.runDetail!.model, equals('claude-opus-4-6'));
      expect(state.events.length, equals(1));
      expect(state.events.first.type, equals('system'));
    });

    // -----------------------------------------------------------------------
    // 9. addEvent — .agent.assistant increments turnCount
    // -----------------------------------------------------------------------

    test('addEvent with .agent.assistant increments turnCount', () async {
      // Set up runDetail first.
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      final wsEvent = WebSocketEvent(
        id: 'ws:assistant:1',
        channel: 'private-task-run.run-uuid-001',
        eventName: '.agent.assistant',
        data: {
          'content': [
            {'type': 'text', 'text': 'Hello '},
            {'type': 'text', 'text': 'world'},
          ],
        },
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.turnCount, equals(1));
      expect(state.events.length, equals(1));
      expect(state.events.first.contentText, equals('Hello world'));
      expect(state.events.first.type, equals('assistant'));
    });

    // -----------------------------------------------------------------------
    // 10. addEvent — .agent.result updates cost and duration
    // -----------------------------------------------------------------------

    test('addEvent with .agent.result updates cost and runDetail', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      final wsEvent = WebSocketEvent(
        id: 'ws:result:1',
        channel: 'private-task-run.run-uuid-001',
        eventName: '.agent.result',
        data: {'total_cost_usd': 0.045, 'duration_ms': 15200},
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.currentCost, equals(0.045));
      expect(state.runDetail!.totalCostUsd, equals(0.045));
      expect(state.runDetail!.durationMs, equals(15200));
      expect(state.events.length, equals(1));
      expect(state.events.first.type, equals('result'));
    });

    // -----------------------------------------------------------------------
    // 11. addEvent — .agent.status does NOT create a StreamEvent
    // -----------------------------------------------------------------------

    test(
      'addEvent with .agent.status updates status but no StreamEvent',
      () async {
        http.alwaysReturn(
          MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
        );
        await state.loadRunDetail(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );

        final wsEvent = WebSocketEvent(
          id: 'ws:status:1',
          channel: 'private-task-run.run-uuid-001',
          eventName: '.agent.status',
          data: {'status': 'done'},
          receivedAt: DateTime.now(),
        );

        state.addEvent(wsEvent);

        expect(state.runDetail!.status, equals('done'));
        expect(state.events, isEmpty);
      },
    );

    // -----------------------------------------------------------------------
    // 12. addEvent — .agent.question creates question StreamEvent
    // -----------------------------------------------------------------------

    test('addEvent with .agent.question creates question event', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      final wsEvent = WebSocketEvent(
        id: 'ws:question:1',
        channel: 'private-task-run.run-uuid-001',
        eventName: '.agent.question',
        data: {'question_text': 'Should I continue?'},
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.events.length, equals(1));
      expect(state.events.first.isQuestion, isTrue);
      expect(state.events.first.contentText, equals('Should I continue?'));
      expect(state.events.first.type, equals('question'));
    });

    // -----------------------------------------------------------------------
    // 13. addStreamEvent — dedup by ID
    // -----------------------------------------------------------------------

    test('addStreamEvent deduplicates by event ID', () {
      final event = StreamEvent.fromMap(kStreamEventA);

      state.addStreamEvent(event);
      state.addStreamEvent(event);

      expect(state.events.length, equals(1));
    });

    // -----------------------------------------------------------------------
    // 14. addStreamEvent — file_change extraction
    // -----------------------------------------------------------------------

    test('addStreamEvent extracts file changes', () {
      final event = StreamEvent.fromMap(kStreamEventFileChange);

      state.addStreamEvent(event);

      expect(state.events.length, equals(1));
      expect(state.fileChanges.length, equals(1));
      expect(state.fileChanges.first.filePath, equals('lib/main.dart'));
      expect(state.fileChanges.first.operation, equals('M'));
    });

    // -----------------------------------------------------------------------
    // 15. cancelRun — success
    // -----------------------------------------------------------------------

    test('cancelRun posts cancel and updates status', () async {
      // Load runDetail first.
      http.whenAny((url) {
        if (url.endsWith('/cancel')) {
          return MagicResponse(data: {'data': null}, statusCode: 200);
        }
        return MagicResponse(data: {'data': kRunDetail}, statusCode: 200);
      });

      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );
      expect(state.runDetail!.status, equals('running'));

      await state.cancelRun(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      expect(state.runDetail!.status, equals('cancelled'));

      final cancelCall = http.calls.last;
      expect(cancelCall.method, equals('POST'));
      expect(
        cancelCall.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/runs/run-uuid-001/cancel',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 16. reset — clears all state
    // -----------------------------------------------------------------------

    test('reset clears all state fields', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );
      expect(state.runDetail, isNotNull);

      state.reset();

      expect(state.runDetail, isNull);
      expect(state.events, isEmpty);
      expect(state.fileChanges, isEmpty);
      expect(state.turnCount, equals(0));
      expect(state.currentCost, equals(0.0));
    });

    // -----------------------------------------------------------------------
    // 17. addEvent — assistant content with mixed block types
    // -----------------------------------------------------------------------

    test('addEvent with .agent.assistant joins only text blocks', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
      );
      await state.loadRunDetail(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'run-uuid-001',
      );

      final wsEvent = WebSocketEvent(
        id: 'ws:assistant:mixed',
        channel: 'private-task-run.run-uuid-001',
        eventName: '.agent.assistant',
        data: {
          'content': [
            {'type': 'text', 'text': 'First part'},
            {'type': 'tool_use', 'name': 'read_file'},
            {'type': 'text', 'text': ' second part'},
          ],
        },
        receivedAt: DateTime.now(),
      );

      state.addEvent(wsEvent);

      expect(state.events.first.contentText, equals('First part second part'));
    });

    // -----------------------------------------------------------------------
    // Question Q&A
    // -----------------------------------------------------------------------

    group('Question Q&A', () {
      test('loadQuestions populates questions list', () async {
        http.alwaysReturn(
          MagicResponse(
            data: {
              'data': [kQuestionPending, kQuestionAnswered],
            },
            statusCode: 200,
          ),
        );

        await state.loadQuestions(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );

        expect(state.questions.length, equals(2));
        expect(state.questions[0].id, equals('question-uuid-001'));
        expect(state.questions[1].id, equals('question-uuid-002'));
        expect(state.pendingQuestions.length, equals(1));
      });

      test('loadQuestions sets empty list on error', () async {
        http.alwaysReturn(
          MagicResponse(
            data: {'message': 'Internal Server Error'},
            statusCode: 500,
          ),
        );

        await state.loadQuestions(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );

        expect(state.questions, isEmpty);
      });

      test('onQuestionEvent appends new question', () {
        state.onQuestionEvent({
          'question_id': 'question-uuid-099',
          'question_text': 'Should I continue?',
        });

        expect(state.questions.length, equals(1));
        expect(state.questions.first.id, equals('question-uuid-099'));
        expect(
          state.questions.first.questionText,
          equals('Should I continue?'),
        );
      });

      test('onQuestionEvent deduplicates by question_id', () {
        state.onQuestionEvent({
          'question_id': 'question-uuid-099',
          'question_text': 'Should I continue?',
        });
        state.onQuestionEvent({
          'question_id': 'question-uuid-099',
          'question_text': 'Should I continue?',
        });

        expect(state.questions.length, equals(1));
      });

      test('answerQuestion optimistically updates pending question', () async {
        // Load a pending question first.
        http.whenAny((url) {
          if (url.contains('/questions')) {
            return MagicResponse(
              data: {
                'data': [kQuestionPending],
              },
              statusCode: 200,
            );
          }
          if (url.contains('/answer')) {
            return MagicResponse(
              data: {
                'data': {'task_run_status': 'running'},
              },
              statusCode: 200,
            );
          }
          return MagicResponse(data: {'data': kRunDetail}, statusCode: 200);
        });

        await state.loadQuestions(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );
        expect(state.pendingQuestions.length, equals(1));

        final result = await state.answerQuestion(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
          'Yes, go ahead.',
        );

        expect(result, isTrue);
        expect(state.pendingQuestions, isEmpty);
        expect(state.questions.first.answerText, equals('Yes, go ahead.'));
        expect(state.questions.first.answeredAt, isNotNull);
      });

      test('reset clears questions', () async {
        http.alwaysReturn(
          MagicResponse(
            data: {
              'data': [kQuestionPending],
            },
            statusCode: 200,
          ),
        );

        await state.loadQuestions(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );
        expect(state.questions, isNotEmpty);

        state.reset();

        expect(state.questions, isEmpty);
      });

      test('addEvent with .agent.question calls onQuestionEvent', () async {
        http.alwaysReturn(
          MagicResponse(data: {'data': kRunDetail}, statusCode: 200),
        );
        await state.loadRunDetail(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'run-uuid-001',
        );

        final wsEvent = WebSocketEvent(
          id: 'ws:question:qa1',
          channel: 'private-task-run.run-uuid-001',
          eventName: '.agent.question',
          data: {
            'question_id': 'question-uuid-ws-001',
            'question_text': 'What framework?',
          },
          receivedAt: DateTime.now(),
        );

        state.addEvent(wsEvent);

        expect(state.questions.length, equals(1));
        expect(state.questions.first.id, equals('question-uuid-ws-001'));
        expect(state.questions.first.questionText, equals('What framework?'));
      });
    });
  });
}
