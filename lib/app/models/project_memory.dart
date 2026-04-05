/// A memory entry belonging to a project.
///
/// Maps to `ProjectMemoryResource` from the Kodizm API. Stores context,
/// feedback, or reference content used by agents during project execution.
/// Supports attribution to either a human user or an agent role, optional
/// expiry, and arbitrary metadata.
///
/// ## Usage
/// ```dart
/// final memory = ProjectMemory.fromMap(json['memory']);
/// print(memory.name);              // 'Architecture Overview'
/// print(memory.createdByUserName); // 'Alice Smith'
/// ```
class ProjectMemory {
  // -------

  /// Creates a [ProjectMemory] with all fields.
  const ProjectMemory({
    required this.id,
    required this.projectId,
    required this.fileName,
    required this.name,
    required this.description,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.createdByUserId,
    this.createdByUserName,
    this.createdByAgentRoleId,
    this.createdByAgentRoleName,
    this.lastSyncedAt,
    this.expiresAt,
  });

  // -------

  /// The unique identifier of this memory entry (UUID).
  final String id;

  /// The identifier of the project this memory belongs to (UUID).
  final String projectId;

  /// The file name used to persist this memory on disk.
  final String fileName;

  /// Human-readable name of this memory entry.
  final String name;

  /// Short description of what this memory entry contains.
  final String description;

  /// The type of memory entry.
  ///
  /// Known values: `'feedback'`, `'user'`, `'project'`, `'reference'`.
  final String type;

  /// Full text content of this memory entry.
  final String content;

  /// Arbitrary key-value metadata attached to this memory entry.
  ///
  /// Shape is defined per-type by the producing agent or user. Null when
  /// no metadata was provided.
  final Map<String, dynamic>? metadata;

  /// The UUID of the human user who created this entry. Null when the entry
  /// was created by an agent role rather than a user.
  final String? createdByUserId;

  /// Display name of the creating user. Sourced from the nested
  /// `created_by_user.name` relation. Null if the relation is not loaded
  /// or the entry was created by an agent.
  final String? createdByUserName;

  /// The UUID of the agent role that created this entry. Null when the entry
  /// was created by a human user rather than an agent.
  final String? createdByAgentRoleId;

  /// Display name of the creating agent role. Sourced from the nested
  /// `created_by_agent_role.name` relation. Null if the relation is not
  /// loaded or the entry was created by a user.
  final String? createdByAgentRoleName;

  /// UTC timestamp of the last sync of this memory entry. Null if never
  /// synced.
  final DateTime? lastSyncedAt;

  /// UTC timestamp after which this memory entry should be considered stale.
  /// Null if the entry does not expire.
  final DateTime? expiresAt;

  /// UTC timestamp when this memory entry was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this memory entry.
  final DateTime updatedAt;

  // -------

  /// Parses a [ProjectMemory] from a JSON-decoded map.
  ///
  /// Extracts [createdByUserName] from the nested `created_by_user` relation
  /// and [createdByAgentRoleName] from the nested `created_by_agent_role`
  /// relation when present. Nullable DateTime fields are parsed only when
  /// non-null.
  factory ProjectMemory.fromMap(Map<String, dynamic> map) {
    final createdByUser = map['created_by_user'] as Map<String, dynamic>?;
    final createdByAgentRole =
        map['created_by_agent_role'] as Map<String, dynamic>?;

    final lastSyncedAtRaw = map['last_synced_at'] as String?;
    final expiresAtRaw = map['expires_at'] as String?;

    return ProjectMemory(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      fileName: map['file_name'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdByUserId: map['created_by_user_id'] as String?,
      createdByUserName: createdByUser?['name'] as String?,
      createdByAgentRoleId: map['created_by_agent_role_id'] as String?,
      createdByAgentRoleName: createdByAgentRole?['name'] as String?,
      lastSyncedAt: lastSyncedAtRaw != null
          ? DateTime.parse(lastSyncedAtRaw)
          : null,
      expiresAt: expiresAtRaw != null ? DateTime.parse(expiresAtRaw) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
