import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/task.dart';

void main() {
  group('Task', () {
    // ---------------------------------------------------------------------------
    // Shared fixtures
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kListPayload = {
      'id': 'task-uuid-001',
      'project_id': 'proj-uuid-001',
      'parent_task_id': null,
      'title': 'Implement authentication',
      'type': 'feature',
      'priority': 'high',
      'status': 'in_progress',
      'estimated_complexity': 3,
      'assigned_agent_role_id': 'role-uuid-001',
      'created_by_user_id': 'user-uuid-001',
      'source': 'manual',
      'design_needed': true,
      'retry_count': 1,
      'branch_name': 'feature/auth',
      'total_cost_usd': '0.42',
      'created_at': '2024-03-01T08:00:00.000Z',
      'updated_at': '2024-03-15T12:30:00.000Z',
    };

    const Map<String, dynamic> kDetailPayload = {
      'id': 'task-uuid-002',
      'project_id': 'proj-uuid-001',
      'parent_task_id': 'task-uuid-001',
      'title': 'Build login screen',
      'type': 'feature',
      'priority': 'medium',
      'status': 'planning',
      'estimated_complexity': 2,
      'assigned_agent_role_id': 'role-uuid-002',
      'created_by_user_id': 'user-uuid-001',
      'source': 'ai',
      'design_needed': false,
      'retry_count': 0,
      'branch_name': null,
      'total_cost_usd': '0.00',
      'description': 'Build the login screen with email/password fields.',
      'acceptance_criteria': 'User can log in with valid credentials.',
      'assigned_agent_role': {'id': 'role-uuid-002', 'name': 'Frontend Dev'},
      'created_by_user': {'id': 'user-uuid-001', 'name': 'Alice'},
      'sub_tasks_count': 3,
      'sections_count': 2,
      'linked_conversations_count': 1,
      'created_at': '2024-03-10T09:00:00.000Z',
      'updated_at': '2024-03-20T11:00:00.000Z',
    };

    // ---------------------------------------------------------------------------
    // fromMap — list shape
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all list-shape fields', () {
      final task = Task.fromMap(kListPayload);

      expect(task.id, equals('task-uuid-001'));
      expect(task.projectId, equals('proj-uuid-001'));
      expect(task.parentTaskId, isNull);
      expect(task.title, equals('Implement authentication'));
      expect(task.type, equals('feature'));
      expect(task.priority, equals('high'));
      expect(task.status, equals('in_progress'));
      expect(task.estimatedComplexity, equals(3));
      expect(task.assignedAgentRoleId, equals('role-uuid-001'));
      expect(task.createdByUserId, equals('user-uuid-001'));
      expect(task.source, equals('manual'));
      expect(task.designNeeded, isTrue);
      expect(task.retryCount, equals(1));
      expect(task.branchName, equals('feature/auth'));
      expect(task.totalCostUsd, equals('0.42'));
    });

    test('fromMap parses createdAt and updatedAt as Carbon', () {
      final task = Task.fromMap(kListPayload);

      expect(task.createdAt, isA<Carbon>());
      expect(task.updatedAt, isA<Carbon>());
      expect(task.createdAt!.toDateTime.year, equals(2024));
      expect(task.createdAt!.toDateTime.month, equals(3));
      expect(task.createdAt!.toDateTime.day, equals(1));
    });

    test('fromMap sets exists to true when id is present', () {
      final task = Task.fromMap(kListPayload);

      expect(task.exists, isTrue);
    });

    test('fromMap sets exists to false when id is absent', () {
      final map = Map<String, dynamic>.from(kListPayload)..remove('id');
      final task = Task.fromMap(map);

      expect(task.exists, isFalse);
    });

    // ---------------------------------------------------------------------------
    // fromMap — detail shape
    // ---------------------------------------------------------------------------

    test('fromMap hydrates detail-only fields when present', () {
      final task = Task.fromMap(kDetailPayload);

      expect(
        task.description,
        equals('Build the login screen with email/password fields.'),
      );
      expect(
        task.acceptanceCriteria,
        equals('User can log in with valid credentials.'),
      );
      expect(task.subTasksCount, equals(3));
      expect(task.sectionsCount, equals(2));
      expect(task.linkedConversationsCount, equals(1));
    });

    test('fromMap extracts nested assignedAgentRoleName', () {
      final task = Task.fromMap(kDetailPayload);

      expect(task.assignedAgentRoleName, equals('Frontend Dev'));
    });

    test('fromMap extracts nested createdByUserName', () {
      final task = Task.fromMap(kDetailPayload);

      expect(task.createdByUserName, equals('Alice'));
    });

    test('fromMap hydrates parentTaskId when present', () {
      final task = Task.fromMap(kDetailPayload);

      expect(task.parentTaskId, equals('task-uuid-001'));
    });

    // ---------------------------------------------------------------------------
    // Nullable / defaulted fields
    // ---------------------------------------------------------------------------

    test('designNeeded defaults to false when absent from map', () {
      final map = Map<String, dynamic>.from(kListPayload)
        ..remove('design_needed');
      final task = Task.fromMap(map);

      expect(task.designNeeded, isFalse);
    });

    test('detail-only fields return null when absent from map', () {
      final task = Task.fromMap(kListPayload);

      expect(task.description, isNull);
      expect(task.acceptanceCriteria, isNull);
      expect(task.assignedAgentRoleName, isNull);
      expect(task.createdByUserName, isNull);
      expect(task.subTasksCount, isNull);
      expect(task.sectionsCount, isNull);
      expect(task.linkedConversationsCount, isNull);
    });

    test('nullable list-shape fields return null when absent', () {
      final minimal = {
        'id': 'task-uuid-003',
        'project_id': 'proj-uuid-001',
        'title': 'Minimal task',
        'type': 'chore',
        'priority': 'low',
        'status': 'draft',
        'source': 'manual',
        'design_needed': false,
        'retry_count': 0,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      final task = Task.fromMap(minimal);

      expect(task.parentTaskId, isNull);
      expect(task.estimatedComplexity, isNull);
      expect(task.assignedAgentRoleId, isNull);
      expect(task.branchName, isNull);
      expect(task.totalCostUsd, isNull);
    });

    // ---------------------------------------------------------------------------
    // fromJson
    // ---------------------------------------------------------------------------

    test('fromJson delegates to fromMap and returns equivalent model', () {
      final json = jsonEncode(kDetailPayload);
      final task = Task.fromJson(json);

      expect(task.id, equals('task-uuid-002'));
      expect(task.title, equals('Build login screen'));
      expect(task.assignedAgentRoleName, equals('Frontend Dev'));
      expect(task.createdByUserName, equals('Alice'));
      expect(task.exists, isTrue);
    });

    // ---------------------------------------------------------------------------
    // Typed setters
    // ---------------------------------------------------------------------------

    test('typed setters mutate the underlying attribute store', () {
      final task = Task.fromMap(kListPayload);

      task.title = 'Updated title';
      task.status = 'done';
      task.branchName = 'hotfix/login';

      expect(task.title, equals('Updated title'));
      expect(task.status, equals('done'));
      expect(task.branchName, equals('hotfix/login'));
    });

    // ---------------------------------------------------------------------------
    // Task ID display accessors
    // ---------------------------------------------------------------------------

    test('taskId accessor returns api value', () {
      final task = Task.fromMap({'id': 'task-uuid-001', 'task_id': 'KDZ-1'});

      expect(task.taskId, equals('KDZ-1'));
    });

    test('taskNumber accessor returns api value', () {
      final task = Task.fromMap({'id': 'task-uuid-001', 'task_number': 42});

      expect(task.taskNumber, equals(42));
    });

    test('taskId is null when absent from map', () {
      final task = Task.fromMap({'id': 'task-uuid-001'});

      expect(task.taskId, isNull);
    });

    // ---------------------------------------------------------------------------
    // ORM configuration
    // ---------------------------------------------------------------------------

    test('incrementing is false (UUID primary keys)', () {
      final task = Task();

      expect(task.incrementing, isFalse);
    });

    test('table is tasks', () {
      final task = Task();

      expect(task.table, equals('tasks'));
    });

    test('resource is tasks', () {
      final task = Task();

      expect(task.resource, equals('tasks'));
    });
  });
}
