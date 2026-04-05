import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/events/websocket_event.dart';
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
  'repo_status': 'cloned',
  'repo_error': null,
  'last_synced_at': '2025-01-01T12:00:00.000Z',
  'mount_path': '/workspace',
  'created_at': '2024-12-01T10:00:00.000Z',
  'updated_at': '2025-01-01T12:00:00.000Z',
};

const Map<String, dynamic> kRepoB = {
  'id': 'repo-uuid-002',
  'project_id': 'proj-uuid-001',
  'name': 'Frontend Repo',
  'repository_url': null,
  'default_branch': 'develop',
  'repo_status': null,
  'repo_error': null,
  'last_synced_at': null,
  'mount_path': '/frontend',
  'created_at': '2025-01-05T09:00:00.000Z',
  'updated_at': '2025-01-05T09:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake WebSocket
// ---------------------------------------------------------------------------

/// Injectable WebSocket for testing without a real Pusher connection.
class _FakeWebSocket implements RepoWebSocket {
  String? subscribedChannel;
  void Function(WebSocketEvent)? handler;

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannel = channel;
    handler = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    subscribedChannel = null;
    handler = null;
  }

  /// Emit a fake WebSocket event to the registered handler.
  void emit(WebSocketEvent event) => handler?.call(event);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('ProjectRepositoryState', () {
    late FakeNetworkDriver driver;
    late ProjectRepositoryState state;

    setUp(() {
      driver = Http.fake();
      state = ProjectRepositoryState();
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
        driver.stub(
          '*/repositories*',
          Http.response({
            'data': [kRepoA, kRepoB],
          }),
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
        driver.assertSentCount(1);
        driver.assertSent(
          (r) =>
              r.method == 'GET' &&
              r.url ==
                  '/teams/team-uuid-001/projects/proj-uuid-001/repositories',
        );
      },
    );

    // -----------------------------------------------------------------------
    // 2. fetchRepositories — empty list transitions to empty state
    // -----------------------------------------------------------------------

    test('fetchRepositories transitions to empty when list is empty', () async {
      driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));

      await state.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      expect(state.isEmpty, isTrue);
      expect(state.repositories, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 3. fetchRepositories — error
    // -----------------------------------------------------------------------

    test('fetchRepositories sets error state on failure', () async {
      driver.stub(
        '*/repositories*',
        Http.response({'message': 'Unauthorized'}, 401),
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
      driver.stub('*/repositories', Http.response({'data': kRepoA}, 201));

      final repo = await state.createRepository(
        'team-uuid-001',
        'proj-uuid-001',
        {'name': 'API Repo', 'mount_path': '/workspace'},
      );

      expect(repo, isNotNull);
      expect(repo!.id, equals('repo-uuid-001'));
      expect(repo.name, equals('API Repo'));

      final request = driver.recorded.first.$1;
      expect(request.method, equals('POST'));
      expect(
        request.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/repositories'),
      );
    });

    // -----------------------------------------------------------------------
    // 5. createRepository — failure returns null
    // -----------------------------------------------------------------------

    test('createRepository returns null on failure', () async {
      driver.stub(
        '*/repositories',
        Http.response({'message': 'Validation error'}, 422),
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
      driver.stub('*/repositories/repo-uuid-001', Http.response(null, 204));

      final result = await state.deleteRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isTrue);

      final request = driver.recorded.first.$1;
      expect(request.method, equals('DELETE'));
      expect(
        request.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 7. deleteRepository — failure returns false
    // -----------------------------------------------------------------------

    test('deleteRepository returns false on failure', () async {
      driver.stub(
        '*/repositories/repo-uuid-001',
        Http.response({'message': 'Forbidden'}, 403),
      );

      final result = await state.deleteRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 8. cloneRepository — success returns true
    // -----------------------------------------------------------------------

    test('cloneRepository posts to clone endpoint and returns true', () async {
      driver.stub('*/repo/clone', Http.response({'data': {}}));

      final result = await state.cloneRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isTrue);

      final request = driver.recorded.first.$1;
      expect(request.method, equals('POST'));
      expect(
        request.url,
        equals(
          '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/repo/clone',
        ),
      );
    });

    // -----------------------------------------------------------------------
    // 9. cloneRepository — failure returns false
    // -----------------------------------------------------------------------

    test('cloneRepository returns false on failure', () async {
      driver.stub(
        '*/repo/clone',
        Http.response({'message': 'Server Error'}, 500),
      );

      final result = await state.cloneRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 10. fetchRepoStatus — success stores status and calls refreshUI
    // -----------------------------------------------------------------------

    test('fetchRepoStatus stores repo status on success', () async {
      driver.stub(
        '*/repo/status',
        Http.response({
          'data': {'status': 'cloned'},
        }),
      );

      expect(state.repoStatuses['repo-uuid-001'], isNull);

      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(state.repoStatuses['repo-uuid-001'], equals('cloned'));
      driver.assertSent(
        (r) =>
            r.url ==
            '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/repo/status',
      );
    });

    // -----------------------------------------------------------------------
    // 11. fetchRepoStatus — failure clears status
    // -----------------------------------------------------------------------

    test('fetchRepoStatus clears repoStatus on failure', () async {
      // Prime repoStatuses with a value via a successful call first.
      driver.stub(
        '*/repo/status',
        Http.response({
          'data': {'status': 'cloned'},
        }),
      );
      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );
      expect(state.repoStatuses['repo-uuid-001'], equals('cloned'));

      // Now simulate an error.
      driver.stub(
        '*/repo/status',
        Http.response({'message': 'Not Found'}, 404),
      );
      await state.fetchRepoStatus(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      expect(state.repoStatuses['repo-uuid-001'], isNull);
    });

    // -----------------------------------------------------------------------
    // 12. repositories getter — returns empty list before first fetch
    // -----------------------------------------------------------------------

    test('repositories getter returns empty list when rxState is null', () {
      expect(state.rxState, isNull);
      expect(state.repositories, isEmpty);
      expect(state.repositories, isA<List>());
    });

    // -----------------------------------------------------------------------
    // 13. setMainRepository — success calls PUT with is_main:true and refreshes
    // -----------------------------------------------------------------------

    test(
      'setMainRepository sends PUT with is_main:true and refreshes repo list',
      () async {
        const Map<String, dynamic> kRepoAMain = {...kRepoA, 'is_main': true};

        driver.stub(
          '*/repositories/repo-uuid-001',
          Http.response({'data': kRepoAMain}),
        );
        driver.stub(
          '*/repositories',
          Http.response({
            'data': [kRepoAMain, kRepoB],
          }),
        );

        await state.setMainRepository(
          'team-uuid-001',
          'proj-uuid-001',
          'repo-uuid-001',
        );

        // PUT call was made with is_main: true.
        driver.assertSent(
          (r) =>
              r.method == 'PUT' &&
              r.url ==
                  '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001' &&
              (r.data as Map<String, dynamic>)['is_main'] == true,
        );

        // GET call for fetchRepositories was made after PUT.
        driver.assertSent(
          (r) =>
              r.method == 'GET' &&
              r.url ==
                  '/teams/team-uuid-001/projects/proj-uuid-001/repositories',
        );

        // Repositories list was refreshed.
        expect(state.repositories.length, equals(2));
        expect(state.repositories[0].isMain, isTrue);
      },
    );

    // -----------------------------------------------------------------------
    // 14. setMainRepository — failure does not crash, no refresh
    // -----------------------------------------------------------------------

    test('setMainRepository does not refresh when PUT fails', () async {
      driver.stub(
        '*/repositories/repo-uuid-001',
        Http.response({'message': 'Forbidden'}, 403),
      );

      await state.setMainRepository(
        'team-uuid-001',
        'proj-uuid-001',
        'repo-uuid-001',
      );

      // Only one call was made (PUT) — no GET for refresh.
      driver.assertSentCount(1);
      driver.assertSent((r) => r.method == 'PUT');
    });

    // -----------------------------------------------------------------------
    // WebSocket handler tests — use _FakeWebSocket for event simulation
    // -----------------------------------------------------------------------

    group('WebSocket handler', () {
      late _FakeWebSocket ws;
      late ProjectRepositoryState wsState;

      setUp(() {
        ws = _FakeWebSocket();
        wsState = ProjectRepositoryState(ws: ws);
      });

      tearDown(() {
        wsState.dispose();
      });

      WebSocketEvent makeRepoStatusEvent({
        required String repoId,
        required String status,
        String projectId = 'proj-uuid-001',
        String? error,
      }) {
        return WebSocketEvent(
          id: 'test-id',
          channel: 'private-team.team-uuid-001',
          eventName: '.repo.status',
          data: {
            'project_id': projectId,
            'repository_id': repoId,
            'status': status,
            'error': error,
          },
          receivedAt: DateTime.now(),
        );
      }

      // 15. onboarding status — intermediate, updates map, no refetch
      test(
        'WebSocket onboarding status updates _repoStatuses without refetch',
        () async {
          driver.stub(
            '*/repositories*',
            Http.response({
              'data': [kRepoA],
            }),
          );

          wsState.subscribeToTeam('team-uuid-001', 'proj-uuid-001');
          expect(ws.subscribedChannel, equals('private-team.team-uuid-001'));

          ws.emit(
            makeRepoStatusEvent(repoId: 'repo-uuid-001', status: 'onboarding'),
          );

          expect(wsState.repoStatuses['repo-uuid-001'], equals('onboarding'));
          // No HTTP calls — onboarding is intermediate, no refetch.
          driver.assertNothingSent();
        },
      );

      // 16. ready status — terminal, updates map AND triggers refetch
      test(
        'WebSocket ready status updates _repoStatuses and triggers fetchRepositories',
        () async {
          driver.stub(
            '*/repositories*',
            Http.response({
              'data': [kRepoA],
            }),
          );

          wsState.subscribeToTeam('team-uuid-001', 'proj-uuid-001');

          ws.emit(
            makeRepoStatusEvent(repoId: 'repo-uuid-001', status: 'ready'),
          );

          // Status is set immediately.
          expect(wsState.repoStatuses['repo-uuid-001'], equals('ready'));

          // Allow async fetchRepositories to complete.
          await Future<void>.delayed(Duration.zero);

          driver.assertSentCount(1);
          driver.assertSent(
            (r) =>
                r.method == 'GET' &&
                r.url ==
                    '/teams/team-uuid-001/projects/proj-uuid-001/repositories',
          );
        },
      );

      // 17. cloned status — still triggers refetch (existing behaviour)
      test(
        'WebSocket cloned status still triggers fetchRepositories',
        () async {
          driver.stub(
            '*/repositories*',
            Http.response({
              'data': [kRepoA],
            }),
          );

          wsState.subscribeToTeam('team-uuid-001', 'proj-uuid-001');

          ws.emit(
            makeRepoStatusEvent(repoId: 'repo-uuid-001', status: 'cloned'),
          );

          expect(wsState.repoStatuses['repo-uuid-001'], equals('cloned'));

          await Future<void>.delayed(Duration.zero);

          driver.assertSentCount(1);
          driver.assertSent((r) => r.method == 'GET');
        },
      );

      // 18. error status — terminal, triggers refetch and stores error message
      test(
        'WebSocket error status triggers fetchRepositories and stores error',
        () async {
          driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));

          wsState.subscribeToTeam('team-uuid-001', 'proj-uuid-001');

          ws.emit(
            makeRepoStatusEvent(
              repoId: 'repo-uuid-001',
              status: 'error',
              error: 'Clone failed: permission denied',
            ),
          );

          expect(wsState.repoStatuses['repo-uuid-001'], equals('error'));
          expect(
            wsState.repoErrors['repo-uuid-001'],
            equals('Clone failed: permission denied'),
          );

          await Future<void>.delayed(Duration.zero);

          driver.assertSentCount(1);
          driver.assertSent((r) => r.method == 'GET');
        },
      );

      // 19. event for different project — ignored
      test('WebSocket event for different project_id is ignored', () {
        wsState.subscribeToTeam('team-uuid-001', 'proj-uuid-001');

        ws.emit(
          makeRepoStatusEvent(
            repoId: 'repo-uuid-999',
            status: 'cloning',
            projectId: 'proj-uuid-OTHER',
          ),
        );

        expect(wsState.repoStatuses['repo-uuid-999'], isNull);
        driver.assertNothingSent();
      });
    });

    // -----------------------------------------------------------------------
    // reanalyzeRepository tests
    // -----------------------------------------------------------------------

    group('reanalyzeRepository', () {
      // 20. optimistic status set + correct POST URL
      test(
        'reanalyzeRepository sets onboarding status optimistically and posts to reanalyze endpoint',
        () async {
          driver.stub('*/repo/reanalyze', Http.response({'data': {}}));

          // Status starts as null.
          expect(state.repoStatuses['repo-uuid-001'], isNull);

          final future = state.reanalyzeRepository(
            'team-uuid-001',
            'proj-uuid-001',
            'repo-uuid-001',
          );

          // Optimistic status is set synchronously before await.
          expect(state.repoStatuses['repo-uuid-001'], equals('onboarding'));

          await future;

          // POST was made to the correct URL.
          driver.assertSentCount(1);
          final request = driver.recorded.first.$1;
          expect(request.method, equals('POST'));
          expect(
            request.url,
            equals(
              '/teams/team-uuid-001/projects/proj-uuid-001/repositories/repo-uuid-001/repo/reanalyze',
            ),
          );
        },
      );

      // 21. optimistic status persists even on failure
      test(
        'reanalyzeRepository keeps onboarding status after server failure',
        () async {
          driver.stub(
            '*/repo/reanalyze',
            Http.response({'message': 'Server Error'}, 500),
          );

          await state.reanalyzeRepository(
            'team-uuid-001',
            'proj-uuid-001',
            'repo-uuid-001',
          );

          // Optimistic status is kept — WebSocket will correct it when the job
          // fails and emits an error event.
          expect(state.repoStatuses['repo-uuid-001'], equals('onboarding'));
        },
      );
    });
  });
}
