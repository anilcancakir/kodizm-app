import 'package:magic/magic.dart';

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
// ProjectRepositoryState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project repository CRUD and related operations.
///
/// Manages the list of repositories for a given project, SSH key generation,
/// repository clone operations, and status polling.
///
/// The primary state (`rxState`) holds the `List<ProjectRepository>` for
/// the currently viewed project. Secondary state fields ([repoStatus]) are
/// managed independently with manual [refreshUI] calls.
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
/// // Generate an SSH key for a specific repository.
/// final pubKey = await repoState.generateSshKey('team-uuid', 'proj-uuid', 'repo-uuid');
///
/// // Check clone status.
/// await repoState.fetchRepoStatus('team-uuid', 'proj-uuid', 'repo-uuid');
/// final status = repoState.repoStatus;
/// ```
class ProjectRepositoryState extends MagicController
    with MagicStateMixin<List<ProjectRepository>> {
  /// Creates a [ProjectRepositoryState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicHttpClient].
  ProjectRepositoryState({ProjectRepositoryHttpClient? httpClient})
    : _http = httpClient ?? const _MagicHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ProjectRepositoryState get instance =>
      Magic.findOrPut(ProjectRepositoryState.new);

  final ProjectRepositoryHttpClient _http;

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  String? _repoStatus;

  /// The repository clone/sync status for the last polled repository.
  String? get repoStatus => _repoStatus;

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
  // SSH key
  // ---------------------------------------------------------------------------

  /// Generate (or regenerate) an SSH deploy key for the given repository.
  ///
  /// Returns the public key string on success, or `null` on failure.
  Future<String?> generateSshKey(
    String teamId,
    String projectId,
    String repoId,
  ) async {
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/repositories/$repoId/ssh-key',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return data['public_key'] as String?;
    }

    return null;
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
  /// Stores the result in [repoStatus] and calls [refreshUI].
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
      _repoStatus = data['status'] as String?;
    } else {
      _repoStatus = null;
    }

    refreshUI();
  }
}
