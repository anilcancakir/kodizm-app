import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/task_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTaskA = {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'parent_task_id': null,
  'title': 'Implement login screen',
  'type': 'feature',
  'priority': 'high',
  'status': 'draft',
  'estimated_complexity': 3,
  'assigned_agent_role_id': 'role-uuid-001',
  'created_by_user_id': 'user-uuid-001',
  'source': 'manual',
  'design_needed': false,
  'retry_count': 0,
  'branch_name': null,
  'total_cost_usd': null,
  'created_at': '2025-01-10T08:00:00.000Z',
  'updated_at': '2025-03-01T12:00:00.000Z',
};

const Map<String, dynamic> kTaskB = {
  'id': 'task-uuid-002',
  'project_id': 'proj-uuid-001',
  'parent_task_id': null,
  'title': 'Fix payment bug',
  'type': 'bug',
  'priority': 'critical',
  'status': 'in_progress',
  'estimated_complexity': 5,
  'assigned_agent_role_id': 'role-uuid-002',
  'created_by_user_id': 'user-uuid-001',
  'source': 'ai',
  'design_needed': false,
  'retry_count': 1,
  'branch_name': 'fix/payment-bug',
  'total_cost_usd': '0.043',
  'created_at': '2025-02-01T10:00:00.000Z',
  'updated_at': '2025-03-20T09:00:00.000Z',
};

const Map<String, dynamic> kSectionA = {
  'id': 'section-uuid-001',
  'task_id': 'task-uuid-001',
  'type': 'analysis',
  'title': 'Analysis Output',
  'content': '## Analysis\n\nSome analysis content.',
  'version': 1,
  'created_by_agent_role_id': 'role-uuid-001',
  'created_by_agent_role': {'id': 'role-uuid-001', 'name': 'Business Analyst'},
  'created_by_user_id': null,
  'created_at': '2025-01-11T08:00:00.000Z',
  'updated_at': '2025-01-11T08:00:00.000Z',
};

const Map<String, dynamic> kRunA = {
  'id': 'run-uuid-001',
  'task_id': 'task-uuid-001',
  'agent_role_id': 'role-uuid-001',
  'agent_role': {'id': 'role-uuid-001', 'name': 'Business Analyst'},
  'status': 'done',
  'model': 'claude-3-5-sonnet',
  'total_cost_usd': 0.021,
  'duration_ms': 12400,
  'num_turns': 8,
  'error': null,
  'started_at': '2025-01-11T08:01:00.000Z',
  'completed_at': '2025-01-11T08:03:00.000Z',
  'created_at': '2025-01-11T08:00:55.000Z',
};

const Map<String, dynamic> kAgentRoleA = {
  'id': 'role-uuid-001',
  'name': 'Business Analyst',
  'description': 'Analyses requirements and produces specs.',
  'scope': 'analysis',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [TaskState] without hitting the
/// network. Each method records the call and returns a pre-configured
/// [MagicResponse].
class FakeTaskHttpClient implements TaskHttpClient {
  final List<TaskHttpCall> calls = [];
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
    calls.add(TaskHttpCall('GET', url, query: query));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('DELETE', url));
    return _responder(url);
  }
}

class TaskHttpCall {
  TaskHttpCall(this.method, this.url, {this.data, this.query});

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
  group('TaskState', () {
    late FakeTaskHttpClient http;
    late TaskState state;

    setUp(() {
      http = FakeTaskHttpClient();
      state = TaskState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. fetchTasks — success
    // -----------------------------------------------------------------------

    test('fetchTasks sets loading then success with task list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kTaskA, kTaskB],
          },
          statusCode: 200,
        ),
      );

      // Should start empty.
      expect(state.isEmpty, isTrue);

      final future = state.fetchTasks('team-uuid-001', 'proj-uuid-001');

      // Loading is synchronous — should be set immediately.
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.rxState, isNotNull);
      expect(state.rxState!.length, equals(2));
      expect(state.rxState![0].id, equals('task-uuid-001'));
      expect(state.rxState![1].id, equals('task-uuid-002'));

      // Verify correct URL was called.
      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/tasks'),
      );
    });

    // -----------------------------------------------------------------------
    // 2. fetchTasks — empty list sets empty state
    // -----------------------------------------------------------------------

    test('fetchTasks sets empty state when list is empty', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
      );

      await state.fetchTasks('team-uuid-001', 'proj-uuid-001');

      expect(state.isEmpty, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 3. fetchTasks — error
    // -----------------------------------------------------------------------

    test('fetchTasks sets loading then error on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.fetchTasks('team-uuid-001', 'proj-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 4. fetchTasks — filter query params are forwarded
    // -----------------------------------------------------------------------

    test('fetchTasks passes filter and sort as query params', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kTaskA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchTasks(
        'team-uuid-001',
        'proj-uuid-001',
        statusFilter: ['draft', 'analysis'],
        typeFilter: ['bug'],
        priorityFilter: ['high', 'critical'],
        sort: '-updated_at',
      );

      final call = http.calls.first;
      expect(call.query, isNotNull);
      expect(call.query!['status'], equals('draft,analysis'));
      expect(call.query!['type'], equals('bug'));
      expect(call.query!['priority'], equals('high,critical'));
      expect(call.query!['sort'], equals('-updated_at'));
    });

    // -----------------------------------------------------------------------
    // 5. fetchTask — stores selectedTask
    // -----------------------------------------------------------------------

    test('fetchTask stores selectedTask', () async {
      http.alwaysReturn(MagicResponse(data: {'data': kTaskA}, statusCode: 200));

      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');

      expect(state.selectedTask, isNotNull);
      expect(state.selectedTask!.id, equals('task-uuid-001'));
      expect(state.selectedTask!.title, equals('Implement login screen'));

      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 6. createTask — success
    // -----------------------------------------------------------------------

    test('createTask posts data and returns created task', () async {
      http.alwaysReturn(MagicResponse(data: {'data': kTaskA}, statusCode: 201));

      final task = await state.createTask('team-uuid-001', 'proj-uuid-001', {
        'title': 'Implement login screen',
        'type': 'feature',
        'priority': 'high',
      });

      expect(task, isNotNull);
      expect(task!.id, equals('task-uuid-001'));

      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/tasks'),
      );
    });

    // -----------------------------------------------------------------------
    // 7. updateTask — success
    // -----------------------------------------------------------------------

    test('updateTask sends PUT and returns updated task', () async {
      http.alwaysReturn(MagicResponse(data: {'data': kTaskA}, statusCode: 200));

      final task = await state.updateTask(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        {'title': 'Implement login screen v2'},
      );

      expect(task, isNotNull);
      expect(task!.id, equals('task-uuid-001'));
      expect(state.selectedTask, isNotNull);
      expect(state.selectedTask!.id, equals('task-uuid-001'));

      expect(http.calls.first.method, equals('PUT'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 8. deleteTask — success
    // -----------------------------------------------------------------------

    test('deleteTask sends DELETE and returns true on success', () async {
      http.alwaysReturn(MagicResponse(data: null, statusCode: 204));

      final result = await state.deleteTask(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      expect(result, isTrue);

      expect(http.calls.first.method, equals('DELETE'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 9. deleteTask — failure returns false
    // -----------------------------------------------------------------------

    test('deleteTask returns false on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      final result = await state.deleteTask(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 10. transitionStatus — updates selectedTask
    // -----------------------------------------------------------------------

    test('transitionStatus PUTs new status and updates selectedTask', () async {
      final updatedTask = {...kTaskA, 'status': 'in_progress'};

      http.alwaysReturn(
        MagicResponse(data: {'data': updatedTask}, statusCode: 200),
      );

      final task = await state.transitionStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'in_progress',
      );

      expect(task, isNotNull);
      expect(task!.status, equals('in_progress'));
      expect(state.selectedTask, isNotNull);
      expect(state.selectedTask!.status, equals('in_progress'));

      final call = http.calls.first;
      expect(call.method, equals('PUT'));
      expect(
        call.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
      expect(
        (call.data as Map<String, dynamic>)['status'],
        equals('in_progress'),
      );
    });

    // -----------------------------------------------------------------------
    // 11. fetchSections — populates sections list
    // -----------------------------------------------------------------------

    test('fetchSections populates sections list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kSectionA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchSections(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      expect(state.sections.length, equals(1));
      expect(state.sections.first.id, equals('section-uuid-001'));
      expect(state.sections.first.type, equals('analysis'));
      expect(
        state.sections.first.createdByAgentRoleName,
        equals('Business Analyst'),
      );

      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/sections',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 12. fetchRuns — populates runs list
    // -----------------------------------------------------------------------

    test('fetchRuns populates runs list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kRunA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchRuns('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');

      expect(state.runs.length, equals(1));
      expect(state.runs.first.id, equals('run-uuid-001'));
      expect(state.runs.first.status, equals('done'));
      expect(state.runs.first.agentRoleName, equals('Business Analyst'));

      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/runs',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 13. startRun — posts and returns TaskRun
    // -----------------------------------------------------------------------

    test('startRun posts agent_role_id and returns created TaskRun', () async {
      http.alwaysReturn(MagicResponse(data: {'data': kRunA}, statusCode: 201));

      final run = await state.startRun(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'role-uuid-001',
      );

      expect(run, isNotNull);
      expect(run!.id, equals('run-uuid-001'));
      expect(run.agentRoleId, equals('role-uuid-001'));
      expect(state.startingRun, isFalse);

      final call = http.calls.first;
      expect(call.method, equals('POST'));
      expect(
        call.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/runs',
        ),
      );
      expect(
        (call.data as Map<String, dynamic>)['agent_role_id'],
        equals('role-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 14. fetchAgentRoles — populates agentRoles list
    // -----------------------------------------------------------------------

    test('fetchAgentRoles populates agentRoles list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kAgentRoleA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchAgentRoles('team-uuid-001');

      expect(state.agentRoles.length, equals(1));
      expect(state.agentRoles.first.id, equals('role-uuid-001'));
      expect(state.agentRoles.first.name, equals('Business Analyst'));
      expect(state.agentRoles.first.scope, equals('analysis'));

      expect(http.calls.first.url, equals('/teams/team-uuid-001/agent-roles'));
    });

    // -----------------------------------------------------------------------
    // 15. sortTasks by priority — critical first
    // -----------------------------------------------------------------------

    test('sortTasks by priority sorts critical before high', () async {
      // Load with high-priority task first, critical second.
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kTaskA, kTaskB], // A=high, B=critical
          },
          statusCode: 200,
        ),
      );

      await state.fetchTasks('team-uuid-001', 'proj-uuid-001');
      expect(state.rxState![0].priority, equals('high'));

      state.sortTasks(TaskSortField.priority);

      expect(state.rxState![0].priority, equals('critical'));
      expect(state.rxState![1].priority, equals('high'));
    });

    // -----------------------------------------------------------------------
    // 16. sortTasks by updatedAt — most recent first
    // -----------------------------------------------------------------------

    test('sortTasks by updatedAt sorts most recent first', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [
              kTaskA,
              kTaskB,
            ], // A updated 2025-03-01, B updated 2025-03-20
          },
          statusCode: 200,
        ),
      );

      await state.fetchTasks('team-uuid-001', 'proj-uuid-001');
      expect(state.rxState![0].id, equals('task-uuid-001'));

      state.sortTasks(TaskSortField.updatedAt);

      // B (2025-03-20) should come before A (2025-03-01).
      expect(state.rxState![0].id, equals('task-uuid-002'));
      expect(state.rxState![1].id, equals('task-uuid-001'));
    });

    // -----------------------------------------------------------------------
    // 17. fetchTask — error sets selectedTask to null
    // -----------------------------------------------------------------------

    test('fetchTask sets selectedTask to null on error', () async {
      // First, set a successful selectedTask.
      http.whenAny(
        (_) => MagicResponse(data: {'data': kTaskA}, statusCode: 200),
      );
      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');
      expect(state.selectedTask, isNotNull);

      // Now simulate an error.
      http.whenAny(
        (_) => MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
      );
      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-999');

      expect(state.selectedTask, isNull);
    });
  });
}
