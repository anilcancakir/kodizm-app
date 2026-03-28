import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

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
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [ProjectState] without hitting the
/// network. Each method records the call and returns a pre-configured
/// [MagicResponse].
class FakeHttpClient implements HttpClient {
  final List<HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Set a responder that maps URL to [MagicResponse].
  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  /// Shortcut: always return the same response regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('GET', url));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('DELETE', url));
    return _responder(url);
  }
}

class HttpCall {
  HttpCall(this.method, this.url, {this.data});

  final String method;
  final String url;
  final dynamic data;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProjectState', () {
    late FakeHttpClient http;
    late ProjectState state;

    setUp(() {
      http = FakeHttpClient();
      state = ProjectState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. fetchProjects — success
    // -----------------------------------------------------------------------

    test('fetchProjects sets loading then success with project list', () async {
      http.alwaysReturn(
        MagicResponse(
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
      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/teams/team-uuid-001/projects'));
    });

    // -----------------------------------------------------------------------
    // 2. fetchProjects — error
    // -----------------------------------------------------------------------

    test('fetchProjects sets loading then error on failure', () async {
      http.alwaysReturn(
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
      http.alwaysReturn(
        MagicResponse(data: {'data': kProjectA}, statusCode: 200),
      );

      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      expect(state.selectedProject, isNotNull);
      expect(state.selectedProject!.id, equals('proj-uuid-001'));
      expect(state.selectedProject!.name, equals('Alpha'));

      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 4. createProject — success
    // -----------------------------------------------------------------------

    test('createProject posts data and returns created project', () async {
      http.alwaysReturn(
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

      expect(http.calls.first.method, equals('POST'));
      expect(http.calls.first.url, equals('/teams/team-uuid-001/projects'));
    });

    // -----------------------------------------------------------------------
    // 5. updateProject — success
    // -----------------------------------------------------------------------

    test('updateProject sends PUT and returns updated project', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kProjectA}, statusCode: 200),
      );

      final project = await state.updateProject(
        'team-uuid-001',
        'proj-uuid-001',
        {'name': 'Alpha Updated'},
      );

      expect(project, isNotNull);
      expect(project!.id, equals('proj-uuid-001'));

      expect(http.calls.first.method, equals('PUT'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 6. deleteProject — success
    // -----------------------------------------------------------------------

    test('deleteProject sends DELETE and returns true on success', () async {
      http.alwaysReturn(MagicResponse(data: null, statusCode: 204));

      final result = await state.deleteProject(
        'team-uuid-001',
        'proj-uuid-001',
      );

      expect(result, isTrue);

      expect(http.calls.first.method, equals('DELETE'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 7. sortProjects — changes order
    // -----------------------------------------------------------------------

    test('sortProjects by name sorts alphabetically', () async {
      // Load projects in reverse alphabetical order.
      http.alwaysReturn(
        MagicResponse(
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
      http.alwaysReturn(
        MagicResponse(
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
      http.whenAny((url) {
        return MagicResponse(data: {'data': kProjectA}, statusCode: 200);
      });
      await state.fetchProject('team-uuid-001', 'proj-uuid-001');
      expect(state.selectedProject, isNotNull);

      // Now simulate an error.
      http.whenAny((url) {
        return MagicResponse(data: {'message': 'Not found'}, statusCode: 404);
      });
      await state.fetchProject('team-uuid-001', 'proj-uuid-999');

      expect(state.selectedProject, isNull);
    });

    // -----------------------------------------------------------------------
    // 10. deleteProject — failure returns false
    // -----------------------------------------------------------------------

    test('deleteProject returns false on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      final result = await state.deleteProject(
        'team-uuid-001',
        'proj-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 11. regenerateSshKey — success returns public key string
    // -----------------------------------------------------------------------

    test(
      'regenerateSshKey posts to project ssh-key endpoint and returns public key',
      () async {
        http.alwaysReturn(
          MagicResponse(
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

        expect(http.calls.first.method, equals('POST'));
        expect(
          http.calls.first.url,
          equals('/teams/team-uuid-001/projects/proj-uuid-001/ssh-key'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 12. regenerateSshKey — failure returns null
    // -----------------------------------------------------------------------

    test('regenerateSshKey returns null on failure', () async {
      http.alwaysReturn(
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
