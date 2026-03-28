import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/session_usage_record.dart';

void main() {
  group('SessionUsageRecord', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'sur-uuid-1',
      'session_id': 'sess-uuid-1',
      'turn_number': 3,
      'model': 'claude-sonnet-4-6',
      'input_tokens': 1200,
      'output_tokens': 450,
      'cache_read_tokens': 800,
      'cache_creation_tokens': 200,
      'cost_usd': '0.004200',
      'is_subagent': false,
      'subagent_type': null,
      'created_at': '2025-03-10T09:00:00.000Z',
    };

    const Map<String, dynamic> subagentFixture = {
      'id': 'sur-uuid-2',
      'session_id': 'sess-uuid-1',
      'turn_number': 7,
      'model': 'claude-haiku-3-5',
      'input_tokens': 300,
      'output_tokens': 120,
      'cache_read_tokens': 0,
      'cache_creation_tokens': 0,
      'cost_usd': '0.000840',
      'is_subagent': true,
      'subagent_type': 'ac:explore',
      'created_at': '2025-03-10T09:01:00.000Z',
    };

    // -------

    test('fromMap parses all required fields correctly', () {
      final record = SessionUsageRecord.fromMap(fullFixture);

      expect(record.id, 'sur-uuid-1');
      expect(record.sessionId, 'sess-uuid-1');
      expect(record.turnNumber, 3);
      expect(record.model, 'claude-sonnet-4-6');
    });

    test('fromMap parses token count fields', () {
      final record = SessionUsageRecord.fromMap(fullFixture);

      expect(record.inputTokens, 1200);
      expect(record.outputTokens, 450);
      expect(record.cacheReadTokens, 800);
      expect(record.cacheCreationTokens, 200);
    });

    test('fromMap parses cost_usd from decimal string', () {
      final record = SessionUsageRecord.fromMap(fullFixture);

      expect(record.costUsd, closeTo(0.0042, 0.000001));
    });

    test('fromMap parses isSubagent as false for non-subagent turns', () {
      final record = SessionUsageRecord.fromMap(fullFixture);

      expect(record.isSubagent, isFalse);
      expect(record.subagentType, isNull);
    });

    test('fromMap parses isSubagent and subagentType for subagent turns', () {
      final record = SessionUsageRecord.fromMap(subagentFixture);

      expect(record.isSubagent, isTrue);
      expect(record.subagentType, 'ac:explore');
    });

    test('fromMap parses createdAt as DateTime', () {
      final record = SessionUsageRecord.fromMap(fullFixture);

      expect(record.createdAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
    });
  });
}
