/// A single AI token usage record for a team, optionally linked to a conversation.
///
/// Maps to `UsageRecordResource` from the Kodizm API. Includes token counts,
/// cost in USD (parsed from a decimal string), billing period, and optional
/// nested context from the linked conversation.
///
/// ## Usage
/// ```dart
/// final record = UsageRecord.fromMap(json['data'][0]);
/// print('${record.model}: \$${record.costUsd}');
/// print(record.taskTitle); // 'Implement login'
/// ```
class UsageRecord {
  // -------

  /// Creates a [UsageRecord] with all fields.
  const UsageRecord({
    required this.id,
    required this.teamId,
    required this.costUsd,
    required this.period,
    required this.recordedAt,
    this.conversationId,
    this.model,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
    this.cacheWriteTokens,
    this.agentRoleName,
    this.taskTitle,
    this.projectId,
  });

  // -------

  /// The unique identifier of this usage record (UUID).
  final String id;

  /// The identifier of the team that incurred this usage (UUID).
  final String teamId;

  /// The identifier of the conversation that generated this record (UUID). Null
  /// when the usage is not tied to a specific conversation.
  final String? conversationId;

  /// The AI model identifier (e.g. `'claude-sonnet-4-6'`). Null when
  /// the model was not recorded.
  final String? model;

  /// Number of input tokens consumed. Null when not tracked.
  final int? inputTokens;

  /// Number of output tokens generated. Null when not tracked.
  final int? outputTokens;

  /// Number of cache-read tokens used. Null when not tracked.
  final int? cacheReadTokens;

  /// Number of cache-write tokens used. Null when not tracked.
  final int? cacheWriteTokens;

  /// Cost of this record in USD, parsed from a decimal string returned by the
  /// API (e.g. `"0.00420"`).
  final double costUsd;

  /// Billing period this record belongs to (e.g. `'2025-03'`).
  final String period;

  /// UTC timestamp when this usage was recorded.
  final DateTime recordedAt;

  /// Agent role name from the linked conversation's agent role.
  /// Null when the record is not linked to a conversation or the relation is
  /// not loaded.
  final String? agentRoleName;

  /// Task title from the linked conversation's task. Null when not loaded.
  final String? taskTitle;

  /// Project identifier from the linked conversation's task (UUID).
  /// Null when not loaded.
  final String? projectId;

  // -------

  /// Parses a [UsageRecord] from a JSON-decoded map.
  ///
  /// Extracts [agentRoleName] from the nested `conversation.agent_role_name`
  /// field, [taskTitle] from `conversation.task.title`, and [projectId] from
  /// `conversation.task.project_id`.
  ///
  /// [costUsd] is parsed via [double.parse] because the API returns it as a
  /// decimal string (e.g. `"0.00420"`).
  factory UsageRecord.fromMap(Map<String, dynamic> map) {
    final conversation = map['conversation'] as Map<String, dynamic>?;
    final task = conversation?['task'] as Map<String, dynamic>?;

    return UsageRecord(
      id: map['id'] as String,
      teamId: map['team_id'] as String,
      conversationId: map['conversation_id'] as String?,
      model: map['model'] as String?,
      inputTokens: map['input_tokens'] as int?,
      outputTokens: map['output_tokens'] as int?,
      cacheReadTokens: map['cache_read_tokens'] as int?,
      cacheWriteTokens: map['cache_write_tokens'] as int?,
      costUsd: double.parse(map['cost_usd'] as String),
      period: map['period'] as String,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      agentRoleName: conversation?['agent_role_name'] as String?,
      taskTitle: task?['title'] as String?,
      projectId: task?['project_id'] as String?,
    );
  }
}
