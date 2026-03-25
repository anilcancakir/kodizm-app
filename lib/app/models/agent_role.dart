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
  const AgentRole({
    required this.id,
    required this.name,
    required this.scope,
    this.description,
  });

  // -------

  /// The unique identifier of the agent role (UUID).
  final String id;

  /// Human-readable name of the role (e.g. `'Business Analyst'`, `'Developer'`).
  final String name;

  /// Optional description explaining the role's purpose and responsibilities.
  final String? description;

  /// Scope identifier for the role (e.g. `'analysis'`, `'implementation'`).
  final String scope;

  // -------

  /// Parses an [AgentRole] from a JSON-decoded map.
  factory AgentRole.fromMap(Map<String, dynamic> map) {
    return AgentRole(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      scope: map['scope'] as String,
    );
  }
}
