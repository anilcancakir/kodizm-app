import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/memory_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kMemoryA = {
  'id': 'mem-uuid-001',
  'project_id': 'proj-uuid-001',
  'file_name': 'architecture.md',
  'name': 'Architecture Overview',
  'description': 'High-level system architecture.',
  'type': 'project',
  'content': '# Architecture\n\nThis system uses a microservices approach.',
  'metadata': null,
  'created_by_user_id': 'user-uuid-001',
  'created_by_user': {'name': 'Alice Smith'},
  'created_by_agent_role_id': null,
  'created_by_agent_role': null,
  'last_synced_at': null,
  'expires_at': null,
  'created_at': '2025-01-10T10:00:00.000Z',
  'updated_at': '2025-01-10T10:00:00.000Z',
};

const Map<String, dynamic> kMemoryB = {
  'id': 'mem-uuid-002',
  'project_id': 'proj-uuid-001',
  'file_name': 'feedback.md',
  'name': 'Sprint Feedback',
  'description': 'Feedback from sprint retrospective.',
  'type': 'feedback',
  'content': 'The team agreed on daily standups.',
  'metadata': null,
  'created_by_user_id': null,
  'created_by_user': null,
  'created_by_agent_role_id': 'role-uuid-001',
  'created_by_agent_role': {'name': 'Business Analyst'},
  'last_synced_at': '2025-02-01T08:00:00.000Z',
  'expires_at': null,
  'created_at': '2025-01-20T14:00:00.000Z',
  'updated_at': '2025-02-01T08:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('MemoryState', () {
    late FakeNetworkDriver driver;
    late MemoryState state;

    setUp(() {
      driver = Http.fake();
      state = MemoryState();
    });

    tearDown(() {
      state.dispose();
      Http.unfake();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state
    // -----------------------------------------------------------------------

    test('initial state has empty memories list and is not loading', () {
      expect(state.memories, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.selectedMemory, isNull);
      expect(state.isEditing, isFalse);
      expect(state.filterType, isNull);
    });

    // -----------------------------------------------------------------------
    // 2. loadMemories — populates list via Http.get
    // -----------------------------------------------------------------------

    test('loadMemories sets loading then populates memory list', () async {
      driver.stub(
        '*/memories*',
        Http.response({
          'data': [kMemoryA, kMemoryB],
        }),
      );

      final future = state.loadMemories('team-uuid-001', 'proj-uuid-001');

      expect(state.isLoading, isTrue);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.memories.length, equals(2));
      expect(state.memories[0].id, equals('mem-uuid-001'));
      expect(state.memories[0].name, equals('Architecture Overview'));
      expect(state.memories[1].id, equals('mem-uuid-002'));

      driver.assertSentCount(1);
      driver.assertSent(
        (r) =>
            r.method == 'GET' &&
            r.url == '/teams/team-uuid-001/projects/proj-uuid-001/memories',
      );
    });

    // -----------------------------------------------------------------------
    // 3. createMemory — sends POST, adds to list
    // -----------------------------------------------------------------------

    test('createMemory posts data and adds memory to list', () async {
      driver.stub('*/memories', Http.response({'data': kMemoryA}, 201));

      final memory = await state.createMemory(
        'team-uuid-001',
        'proj-uuid-001',
        'architecture.md',
        'Architecture Overview',
        'High-level system architecture.',
        'project',
        '# Architecture\n\nThis system uses a microservices approach.',
      );

      expect(memory, isNotNull);
      expect(memory!.id, equals('mem-uuid-001'));
      expect(memory.name, equals('Architecture Overview'));
      expect(state.memories.length, equals(1));
      expect(state.memories[0].id, equals('mem-uuid-001'));

      driver.assertSentCount(1);
      driver.assertSent(
        (r) =>
            r.method == 'POST' &&
            r.url == '/teams/team-uuid-001/projects/proj-uuid-001/memories',
      );
    });

    // -----------------------------------------------------------------------
    // 4. updateMemory — sends PUT, updates local state
    // -----------------------------------------------------------------------

    test('updateMemory sends PUT and updates memory in list', () async {
      // Seed the list with two memories.
      driver.stub(
        '*/memories*',
        Http.response({
          'data': [kMemoryA, kMemoryB],
        }),
      );
      await state.loadMemories('team-uuid-001', 'proj-uuid-001');

      final Map<String, dynamic> kMemoryAUpdated = {
        ...kMemoryA,
        'name': 'Updated Architecture',
        'description': 'Revised architecture notes.',
      };

      driver.stub(
        '*/memories/mem-uuid-001',
        Http.response({'data': kMemoryAUpdated}),
      );

      final updated = await state.updateMemory(
        'team-uuid-001',
        'proj-uuid-001',
        'mem-uuid-001',
        name: 'Updated Architecture',
        description: 'Revised architecture notes.',
      );

      expect(updated, isNotNull);
      expect(updated!.name, equals('Updated Architecture'));
      expect(updated.description, equals('Revised architecture notes.'));

      // In-memory list should reflect the update.
      expect(state.memories.length, equals(2));
      expect(
        state.memories.firstWhere((m) => m.id == 'mem-uuid-001').name,
        equals('Updated Architecture'),
      );

      driver.assertSent(
        (r) =>
            r.method == 'PUT' &&
            r.url ==
                '/teams/team-uuid-001/projects/proj-uuid-001/memories/mem-uuid-001',
      );
    });

    // -----------------------------------------------------------------------
    // 5. deleteMemory — sends DELETE, removes from list
    // -----------------------------------------------------------------------

    test('deleteMemory sends DELETE and removes memory from list', () async {
      // Seed the list with two memories.
      driver.stub(
        '*/memories*',
        Http.response({
          'data': [kMemoryA, kMemoryB],
        }),
      );
      await state.loadMemories('team-uuid-001', 'proj-uuid-001');
      expect(state.memories.length, equals(2));

      driver.stub('*/memories/mem-uuid-001', Http.response(null, 204));

      final result = await state.deleteMemory(
        'team-uuid-001',
        'proj-uuid-001',
        'mem-uuid-001',
      );

      expect(result, isTrue);
      expect(state.memories.length, equals(1));
      expect(state.memories[0].id, equals('mem-uuid-002'));

      driver.assertSent(
        (r) =>
            r.method == 'DELETE' &&
            r.url ==
                '/teams/team-uuid-001/projects/proj-uuid-001/memories/mem-uuid-001',
      );
    });
  });
}
