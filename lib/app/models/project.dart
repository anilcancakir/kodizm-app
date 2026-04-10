import 'dart:convert';

import 'package:magic/magic.dart';

import 'project_container.dart';
import 'project_repository.dart';

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
    'short_name',
    'slug',
    'description',
    'tech_stack',
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

  /// Get the short name (slug-like identifier) for this project.
  String? get shortName => getAttribute('short_name') as String?;

  /// Set the short name.
  set shortName(String? value) => setAttribute('short_name', value);

  /// Get the URL-friendly slug for this project.
  String? get slug => getAttribute('slug') as String?;

  /// Set the project slug.
  set slug(String? value) => setAttribute('slug', value);

  /// Get the optional project description.
  String? get description => getAttribute('description') as String?;

  /// Set the project description.
  set description(String? value) => setAttribute('description', value);

  /// Get the optional tech stack list (e.g. `['laravel', 'phpunit']`).
  List<String> get techStack {
    final raw = getAttribute('tech_stack');
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  /// Set the tech stack list.
  set techStack(List<String>? value) => setAttribute('tech_stack', value);

  /// Get the execution mode (`'manual'` or `'auto'`).
  ///
  /// Falls back to `'manual'` when not set on the model.
  String get executionMode =>
      getAttribute('execution_mode') as String? ?? 'manual';

  /// Set the execution mode.
  set executionMode(String value) => setAttribute('execution_mode', value);

  /// Get the optional project-level settings map.
  Map<String, dynamic>? get settings {
    final raw = getAttribute('settings');
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Set the project settings map.
  set settings(Map<String, dynamic>? value) => setAttribute('settings', value);

  /// Get the SSH public key provisioned for agent access to this project.
  ///
  /// Returns `null` when no key has been generated yet.
  String? get sshPublicKey => getAttribute('ssh_public_key') as String?;

  /// Whether an SSH key pair has been generated for this project.
  ///
  /// Falls back to `false` when not set on the model.
  bool get hasSshKey {
    final raw = getAttribute('has_ssh_key');
    if (raw is bool) return raw;
    return false;
  }

  // -- Pipeline --

  /// Get the project-level pipeline configuration map.
  ///
  /// Contains the auto-pipeline settings including enabled state, agent role,
  /// and retry limits. Returns `null` when not set.
  Map<String, dynamic>? get pipelineConfig {
    final raw = getAttribute('pipeline_config');
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Set the project-level pipeline configuration map.
  set pipelineConfig(Map<String, dynamic>? value) =>
      setAttribute('pipeline_config', value);

  /// Whether the auto-pipeline is enabled for this project.
  ///
  /// Reads from [pipelineConfig] and defaults to `false` when not set.
  bool get isPipelineEnabled {
    final val = pipelineConfig?['enabled'];
    return val is bool ? val : false;
  }

  // -- Environment --

  /// Get the project-level environment configuration map.
  ///
  /// Contains per-service runtime version overrides defined for this project.
  /// Returns `null` when not set on the model.
  Map<String, dynamic>? get environment {
    final raw = getAttribute('environment');
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Set the project-level environment configuration map.
  set environment(Map<String, dynamic>? value) =>
      setAttribute('environment', value);

  /// Get the resolved environment map, merging project and team-level settings.
  ///
  /// Populated by the API and reflects the effective runtime versions after
  /// inheritance resolution. Returns `null` when not included in the response.
  Map<String, dynamic>? get resolvedEnvironment {
    final raw = getAttribute('resolved_environment');
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// Get the resolved runtime version for a specific service key.
  ///
  /// Reads from [resolvedEnvironment] and returns the value as a [String],
  /// or `null` when the key is absent or [resolvedEnvironment] is not loaded.
  ///
  /// ```dart
  /// final nodeVersion = project.runtimeVersion('node'); // e.g. '20'
  /// ```
  String? runtimeVersion(String key) => resolvedEnvironment?[key]?.toString();

  /// Whether a specific service is enabled in the resolved environment.
  ///
  /// Reads the boolean flag for [key] from [resolvedEnvironment].
  /// Defaults to `true` when the key is absent or [resolvedEnvironment] is
  /// not loaded.
  ///
  /// ```dart
  /// final postgresEnabled = project.serviceEnabled('pg'); // true/false
  /// ```
  bool serviceEnabled(String key) {
    final val = resolvedEnvironment?[key];
    return val is bool ? val : true;
  }

  // ---------------------------------------------------------------------------
  // Relationship Accessors
  // ---------------------------------------------------------------------------

  /// Get the container linked to this project.
  ///
  /// Parses the nested `container` map from the API response into
  /// a typed [ProjectContainer] value object. Returns null when
  /// the relation is not loaded or no container exists.
  ProjectContainer? get container {
    final raw = getAttribute('container');
    if (raw is! Map<String, dynamic>) return null;
    return ProjectContainer.fromMap(raw);
  }

  /// Get the list of repositories linked to this project.
  ///
  /// Parses the nested `repositories` array from the API response into
  /// a typed list of [ProjectRepository] value objects. Returns an empty
  /// list when the relation is not loaded.
  List<ProjectRepository> get repositories {
    final raw = getAttribute('repositories');
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProjectRepository.fromMap)
        .toList();
  }

  /// Get the total number of repositories linked to this project.
  ///
  /// Uses the API-provided `repositories_count` when available, otherwise
  /// falls back to the length of the loaded [repositories] list.
  int get repositoriesCount {
    final raw = getAttribute('repositories_count');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return repositories.length;
  }

  // ---------------------------------------------------------------------------
  // Computed (API-only) Accessors
  // ---------------------------------------------------------------------------

  /// Get the total number of tasks in this project (computed by the API).
  ///
  /// Returns `null` when not included in the API response.
  int? get taskCount {
    final raw = getAttribute('task_count');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  /// Get the number of currently active runs in this project (computed by the API).
  ///
  /// Returns `null` when not included in the API response.
  int? get activeRunCount {
    final raw = getAttribute('active_run_count');
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

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
