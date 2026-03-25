import 'dart:convert';

import 'package:magic/magic.dart';

/// Project model.
///
/// Represents a Kodizm project within a team. Extends the Magic ORM [Model]
/// with [HasTimestamps] and [InteractsWithPersistence] mixins to provide full
/// persistence and timestamp tracking.
///
/// ## Usage
///
/// ```dart
/// // Hydrate from API response
/// final project = Project.fromMap(responseData);
/// Log.debug(project.name);
///
/// // Find a project by ID
/// final project = await Project.find('proj-uuid-001');
/// Log.debug(project?.slug);
/// ```
class Project extends Model with HasTimestamps, InteractsWithPersistence {
  /// The table associated with the model.
  @override
  String get table => 'projects';

  /// The API resource for remote operations.
  @override
  String get resource => 'projects';

  /// Whether the primary key is auto-incrementing.
  ///
  /// Set to false because this app uses string UUIDs as primary keys.
  @override
  bool get incrementing => false;

  /// The attributes that are mass assignable.
  @override
  List<String> get fillable => [
    'team_id',
    'name',
    'slug',
    'description',
    'repository_url',
    'default_branch',
    'tech_stack',
    'ssh_public_key',
    'execution_mode',
    'settings',
  ];

  /// The attributes that should be cast.
  @override
  Map<String, String> get casts => {};

  // ---------------------------------------------------------------------------
  // Typed Accessors
  // ---------------------------------------------------------------------------

  /// Get the project's ID.
  @override
  String get id => getAttribute('id')?.toString() ?? '';

  /// Get the ID of the team this project belongs to.
  String? get teamId => getAttribute('team_id') as String?;

  /// Set the team ID.
  set teamId(String? value) => setAttribute('team_id', value);

  /// Get the project name.
  String? get name => getAttribute('name') as String?;

  /// Set the project name.
  set name(String? value) => setAttribute('name', value);

  /// Get the URL-friendly slug for this project.
  String? get slug => getAttribute('slug') as String?;

  /// Set the project slug.
  set slug(String? value) => setAttribute('slug', value);

  /// Get the optional project description.
  String? get description => getAttribute('description') as String?;

  /// Set the project description.
  set description(String? value) => setAttribute('description', value);

  /// Get the optional repository URL (SSH or HTTPS).
  String? get repositoryUrl => getAttribute('repository_url') as String?;

  /// Set the repository URL.
  set repositoryUrl(String? value) => setAttribute('repository_url', value);

  /// Get the default Git branch (e.g. `main`, `master`).
  ///
  /// Falls back to `'main'` when not set on the model.
  String get defaultBranch =>
      getAttribute('default_branch') as String? ?? 'main';

  /// Set the default Git branch.
  set defaultBranch(String value) => setAttribute('default_branch', value);

  /// Get the optional tech stack description (e.g. `Laravel, PostgreSQL`).
  String? get techStack => getAttribute('tech_stack') as String?;

  /// Set the tech stack description.
  set techStack(String? value) => setAttribute('tech_stack', value);

  /// Get the optional SSH public key provisioned for agent access.
  String? get sshPublicKey => getAttribute('ssh_public_key') as String?;

  /// Set the SSH public key.
  set sshPublicKey(String? value) => setAttribute('ssh_public_key', value);

  /// Get the execution mode (`'manual'` or `'auto'`).
  ///
  /// Falls back to `'manual'` when not set on the model.
  String get executionMode =>
      getAttribute('execution_mode') as String? ?? 'manual';

  /// Set the execution mode.
  set executionMode(String value) => setAttribute('execution_mode', value);

  /// Get the optional project-level settings map.
  Map<String, dynamic>? get settings =>
      getAttribute('settings') as Map<String, dynamic>?;

  /// Set the project settings map.
  set settings(Map<String, dynamic>? value) => setAttribute('settings', value);

  // ---------------------------------------------------------------------------
  // Computed (API-only) Accessors
  // ---------------------------------------------------------------------------

  /// Get the total number of tasks in this project (computed by the API).
  ///
  /// Returns `null` when not included in the API response.
  int? get taskCount => getAttribute('task_count') as int?;

  /// Get the number of currently active runs in this project (computed by the API).
  ///
  /// Returns `null` when not included in the API response.
  int? get activeRunCount => getAttribute('active_run_count') as int?;

  // ---------------------------------------------------------------------------
  // Static Helpers
  // ---------------------------------------------------------------------------

  /// Find a project by ID.
  ///
  /// Returns `null` if no project with the given [id] exists.
  ///
  /// ```dart
  /// final project = await Project.find('proj-uuid-001');
  /// ```
  static Future<Project?> find(dynamic id) =>
      InteractsWithPersistence.findById<Project>(id, Project.new);

  /// Get all projects.
  ///
  /// ```dart
  /// final projects = await Project.all();
  /// ```
  static Future<List<Project>> all() =>
      InteractsWithPersistence.allModels<Project>(Project.new);

  // ---------------------------------------------------------------------------
  // Factory Methods
  // ---------------------------------------------------------------------------

  /// Create a [Project] from a [Map].
  ///
  /// Uses [setRawAttributes] to hydrate the model directly from raw API data,
  /// bypassing mass-assignment protection. The [exists] flag is set based on
  /// whether the map contains an `id` key.
  ///
  /// ```dart
  /// final project = Project.fromMap({'id': 'proj-uuid-001', 'name': 'My Project', ...});
  /// ```
  static Project fromMap(Map<String, dynamic> map) {
    return Project()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }

  /// Create a [Project] from a JSON string.
  ///
  /// Decodes [json] and delegates to [fromMap].
  ///
  /// ```dart
  /// final project = Project.fromJson('{"id":"proj-uuid-001","name":"My Project"}');
  /// ```
  static Project fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return Project.fromMap(map);
  }
}
