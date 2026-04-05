import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/project_memory.dart';

void main() {
  group('ProjectMemory', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'mem-uuid-1',
      'project_id': 'proj-uuid-1',
      'file_name': 'architecture.md',
      'name': 'Architecture Overview',
      'description': 'High-level system architecture notes.',
      'type': 'project',
      'content': '# Architecture\n\nThis is the architecture.',
      'metadata': {'source': 'agent', 'version': '2'},
      'created_by_user_id': 'user-uuid-1',
      'created_by_user': {'id': 'user-uuid-1', 'name': 'Alice Smith'},
      'created_by_agent_role_id': 'role-uuid-1',
      'created_by_agent_role': {
        'id': 'role-uuid-1',
        'name': 'Business Analyst',
      },
      'last_synced_at': '2026-04-01T10:00:00.000000Z',
      'expires_at': '2027-04-01T10:00:00.000000Z',
      'created_at': '2026-03-25T09:00:00.000000Z',
      'updated_at': '2026-03-25T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'mem-uuid-2',
      'project_id': 'proj-uuid-2',
      'file_name': 'note.md',
      'name': 'Quick Note',
      'description': 'A brief note.',
      'type': 'feedback',
      'content': 'Just a note.',
      'metadata': null,
      'created_by_user_id': null,
      'created_by_user': null,
      'created_by_agent_role_id': null,
      'created_by_agent_role': null,
      'last_synced_at': null,
      'expires_at': null,
      'created_at': '2026-03-26T08:00:00.000000Z',
      'updated_at': '2026-03-26T08:00:00.000000Z',
    };

    // -------

    test('fromMap parses all fields from full fixture', () {
      final mem = ProjectMemory.fromMap(fullFixture);

      expect(mem.id, 'mem-uuid-1');
      expect(mem.projectId, 'proj-uuid-1');
      expect(mem.fileName, 'architecture.md');
      expect(mem.name, 'Architecture Overview');
      expect(mem.description, 'High-level system architecture notes.');
      expect(mem.type, 'project');
      expect(mem.content, '# Architecture\n\nThis is the architecture.');
      expect(mem.metadata, {'source': 'agent', 'version': '2'});
      expect(mem.createdByUserId, 'user-uuid-1');
      expect(mem.createdByUserName, 'Alice Smith');
      expect(mem.createdByAgentRoleId, 'role-uuid-1');
      expect(mem.createdByAgentRoleName, 'Business Analyst');
      expect(mem.lastSyncedAt, DateTime.parse('2026-04-01T10:00:00.000000Z'));
      expect(mem.expiresAt, DateTime.parse('2027-04-01T10:00:00.000000Z'));
      expect(mem.createdAt, DateTime.parse('2026-03-25T09:00:00.000000Z'));
      expect(mem.updatedAt, DateTime.parse('2026-03-25T10:00:00.000000Z'));
    });

    test('fromMap handles null optional fields in minimal fixture', () {
      final mem = ProjectMemory.fromMap(minimalFixture);

      expect(mem.id, 'mem-uuid-2');
      expect(mem.projectId, 'proj-uuid-2');
      expect(mem.metadata, isNull);
      expect(mem.createdByUserId, isNull);
      expect(mem.createdByUserName, isNull);
      expect(mem.createdByAgentRoleId, isNull);
      expect(mem.createdByAgentRoleName, isNull);
      expect(mem.lastSyncedAt, isNull);
      expect(mem.expiresAt, isNull);
    });

    test('fromMap parses type field as String value', () {
      final memProject = ProjectMemory.fromMap(fullFixture);
      final memFeedback = ProjectMemory.fromMap(minimalFixture);

      expect(memProject.type, 'project');
      expect(memFeedback.type, 'feedback');
    });
  });
}
