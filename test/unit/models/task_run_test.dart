import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/task_run.dart';

void main() {
  group('TaskRun', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'run-uuid-1',
      'task_id': 'task-uuid-1',
      'agent_role_id': 'role-uuid-1',
      'agent_role': {'id': 'role-uuid-1', 'name': 'Developer'},
      'status': 'done',
      'model': 'claude-3-5-sonnet',
      'session_id': 'sess-uuid-1',
      'prompt': 'Implement the login feature',
      'total_cost_usd': 0.0042,
      'duration_ms': 8500,
      'num_turns': 12,
      'error': null,
      'started_at': '2025-03-10T09:00:00.000Z',
      'completed_at': '2025-03-10T09:00:08.500Z',
      'created_at': '2025-03-10T09:00:00.000Z',
    };

    const Map<String, dynamic> failedFixture = {
      'id': 'run-uuid-2',
      'task_id': 'task-uuid-2',
      'agent_role_id': 'role-uuid-2',
      'agent_role': null,
      'status': 'failed',
      'model': null,
      'session_id': null,
      'prompt': null,
      'total_cost_usd': null,
      'duration_ms': null,
      'num_turns': null,
      'error': 'Rate limit exceeded',
      'started_at': '2025-03-11T10:00:00.000Z',
      'completed_at': null,
      'created_at': '2025-03-11T10:00:00.000Z',
    };

    // -------

    test('fromMap parses all required fields correctly', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.id, 'run-uuid-1');
      expect(run.taskId, 'task-uuid-1');
      expect(run.agentRoleId, 'role-uuid-1');
      expect(run.status, 'done');
      expect(run.model, 'claude-3-5-sonnet');
    });

    test('fromMap parses agentRoleName from nested agent_role relation', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.agentRoleName, 'Developer');
    });

    test('fromMap handles null agent_role relation', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.agentRoleName, isNull);
    });

    test('fromMap parses numeric fields with correct types', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.totalCostUsd, closeTo(0.0042, 0.000001));
      expect(run.durationMs, 8500);
      expect(run.numTurns, 12);
    });

    test('fromMap handles null numeric fields', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.totalCostUsd, isNull);
      expect(run.durationMs, isNull);
      expect(run.numTurns, isNull);
    });

    test('fromMap parses nullable DateTime fields', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.startedAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
      expect(run.completedAt, DateTime.parse('2025-03-10T09:00:08.500Z'));
      expect(run.createdAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
    });

    test('fromMap handles present startedAt with null completedAt', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.startedAt, isNotNull);
      expect(run.completedAt, isNull);
    });

    test('fromMap captures error field', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.error, 'Rate limit exceeded');
    });

    test('fromMap sets error to null when absent', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.error, isNull);
    });

    test('fromMap parses sessionId from session_id key', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.sessionId, 'sess-uuid-1');
    });

    test('fromMap handles null sessionId', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.sessionId, isNull);
    });

    test('fromMap parses prompt text', () {
      final run = TaskRun.fromMap(fullFixture);

      expect(run.prompt, 'Implement the login feature');
    });

    test('fromMap handles null prompt', () {
      final run = TaskRun.fromMap(failedFixture);

      expect(run.prompt, isNull);
    });
  });
}
