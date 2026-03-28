import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/session.dart';
import 'package:app/app/models/session_usage_record.dart';
import 'package:app/app/models/session_share.dart';

void main() {
  group('Session', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'sess-uuid-1',
      'type': 'autonomous',
      'phase': 'executing',
      'model': 'claude-sonnet-4-6',
      'total_cost_usd': '0.012600',
      'total_input_tokens': 4800,
      'total_output_tokens': 1200,
      'total_cache_read_tokens': 2400,
      'total_cache_creation_tokens': 600,
      'warm_until': null,
      'started_at': '2025-03-10T09:00:00.000Z',
      'completed_at': null,
      'created_at': '2025-03-10T08:59:00.000Z',
      'updated_at': '2025-03-10T09:00:00.000Z',
      'usage_records': [
        {
          'id': 'sur-uuid-1',
          'session_id': 'sess-uuid-1',
          'turn_number': 1,
          'model': 'claude-sonnet-4-6',
          'input_tokens': 1200,
          'output_tokens': 450,
          'cache_read_tokens': 800,
          'cache_creation_tokens': 200,
          'cost_usd': '0.004200',
          'is_subagent': false,
          'subagent_type': null,
          'created_at': '2025-03-10T09:00:00.000Z',
        },
      ],
      'shares': [
        {
          'id': 'share-uuid-1',
          'session_id': 'sess-uuid-1',
          'shareable_type': 'App\\Models\\Project',
          'shareable_id': 'proj-uuid-1',
          'permission': 'read',
          'shared_by': 'user-uuid-1',
          'created_at': '2025-03-10T09:00:00.000Z',
          'updated_at': '2025-03-10T09:00:00.000Z',
        },
      ],
    };

    const Map<String, dynamic> warmFixture = {
      'id': 'sess-uuid-2',
      'type': 'interactive',
      'phase': 'warm',
      'model': 'claude-haiku-3-5',
      'total_cost_usd': '0.001000',
      'total_input_tokens': 500,
      'total_output_tokens': 200,
      'total_cache_read_tokens': 0,
      'total_cache_creation_tokens': 0,
      'warm_until': '2025-03-10T09:15:00.000Z',
      'started_at': '2025-03-10T09:00:00.000Z',
      'completed_at': '2025-03-10T09:05:00.000Z',
      'created_at': '2025-03-10T08:59:00.000Z',
      'updated_at': '2025-03-10T09:05:00.000Z',
    };

    const Map<String, dynamic> noRelationsFixture = {
      'id': 'sess-uuid-3',
      'type': 'system',
      'phase': 'dead',
      'model': null,
      'total_cost_usd': '0.000000',
      'total_input_tokens': 0,
      'total_output_tokens': 0,
      'total_cache_read_tokens': 0,
      'total_cache_creation_tokens': 0,
      'warm_until': null,
      'started_at': null,
      'completed_at': null,
      'created_at': '2025-03-10T08:59:00.000Z',
      'updated_at': '2025-03-10T08:59:00.000Z',
    };

    // -------

    test('fromMap parses all required fields correctly', () {
      final session = Session.fromMap(fullFixture);

      expect(session.id, 'sess-uuid-1');
      expect(session.type, 'autonomous');
      expect(session.phase, 'executing');
      expect(session.model, 'claude-sonnet-4-6');
    });

    test('fromMap parses totalCostUsd from decimal string', () {
      final session = Session.fromMap(fullFixture);

      expect(session.totalCostUsd, closeTo(0.0126, 0.000001));
    });

    test('fromMap parses token count fields', () {
      final session = Session.fromMap(fullFixture);

      expect(session.totalInputTokens, 4800);
      expect(session.totalOutputTokens, 1200);
      expect(session.totalCacheReadTokens, 2400);
      expect(session.totalCacheCreationTokens, 600);
    });

    test('fromMap parses nullable warmUntil as null when absent', () {
      final session = Session.fromMap(fullFixture);

      expect(session.warmUntil, isNull);
    });

    test('fromMap parses warmUntil as DateTime when present', () {
      final session = Session.fromMap(warmFixture);

      expect(session.warmUntil, DateTime.parse('2025-03-10T09:15:00.000Z'));
    });

    test('fromMap parses startedAt and completedAt as DateTimes', () {
      final session = Session.fromMap(fullFixture);

      expect(session.startedAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
      expect(session.completedAt, isNull);
    });

    test('fromMap parses completedAt when present', () {
      final session = Session.fromMap(warmFixture);

      expect(session.completedAt, DateTime.parse('2025-03-10T09:05:00.000Z'));
    });

    test('fromMap parses createdAt and updatedAt as DateTimes', () {
      final session = Session.fromMap(fullFixture);

      expect(session.createdAt, DateTime.parse('2025-03-10T08:59:00.000Z'));
      expect(session.updatedAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
    });

    test('fromMap parses nested usage_records into typed list', () {
      final session = Session.fromMap(fullFixture);

      expect(session.usageRecords, hasLength(1));
      expect(session.usageRecords.first, isA<SessionUsageRecord>());
      expect(session.usageRecords.first.id, 'sur-uuid-1');
    });

    test('fromMap parses nested shares into typed list', () {
      final session = Session.fromMap(fullFixture);

      expect(session.shares, hasLength(1));
      expect(session.shares.first, isA<SessionShare>());
      expect(session.shares.first.id, 'share-uuid-1');
    });

    test('fromMap defaults usageRecords to empty list when key absent', () {
      final session = Session.fromMap(noRelationsFixture);

      expect(session.usageRecords, isEmpty);
    });

    test('fromMap defaults shares to empty list when key absent', () {
      final session = Session.fromMap(noRelationsFixture);

      expect(session.shares, isEmpty);
    });

    test('fromMap handles null model field', () {
      final session = Session.fromMap(noRelationsFixture);

      expect(session.model, isNull);
    });

    // -------

    test('copyWith replaces phase field', () {
      final session = Session.fromMap(fullFixture);
      final updated = session.copyWith(phase: 'warm');

      expect(updated.phase, 'warm');
      expect(updated.id, session.id);
    });

    test('copyWith replaces model field', () {
      final session = Session.fromMap(fullFixture);
      final updated = session.copyWith(model: 'claude-opus-4-5');

      expect(updated.model, 'claude-opus-4-5');
    });

    test('copyWith replaces totalCostUsd field', () {
      final session = Session.fromMap(fullFixture);
      final updated = session.copyWith(totalCostUsd: 0.05);

      expect(updated.totalCostUsd, closeTo(0.05, 0.000001));
    });

    test('copyWith retains all unchanged fields', () {
      final session = Session.fromMap(fullFixture);
      final updated = session.copyWith(phase: 'warm');

      expect(updated.type, session.type);
      expect(updated.totalInputTokens, session.totalInputTokens);
      expect(updated.usageRecords, session.usageRecords);
      expect(updated.shares, session.shares);
    });
  });
}
