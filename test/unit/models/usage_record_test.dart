import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/usage_record.dart';

void main() {
  group('UsageRecord', () {
    // ---------------------------------------------------------------------------
    // Shared fixture
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kApiPayload = {
      'id': 'usage-uuid-001',
      'team_id': 'team-uuid-001',
      'task_run_id': 'run-uuid-001',
      'model': 'claude-3-5-sonnet-20241022',
      'input_tokens': 1500,
      'output_tokens': 300,
      'cache_read_tokens': 200,
      'cache_write_tokens': 50,
      'cost_usd': '0.00420',
      'period': '2025-03',
      'recorded_at': '2025-03-15T12:00:00.000Z',
      'task_run': {
        'agent_role_name': 'Dev',
        'task': {'title': 'Implement login', 'project_id': 'proj-uuid-001'},
      },
    };

    // ---------------------------------------------------------------------------
    // fromMap
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all required fields correctly', () {
      final record = UsageRecord.fromMap(kApiPayload);

      expect(record.id, equals('usage-uuid-001'));
      expect(record.teamId, equals('team-uuid-001'));
      expect(record.taskRunId, equals('run-uuid-001'));
      expect(record.model, equals('claude-3-5-sonnet-20241022'));
      expect(record.inputTokens, equals(1500));
      expect(record.outputTokens, equals(300));
      expect(record.cacheReadTokens, equals(200));
      expect(record.cacheWriteTokens, equals(50));
      expect(record.period, equals('2025-03'));
      expect(
        record.recordedAt,
        equals(DateTime.parse('2025-03-15T12:00:00.000Z')),
      );
    });

    test('fromMap parses costUsd from decimal string', () {
      final record = UsageRecord.fromMap(kApiPayload);

      expect(record.costUsd, equals(0.00420));
      expect(record.costUsd, isA<double>());
    });

    test('fromMap extracts nested task_run fields correctly', () {
      final record = UsageRecord.fromMap(kApiPayload);

      expect(record.agentRoleName, equals('Dev'));
      expect(record.taskTitle, equals('Implement login'));
      expect(record.projectId, equals('proj-uuid-001'));
    });

    // ---------------------------------------------------------------------------
    // Nullable fields
    // ---------------------------------------------------------------------------

    test('nullable fields return null when task_run is absent', () {
      const minimal = {
        'id': 'usage-uuid-002',
        'team_id': 'team-uuid-001',
        'task_run_id': null,
        'model': null,
        'input_tokens': null,
        'output_tokens': null,
        'cache_read_tokens': null,
        'cache_write_tokens': null,
        'cost_usd': '0.00100',
        'period': '2025-03',
        'recorded_at': '2025-03-16T08:00:00.000Z',
        'task_run': null,
      };

      final record = UsageRecord.fromMap(minimal);

      expect(record.taskRunId, isNull);
      expect(record.model, isNull);
      expect(record.inputTokens, isNull);
      expect(record.outputTokens, isNull);
      expect(record.cacheReadTokens, isNull);
      expect(record.cacheWriteTokens, isNull);
      expect(record.agentRoleName, isNull);
      expect(record.taskTitle, isNull);
      expect(record.projectId, isNull);
    });

    test(
      'nested task fields return null when task is absent inside task_run',
      () {
        final map = {
          ...kApiPayload,
          'task_run': {'agent_role_name': 'QA', 'task': null},
        };

        final record = UsageRecord.fromMap(map);

        expect(record.agentRoleName, equals('QA'));
        expect(record.taskTitle, isNull);
        expect(record.projectId, isNull);
      },
    );

    // ---------------------------------------------------------------------------
    // costUsd parsing
    // ---------------------------------------------------------------------------

    test('costUsd parses large decimal string correctly', () {
      final map = {...kApiPayload, 'cost_usd': '123.456789'};
      final record = UsageRecord.fromMap(map);

      expect(record.costUsd, closeTo(123.456789, 0.000001));
    });

    test('recordedAt is parsed as UTC DateTime', () {
      final record = UsageRecord.fromMap(kApiPayload);

      expect(record.recordedAt.isUtc, isTrue);
      expect(record.recordedAt.year, equals(2025));
      expect(record.recordedAt.month, equals(3));
      expect(record.recordedAt.day, equals(15));
    });
  });
}
