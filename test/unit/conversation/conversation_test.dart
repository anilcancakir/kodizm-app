import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/conversation.dart';

void main() {
  group('Conversation', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'conv-uuid-1',
      'project_id': 'proj-uuid-1',
      'user': {'id': 'user-uuid-1', 'name': 'John Doe'},
      'agent_role': {'id': 'role-uuid-1', 'name': 'Developer', 'slug': 'dev'},
      'title': 'Debug session',
      'status': 'active',
      'model': 'claude-sonnet-4-6',
      'total_cost_usd': '0.0234',
      'total_input_tokens': 1500,
      'total_output_tokens': 800,
      'messages_count': 6,
      'last_activity_at': '2026-03-27T10:00:00.000000Z',
      'started_at': '2026-03-27T09:00:00.000000Z',
      'completed_at': null,
      'created_at': '2026-03-27T09:00:00.000000Z',
      'updated_at': '2026-03-27T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'conv-uuid-2',
      'project_id': 'proj-uuid-2',
      'user': {'id': 'user-uuid-2', 'name': null},
      'agent_role': {'id': 'role-uuid-2', 'name': null, 'slug': null},
      'title': null,
      'status': 'completed',
      'model': null,
      'total_cost_usd': null,
      'total_input_tokens': 0,
      'total_output_tokens': 0,
      'messages_count': 0,
      'last_activity_at': null,
      'started_at': null,
      'completed_at': '2026-03-27T11:00:00.000000Z',
      'created_at': '2026-03-27T08:00:00.000000Z',
      'updated_at': '2026-03-27T11:00:00.000000Z',
    };

    // -------

    test('fromMap parses all required fields from full payload', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(conversation.id, 'conv-uuid-1');
      expect(conversation.projectId, 'proj-uuid-1');
      expect(conversation.status, 'active');
      expect(conversation.model, 'claude-sonnet-4-6');
    });

    test('fromMap extracts nested user id and name', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(conversation.userId, 'user-uuid-1');
      expect(conversation.userName, 'John Doe');
    });

    test('fromMap handles null user name', () {
      final conversation = Conversation.fromMap(minimalFixture);

      expect(conversation.userId, 'user-uuid-2');
      expect(conversation.userName, isNull);
    });

    test('fromMap extracts nested agent_role id, name, and slug', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(conversation.agentRoleId, 'role-uuid-1');
      expect(conversation.agentRoleName, 'Developer');
      expect(conversation.agentRoleSlug, 'dev');
    });

    test('fromMap handles null agent_role name and slug', () {
      final conversation = Conversation.fromMap(minimalFixture);

      expect(conversation.agentRoleId, 'role-uuid-2');
      expect(conversation.agentRoleName, isNull);
      expect(conversation.agentRoleSlug, isNull);
    });

    test('fromMap parses total_cost_usd string to double', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(conversation.totalCostUsd, closeTo(0.0234, 0.000001));
    });

    test('fromMap handles null total_cost_usd', () {
      final conversation = Conversation.fromMap(minimalFixture);

      expect(conversation.totalCostUsd, isNull);
    });

    test('fromMap parses token count and messages_count fields', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(conversation.totalInputTokens, 1500);
      expect(conversation.totalOutputTokens, 800);
      expect(conversation.messagesCount, 6);
    });

    test('fromMap parses DateTime fields correctly', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(
        conversation.createdAt,
        DateTime.parse('2026-03-27T09:00:00.000000Z'),
      );
      expect(
        conversation.updatedAt,
        DateTime.parse('2026-03-27T10:00:00.000000Z'),
      );
      expect(
        conversation.startedAt,
        DateTime.parse('2026-03-27T09:00:00.000000Z'),
      );
      expect(conversation.completedAt, isNull);
    });

    test('fromMap parses nullable DateTime fields', () {
      final conversation = Conversation.fromMap(fullFixture);

      expect(
        conversation.lastActivityAt,
        DateTime.parse('2026-03-27T10:00:00.000000Z'),
      );
    });

    test('fromMap handles null optional DateTime fields', () {
      final conversation = Conversation.fromMap(minimalFixture);

      expect(conversation.lastActivityAt, isNull);
      expect(conversation.startedAt, isNull);
      expect(
        conversation.completedAt,
        DateTime.parse('2026-03-27T11:00:00.000000Z'),
      );
    });

    test('fromMap handles null title', () {
      final conversation = Conversation.fromMap(minimalFixture);

      expect(conversation.title, isNull);
    });

    // -------

    test('copyWith returns new instance with updated status', () {
      final conversation = Conversation.fromMap(fullFixture);
      final updated = conversation.copyWith(status: 'completed');

      expect(updated.status, 'completed');
      expect(updated.id, conversation.id);
      expect(updated.projectId, conversation.projectId);
    });

    test('copyWith preserves all unchanged fields', () {
      final conversation = Conversation.fromMap(fullFixture);
      final updated = conversation.copyWith(totalCostUsd: 0.99);

      expect(updated.totalCostUsd, closeTo(0.99, 0.000001));
      expect(updated.id, conversation.id);
      expect(updated.projectId, conversation.projectId);
      expect(updated.userId, conversation.userId);
      expect(updated.userName, conversation.userName);
      expect(updated.agentRoleId, conversation.agentRoleId);
      expect(updated.agentRoleName, conversation.agentRoleName);
      expect(updated.agentRoleSlug, conversation.agentRoleSlug);
      expect(updated.title, conversation.title);
      expect(updated.status, conversation.status);
      expect(updated.model, conversation.model);
      expect(updated.totalInputTokens, conversation.totalInputTokens);
      expect(updated.totalOutputTokens, conversation.totalOutputTokens);
      expect(updated.messagesCount, conversation.messagesCount);
      expect(updated.lastActivityAt, conversation.lastActivityAt);
      expect(updated.startedAt, conversation.startedAt);
      expect(updated.completedAt, conversation.completedAt);
      expect(updated.createdAt, conversation.createdAt);
      expect(updated.updatedAt, conversation.updatedAt);
    });

    test('copyWith with messagesCount updates only that field', () {
      final conversation = Conversation.fromMap(fullFixture);
      final updated = conversation.copyWith(messagesCount: 12);

      expect(updated.messagesCount, 12);
      expect(updated.status, conversation.status);
      expect(updated.totalCostUsd, conversation.totalCostUsd);
    });
  });
}
