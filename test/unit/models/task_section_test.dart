import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/task_section.dart';

void main() {
  group('TaskSection', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'section-uuid-1',
      'task_id': 'task-uuid-1',
      'type': 'analysis',
      'title': 'Analysis Output',
      'content': 'The system requires a login flow.',
      'created_by_agent_role_id': 'role-uuid-1',
      'created_by_agent_role': {
        'id': 'role-uuid-1',
        'name': 'Business Analyst',
      },
      'created_by_user_id': null,
      'version': 2,
      'created_at': '2025-03-01T10:00:00.000Z',
      'updated_at': '2025-03-02T11:00:00.000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'section-uuid-2',
      'task_id': 'task-uuid-2',
      'type': 'planning',
      'title': 'Plan',
      'content': 'Step 1: Do this.',
      'created_by_agent_role_id': null,
      'created_by_agent_role': null,
      'created_by_user_id': 'user-uuid-1',
      'version': 1,
      'created_at': '2025-03-05T08:00:00.000Z',
      'updated_at': '2025-03-05T08:00:00.000Z',
    };

    // -------

    test('fromMap parses all required fields correctly', () {
      final section = TaskSection.fromMap(fullFixture);

      expect(section.id, 'section-uuid-1');
      expect(section.taskId, 'task-uuid-1');
      expect(section.type, 'analysis');
      expect(section.title, 'Analysis Output');
      expect(section.content, 'The system requires a login flow.');
      expect(section.version, 2);
    });

    test(
      'fromMap parses createdByAgentRoleId and createdByAgentRoleName from nested relation',
      () {
        final section = TaskSection.fromMap(fullFixture);

        expect(section.createdByAgentRoleId, 'role-uuid-1');
        expect(section.createdByAgentRoleName, 'Business Analyst');
        expect(section.createdByUserId, isNull);
      },
    );

    test('fromMap handles null created_by_agent_role relation', () {
      final section = TaskSection.fromMap(minimalFixture);

      expect(section.createdByAgentRoleId, isNull);
      expect(section.createdByAgentRoleName, isNull);
      expect(section.createdByUserId, 'user-uuid-1');
    });

    test('fromMap parses createdAt and updatedAt as DateTime', () {
      final section = TaskSection.fromMap(fullFixture);

      expect(section.createdAt, DateTime.parse('2025-03-01T10:00:00.000Z'));
      expect(section.updatedAt, DateTime.parse('2025-03-02T11:00:00.000Z'));
    });

    test('constructor produces correct field values', () {
      final section = TaskSection(
        id: 'abc',
        taskId: 'task-abc',
        type: 'review',
        title: 'Review Notes',
        content: 'LGTM',
        createdByAgentRoleId: null,
        createdByAgentRoleName: null,
        createdByUserId: 'user-1',
        version: 1,
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 2),
      );

      expect(section.id, 'abc');
      expect(section.type, 'review');
      expect(section.version, 1);
    });
  });
}
