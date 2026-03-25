/// A discrete content section produced during a task run.
///
/// Sections capture the output of a specific phase of AI processing,
/// such as analysis, planning, or code generation.
///
/// ## Usage
/// ```dart
/// final section = TaskSection.fromMap(json['sections'][0]);
/// print(section.title); // 'Analysis Output'
/// ```
class TaskSection {
  // -------

  /// Creates a [TaskSection] with all fields.
  const TaskSection({
    required this.id,
    required this.taskId,
    required this.type,
    required this.title,
    required this.content,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.createdByAgentRoleId,
    this.createdByAgentRoleName,
    this.createdByUserId,
  });

  // -------

  /// The unique identifier of the section (UUID).
  final String id;

  /// The identifier of the parent task (UUID).
  final String taskId;

  /// Section type slug (e.g. `'analysis'`, `'planning'`, `'code'`).
  final String type;

  /// Human-readable title of the section.
  final String title;

  /// Markdown content of the section.
  final String content;

  /// The identifier of the agent role that created this section (UUID). Null if created by a user.
  final String? createdByAgentRoleId;

  /// The display name of the agent role that created this section. Sourced from
  /// the nested `created_by_agent_role.name` relation. Null if created by a user.
  final String? createdByAgentRoleName;

  /// The identifier of the user that created this section (UUID). Null if created by an agent.
  final String? createdByUserId;

  /// Monotonically increasing version counter for this section.
  final int version;

  /// UTC timestamp when this section was created.
  final DateTime createdAt;

  /// UTC timestamp when this section was last updated.
  final DateTime updatedAt;

  // -------

  /// Parses a [TaskSection] from a JSON-decoded map.
  ///
  /// Extracts [createdByAgentRoleName] from the nested `created_by_agent_role`
  /// relation map when present.
  factory TaskSection.fromMap(Map<String, dynamic> map) {
    final agentRole = map['created_by_agent_role'] as Map<String, dynamic>?;

    return TaskSection(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdByAgentRoleId: map['created_by_agent_role_id'] as String?,
      createdByAgentRoleName: agentRole?['name'] as String?,
      createdByUserId: map['created_by_user_id'] as String?,
      version: map['version'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
