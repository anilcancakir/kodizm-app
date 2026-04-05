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
// ProjectState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project CRUD and related operations.
///
/// Manages the list of projects for a team, a single selected project,
/// and in-memory sorting.
///
/// The primary state (`rxState`) holds the `List<Project>` for the active
/// team. The secondary state field ([selectedProject]) is managed
/// independently with manual [refreshUI] calls.
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
  /// Creates a [ProjectState].
  ProjectState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ProjectState get instance => Magic.findOrPut(ProjectState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  Project? _selectedProject;

  /// The currently selected project (set by [fetchProject]).
  Project? get selectedProject => _selectedProject;

  Map<String, dynamic>? _runtimes;

  /// Cached runtimes response from [fetchRuntimes].
  ///
  /// Returns `null` until the first successful [fetchRuntimes] call.
  Map<String, dynamic>? get runtimes => _runtimes;

  // ---------------------------------------------------------------------------
  // Project list operations
  // ---------------------------------------------------------------------------

  /// Fetch all projects for the given [teamId].
  ///
  /// Sets loading, then populates `rxState` with the parsed project list on
  /// success, or transitions to error on failure.
  Future<void> fetchProjects(String teamId) async {
    await fetchList<Project>('/teams/$teamId/projects', Project.fromMap);
  }

  /// Fetch a single project and store it as [selectedProject].
  ///
  /// Does **not** affect the primary list state. Calls [refreshUI] after
  /// updating [_selectedProject].
  Future<void> fetchProject(String teamId, String projectId) async {
    final response = await Http.get('/teams/$teamId/projects/$projectId');

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
    final response = await Http.post('/teams/$teamId/projects', data: data);

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
    final response = await Http.put(
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
    final response = await Http.delete('/teams/$teamId/projects/$projectId');

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // SSH key
  // ---------------------------------------------------------------------------

  /// Regenerate the SSH deploy key for the given project.
  ///
  /// POSTs to `/teams/[teamId]/projects/[projectId]/ssh-key` and returns the
  /// new public key string on success, or `null` on failure. On success,
  /// [fetchProject] is called to refresh the project data.
  Future<String?> regenerateSshKey(String teamId, String projectId) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/ssh-key',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final key = data['ssh_public_key'] as String?;
      await fetchProject(teamId, projectId);
      return key;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Runtimes
  // ---------------------------------------------------------------------------

  /// Fetch available language runtimes from the API.
  ///
  /// Calls `GET /api/v1/environment/runtimes` and caches the result in
  /// [_runtimes]. Subsequent calls return the cached value without hitting
  /// the network.
  ///
  /// Returns the runtimes map on success, or `null` on failure.
  Future<Map<String, dynamic>?> fetchRuntimes() async {
    if (_runtimes != null) {
      return _runtimes;
    }

    final response = await Http.get('/environment/runtimes');

    if (response.successful) {
      _runtimes = response.data as Map<String, dynamic>?;
      refreshUI();
      return _runtimes;
    }

    return null;
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
}
