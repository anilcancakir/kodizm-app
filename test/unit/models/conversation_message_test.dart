import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/models/conversation_message.dart';

void main() {
  /// Tests for [ConversationMessage] model.
  group('ConversationMessage', () {
    final baseMap = <String, dynamic>{
      'id': 'msg-123',
      'conversation_id': 'conv-456',
      'role': 'assistant',
      'content': 'Hello, world!',
      'created_at': '2026-04-04T10:00:00Z',
    };

    test('fromMap parses status field when present', () {
      final map = {...baseMap, 'status': 'queued'};

      final message = ConversationMessage.fromMap(map);

      expect(message.status, equals('queued'));
    });

    test('fromMap parses status as null when absent', () {
      final message = ConversationMessage.fromMap(baseMap);

      expect(message.status, isNull);
    });

    test('fromMap handles various status values', () {
      const statuses = [
        'queued',
        'processing',
        'completed',
        'failed',
        'cancelled',
      ];

      for (final status in statuses) {
        final map = {...baseMap, 'status': status};

        final message = ConversationMessage.fromMap(map);

        expect(message.status, equals(status));
      }
    });

    test('copyWith preserves status when not specified', () {
      final map = {...baseMap, 'status': 'processing'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(content: 'Updated content');

      expect(copied.status, equals('processing'));
      expect(copied.content, equals('Updated content'));
    });

    test('copyWith updates status when specified', () {
      final map = {...baseMap, 'status': 'processing'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(status: 'completed');

      expect(copied.status, equals('completed'));
    });

    test('copyWith can set status to null', () {
      final map = {...baseMap, 'status': 'queued'};

      final original = ConversationMessage.fromMap(map);
      final copied = original.copyWith(status: null);

      expect(copied.status, isNull);
    });

    test('fromMap preserves all existing fields alongside status', () {
      final map = {
        ...baseMap,
        'status': 'completed',
        'metadata': {'key': 'value'},
        'cost_usd': '0.05',
        'usage': {'input_tokens': 100, 'output_tokens': 50},
        'duration_ms': 1250,
        'num_turns': 2,
        'error': null,
        'started_at': '2026-04-04T09:59:00Z',
        'completed_at': '2026-04-04T10:00:00Z',
      };

      final message = ConversationMessage.fromMap(map);

      expect(message.id, equals('msg-123'));
      expect(message.conversationId, equals('conv-456'));
      expect(message.role, equals('assistant'));
      expect(message.content, equals('Hello, world!'));
      expect(message.status, equals('completed'));
      expect(message.metadata, equals({'key': 'value'}));
      expect(message.costUsd, equals(0.05));
      expect(message.usage, equals({'input_tokens': 100, 'output_tokens': 50}));
      expect(message.durationMs, equals(1250));
      expect(message.numTurns, equals(2));
      expect(message.error, isNull);
      expect(message.startedAt, isNotNull);
      expect(message.completedAt, isNotNull);
      expect(message.createdAt, isNotNull);
    });
  });
}
