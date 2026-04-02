/// A Docker container provisioned for a project's execution environment.
///
/// Immutable value object that maps directly to `ProjectContainerResource`
/// from the Kodizm API. Represents one Docker container lifecycle bound to
/// a project — tracking its current status, volume, host, and health state.
///
/// ## Usage
/// ```dart
/// final container = ProjectContainer.fromMap(json['container']);
/// print('${container.containerName} — ${container.status}');
/// ```
class ProjectContainer {
  // -------

  /// Creates a [ProjectContainer] with all fields.
  const ProjectContainer({
    required this.id,
    required this.containerName,
    required this.volumeName,
    required this.status,
    required this.dockerHostId,
    required this.createdAt,
    required this.updatedAt,
    this.lastActivityAt,
    this.healthCheckedAt,
    this.bootstrappedAt,
    this.lastError,
  });

  // -------

  /// The unique identifier of this container record (UUID).
  final String id;

  /// The Docker container name used on the host (e.g. `'kodizm-proj-abc123'`).
  final String containerName;

  /// The Docker volume name bound to this container (e.g. `'kodizm-vol-abc123'`).
  final String volumeName;

  /// The current container status — `'creating'`, `'running'`, `'stopped'`,
  /// or `'failed'`.
  final String status;

  /// The UUID of the [DockerHost] this container is provisioned on.
  final String dockerHostId;

  /// UTC timestamp of the last agent activity inside this container.
  /// Null when no activity has occurred yet.
  final DateTime? lastActivityAt;

  /// UTC timestamp of the last successful health check for this container.
  /// Null when no health check has run yet.
  final DateTime? healthCheckedAt;

  /// UTC timestamp when the container bootstrap process completed.
  /// Null when bootstrapping has not yet finished.
  final DateTime? bootstrappedAt;

  /// The most recent error message from a failed operation, if any.
  /// Null when the container is healthy.
  final String? lastError;

  /// UTC timestamp when this container record was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this container record.
  final DateTime updatedAt;

  // -------

  /// Parses a [ProjectContainer] from a JSON-decoded map.
  ///
  /// All nullable timestamp fields default to `null` when absent or `null`
  /// in the map. Timestamps are parsed via [DateTime.parse] from ISO-8601 strings.
  factory ProjectContainer.fromMap(Map<String, dynamic> map) {
    return ProjectContainer(
      id: map['id'] as String,
      containerName: map['container_name'] as String,
      volumeName: map['volume_name'] as String,
      status: map['status'] as String,
      dockerHostId: map['docker_host_id'] as String,
      lastActivityAt: map['last_activity_at'] != null
          ? DateTime.parse(map['last_activity_at'] as String)
          : null,
      healthCheckedAt: map['health_checked_at'] != null
          ? DateTime.parse(map['health_checked_at'] as String)
          : null,
      bootstrappedAt: map['bootstrapped_at'] != null
          ? DateTime.parse(map['bootstrapped_at'] as String)
          : null,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
