/// A knowledge-base document or memory entry belonging to a project.
///
/// Maps to `ProjectDocumentResource` from the Kodizm API. Supports markdown
/// content, an optional category tag, arbitrary metadata, and attribution to
/// either a human user or an agent role. Unified model for both documents
/// and memories via the [type] field.
///
/// ## Usage
/// ```dart
/// final doc = ProjectDocument.fromMap(json['document']);
/// print(doc.title);        // 'Architecture Overview'
/// print(doc.createdByUserName);  // 'Alice Smith'
/// print(doc.isMemory);     // false
/// ```
class ProjectDocument {
  // -------

  /// Creates a [ProjectDocument] with all fields.
  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category,
    this.metadata,
    this.createdByUserId,
    this.createdByUserName,
    this.createdByAgentRoleId,
    this.createdByAgentRoleName,
    this.type,
    this.memoryType,
    this.autoInject,
    this.priority,
  });

  // -------

  /// The unique identifier of this document (UUID).
  final String id;

  /// The identifier of the project this document belongs to (UUID).
  final String projectId;

  /// Human-readable title of the document.
  final String title;

  /// Full markdown content of the document.
  final String content;

  /// Optional category tag classifying the document type.
  ///
  /// Known values: `'architecture'`, `'api'`, `'guide'`, `'convention'`,
  /// `'runbook'`, `'agent_output'`, `'other'`. Null if uncategorised.
  final String? category;

  /// Arbitrary key-value metadata attached to the document.
  ///
  /// Shape is defined per-category by the producing agent or user. Null
  /// when no metadata was provided.
  final Map<String, dynamic>? metadata;

  /// The UUID of the human user who created this document. Null when
  /// the document was created by an agent role rather than a user.
  final String? createdByUserId;

  /// Display name of the creating user. Sourced from the nested
  /// `created_by_user.name` relation. Null if the relation is not loaded
  /// or the document was created by an agent.
  final String? createdByUserName;

  /// The UUID of the agent role that created this document. Null when
  /// the document was created by a human user rather than an agent.
  final String? createdByAgentRoleId;

  /// Display name of the creating agent role. Sourced from the nested
  /// `created_by_agent_role.name` relation. Null if the relation is not
  /// loaded or the document was created by a user.
  final String? createdByAgentRoleName;

  /// UTC timestamp when this document was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this document.
  final DateTime updatedAt;

  // -------
  // Unified knowledge fields
  // -------

  /// The type of knowledge entry: `'document'` or `'memory'`.
  ///
  /// Null for legacy entries that predate the unified model.
  final String? type;

  /// The memory sub-type when [type] is `'memory'`.
  ///
  /// Known values: `'feedback'`, `'user'`, `'project'`, `'reference'`.
  /// Null for document-type entries.
  final String? memoryType;

  /// Whether this entry is auto-injected into CLAUDE.md context.
  ///
  /// Only relevant for memory-type entries.
  final bool? autoInject;

  /// Injection priority for auto-injected entries.
  ///
  /// Lower numbers are injected first. Null when not set.
  final int? priority;

  // -------
  // Convenience accessors
  // -------

  /// Returns `true` when this entry is a memory (not a document).
  bool get isMemory => type == 'memory';

  // -------

  /// Parses a [ProjectDocument] from a JSON-decoded map.
  ///
  /// Extracts [createdByUserName] from the nested `created_by_user` relation
  /// and [createdByAgentRoleName] from the nested `created_by_agent_role`
  /// relation when present.
  factory ProjectDocument.fromMap(Map<String, dynamic> map) {
    final createdByUser = map['created_by_user'] as Map<String, dynamic>?;
    final createdByAgentRole =
        map['created_by_agent_role'] as Map<String, dynamic>?;

    return ProjectDocument(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: map['category'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdByUserId: map['created_by_user_id'] as String?,
      createdByUserName: createdByUser?['name'] as String?,
      createdByAgentRoleId: map['created_by_agent_role_id'] as String?,
      createdByAgentRoleName: createdByAgentRole?['name'] as String?,
      type: map['type'] as String?,
      memoryType: map['memory_type'] as String?,
      autoInject: map['auto_inject'] as bool?,
      priority: map['priority'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
