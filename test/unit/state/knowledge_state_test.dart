import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/knowledge_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kDocumentA = {
  'id': 'doc-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Architecture Overview',
  'content': '## Architecture\n\nThis project uses Flutter + Laravel.',
  'category': 'architecture',
  'metadata': null,
  'type': 'document',
  'memory_type': null,
  'auto_inject': null,
  'priority': null,
  'created_by_user_id': 'user-uuid-001',
  'created_by_user': {'id': 'user-uuid-001', 'name': 'Alice Smith'},
  'created_by_agent_role_id': null,
  'created_by_agent_role': null,
  'created_at': '2025-01-10T08:00:00.000Z',
  'updated_at': '2025-03-01T12:00:00.000Z',
};

const Map<String, dynamic> kDocumentB = {
  'id': 'doc-uuid-002',
  'project_id': 'proj-uuid-001',
  'title': 'API Reference',
  'content': '## API\n\nEndpoints documented here.',
  'category': 'api',
  'metadata': null,
  'type': 'document',
  'memory_type': null,
  'auto_inject': null,
  'priority': null,
  'created_by_user_id': null,
  'created_by_user': null,
  'created_by_agent_role_id': 'role-uuid-001',
  'created_by_agent_role': {'id': 'role-uuid-001', 'name': 'Business Analyst'},
  'created_at': '2025-02-01T10:00:00.000Z',
  'updated_at': '2025-03-20T09:00:00.000Z',
};

const Map<String, dynamic> kMemoryA = {
  'id': 'mem-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Architecture Notes',
  'content': '# Architecture\n\nThis system uses a microservices approach.',
  'category': null,
  'metadata': null,
  'type': 'memory',
  'memory_type': 'project',
  'auto_inject': true,
  'priority': 1,
  'created_by_user_id': 'user-uuid-001',
  'created_by_user': {'name': 'Alice Smith'},
  'created_by_agent_role_id': null,
  'created_by_agent_role': null,
  'created_at': '2025-01-10T10:00:00.000Z',
  'updated_at': '2025-01-10T10:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('KnowledgeState', () {
    late KnowledgeState state;

    setUp(() {
      state = KnowledgeState();
    });

    tearDown(() {
      state.dispose();
      Http.unfake();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state
    // -----------------------------------------------------------------------

    test('initial state has empty documents list and is not loading', () {
      expect(state.documents, isEmpty);
      expect(state.isEmpty, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.selectedDocument, isNull);
      expect(state.isEditing, isFalse);
    });

    // -----------------------------------------------------------------------
    // 2. loadDocuments — populates documents list
    // -----------------------------------------------------------------------

    test('loadDocuments populates documents list via GET', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kDocumentA, kDocumentB],
          },
          statusCode: 200,
        ),
      );

      expect(state.isEmpty, isTrue);

      final future = state.loadDocuments('team-uuid-001', 'proj-uuid-001');

      expect(state.isLoading, isTrue);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.documents.length, equals(2));
      expect(state.documents[0].id, equals('doc-uuid-001'));
      expect(state.documents[0].title, equals('Architecture Overview'));
      expect(state.documents[1].id, equals('doc-uuid-002'));

      expect(fake.recorded.length, equals(1));
      expect(fake.recorded.first.$1.method, equals('GET'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/documents'),
      );
    });

    // -----------------------------------------------------------------------
    // 3. loadDocument — loads single document into selectedDocument
    // -----------------------------------------------------------------------

    test('loadDocument sets selectedDocument via GET', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kDocumentA}, statusCode: 200),
      );

      await state.loadDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'doc-uuid-001',
      );

      expect(state.selectedDocument, isNotNull);
      expect(state.selectedDocument!.id, equals('doc-uuid-001'));
      expect(state.selectedDocument!.title, equals('Architecture Overview'));
      expect(state.selectedDocument!.createdByUserName, equals('Alice Smith'));

      expect(
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/documents/doc-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 4. updateDocument — sends PUT and updates local state
    // -----------------------------------------------------------------------

    test('updateDocument sends PUT and updates local state', () async {
      // Pre-load two documents.
      Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kDocumentA, kDocumentB],
          },
          statusCode: 200,
        ),
      );
      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');
      expect(state.documents.length, equals(2));

      Http.unfake();

      final updatedDoc = {...kDocumentA, 'title': 'Architecture Overview v2'};
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': updatedDoc}, statusCode: 200),
      );

      final result = await state.updateDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'doc-uuid-001',
        title: 'Architecture Overview v2',
      );

      expect(result, isNotNull);
      expect(result!.title, equals('Architecture Overview v2'));

      // Local list should be updated in place.
      final localDoc = state.documents.firstWhere(
        (d) => d.id == 'doc-uuid-001',
      );
      expect(localDoc.title, equals('Architecture Overview v2'));

      expect(fake.recorded.first.$1.method, equals('PUT'));
      expect(
        fake.recorded.first.$1.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/documents/doc-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 5. createDocument — sends POST and adds to list
    // -----------------------------------------------------------------------

    test('createDocument sends POST and adds document to list', () async {
      // Pre-load one document.
      Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kDocumentB],
          },
          statusCode: 200,
        ),
      );
      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');
      expect(state.documents.length, equals(1));

      Http.unfake();

      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kDocumentA}, statusCode: 201),
      );

      final result = await state.createDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'Architecture Overview',
        '## Architecture\n\nThis project uses Flutter + Laravel.',
        'architecture',
      );

      expect(result, isNotNull);
      expect(result!.id, equals('doc-uuid-001'));
      expect(result.title, equals('Architecture Overview'));

      // Should be added to the local list.
      expect(state.documents.length, equals(2));
      expect(state.documents.any((d) => d.id == 'doc-uuid-001'), isTrue);

      expect(fake.recorded.first.$1.method, equals('POST'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/documents'),
      );
    });

    // -----------------------------------------------------------------------
    // 6. loadMemories — loads memory entries via type=memory
    // -----------------------------------------------------------------------

    test('loadMemories populates list with memory-type entries', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kMemoryA],
          },
          statusCode: 200,
        ),
      );

      await state.loadMemories('team-uuid-001', 'proj-uuid-001');

      expect(state.isSuccess, isTrue);
      expect(state.documents.length, equals(1));
      expect(state.documents[0].id, equals('mem-uuid-001'));
      expect(state.documents[0].isMemory, isTrue);
      expect(state.documents[0].memoryType, equals('project'));
      expect(state.documents[0].autoInject, isTrue);

      expect(fake.recorded.length, equals(1));
      expect(fake.recorded.first.$1.method, equals('GET'));
    });

    // -----------------------------------------------------------------------
    // 7. createMemory — sends POST with memory fields
    // -----------------------------------------------------------------------

    test('createMemory sends POST with type=memory', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kMemoryA}, statusCode: 201),
      );

      final result = await state.createMemory(
        'team-uuid-001',
        'proj-uuid-001',
        'Architecture Notes',
        '# Architecture\n\nThis system uses a microservices approach.',
        'project',
      );

      expect(result, isNotNull);
      expect(result!.id, equals('mem-uuid-001'));
      expect(result.isMemory, isTrue);
      expect(state.documents.length, equals(1));

      expect(fake.recorded.first.$1.method, equals('POST'));
    });

    // -----------------------------------------------------------------------
    // 8. deleteDocument — removes entry from list
    // -----------------------------------------------------------------------

    test('deleteDocument removes entry from list', () async {
      Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kDocumentA, kDocumentB],
          },
          statusCode: 200,
        ),
      );
      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');
      expect(state.documents.length, equals(2));

      Http.unfake();

      Http.fake(
        (MagicRequest req) => MagicResponse(data: null, statusCode: 204),
      );

      final result = await state.deleteDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'doc-uuid-001',
      );

      expect(result, isTrue);
      expect(state.documents.length, equals(1));
      expect(state.documents[0].id, equals('doc-uuid-002'));
    });
  });
}
