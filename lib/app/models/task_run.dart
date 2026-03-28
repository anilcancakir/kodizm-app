/// A single execution run of a task by an AI agent.
///
/// Captures the lifecycle, cost, and outcome of one agent invocation
/// against a task.
///
/// ## Usage
/// ```dart
/// final run = TaskRun.fromMap(json['runs'][0]);
/// print('${run.agentRoleName}: ${run.status}');
/// ```
class TaskRun {
  // -------

  /// Creates a [TaskRun] with all fields.
  const TaskRun({
    required this.id,
    required this.taskId,
    required this.agentRoleId,
    required this.status,
    required this.createdAt,
    this.agentRoleName,
    this.model,
    this.sessionId,
    this.prompt,
    this.totalCostUsd,
    this.durationMs,
    this.numTurns,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  // -------

  /// The unique identifier of the task run (UUID).
  final String id;

  /// The identifier of the parent task (UUID).
  final String taskId;

  /// The identifier of the agent role executing this run (UUID).
  final String agentRoleId;

  /// The display name of the agent role. Sourced from the nested
  /// `agent_role.name` relation. Null if the relation is not loaded.
  final String? agentRoleName;

  /// Execution status (e.g. `'running'`, `'done'`, `'failed'`).
  final String status;

  /// LLM model identifier used for this run (e.g. `'claude-3-5-sonnet'`).
  final String? model;

  /// Session identifier (UUID FK to Session). Null until assigned.
  final String? sessionId;

  /// The prompt text sent to the agent for this run.
  final String? prompt;

  /// Total cost of the run in USD. Null if billing has not yet been computed.
  final double? totalCostUsd;

  /// Wall-clock duration in milliseconds. Null for incomplete or aborted runs.
  final int? durationMs;

  /// Number of conversational turns in the run. Null if not yet computed.
  final int? numTurns;

  /// Error message if the run failed. Null on success.
  final String? error;

  /// UTC timestamp when the run was dispatched to the agent.
  final DateTime? startedAt;

  /// UTC timestamp when the run completed or failed.
  final DateTime? completedAt;

  /// UTC timestamp when this run record was created.
  final DateTime createdAt;

  // -------

  /// Parses a [TaskRun] from a JSON-decoded map.
  ///
  /// Extracts [agentRoleName] from the nested `agent_role.name` relation
  /// when present.
  factory TaskRun.fromMap(Map<String, dynamic> map) {
    final agentRole = map['agent_role'] as Map<String, dynamic>?;

    return TaskRun(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      agentRoleId: map['agent_role_id'] as String,
      agentRoleName: agentRole?['name'] as String?,
      status: map['status'] as String,
      model: map['model'] as String?,
      sessionId: map['session_id'] as String?,
      prompt: map['prompt'] as String?,
      totalCostUsd: (map['total_cost_usd'] as num?)?.toDouble(),
      durationMs: map['duration_ms'] as int?,
      numTurns: map['num_turns'] as int?,
      error: map['error'] as String?,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
