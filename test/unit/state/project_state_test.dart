import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/project_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kProjectA = {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'short_name': 'alpha',
  'slug': 'alpha',
  'description': 'First project.',
  'tech_stack': 'Flutter, Dart',
  'execution_mode': 'manual',
  'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlphaKey',
  'has_ssh_key': true,
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
  'task_count': 10,
  'active_run_count': 1,
};

const Map<String, dynamic> kProjectB = {
  'id': 'proj-uuid-002',
  'team_id': 'team-uuid-001',
  'name': 'Bravo',
  'short_name': 'bravo',
  'slug': 'bravo',
  'description': 'Second project.',
  'tech_stack': 'Laravel, PostgreSQL',
  'execution_mode': 'auto',
  'ssh_public_key': null,
  'has_ssh_key': false,
  'created_at': '2025-03-01T08:00:00.000Z',
  'updated_at': '2025-03-20T12:00:00.000Z',
  'task_count': 5,
  'active_run_count': 0,
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('ProjectState', () {
    late ProjectState state;

    setUp(() {
      state = ProjectState();
    });

    tearDown(() {
      state.dispose();
      Http.unfake();
    });

    // -----------------------------------------------------------------------
    // 1. fetchProjects — success
    // -----------------------------------------------------------------------

    test('fetchProjects sets loading then success with project list', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kProjectA, kProjectB],
          },
          statusCode: 200,
        ),
      );

      // Should start empty.
      expect(state.isEmpty, isTrue);

      final future = state.fetchProjects('team-uuid-001');

      // Loading is synchronous — should be set immediately.
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.rxState, isNotNull);
      expect(state.rxState!.length, equals(2));
      expect(state.rxState![0].id, equals('proj-uuid-001'));
      expect(state.rxState![1].id, equals('proj-uuid-002'));

      // Verify correct URL was called.
      expect(fake.recorded.length, equals(1));
      expect(fake.recorded.first.$1.method, equals('GET'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects'),
      );
    });

    // -----------------------------------------------------------------------
    // 2. fetchProjects — error
    // -----------------------------------------------------------------------

    test('fetchProjects sets loading then error on failure', () async {
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.fetchProjects('team-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 3. fetchProject — stores selectedProject
    // -----------------------------------------------------------------------

    test('fetchProject stores selectedProject', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kProjectA}, statusCode: 200),
      );

      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      expect(state.selectedProject, isNotNull);
      expect(state.selectedProject!.id, equals('proj-uuid-001'));
      expect(state.selectedProject!.name, equals('Alpha'));

      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 4. createProject — success
    // -----------------------------------------------------------------------

    test('createProject posts data and returns created project', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kProjectA}, statusCode: 201),
      );

      final project = await state.createProject('team-uuid-001', {
        'name': 'Alpha',
        'description': 'First project.',
      });

      expect(project, isNotNull);
      expect(project!.id, equals('proj-uuid-001'));
      expect(project.shortName, equals('alpha'));
      expect(
        project.sshPublicKey,
        equals('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlphaKey'),
      );
      expect(project.hasSshKey, isTrue);

      expect(fake.recorded.first.$1.method, equals('POST'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects'),
      );
    });

    // -----------------------------------------------------------------------
    // 5. updateProject — success
    // -----------------------------------------------------------------------

    test('updateProject sends PUT and returns updated project', () async {
      final fake = Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kProjectA}, statusCode: 200),
      );

      final project = await state.updateProject(
        'team-uuid-001',
        'proj-uuid-001',
        {'name': 'Alpha Updated'},
      );

      expect(project, isNotNull);
      expect(project!.id, equals('proj-uuid-001'));

      expect(fake.recorded.first.$1.method, equals('PUT'));
      expect(
        fake.recorded.first.$1.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 6. deleteProject — success
    // -----------------------------------------------------------------------

    test('deleteProject sends POST with _method DELETE and password', () async {
      final fake = Http.fake(
        (MagicRequest req) => MagicResponse(data: null, statusCode: 204),
      );

      final result = await state.deleteProject(
        'team-uuid-001',
        'proj-uuid-001',
        password: 'secret123',
      );

      expect(result.successful, isTrue);

      final recorded = fake.recorded.first.$1;
      expect(recorded.method, equals('POST'));
      expect(
        recorded.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
      expect(recorded.data['_method'], equals('DELETE'));
      expect(recorded.data['password'], equals('secret123'));
    });

    // -----------------------------------------------------------------------
    // 7. sortProjects — changes order
    // -----------------------------------------------------------------------

    test('sortProjects by name sorts alphabetically', () async {
      // Load projects in reverse alphabetical order.
      Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kProjectB, kProjectA],
          },
          statusCode: 200,
        ),
      );

      await state.fetchProjects('team-uuid-001');
      expect(state.rxState![0].name, equals('Bravo'));

      state.sortProjects(SortField.name);

      expect(state.rxState![0].name, equals('Alpha'));
      expect(state.rxState![1].name, equals('Bravo'));
    });

    // -----------------------------------------------------------------------
    // 8. sortProjects by lastUpdated — most recent first
    // -----------------------------------------------------------------------

    test('sortProjects by lastUpdated sorts most recent first', () async {
      Http.fake(
        (MagicRequest req) => MagicResponse(
          data: {
            'data': [kProjectA, kProjectB],
          },
          statusCode: 200,
        ),
      );

      await state.fetchProjects('team-uuid-001');
      // kProjectA updated 2024-06, kProjectB updated 2025-03 — B is newer.
      expect(state.rxState![0].name, equals('Alpha'));

      state.sortProjects(SortField.lastUpdated);

      expect(state.rxState![0].name, equals('Bravo'));
      expect(state.rxState![1].name, equals('Alpha'));
    });

    // -----------------------------------------------------------------------
    // 9. fetchProject — error sets selectedProject to null
    // -----------------------------------------------------------------------

    test('fetchProject sets selectedProject to null on error', () async {
      // First, set a successful selectedProject.
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'data': kProjectA}, statusCode: 200),
      );
      await state.fetchProject('team-uuid-001', 'proj-uuid-001');
      expect(state.selectedProject, isNotNull);

      // Now simulate an error.
      Http.unfake();
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
      );
      await state.fetchProject('team-uuid-001', 'proj-uuid-999');

      expect(state.selectedProject, isNull);
    });

    // -----------------------------------------------------------------------
    // 10. deleteProject — failure returns false
    // -----------------------------------------------------------------------

    test('deleteProject returns unsuccessful response on failure', () async {
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      final result = await state.deleteProject(
        'team-uuid-001',
        'proj-uuid-001',
        password: 'wrong-password',
      );

      expect(result.successful, isFalse);
    });

    // -----------------------------------------------------------------------
    // 11. regenerateSshKey — success returns public key string
    // -----------------------------------------------------------------------

    test(
      'regenerateSshKey posts to project ssh-key endpoint and returns public key',
      () async {
        final fake = Http.fake(
          (MagicRequest req) => MagicResponse(
            data: {
              'data': {
                'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKey',
              },
            },
            statusCode: 200,
          ),
        );

        final key = await state.regenerateSshKey(
          'team-uuid-001',
          'proj-uuid-001',
        );

        expect(key, equals('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINewKey'));

        expect(fake.recorded.first.$1.method, equals('POST'));
        expect(
          fake.recorded.first.$1.url,
          equals('/teams/team-uuid-001/projects/proj-uuid-001/ssh-key'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 12. regenerateSshKey — failure returns null
    // -----------------------------------------------------------------------

    test('regenerateSshKey returns null on failure', () async {
      Http.fake(
        (MagicRequest req) =>
            MagicResponse(data: {'message': 'Not Found'}, statusCode: 404),
      );

      final key = await state.regenerateSshKey(
        'team-uuid-001',
        'proj-uuid-001',
      );

      expect(key, isNull);
    });
  });
}
