/// A conversation between a user and an agent role in a project.
///
/// Maps directly to `ConversationResource` from the Kodizm API.
/// Nested `user` and `agent_role` relations are flattened into individual
/// fields for convenient access.
///
/// ## Usage
/// ```dart
/// final conversation = Conversation.fromMap(json['conversation']);
/// final updated = conversation.copyWith(status: 'completed');
/// ```
class Conversation {
  // -------

  /// Creates a [Conversation] with all fields.
  const Conversation({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.agentRoleId,
    required this.status,
    this.totalInputTokens,
    this.totalOutputTokens,
    this.messagesCount,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
    this.agentRoleName,
    this.agentRoleSlug,
    this.title,
    this.model,
    this.totalCostUsd,
    this.lastActivityAt,
    this.startedAt,
    this.completedAt,
    this.type = 'interactive',
    this.taskId,
    this.prompt,
  });

  // -------

  /// The unique identifier of this conversation (UUID).
  final String id;

  /// The identifier of the parent project (UUID).
  final String projectId;

  /// The identifier of the user who started this conversation (UUID).
  /// Sourced from the nested `user.id` relation.
  final String userId;

  /// The display name of the user. Sourced from the nested `user.name`
  /// relation. Null if name is not set on the user record.
  final String? userName;

  /// The identifier of the agent role assigned to this conversation (UUID).
  /// Sourced from the nested `agent_role.id` relation.
  final String agentRoleId;

  /// The display name of the agent role. Sourced from the nested
  /// `agent_role.name` relation. Null if the relation is not loaded.
  final String? agentRoleName;

  /// The slug of the agent role. Sourced from the nested
  /// `agent_role.slug` relation. Null if the relation is not loaded.
  final String? agentRoleSlug;

  /// Optional title for this conversation. Null if not set.
  final String? title;

  /// Conversation lifecycle status (e.g. `'active'`, `'completed'`, `'failed'`).
  final String status;

  /// LLM model identifier used for this conversation (e.g. `'claude-sonnet-4-6'`).
  /// Null if not yet assigned.
  final String? model;

  /// Total cost of the conversation in USD. Null if billing has not been computed.
  /// Parsed from the API string representation.
  final double? totalCostUsd;

  /// Total number of input tokens consumed across all messages. Null on fresh conversations.
  final int? totalInputTokens;

  /// Total number of output tokens generated across all messages. Null on fresh conversations.
  final int? totalOutputTokens;

  /// Total number of messages in this conversation. Null on fresh conversations.
  final int? messagesCount;

  /// UTC timestamp of the most recent message activity. Null if no messages yet.
  final DateTime? lastActivityAt;

  /// UTC timestamp when the conversation was started. Null if not yet started.
  final DateTime? startedAt;

  /// UTC timestamp when the conversation completed. Null if still active.
  final DateTime? completedAt;

  /// UTC timestamp when this conversation record was created.
  final DateTime createdAt;

  /// Conversation type — `'interactive'` (user-driven chat) or `'autonomous'`
  /// (task-triggered agent run).
  final String type;

  /// The identifier of the parent task (UUID). Present only for autonomous
  /// conversations spawned from a task run. Null for interactive chats.
  final String? taskId;

  /// The prompt text sent to the agent for autonomous conversations. Null for
  /// interactive chats where the user types messages directly.
  final String? prompt;

  /// UTC timestamp of the last update to this conversation record.
  final DateTime updatedAt;

  // -------

  /// Whether this conversation is an autonomous task run.
  bool get isAutonomous => type == 'autonomous';

  // -------

  /// Parses a [Conversation] from a JSON-decoded map.
  ///
  /// Extracts [userId] and [userName] from the nested `user` relation and
  /// [agentRoleId], [agentRoleName], [agentRoleSlug] from the nested
  /// `agent_role` relation. [totalCostUsd] is parsed from an API string value.
  factory Conversation.fromMap(Map<String, dynamic> map) {
    final user = map['user'] as Map<String, dynamic>?;
    final agentRole = map['agent_role'] as Map<String, dynamic>?;
    final costString = map['total_cost_usd'] as String?;

    return Conversation(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      userId: user?['id'] as String? ?? '',
      userName: user?['name'] as String?,
      agentRoleId: agentRole?['id'] as String? ?? '',
      agentRoleName: agentRole?['name'] as String?,
      agentRoleSlug: agentRole?['slug'] as String?,
      title: map['title'] as String?,
      status: map['status'] as String,
      model: map['model'] as String?,
      totalCostUsd: costString != null ? double.parse(costString) : null,
      totalInputTokens: map['total_input_tokens'] as int?,
      totalOutputTokens: map['total_output_tokens'] as int?,
      messagesCount: map['messages_count'] as int?,
      lastActivityAt: map['last_activity_at'] != null
          ? DateTime.parse(map['last_activity_at'] as String)
          : null,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      type: map['type'] as String? ?? 'interactive',
      taskId: map['task_id'] as String?,
      prompt: map['prompt'] as String?,
    );
  }

  // -------

  /// Returns a copy of this [Conversation] with the specified fields replaced.
  ///
  /// All fields not provided retain their current values.
  Conversation copyWith({
    String? title,
    String? status,
    String? model,
    double? totalCostUsd,
    int? messagesCount,
    DateTime? lastActivityAt,
    DateTime? completedAt,
    String? type,
    String? taskId,
    String? prompt,
  }) {
    return Conversation(
      id: id,
      projectId: projectId,
      userId: userId,
      userName: userName,
      agentRoleId: agentRoleId,
      agentRoleName: agentRoleName,
      agentRoleSlug: agentRoleSlug,
      title: title ?? this.title,
      status: status ?? this.status,
      model: model ?? this.model,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      messagesCount: messagesCount ?? this.messagesCount,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      prompt: prompt ?? this.prompt,
    );
  }
}
