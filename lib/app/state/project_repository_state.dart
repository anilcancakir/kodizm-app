import 'package:magic/magic.dart';

import '../events/websocket_event.dart';
import '../models/project_repository.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [ProjectRepositoryState] uses.
///
/// In production the default [_MagicHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class ProjectRepositoryHttpClient {
  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });

  /// Perform a POST request.
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a PUT request.
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a DELETE request.
  Future<MagicResponse> delete(String url, {Map<String, String>? headers});
}

/// Default production [ProjectRepositoryHttpClient] backed by the Magic [Http] facade.
class _MagicHttpClient implements ProjectRepositoryHttpClient {
  const _MagicHttpClient();

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => Http.get(url, query: query, headers: headers);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => Http.post(url, data: data, headers: headers);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => Http.put(url, data: data, headers: headers);

  @override
  Future<MagicResponse> delete(String url, {Map<String, String>? headers}) =>
      Http.delete(url, headers: headers);
}

// ---------------------------------------------------------------------------
// WebSocket abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over WebSocket subscribe/unsubscribe for testability.
///
/// In production the default [_MagicRepoWebSocket] resolves the real
/// [WebSocketService] singleton. Tests inject a fake.
abstract class RepoWebSocket {
  /// Subscribe to [channel] with an event callback.
  void subscribe(String channel, void Function(WebSocketEvent) onEvent);

  /// Unsubscribe from [channel].
  void unsubscribe(String channel);
}

/// Default production [RepoWebSocket] backed by the [WebSocketService]
/// singleton registered in the Magic IoC container.
class _MagicRepoWebSocket implements RepoWebSocket {
  const _MagicRepoWebSocket();

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    Magic.make('websocket').subscribe(channel, onEvent);
  }

  @override
  void unsubscribe(String channel) {
    Magic.make('websocket').unsubscribe(channel);
  }
}

// ---------------------------------------------------------------------------
// ProjectRepositoryState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project repository CRUD and related operations.
///
/// Manages the list of repositories for a given project, SSH key generation,
/// repository clone operations, and status polling.
///
/// The primary state (`rxState`) holds the `List<ProjectRepository>` for
/// the currently viewed project. Secondary state ([repoStatuses]) tracks
/// per-repo clone status keyed by repository ID, updated via polling timers.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final repoState = ProjectRepositoryState.instance;
///
/// // Fetch all repositories for a project.
/// await repoState.fetchRepositories('team-uuid', 'proj-uuid');
/// final repos = repoState.repositories;
///
/// // Start polling a repo's clone status.
/// repoState.startStatusPolling('team-uuid', 'proj-uuid', 'repo-uuid');
/// final status = repoState.repoStatuses['repo-uuid'];
/// ```
class ProjectRepositoryState extends MagicController
    with MagicStateMixin<List<ProjectRepository>> {
  /// Creates a [ProjectRepositoryState] with optional [httpClient] and [ws] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicHttpClient]. Same for [ws] → [_MagicRepoWebSocket].
  ProjectRepositoryState({
    ProjectRepositoryHttpClient? httpClient,
    RepoWebSocket? ws,
  }) : _http = httpClient ?? const _MagicHttpClient(),
       _ws = ws ?? const _MagicRepoWebSocket();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ProjectRepositoryState get instance =>
      Magic.findOrPut(ProjectRepositoryState.new);

  final ProjectRepositoryHttpClient _http;
  final RepoWebSocket _ws;

  /// The currently subscribed team channel, or `null` if not listening.
  String? _activeChannel;

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  /// Per-repository clone/sync status, keyed by repository ID.
  ///
  /// Values: `not_cloned`, `cloning`, `cloned`, `error`, or `null` if unknown.
  final Map<String, String?> _repoStatuses = {};

  /// Per-repository error messages, keyed by repository ID.
  final Map<String, String?> _repoErrors = {};

  /// Per-repository clone/sync status map (read-only view).
  Map<String, String?> get repoStatuses => Map.unmodifiable(_repoStatuses);

  /// Per-repository error messages (read-only view).
  Map<String, String?> get repoErrors => Map.unmodifiable(_repoErrors);

  /// The currently loaded repository list (empty list when not yet fetched).
  List<ProjectRepository> get repositories => rxState ?? [];

  // ---------------------------------------------------------------------------
  // Repository list operations
  // ---------------------------------------------------------------------------

  /// Fetch all repositories for the given [projectId] under [teamId].
  ///
  /// Sets loading, then populates `rxState` with the parsed repository list on
  /// success, or transitions to error on failure.
  Future<void> fetchRepositories(String teamId, String projectId) async {
    setLoading();

    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/repositories',
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final repos = items
          .map(
            (item) => ProjectRepository.fromMap(item as Map<String, dynamic>),
          )
          .toList();
      repos.isEmpty ? setEmpty() : setSuccess(repos);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch repositories');
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new repository link under the given [teamId] and [projectId].
  ///
  /// Returns the created [ProjectRepository] on success, or `null` on failure.
  Future<ProjectRepository?> createRepository(
    String teamId,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/repositories',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> repoData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return ProjectRepository.fromMap(repoData);
    }

    return null;
  }

  /// Update an existing repository link.
  ///
  /// Returns the updated [ProjectRepository] on success, or `null` on failure.
  Future<ProjectRepository?> updateRepository(
    String teamId,
    String projectId,
    String repoId,
    Map<String, dynamic> data,
  ) async {
    final response = await _http.put(
      '/teams/$teamId/projects/$projectId/repositories/$repoId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> repoData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return ProjectRepository.fromMap(repoData);
    }

    return null;
  }

  /// Designate a repository as the primary (main) repository for the project.
  ///
  /// Calls [updateRepository] with `{'is_main': true}` then refreshes the
  /// repository list via [fetchRepositories] on success.
  Future<void> setMainRepository(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    final updated = await updateRepository(teamId, projectId, repoId, {
      'is_main': true,
    });

    if (updated != null) {
      await fetchRepositories(teamId, projectId);
    }
  }

  /// Delete a repository link.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteRepository(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    final response = await _http.delete(
      '/teams/$teamId/projects/$projectId/repositories/$repoId',
    );

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // Clone and status
  // ---------------------------------------------------------------------------

  /// Trigger a clone operation for the given repository.
  ///
  /// Returns `true` when the clone was accepted by the server, `false` on
  /// failure.
  Future<bool> cloneRepository(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/repositories/$repoId/repo/clone',
    );

    return response.successful;
  }

  /// Fetch the repository clone/sync status for the given repository.
  ///
  /// Stores the result in [repoStatuses] keyed by [repoId] and calls [refreshUI].
  Future<void> fetchRepoStatus(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/repositories/$repoId/repo/status',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _repoStatuses[repoId] = data['status'] as String?;
    } else {
      _repoStatuses[repoId] = null;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // WebSocket subscription
  // ---------------------------------------------------------------------------

  /// Subscribe to the team channel for real-time repo status updates.
  ///
  /// Listens for `.repo.status` events and updates [repoStatuses] accordingly.
  /// On terminal status (`cloned` or `error`), re-fetches the full repository
  /// list so the model picks up `repo_error` and other updated fields.
  void subscribeToTeam(String teamId, String projectId) {
    if (_activeChannel != null) unsubscribeFromTeam();

    final channel = 'private-team.$teamId';
    _activeChannel = channel;
    _activeProjectId = projectId;
    _activeTeamId = teamId;

    _ws.subscribe(channel, _handleWebSocketEvent);
  }

  /// Unsubscribe from the currently active team channel.
  ///
  /// No-op when not subscribed. Called from the view's `dispose()`.
  void unsubscribeFromTeam() {
    if (_activeChannel == null) return;

    _ws.unsubscribe(_activeChannel!);
    _activeChannel = null;
    _activeProjectId = null;
    _activeTeamId = null;
  }

  /// Mark a repository as cloning immediately (before the server event arrives).
  ///
  /// Called after [createRepository] with a URL so the UI shows a spinner
  /// without waiting for the first WebSocket event.
  void markAsCloning(String repoId) {
    _repoStatuses[repoId] = 'cloning';
    _repoErrors[repoId] = null;
    refreshUI();
  }

  /// Handle a WebSocket event from the team channel.
  void _handleWebSocketEvent(WebSocketEvent wsEvent) {
    if (wsEvent.eventName != '.repo.status') return;

    final data = wsEvent.data;

    // Only handle events for the currently viewed project.
    final projectId = data['project_id'] as String?;
    if (projectId != _activeProjectId) return;

    final repoId = data['repository_id'] as String?;
    final status = data['status'] as String?;
    final error = data['error'] as String?;

    if (repoId == null || status == null) return;

    _repoStatuses[repoId] = status;
    _repoErrors[repoId] = error;
    refreshUI();

    // On terminal status, re-fetch full list for complete model data.
    if (status == 'cloned' || status == 'ready' || status == 'error') {
      if (_activeTeamId != null && _activeProjectId != null) {
        fetchRepositories(_activeTeamId!, _activeProjectId!);
      }
    }
  }

  String? _activeProjectId;
  String? _activeTeamId;

  // ---------------------------------------------------------------------------
  // Re-analysis
  // ---------------------------------------------------------------------------

  /// Triggers re-analysis of a repository's codebase.
  ///
  /// Sends POST to reanalyze endpoint and optimistically sets status to
  /// `onboarding` so the UI reflects the in-progress state immediately.
  /// The WebSocket will emit further status events as the job progresses.
  Future<void> reanalyzeRepository(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    // Set optimistic status before the network round-trip.
    _repoStatuses[repoId] = 'onboarding';
    refreshUI();

    await _http.post(
      '/teams/$teamId/projects/$projectId/repositories/$repoId/repo/reanalyze',
    );
  }
}
