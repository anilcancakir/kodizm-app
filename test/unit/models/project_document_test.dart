import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/project_document.dart';

void main() {
  group('ProjectDocument', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'doc-uuid-1',
      'project_id': 'proj-uuid-1',
      'title': 'Architecture Overview',
      'content': '# Architecture\n\nThis document describes the system.',
      'category': 'architecture',
      'metadata': {
        'tags': ['overview', 'design'],
        'version': '1.0',
      },
      'created_by_user_id': 'user-uuid-1',
      'created_by_user': {'id': 'user-uuid-1', 'name': 'Alice Smith'},
      'created_by_agent_role_id': 'role-uuid-1',
      'created_by_agent_role': {
        'id': 'role-uuid-1',
        'name': 'Business Analyst',
      },
      'created_at': '2026-03-25T09:00:00.000000Z',
      'updated_at': '2026-03-25T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'doc-uuid-2',
      'project_id': 'proj-uuid-2',
      'title': 'Quick Note',
      'content': 'Just a note.',
      'category': null,
      'metadata': null,
      'created_by_user_id': null,
      'created_by_user': null,
      'created_by_agent_role_id': null,
      'created_by_agent_role': null,
      'created_at': '2026-03-26T08:00:00.000000Z',
      'updated_at': '2026-03-26T08:00:00.000000Z',
    };

    // -------

    test('fromMap parses all required fields from full payload', () {
      final doc = ProjectDocument.fromMap(fullFixture);

      expect(doc.id, 'doc-uuid-1');
      expect(doc.projectId, 'proj-uuid-1');
      expect(doc.title, 'Architecture Overview');
      expect(
        doc.content,
        '# Architecture\n\nThis document describes the system.',
      );
      expect(doc.category, 'architecture');
    });

    test('fromMap extracts createdByUserName from nested created_by_user', () {
      final doc = ProjectDocument.fromMap(fullFixture);

      expect(doc.createdByUserId, 'user-uuid-1');
      expect(doc.createdByUserName, 'Alice Smith');
    });

    test(
      'fromMap extracts createdByAgentRoleName from nested created_by_agent_role',
      () {
        final doc = ProjectDocument.fromMap(fullFixture);

        expect(doc.createdByAgentRoleId, 'role-uuid-1');
        expect(doc.createdByAgentRoleName, 'Business Analyst');
      },
    );

    test('fromMap parses metadata map correctly', () {
      final doc = ProjectDocument.fromMap(fullFixture);

      expect(doc.metadata, isNotNull);
      expect(doc.metadata!['version'], '1.0');
    });

    test('fromMap parses DateTime fields correctly', () {
      final doc = ProjectDocument.fromMap(fullFixture);

      expect(doc.createdAt, DateTime.parse('2026-03-25T09:00:00.000000Z'));
      expect(doc.updatedAt, DateTime.parse('2026-03-25T10:00:00.000000Z'));
    });

    test('fromMap handles null optional fields in minimal payload', () {
      final doc = ProjectDocument.fromMap(minimalFixture);

      expect(doc.category, isNull);
      expect(doc.metadata, isNull);
      expect(doc.createdByUserId, isNull);
      expect(doc.createdByUserName, isNull);
      expect(doc.createdByAgentRoleId, isNull);
      expect(doc.createdByAgentRoleName, isNull);
    });

    test('fromMap with null nested relations sets name fields to null', () {
      final doc = ProjectDocument.fromMap(minimalFixture);

      expect(doc.createdByUserName, isNull);
      expect(doc.createdByAgentRoleName, isNull);
    });

    test('fromMap parses minimal required fields correctly', () {
      final doc = ProjectDocument.fromMap(minimalFixture);

      expect(doc.id, 'doc-uuid-2');
      expect(doc.projectId, 'proj-uuid-2');
      expect(doc.title, 'Quick Note');
      expect(doc.content, 'Just a note.');
      expect(doc.createdAt, DateTime.parse('2026-03-26T08:00:00.000000Z'));
      expect(doc.updatedAt, DateTime.parse('2026-03-26T08:00:00.000000Z'));
    });
  });
}
