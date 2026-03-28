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
    required this.hasSshKey,
    this.repositoryUrl,
    this.sshPublicKey,
    this.repoStatus,
    this.repoError,
    this.lastSyncedAt,
    this.createdAt,
    this.updatedAt,
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

  /// The SSH public key provisioned for agent access to this repository.
  /// Null when no key has been generated.
  final String? sshPublicKey;

  /// The current sync status of the repository (e.g. `'synced'`, `'error'`).
  /// Null when status has not been determined.
  final String? repoStatus;

  /// Error message from the last failed sync attempt. Null when healthy.
  final String? repoError;

  /// ISO-8601 timestamp of the last successful sync. Null when never synced.
  final String? lastSyncedAt;

  /// The container-local mount path for this repository clone.
  final String mountPath;

  /// Whether an SSH key pair has been generated for this repository.
  final bool hasSshKey;

  /// ISO-8601 timestamp when this record was created. Null when not provided.
  final String? createdAt;

  /// ISO-8601 timestamp of the last update. Null when not provided.
  final String? updatedAt;

  // -------

  /// Parses a [ProjectRepository] from a JSON-decoded map.
  ///
  /// Applies sensible defaults for [defaultBranch] (`'main'`),
  /// [mountPath] (`'/workspace'`), and [hasSshKey] (`false`).
  factory ProjectRepository.fromMap(Map<String, dynamic> map) {
    return ProjectRepository(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      name: map['name'] as String,
      repositoryUrl: map['repository_url'] as String?,
      defaultBranch: map['default_branch'] as String? ?? 'main',
      sshPublicKey: map['ssh_public_key'] as String?,
      repoStatus: map['repo_status'] as String?,
      repoError: map['repo_error'] as String?,
      lastSyncedAt: map['last_synced_at'] as String?,
      mountPath: map['mount_path'] as String? ?? '/workspace',
      hasSshKey: map['has_ssh_key'] as bool? ?? false,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
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
    String? sshPublicKey,
    bool clearSshPublicKey = false,
    String? repoStatus,
    bool clearRepoStatus = false,
    String? repoError,
    bool clearRepoError = false,
    String? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? mountPath,
    bool? hasSshKey,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProjectRepository(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      repositoryUrl: clearRepositoryUrl
          ? null
          : (repositoryUrl ?? this.repositoryUrl),
      defaultBranch: defaultBranch ?? this.defaultBranch,
      sshPublicKey: clearSshPublicKey
          ? null
          : (sshPublicKey ?? this.sshPublicKey),
      repoStatus: clearRepoStatus ? null : (repoStatus ?? this.repoStatus),
      repoError: clearRepoError ? null : (repoError ?? this.repoError),
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      mountPath: mountPath ?? this.mountPath,
      hasSshKey: hasSshKey ?? this.hasSshKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
