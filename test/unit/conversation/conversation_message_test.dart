import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/conversation_message.dart';

void main() {
  group('ConversationMessage', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'msg-uuid-1',
      'conversation_id': 'conv-uuid-1',
      'role': 'assistant',
      'content': 'Hello! How can I help you today?',
      'metadata': {'tool': 'bash', 'exit_code': 0},
      'cost_usd': '0.0012',
      'usage': {'input_tokens': 200, 'output_tokens': 50},
      'duration_ms': 1234,
      'num_turns': 2,
      'error': null,
      'started_at': '2026-03-27T10:00:00.000000Z',
      'completed_at': '2026-03-27T10:00:01.000000Z',
      'created_at': '2026-03-27T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'msg-uuid-2',
      'conversation_id': 'conv-uuid-2',
      'role': 'user',
      'content': 'Hello agent',
      'metadata': null,
      'cost_usd': null,
      'usage': null,
      'duration_ms': null,
      'num_turns': null,
      'error': null,
      'started_at': '2026-03-27T10:00:00.000000Z',
      'completed_at': null,
      'created_at': '2026-03-27T10:00:00.000000Z',
    };

    const Map<String, dynamic> errorFixture = {
      'id': 'msg-uuid-3',
      'conversation_id': 'conv-uuid-3',
      'role': 'assistant',
      'content': '',
      'metadata': null,
      'cost_usd': null,
      'usage': null,
      'duration_ms': null,
      'num_turns': null,
      'error': 'Rate limit exceeded',
      'started_at': null,
      'completed_at': null,
      'created_at': '2026-03-27T10:00:00.000000Z',
    };

    // -------

    test('fromMap parses all required fields from full payload', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.id, 'msg-uuid-1');
      expect(message.conversationId, 'conv-uuid-1');
      expect(message.role, 'assistant');
      expect(message.content, 'Hello! How can I help you today?');
    });

    test('fromMap parses cost_usd string to double', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.costUsd, closeTo(0.0012, 0.000001));
    });

    test('fromMap handles null cost_usd', () {
      final message = ConversationMessage.fromMap(minimalFixture);

      expect(message.costUsd, isNull);
    });

    test('fromMap parses usage map and numeric fields', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.usage, {'input_tokens': 200, 'output_tokens': 50});
      expect(message.durationMs, 1234);
      expect(message.numTurns, 2);
    });

    test('fromMap handles null usage, durationMs, numTurns', () {
      final message = ConversationMessage.fromMap(minimalFixture);

      expect(message.usage, isNull);
      expect(message.durationMs, isNull);
      expect(message.numTurns, isNull);
    });

    test('fromMap parses metadata map', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.metadata, {'tool': 'bash', 'exit_code': 0});
    });

    test('fromMap handles null metadata', () {
      final message = ConversationMessage.fromMap(minimalFixture);

      expect(message.metadata, isNull);
    });

    test('fromMap parses error field', () {
      final message = ConversationMessage.fromMap(errorFixture);

      expect(message.error, 'Rate limit exceeded');
    });

    test('fromMap handles null error', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.error, isNull);
    });

    test('fromMap parses DateTime fields correctly', () {
      final message = ConversationMessage.fromMap(fullFixture);

      expect(message.createdAt, DateTime.parse('2026-03-27T10:00:00.000000Z'));
      expect(message.startedAt, DateTime.parse('2026-03-27T10:00:00.000000Z'));
      expect(
        message.completedAt,
        DateTime.parse('2026-03-27T10:00:01.000000Z'),
      );
    });

    test('fromMap handles null optional DateTime fields', () {
      final message = ConversationMessage.fromMap(minimalFixture);

      expect(message.completedAt, isNull);
    });

    test('fromMap handles null started_at', () {
      final message = ConversationMessage.fromMap(errorFixture);

      expect(message.startedAt, isNull);
    });

    // -------

    test('copyWith returns new instance with updated role', () {
      final message = ConversationMessage.fromMap(minimalFixture);
      final updated = message.copyWith(role: 'assistant');

      expect(updated.role, 'assistant');
      expect(updated.id, message.id);
      expect(updated.conversationId, message.conversationId);
    });

    test('copyWith preserves all unchanged fields', () {
      final message = ConversationMessage.fromMap(fullFixture);
      final updated = message.copyWith(costUsd: 0.99);

      expect(updated.costUsd, closeTo(0.99, 0.000001));
      expect(updated.id, message.id);
      expect(updated.conversationId, message.conversationId);
      expect(updated.role, message.role);
      expect(updated.content, message.content);
      expect(updated.metadata, message.metadata);
      expect(updated.usage, message.usage);
      expect(updated.durationMs, message.durationMs);
      expect(updated.numTurns, message.numTurns);
      expect(updated.error, message.error);
      expect(updated.startedAt, message.startedAt);
      expect(updated.completedAt, message.completedAt);
      expect(updated.createdAt, message.createdAt);
    });

    test('copyWith with content updates only that field', () {
      final message = ConversationMessage.fromMap(minimalFixture);
      final updated = message.copyWith(content: 'Updated content');

      expect(updated.content, 'Updated content');
      expect(updated.role, message.role);
      expect(updated.costUsd, message.costUsd);
    });
  });
}
