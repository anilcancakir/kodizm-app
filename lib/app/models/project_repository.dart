/// A repository linked to a Kodizm project.
///
/// Immutable value object mapping directly to `ProjectRepositoryResource`
/// from the Kodizm API. A project can have multiple repositories, each
/// cloned into a unique [mountPath] inside the execution container.
///
/// ## Usage
/// ```dart
/// final repo = ProjectRepository.fromMap(json['repositories'][0]);
/// print('${repo.name} -> ${repo.repositoryUrl}');
/// final updated = repo.copyWith(defaultBranch: 'develop');
/// ```
class ProjectRepository {
  // -------

  /// Creates a [ProjectRepository] with all fields.
  const ProjectRepository({
    required this.id,
    required this.projectId,
    required this.name,
    required this.defaultBranch,
    required this.mountPath,
    this.repositoryUrl,
    this.repoStatus,
    this.repoError,
    this.onboardingConversationId,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
    this.isMain = false,
  });

  // -------

  /// The unique identifier of this repository (UUID).
  final String id;

  /// The identifier of the parent project (UUID).
  final String projectId;

  /// A human-readable name for this repository link.
  final String name;

  /// The remote repository URL (SSH or HTTPS). Null when not yet configured.
  final String? repositoryUrl;

  /// The default Git branch to check out (e.g. `'main'`, `'master'`).
  final String defaultBranch;

  /// The current sync status of the repository (e.g. `'synced'`, `'error'`).
  /// Null when status has not been determined.
  final String? repoStatus;

  /// Error message from the last failed sync attempt. Null when healthy.
  final String? repoError;

  /// The conversation ID of the onboarding session for this repository.
  /// Null when onboarding has not been started.
  final String? onboardingConversationId;

  /// ISO-8601 timestamp of the last successful sync. Null when never synced.
  final String? lastSyncedAt;

  /// The container-local mount path for this repository clone.
  final String mountPath;

  /// ISO-8601 timestamp when this record was created. Null when not provided.
  final String? createdAt;

  /// ISO-8601 timestamp of the last update. Null when not provided.
  final String? updatedAt;

  /// Whether this is the primary (main) repository for the project.
  final bool isMain;

  // -------

  /// Parses a [ProjectRepository] from a JSON-decoded map.
  ///
  /// Applies sensible defaults for [defaultBranch] (`'main'`) and
  /// [mountPath] (`'/workspace'`).
  factory ProjectRepository.fromMap(Map<String, dynamic> map) {
    return ProjectRepository(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      name: map['name'] as String,
      repositoryUrl: map['repository_url'] as String?,
      defaultBranch: map['default_branch'] as String? ?? 'main',
      repoStatus: map['repo_status'] as String?,
      repoError: map['repo_error'] as String?,
      onboardingConversationId: map['onboarding_conversation_id'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      mountPath: map['mount_path'] as String? ?? '/workspace',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      isMain: map['is_main'] as bool? ?? false,
    );
  }

  // -------

  /// Returns a copy of this [ProjectRepository] with the specified fields
  /// replaced.
  ///
  /// All fields not provided retain their current values.
  ProjectRepository copyWith({
    String? id,
    String? projectId,
    String? name,
    String? repositoryUrl,
    bool clearRepositoryUrl = false,
    String? defaultBranch,
    String? repoStatus,
    bool clearRepoStatus = false,
    String? repoError,
    bool clearRepoError = false,
    String? onboardingConversationId,
    bool clearOnboardingConversationId = false,
    String? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? mountPath,
    String? createdAt,
    String? updatedAt,
    bool? isMain,
  }) {
    return ProjectRepository(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      repositoryUrl: clearRepositoryUrl
          ? null
          : (repositoryUrl ?? this.repositoryUrl),
      defaultBranch: defaultBranch ?? this.defaultBranch,
      repoStatus: clearRepoStatus ? null : (repoStatus ?? this.repoStatus),
      repoError: clearRepoError ? null : (repoError ?? this.repoError),
      onboardingConversationId: clearOnboardingConversationId
          ? null
          : (onboardingConversationId ?? this.onboardingConversationId),
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      mountPath: mountPath ?? this.mountPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMain: isMain ?? this.isMain,
    );
  }
}
