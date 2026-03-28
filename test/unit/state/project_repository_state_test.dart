import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/project_repository_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kRepoA = {
  'id': 'repo-uuid-001',
  'project_id': 'proj-uuid-001',
  'name': 'API Repo',
  'repository_url': 'git@github.com:acme/api.git',
  'default_branch': 'main',
  'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey',
  'repo_status': 'cloned',
  'repo_error': null,
  'last_synced_at': '2025-01-01T12:00:00.000Z',
  'mount_path': '/workspace',
  'has_ssh_key': true,
  'created_at': '2024-12-01T10:00:00.000Z',
  'updated_at': '2025-01-01T12:00:00.000Z',
};

const Map<String, dynamic> kRepoB = {
  'id': 'repo-uuid-002',
  'project_id': 'proj-uuid-001',
  'name': 'Frontend Repo',
  'repository_url': null,
  'default_branch': 'develop',
  'ssh_public_key': null,
  'repo_status': null,
  'repo_error': null,
  'last_synced_at': null,
  'mount_path': '/frontend',
  'has_ssh_key': false,
  'created_at': '2025-01-05T09:00:00.000Z',
  'updated_at': '2025-01-05T09:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [ProjectRepositoryState] without hitting
/// the network. Records calls and returns pre-configured [MagicResponse]s.
class _FakeHttpClient implements ProjectRepositoryHttpClient {
  final List<_HttpCall> calls = [];
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
    calls.add(_HttpCall('GET', url));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('DELETE', url));
    return _responder(url);
  }
}

class _HttpCall {
  _HttpCall(this.method, this.url, {this.data});

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
  group('ProjectRepositoryState', () {
    late _FakeHttpClient http;
    late ProjectRepositoryState state;

    setUp(() {
      http = _FakeHttpClient();
      state = ProjectRepositoryState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. fetchRepositories — success with items
    // -----------------------------------------------------------------------

    test(
      'fetchRepositories sets loading then success with repo list',
      () async {
        http.alwaysReturn(
          MagicResponse(
            data: {
              'data': [kRepoA, kRepoB],
            },
            statusCode: 200,
          ),
        );

        // Initial state: empty list, not loading.
        expect(state.repositories, isEmpty);
        expect(state.isLoading, isFalse);

        final future = state.fetchRepositories(
          'team-uuid-001',
          'proj-uuid-001',
        );

        // setLoading is synchronous.
        expect(state.isLoading, isTrue);

        await future;

        expect(state.isSuccess, isTrue);
        expect(state.repositories.length, equals(2));
        expect(state.repositories[0].id, equals('repo-uuid-001'));
        expect(state.repositories[0].name, equals('API Repo'));
        expect(state.repositories[1].id, equals('repo-uuid-002'));

        // Verify correct URL.
        expect(http.calls.length, equals(1));
        expect(http.calls.first.method, equals('GET'));
        expect(
          http.calls.first.url,
          equals('/teams/team-uuid-001/projects/proj-uuid-001/repositories'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 2. fetchRepositories — empty list transitions to empty state
    // -----------------------------------------------------------------------

    test('fetchRepositories transitions to empty when list is empty', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
      );

      await state.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      expect(state.isEmpty, isTrue);
      expect(state.repositories, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 3. fetchRepositories — error
    // -----------------------------------------------------------------------

    test('fetchRepositories sets error state on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.fetchRepositories('team-uuid-001', 'proj-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 4. createRepository — success returns created repo
    // -----------------------------------------------------------------------

    test('createRepository posts data and returns created repo', () async {
      http.alwaysReturn(MagicResponse(data: {'data': kRepoA}, statusCode: 201));

      final repo = await state.createRepository(
        'team-uuid-001',
        'proj-uuid-001',
        {'name': 'API Repo', 'mount_path': '/workspace'},
      );

      expect(repo, isNotNull);
      expect(repo!.id, equals('repo-uuid-001'));
      expect(repo.name, equals('API Repo'));

      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/repositories'),
      );
    });

    // -----------------------------------------------------------------------
    // 5. createRepository — failure returns null
    // -----------------------------------------------------------------------

    test('createRepository returns null on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Validation error'}, statusCode: 422),
      );

      final repo = await state.createRepository(
        'team-uuid-001',
        'proj-uuid-001',
        {'name': ''},
      );

      expect(repo, isNull);
    });

    // -----------------------------------------------------------------------
    // 6. deleteRepository — success returns true
    // -----------------------------------------------------------------------

    test('deleteRepository sends DELETE and returns true on success', () async {
      http.alwaysReturn(MagicResponse(data: null, statusCode: 204));

      final result = await state.deleteRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isTrue);

      expect(http.calls.first.method, equals('DELETE'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 7. deleteRepository — failure returns false
    // -----------------------------------------------------------------------

    test('deleteRepository returns false on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      final result = await state.deleteRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 8. generateSshKey — success returns public key string
    // -----------------------------------------------------------------------

    test('generateSshKey posts and returns public key string', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': {'public_key': 'ssh-ed25519 AAAAC3...'},
          },
          statusCode: 200,
        ),
      );

      final key = await state.generateSshKey(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(key, equals('ssh-ed25519 AAAAC3...'));

      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/ssh-key',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 9. generateSshKey — failure returns null
    // -----------------------------------------------------------------------

    test('generateSshKey returns null on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not Found'}, statusCode: 404),
      );

      final key = await state.generateSshKey(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(key, isNull);
    });

    // -----------------------------------------------------------------------
    // 10. cloneRepository — success returns true
    // -----------------------------------------------------------------------

    test('cloneRepository posts to clone endpoint and returns true', () async {
      http.alwaysReturn(MagicResponse(data: {'data': {}}, statusCode: 200));

      final result = await state.cloneRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isTrue);

      expect(http.calls.first.method, equals('POST'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/repo/clone',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 11. cloneRepository — failure returns false
    // -----------------------------------------------------------------------

    test('cloneRepository returns false on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Server Error'}, statusCode: 500),
      );

      final result = await state.cloneRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 12. fetchRepoStatus — success stores status and calls refreshUI
    // -----------------------------------------------------------------------

    test('fetchRepoStatus stores repo status on success', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': {'status': 'cloned'},
          },
          statusCode: 200,
        ),
      );

      expect(state.repoStatus, isNull);

      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(state.repoStatus, equals('cloned'));
      expect(
        http.calls.first.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/repo/status',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 13. fetchRepoStatus — failure clears status
    // -----------------------------------------------------------------------

    test('fetchRepoStatus clears repoStatus on failure', () async {
      // Prime repoStatus with a value via a successful call first.
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': {'status': 'cloned'},
          },
          statusCode: 200,
        ),
      );
      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );
      expect(state.repoStatus, equals('cloned'));

      // Now simulate an error.
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not Found'}, statusCode: 404),
      );
      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(state.repoStatus, isNull);
    });

    // -----------------------------------------------------------------------
    // 14. repositories getter — returns empty list before first fetch
    // -----------------------------------------------------------------------

    test('repositories getter returns empty list when rxState is null', () {
      expect(state.rxState, isNull);
      expect(state.repositories, isEmpty);
      expect(state.repositories, isA<List>());
    });
  });
}
