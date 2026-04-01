/// An agent role definition, describing the kind of AI agent
/// that can be assigned to a task run.
///
/// ## Usage
/// ```dart
/// final role = AgentRole.fromMap(json['agent_role']);
/// print(role.name); // 'Business Analyst'
/// ```
class AgentRole {
  // -------

  /// Creates an [AgentRole] with all fields.
  AgentRole({
    required this.id,
    required this.name,
    required this.scope,
    this.description,
    this.teamId = '',
    this.projectId,
    this.parentId,
    this.slug = '',
    this.cliBackend = '',
    this.preferredModel,
    this.backendConfig,
    this.toolPermissions,
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  // -------

  /// The unique identifier of the agent role (UUID).
  final String id;

  /// The team this role belongs to (UUID).
  final String teamId;

  /// The project this role is scoped to (UUID), or null for team-wide roles.
  final String? projectId;

  /// The parent role UUID for role inheritance, or null if no parent.
  final String? parentId;

  /// Human-readable name of the role (e.g. `'Business Analyst'`, `'Developer'`).
  final String name;

  /// URL-safe slug identifier for the role (e.g. `'business-analyst'`).
  final String slug;

  /// Optional description explaining the role's purpose and responsibilities.
  final String? description;

  /// The CLI backend used by this role (e.g. `'claude_code'`, `'claude'`).
  final String cliBackend;

  /// The preferred model identifier for this role (e.g. `'claude-sonnet-4-5'`).
  final String? preferredModel;

  /// Backend-specific configuration as a JSON object (e.g. temperature, max_tokens).
  final Map<String, dynamic>? backendConfig;

  /// Tool permissions map controlling which tools the agent may use.
  final Map<String, dynamic>? toolPermissions;

  /// Scope identifier for the role (e.g. `'analysis'`, `'implementation'`).
  final String scope;

  /// Whether this role is currently active and available for assignment.
  final bool isActive;

  /// Display sort order for listing roles.
  final int sortOrder;

  /// ISO 8601 datetime string of when the role was created.
  final String? createdAt;

  /// ISO 8601 datetime string of when the role was last updated.
  final String? updatedAt;

  // -------

  /// Parses an [AgentRole] from a JSON-decoded map.
  factory AgentRole.fromMap(Map<String, dynamic> map) {
    return AgentRole(
      id: map['id'] as String,
      teamId: map['team_id'] as String? ?? '',
      projectId: map['project_id'] as String?,
      parentId: map['parent_id'] as String?,
      name: map['name'] as String,
      slug: map['slug'] as String? ?? '',
      description: map['description'] as String?,
      cliBackend: map['cli_backend'] as String? ?? '',
      preferredModel: map['preferred_model'] as String?,
      backendConfig: map['backend_config'] as Map<String, dynamic>?,
      toolPermissions: map['tool_permissions'] as Map<String, dynamic>?,
      scope: map['scope'] as String,
      isActive: (map['is_active'] as bool?) ?? true,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
