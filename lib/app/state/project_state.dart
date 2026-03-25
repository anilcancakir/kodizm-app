import 'package:magic/magic.dart';

import '../models/project.dart';

// ---------------------------------------------------------------------------
// Sort support
// ---------------------------------------------------------------------------

/// Fields by which the project list can be sorted.
enum SortField {
  /// Sort alphabetically by project name (A-Z).
  name,

  /// Sort by last updated timestamp (most recent first).
  lastUpdated,
}

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [ProjectState] uses.
///
/// In production the default [_MagicHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class HttpClient {
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

/// Default production [HttpClient] backed by the Magic [Http] facade.
class _MagicHttpClient implements HttpClient {
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
// ProjectState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project CRUD and related operations.
///
/// Manages the list of projects for a team, a single selected project,
/// sorting, SSH key generation, and repository status checks.
///
/// The primary state (`rxState`) holds the `List<Project>` for the active
/// team. Secondary state fields ([selectedProject], [repoStatus]) are
/// managed independently with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final projects = ProjectState.instance;
///
/// // Fetch all projects for a team.
/// await projects.fetchProjects('team-uuid-001');
/// final list = projects.rxState; // List<Project>?
///
/// // Fetch a single project.
/// await projects.fetchProject('team-uuid-001', 'proj-uuid-001');
/// final selected = projects.selectedProject;
///
/// // Sort the in-memory list.
/// projects.sortProjects(SortField.name);
/// ```
class ProjectState extends MagicController with MagicStateMixin<List<Project>> {
  /// Creates a [ProjectState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicHttpClient].
  ProjectState({HttpClient? httpClient})
    : _http = httpClient ?? const _MagicHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ProjectState get instance => Magic.findOrPut(ProjectState.new);

  final HttpClient _http;

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  Project? _selectedProject;
  String? _repoStatus;

  /// The currently selected project (set by [fetchProject]).
  Project? get selectedProject => _selectedProject;

  /// The repository clone/sync status for the selected project.
  String? get repoStatus => _repoStatus;

  // ---------------------------------------------------------------------------
  // Project list operations
  // ---------------------------------------------------------------------------

  /// Fetch all projects for the given [teamId].
  ///
  /// Sets loading, then populates `rxState` with the parsed project list on
  /// success, or transitions to error on failure.
  Future<void> fetchProjects(String teamId) async {
    setLoading();

    final response = await _http.get('/teams/$teamId/projects');

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final projects = items
          .map((item) => Project.fromMap(item as Map<String, dynamic>))
          .toList();
      projects.isEmpty ? setEmpty() : setSuccess(projects);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch projects');
    }
  }

  /// Fetch a single project and store it as [selectedProject].
  ///
  /// Does **not** affect the primary list state. Calls [refreshUI] after
  /// updating [_selectedProject].
  Future<void> fetchProject(String teamId, String projectId) async {
    final response = await _http.get('/teams/$teamId/projects/$projectId');

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedProject = Project.fromMap(data);
    } else {
      _selectedProject = null;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new project under the given [teamId].
  ///
  /// Returns the created [Project] on success, or `null` on failure.
  Future<Project?> createProject(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    final response = await _http.post('/teams/$teamId/projects', data: data);

    if (response.successful) {
      final Map<String, dynamic> projectData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return Project.fromMap(projectData);
    }

    return null;
  }

  /// Update an existing project.
  ///
  /// Returns the updated [Project] on success, or `null` on failure.
  Future<Project?> updateProject(
    String teamId,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final response = await _http.put(
      '/teams/$teamId/projects/$projectId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> projectData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return Project.fromMap(projectData);
    }

    return null;
  }

  /// Delete a project.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteProject(String teamId, String projectId) async {
    final response = await _http.delete('/teams/$teamId/projects/$projectId');

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  /// Sort the in-memory project list by the given [field].
  ///
  /// - [SortField.name] sorts alphabetically (A-Z).
  /// - [SortField.lastUpdated] sorts by most recently updated first.
  ///
  /// No-ops when `rxState` is null or empty. Calls [setSuccess] to notify
  /// listeners.
  void sortProjects(SortField field) {
    final projects = rxState;
    if (projects == null || projects.isEmpty) return;

    final sorted = List<Project>.from(projects);

    switch (field) {
      case SortField.name:
        sorted.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
      case SortField.lastUpdated:
        sorted.sort((a, b) {
          final aDate = a.updatedAt?.toDateTime ?? DateTime(0);
          final bDate = b.updatedAt?.toDateTime ?? DateTime(0);
          return bDate.compareTo(aDate); // Most recent first.
        });
    }

    setSuccess(sorted);
  }

  // ---------------------------------------------------------------------------
  // SSH key
  // ---------------------------------------------------------------------------

  /// Generate (or regenerate) an SSH deploy key for the given project.
  ///
  /// Returns the public key string on success, or `null` on failure.
  Future<String?> generateSshKey(String teamId, String projectId) async {
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/ssh-key',
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
  // Repository status
  // ---------------------------------------------------------------------------

  /// Fetch the repository clone/sync status for the given project.
  ///
  /// Stores the result in [repoStatus] and calls [refreshUI].
  Future<void> fetchRepoStatus(String teamId, String projectId) async {
    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/repo-status',
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
