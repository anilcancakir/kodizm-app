/// A single turn-level token usage record within a session.
///
/// Maps directly to `SessionUsageRecordResource` from the Kodizm API.
/// Each record captures the token counts and cost for one LLM turn,
/// distinguishing between primary agent turns and spawned subagent turns.
///
/// ## Usage
/// ```dart
/// final record = SessionUsageRecord.fromMap(json['usage_records'][0]);
/// print('Turn ${record.turnNumber}: \$${record.costUsd}');
/// print(record.isSubagent ? 'subagent: ${record.subagentType}' : 'primary');
/// ```
class SessionUsageRecord {
  // -------

  /// Creates a [SessionUsageRecord] with all fields.
  const SessionUsageRecord({
    required this.id,
    required this.sessionId,
    required this.turnNumber,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheCreationTokens,
    required this.costUsd,
    required this.isSubagent,
    required this.createdAt,
    this.subagentType,
  });

  // -------

  /// The unique identifier of this usage record (UUID).
  final String id;

  /// The identifier of the parent session (UUID).
  final String sessionId;

  /// The sequential turn number within the session (1-based).
  final int turnNumber;

  /// The AI model identifier used for this turn (e.g. `'claude-sonnet-4-6'`).
  final String model;

  /// Number of input (prompt) tokens consumed in this turn.
  final int inputTokens;

  /// Number of output (completion) tokens generated in this turn.
  final int outputTokens;

  /// Number of tokens read from the prompt cache in this turn.
  final int cacheReadTokens;

  /// Number of tokens written to the prompt cache in this turn.
  final int cacheCreationTokens;

  /// Cost of this turn in USD, parsed from the API decimal string.
  final double costUsd;

  /// Whether this turn was executed by a spawned subagent.
  final bool isSubagent;

  /// The subagent type identifier (e.g. `'ac:explore'`). Null when
  /// [isSubagent] is `false`.
  final String? subagentType;

  /// UTC timestamp when this record was created.
  final DateTime createdAt;

  // -------

  /// Parses a [SessionUsageRecord] from a JSON-decoded map.
  ///
  /// [costUsd] is parsed via [double.tryParse] because the API returns it as a
  /// decimal string (e.g. `"0.004200"`).
  factory SessionUsageRecord.fromMap(Map<String, dynamic> map) {
    return SessionUsageRecord(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      turnNumber: map['turn_number'] as int,
      model: map['model'] as String,
      inputTokens: map['input_tokens'] as int,
      outputTokens: map['output_tokens'] as int,
      cacheReadTokens: map['cache_read_tokens'] as int,
      cacheCreationTokens: map['cache_creation_tokens'] as int,
      costUsd: double.tryParse(map['cost_usd']?.toString() ?? '') ?? 0.0,
      isSubagent: map['is_subagent'] as bool,
      subagentType: map['subagent_type'] as String?,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
