import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/conversation.dart';

void main() {
  group('Conversation — progress fields', () {
    // -----------------------------------------------------------------------
    // Fixtures
    // -----------------------------------------------------------------------

    const Map<String, dynamic> baseFixture = {
      'id': 'conv-123',
      'project_id': 'proj-456',
      'user': {'id': 'user-1', 'name': 'Test User'},
      'agent_role': {'id': 'role-1', 'name': 'Developer', 'slug': 'dev'},
      'status': 'active',
      'type': 'interactive',
      'total_input_tokens': 0,
      'total_output_tokens': 0,
      'created_at': '2026-04-07T00:00:00.000Z',
      'updated_at': '2026-04-07T00:00:00.000Z',
    };

    // -----------------------------------------------------------------------
    // fromMap
    // -----------------------------------------------------------------------

    test('fromMap parses all progress fields when present', () {
      final map = {
        ...baseFixture,
        'last_progress_status': 'implementing',
        'last_progress_message': 'Running tests',
        'last_progress_percentage': 75,
        'last_progress_at': '2026-04-07T12:00:00.000Z',
      };

      final conv = Conversation.fromMap(map);

      expect(conv.lastProgressStatus, 'implementing');
      expect(conv.lastProgressMessage, 'Running tests');
      expect(conv.lastProgressPercentage, 75);
      expect(conv.lastProgressAt, isA<DateTime>());
    });

    test('fromMap handles missing progress fields gracefully', () {
      final conv = Conversation.fromMap(baseFixture);

      expect(conv.lastProgressStatus, isNull);
      expect(conv.lastProgressMessage, isNull);
      expect(conv.lastProgressPercentage, isNull);
      expect(conv.lastProgressAt, isNull);
    });

    test('lastProgressAt is parsed as DateTime with correct components', () {
      final map = {
        ...baseFixture,
        'last_progress_at': '2026-04-07T12:30:00.000Z',
      };

      final conv = Conversation.fromMap(map);

      expect(conv.lastProgressAt?.year, 2026);
      expect(conv.lastProgressAt?.month, 4);
      expect(conv.lastProgressAt?.hour, 12);
      expect(conv.lastProgressAt?.minute, 30);
    });

    test('fromMap parses last_progress_percentage as int', () {
      final map = {...baseFixture, 'last_progress_percentage': 100};

      final conv = Conversation.fromMap(map);

      expect(conv.lastProgressPercentage, 100);
      expect(conv.lastProgressPercentage, isA<int>());
    });

    // -----------------------------------------------------------------------
    // copyWith
    // -----------------------------------------------------------------------

    test('copyWith overrides progress fields independently', () {
      final conv = Conversation.fromMap(baseFixture);
      final updated = conv.copyWith(
        lastProgressStatus: 'blocked',
        lastProgressPercentage: 90,
      );

      expect(updated.lastProgressStatus, 'blocked');
      expect(updated.lastProgressPercentage, 90);
      expect(updated.lastProgressMessage, isNull);
      expect(updated.lastProgressAt, isNull);
    });

    test('copyWith preserves identity fields when updating progress', () {
      final conv = Conversation.fromMap({
        ...baseFixture,
        'last_progress_status': 'running',
        'last_progress_message': 'Initial',
        'last_progress_percentage': 50,
        'last_progress_at': '2026-04-07T10:00:00.000Z',
      });

      final updated = conv.copyWith(lastProgressStatus: 'completed');

      expect(updated.id, conv.id);
      expect(updated.projectId, conv.projectId);
      expect(updated.userId, conv.userId);
      expect(updated.agentRoleName, conv.agentRoleName);
      expect(updated.lastProgressStatus, 'completed');
      // Unchanged fields from original.
      expect(updated.lastProgressMessage, conv.lastProgressMessage);
      expect(updated.lastProgressPercentage, conv.lastProgressPercentage);
      expect(updated.lastProgressAt, conv.lastProgressAt);
    });

    test('copyWith with lastProgressAt updates only that DateTime field', () {
      final conv = Conversation.fromMap(baseFixture);
      final newAt = DateTime.utc(2026, 4, 7, 15, 0, 0);
      final updated = conv.copyWith(lastProgressAt: newAt);

      expect(updated.lastProgressAt, newAt);
      expect(updated.lastProgressStatus, isNull);
    });
  });
}
