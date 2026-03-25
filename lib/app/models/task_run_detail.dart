/// Extended detail model for a single agent execution run.
///
/// Includes all fields from `TaskRunDetailResource`, including the full
/// agent role relation, container/worktree metadata, token usage, and
/// timing information. Supports [copyWith] for reactive state updates.
///
/// ## Usage
/// ```dart
/// final run = TaskRunDetail.fromMap(json['run']);
/// final updated = run.copyWith(status: 'done', durationMs: 12000);
/// ```
class TaskRunDetail {
  // -------

  /// Creates a [TaskRunDetail] with all fields.
  const TaskRunDetail({
    required this.id,
    required this.taskId,
    required this.agentRoleId,
    required this.status,
    required this.prompt,
    required this.createdAt,
    this.agentRoleName,
    this.agentRoleSlug,
    this.model,
    this.sessionId,
    this.containerName,
    this.totalCostUsd,
    this.usage,
    this.durationMs,
    this.numTurns,
    this.error,
    this.aiTokenId,
    this.worktreePath,
    this.worktreeBranch,
    this.warmUntil,
    this.startedAt,
    this.completedAt,
    this.updatedAt,
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

  /// The slug of the agent role. Sourced from the nested
  /// `agent_role.slug` relation. Null if the relation is not loaded.
  final String? agentRoleSlug;

  /// Execution status (e.g. `'running'`, `'done'`, `'failed'`).
  final String status;

  /// The prompt sent to the agent for this run.
  final String prompt;

  /// LLM model identifier used for this run (e.g. `'claude-sonnet-4-6'`).
  final String? model;

  /// Session identifier returned by the agent runtime. Null until assigned.
  final String? sessionId;

  /// Docker container name for this run. Null if not yet dispatched.
  final String? containerName;

  /// Total cost of the run in USD. Null if billing has not yet been computed.
  final double? totalCostUsd;

  /// Raw token usage breakdown from the LLM provider.
  final Map<String, dynamic>? usage;

  /// Wall-clock duration in milliseconds. Null for incomplete or aborted runs.
  final int? durationMs;

  /// Number of conversational turns in the run. Null if not yet computed.
  final int? numTurns;

  /// Error message if the run failed. Null on success.
  final String? error;

  /// The AI token credential UUID used for this run.
  final String? aiTokenId;

  /// Filesystem path to the git worktree for this run.
  final String? worktreePath;

  /// Git branch name for the worktree (e.g. `'agent/task-abc'`).
  final String? worktreeBranch;

  /// ISO-8601 timestamp string until which the container stays warm.
  /// Kept as raw string to avoid timezone drift on display.
  final String? warmUntil;

  /// UTC timestamp when the run was dispatched to the agent.
  final DateTime? startedAt;

  /// UTC timestamp when the run completed or failed.
  final DateTime? completedAt;

  /// UTC timestamp when this run record was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this run record.
  final DateTime? updatedAt;

  // -------

  /// Parses a [TaskRunDetail] from a JSON-decoded map.
  ///
  /// Extracts [agentRoleName] and [agentRoleSlug] from the nested
  /// `agent_role` relation when present.
  factory TaskRunDetail.fromMap(Map<String, dynamic> map) {
    final agentRole = map['agent_role'] as Map<String, dynamic>?;

    return TaskRunDetail(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      agentRoleId: map['agent_role_id'] as String,
      agentRoleName: agentRole?['name'] as String?,
      agentRoleSlug: agentRole?['slug'] as String?,
      status: map['status'] as String,
      prompt: map['prompt'] as String,
      model: map['model'] as String?,
      sessionId: map['session_id'] as String?,
      containerName: map['container_name'] as String?,
      totalCostUsd: (map['total_cost_usd'] as num?)?.toDouble(),
      usage: map['usage'] as Map<String, dynamic>?,
      durationMs: map['duration_ms'] as int?,
      numTurns: map['num_turns'] as int?,
      error: map['error'] as String?,
      aiTokenId: map['ai_token_id'] as String?,
      worktreePath: map['worktree_path'] as String?,
      worktreeBranch: map['worktree_branch'] as String?,
      warmUntil: map['warm_until'] as String?,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  // -------

  /// Returns a copy of this [TaskRunDetail] with the specified fields replaced.
  ///
  /// All fields not provided retain their current values.
  TaskRunDetail copyWith({
    String? status,
    String? sessionId,
    String? model,
    double? totalCostUsd,
    int? durationMs,
    int? numTurns,
  }) {
    return TaskRunDetail(
      id: id,
      taskId: taskId,
      agentRoleId: agentRoleId,
      agentRoleName: agentRoleName,
      agentRoleSlug: agentRoleSlug,
      status: status ?? this.status,
      prompt: prompt,
      model: model ?? this.model,
      sessionId: sessionId ?? this.sessionId,
      containerName: containerName,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      usage: usage,
      durationMs: durationMs ?? this.durationMs,
      numTurns: numTurns ?? this.numTurns,
      error: error,
      aiTokenId: aiTokenId,
      worktreePath: worktreePath,
      worktreeBranch: worktreeBranch,
      warmUntil: warmUntil,
      startedAt: startedAt,
      completedAt: completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
