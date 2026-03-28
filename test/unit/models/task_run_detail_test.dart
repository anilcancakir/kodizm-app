import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/task_run_detail.dart';

void main() {
  group('TaskRunDetail', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'run-uuid-1',
      'task_id': 'task-uuid-1',
      'agent_role_id': 'role-uuid-1',
      'agent_role': {
        'id': 'role-uuid-1',
        'name': 'Developer',
        'slug': 'developer',
        'description': 'Writes the code',
        'preferred_model': 'claude-sonnet-4-6',
      },
      'status': 'running',
      'prompt': 'Implement the feature...',
      'model': 'claude-sonnet-4-6',
      'session_id': 'sess_abc123',
      'total_cost_usd': 0.47,
      'usage': {'input_tokens': 1000, 'output_tokens': 500},
      'duration_ms': 154000,
      'num_turns': 12,
      'error': null,
      'ai_token_id': 'token-uuid-1',
      'worktree_path': '/path/to/worktree',
      'worktree_branch': 'agent/task-abc',
      'started_at': '2026-03-25T10:00:00.000000Z',
      'completed_at': null,
      'created_at': '2026-03-25T09:59:00.000000Z',
      'updated_at': '2026-03-25T10:02:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'run-uuid-2',
      'task_id': 'task-uuid-2',
      'agent_role_id': 'role-uuid-2',
      'agent_role': null,
      'status': 'failed',
      'prompt': 'Analyse the requirements.',
      'model': null,
      'session_id': null,
      'total_cost_usd': null,
      'usage': null,
      'duration_ms': null,
      'num_turns': null,
      'error': 'Rate limit exceeded',
      'ai_token_id': null,
      'worktree_path': null,
      'worktree_branch': null,
      'started_at': null,
      'completed_at': null,
      'created_at': '2026-03-25T09:00:00.000000Z',
      'updated_at': null,
    };

    // -------

    test('fromMap parses all required fields from full payload', () {
      final run = TaskRunDetail.fromMap(fullFixture);

      expect(run.id, 'run-uuid-1');
      expect(run.taskId, 'task-uuid-1');
      expect(run.agentRoleId, 'role-uuid-1');
      expect(run.status, 'running');
      expect(run.prompt, 'Implement the feature...');
      expect(run.model, 'claude-sonnet-4-6');
    });

    test(
      'fromMap extracts agentRoleName and agentRoleSlug from nested agent_role',
      () {
        final run = TaskRunDetail.fromMap(fullFixture);

        expect(run.agentRoleName, 'Developer');
        expect(run.agentRoleSlug, 'developer');
      },
    );

    test('fromMap handles null agent_role — sets name and slug to null', () {
      final run = TaskRunDetail.fromMap(minimalFixture);

      expect(run.agentRoleName, isNull);
      expect(run.agentRoleSlug, isNull);
    });

    test('fromMap parses numeric and cost fields correctly', () {
      final run = TaskRunDetail.fromMap(fullFixture);

      expect(run.totalCostUsd, closeTo(0.47, 0.000001));
      expect(run.durationMs, 154000);
      expect(run.numTurns, 12);
    });

    test('fromMap handles null optionals in minimal payload', () {
      final run = TaskRunDetail.fromMap(minimalFixture);

      expect(run.model, isNull);
      expect(run.sessionId, isNull);
      expect(run.totalCostUsd, isNull);
      expect(run.usage, isNull);
      expect(run.durationMs, isNull);
      expect(run.numTurns, isNull);
      expect(run.error, 'Rate limit exceeded');
      expect(run.aiTokenId, isNull);
      expect(run.worktreePath, isNull);
      expect(run.worktreeBranch, isNull);
      expect(run.updatedAt, isNull);
    });

    test('fromMap parses DateTime fields including nullable ones', () {
      final run = TaskRunDetail.fromMap(fullFixture);

      expect(run.createdAt, DateTime.parse('2026-03-25T09:59:00.000000Z'));
      expect(run.updatedAt, DateTime.parse('2026-03-25T10:02:00.000000Z'));
      expect(run.startedAt, DateTime.parse('2026-03-25T10:00:00.000000Z'));
      expect(run.completedAt, isNull);
    });

    test('fromMap parses usage map and extra string fields', () {
      final run = TaskRunDetail.fromMap(fullFixture);

      expect(run.usage, {'input_tokens': 1000, 'output_tokens': 500});
      expect(run.sessionId, 'sess_abc123');
      expect(run.aiTokenId, 'token-uuid-1');
      expect(run.worktreePath, '/path/to/worktree');
      expect(run.worktreeBranch, 'agent/task-abc');
    });

    // -------

    test('copyWith returns new instance with updated status', () {
      final run = TaskRunDetail.fromMap(fullFixture);
      final updated = run.copyWith(status: 'done');

      expect(updated.status, 'done');
      expect(updated.id, run.id);
      expect(updated.prompt, run.prompt);
    });

    test('copyWith preserves all unchanged fields', () {
      final run = TaskRunDetail.fromMap(fullFixture);
      final updated = run.copyWith(
        totalCostUsd: 1.23,
        durationMs: 99000,
        numTurns: 20,
      );

      expect(updated.totalCostUsd, closeTo(1.23, 0.000001));
      expect(updated.durationMs, 99000);
      expect(updated.numTurns, 20);
      expect(updated.id, run.id);
      expect(updated.taskId, run.taskId);
      expect(updated.agentRoleId, run.agentRoleId);
      expect(updated.agentRoleName, run.agentRoleName);
      expect(updated.agentRoleSlug, run.agentRoleSlug);
      expect(updated.prompt, run.prompt);
      expect(updated.model, run.model);
      expect(updated.sessionId, run.sessionId);
      expect(updated.usage, run.usage);
      expect(updated.error, run.error);
      expect(updated.aiTokenId, run.aiTokenId);
      expect(updated.worktreePath, run.worktreePath);
      expect(updated.worktreeBranch, run.worktreeBranch);
      expect(updated.startedAt, run.startedAt);
      expect(updated.completedAt, run.completedAt);
      expect(updated.createdAt, run.createdAt);
      expect(updated.updatedAt, run.updatedAt);
    });

    test('copyWith with model and sessionId updates only those fields', () {
      final run = TaskRunDetail.fromMap(fullFixture);
      final updated = run.copyWith(
        model: 'claude-opus-4-5',
        sessionId: 'sess_new456',
      );

      expect(updated.model, 'claude-opus-4-5');
      expect(updated.sessionId, 'sess_new456');
      expect(updated.status, run.status);
      expect(updated.totalCostUsd, run.totalCostUsd);
    });
  });
}
