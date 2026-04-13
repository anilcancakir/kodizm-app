import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

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

const Map<String, dynamic> kConversationA = {
  'id': 'conv-uuid-001',
  'project_id': 'proj-uuid-001',
  'user': {'id': 'user-uuid-001', 'name': 'Test User'},
  'agent_role': {
    'id': 'role-uuid-001',
    'name': 'Business Analyst',
    'slug': 'ba',
  },
  'status': 'completed',
  'type': 'autonomous',
  'task_id': 'task-uuid-001',
  'prompt': 'Implement the login screen',
  'model': 'claude-3-5-sonnet',
  'total_cost_usd': '0.0210',
  'total_input_tokens': 1200,
  'total_output_tokens': 800,
  'messages_count': 8,
  'last_activity_at': '2025-01-11T08:03:00.000Z',
  'started_at': '2025-01-11T08:01:00.000Z',
  'completed_at': '2025-01-11T08:03:00.000Z',
  'created_at': '2025-01-11T08:00:55.000Z',
  'updated_at': '2025-01-11T08:03:00.000Z',
};

const Map<String, dynamic> kAgentRoleA = {
  'id': 'role-uuid-001',
  'name': 'Business Analyst',
  'description': 'Analyses requirements and produces specs.',
  'scope': 'analysis',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('TaskState', () {
    late TaskState state;

    setUp(() {
      state = TaskState();
    });

    tearDown(() {
      state.dispose();
      Http.unfake();
    });

    // -----------------------------------------------------------------------
    // 1. fetchTasks — success
    // -----------------------------------------------------------------------

    test('fetchTasks sets loading then success with task list', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
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
      expect(fake.recorded.length, equals(1));
      expect(fake.recorded.first.$1.method, equals('GET'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/tasks'),
      );
    });

    // -----------------------------------------------------------------------
    // 2. fetchTasks — empty list sets empty state
    // -----------------------------------------------------------------------

    test('fetchTasks sets empty state when list is empty', () async {
      Http.fake(
        (MagicRequest req) =>
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
      Http.fake(
        (MagicRequest req) =>
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
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
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

      final req = fake.recorded.first.$1;
      expect(req.queryParameters, isNotNull);
      expect(req.queryParameters!['status'], equals('draft,analysis'));
      expect(req.queryParameters!['type'], equals('bug'));
      expect(req.queryParameters!['priority'], equals('high,critical'));
      expect(req.queryParameters!['sort'], equals('-updated_at'));
    });

    // -----------------------------------------------------------------------
    // 5. fetchTask — stores selectedTask
    // -----------------------------------------------------------------------

    test('fetchTask stores selectedTask', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kTaskA}, statusCode: 200),
      );

      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');

      expect(state.selectedTask, isNotNull);
      expect(state.selectedTask!.id, equals('task-uuid-001'));
      expect(state.selectedTask!.title, equals('Implement login screen'));

      expect(
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 6. createTask — success
    // -----------------------------------------------------------------------

    test('createTask posts data and returns created task', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kTaskA}, statusCode: 201),
      );

      final task = await state.createTask('team-uuid-001', 'proj-uuid-001', {
        'title': 'Implement login screen',
        'type': 'feature',
        'priority': 'high',
      });

      expect(task, isNotNull);
      expect(task!.id, equals('task-uuid-001'));

      expect(fake.recorded.first.$1.method, equals('POST'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/tasks'),
      );
    });

    // -----------------------------------------------------------------------
    // 7. updateTask — success
    // -----------------------------------------------------------------------

    test('updateTask sends PUT and returns updated task', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kTaskA}, statusCode: 200),
      );

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

      expect(fake.recorded.first.$1.method, equals('PUT'));
      expect(
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 8. deleteTask — success
    // -----------------------------------------------------------------------

    test('deleteTask sends DELETE and returns true on success', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(data: null, statusCode: 204),
      );

      final result = await state.deleteTask(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      expect(result, isTrue);

      expect(fake.recorded.first.$1.method, equals('DELETE'));
      expect(
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 9. deleteTask — failure returns false
    // -----------------------------------------------------------------------

    test('deleteTask returns false on failure', () async {
      Http.fake(
        (MagicRequest req) =>
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

      final fake = Http.fake(
        (MagicRequest req) =>
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

      final req = fake.recorded.first.$1;
      expect(req.method, equals('PUT'));
      expect(
        req.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001',
        ),
      );
      expect(
        (req.data as Map<String, dynamic>)['status'],
        equals('in_progress'),
      );
    });

    // -----------------------------------------------------------------------
    // 11. fetchSections — populates sections list
    // -----------------------------------------------------------------------

    test('fetchSections populates sections list', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
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
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/sections',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 12. fetchConversations — populates conversations list
    // -----------------------------------------------------------------------

    test('fetchConversations populates conversations list', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kConversationA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchConversations(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      );

      expect(state.conversations.length, equals(1));
      expect(state.conversations.first.id, equals('conv-uuid-001'));
      expect(state.conversations.first.status, equals('completed'));
      expect(
        state.conversations.first.agentRoleName,
        equals('Business Analyst'),
      );
      expect(state.conversations.first.isAutonomous, isTrue);

      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/conversations'),
      );
    });

    // -----------------------------------------------------------------------
    // 13. startRun — posts and returns Conversation
    // -----------------------------------------------------------------------

    test(
      'startRun posts agent_role_id and returns created Conversation',
      () async {
        final fake = Http.fake(
          (MagicRequest req) =>
              MagicResponse(data: {'data': kConversationA}, statusCode: 201),
        );

        final conversation = await state.startRun(
          'team-uuid-001',
          'proj-uuid-001',
          'task-uuid-001',
          'role-uuid-001',
        );

        expect(conversation, isNotNull);
        expect(conversation!.id, equals('conv-uuid-001'));
        expect(conversation.agentRoleId, equals('role-uuid-001'));
        expect(conversation.isAutonomous, isTrue);
        expect(conversation.taskId, equals('task-uuid-001'));
        expect(state.startingRun, isFalse);

        final req = fake.recorded.first.$1;
        expect(req.method, equals('POST'));
        expect(
          req.url,
          equals(
            '/teams/team-uuid-001/projects/proj-uuid-001/tasks/task-uuid-001/run',
          ),
        );
        expect(
          (req.data as Map<String, dynamic>)['agent_role_id'],
          equals('role-uuid-001'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 13b. startRun — includes prompt in request body when provided
    // -----------------------------------------------------------------------

    test('startRun includes prompt in request body when provided', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kConversationA}, statusCode: 201),
      );

      await state.startRun(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'role-uuid-001',
        prompt: 'Review auth middleware for security issues',
      );

      final req = fake.recorded.first.$1;
      final body = req.data as Map<String, dynamic>;
      expect(body['agent_role_id'], equals('role-uuid-001'));
      expect(
        body['prompt'],
        equals('Review auth middleware for security issues'),
      );
    });

    // -----------------------------------------------------------------------
    // 13c. startRun — omits prompt key when prompt is null
    // -----------------------------------------------------------------------

    test('startRun omits prompt key when prompt is null', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kConversationA}, statusCode: 201),
      );

      await state.startRun(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
        'role-uuid-001',
      );

      final req = fake.recorded.first.$1;
      final body = req.data as Map<String, dynamic>;
      expect(body.containsKey('prompt'), isFalse);
    });

    // -----------------------------------------------------------------------
    // 14. fetchAgentRoles — populates agentRoles list
    // -----------------------------------------------------------------------

    test('fetchAgentRoles populates agentRoles list', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
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

      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/agent-roles'),
      );
    });

    // -----------------------------------------------------------------------
    // 15. sortTasks by priority — critical first
    // -----------------------------------------------------------------------

    test('sortTasks by priority sorts critical before high', () async {
      // Load with high-priority task first, critical second.
      Http.fake(
        (MagicRequest req) => MagicResponse(
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
      Http.fake(
        (MagicRequest req) => MagicResponse(
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
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kTaskA}, statusCode: 200),
      );
      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001');
      expect(state.selectedTask, isNotNull);

      // Now simulate an error.
      Http.unfake();
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
      );
      await state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-999');

      expect(state.selectedTask, isNull);
    });
  });
}
