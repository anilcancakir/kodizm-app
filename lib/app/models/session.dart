import 'project_container.dart';
import 'session_share.dart';
import 'session_usage_record.dart';

/// An AI agent execution session managed by the Kodizm Claude Code CLI.
///
/// Maps directly to `SessionResource` from the Kodizm API. A session
/// represents one lifecycle of a container (provision → execute → warm → dead),
/// aggregating token usage and cost across all turns.
///
/// ## Usage
/// ```dart
/// final session = Session.fromMap(json['session']);
/// print('${session.type} — ${session.phase}: \$${session.totalCostUsd}');
/// final warmed = session.copyWith(phase: 'warm');
/// ```
class Session {
  // -------

  /// Creates a [Session] with all fields.
  const Session({
    required this.id,
    required this.type,
    required this.phase,
    required this.totalCostUsd,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.totalCacheReadTokens,
    required this.totalCacheCreationTokens,
    required this.createdAt,
    required this.updatedAt,
    required this.usageRecords,
    required this.shares,
    this.model,
    this.warmUntil,
    this.startedAt,
    this.completedAt,
    this.executionMode,
    this.containerName,
    this.workspacePath,
    this.workspaceBranch,
    this.projectContainer,
  });

  // -------

  /// The unique identifier of this session (UUID).
  final String id;

  /// The session type — `'autonomous'`, `'interactive'`, or `'system'`.
  final String type;

  /// The current lifecycle phase — `'provisioning'`, `'executing'`,
  /// `'warm'`, or `'dead'`.
  final String phase;

  /// The AI model assigned to this session (e.g. `'claude-sonnet-4-6'`).
  /// Null when no model has been assigned yet.
  final String? model;

  /// Cumulative cost of all turns in this session in USD, parsed from
  /// the API decimal string representation.
  final double totalCostUsd;

  /// Total input (prompt) tokens consumed across all turns.
  final int totalInputTokens;

  /// Total output (completion) tokens generated across all turns.
  final int totalOutputTokens;

  /// Total tokens read from the prompt cache across all turns.
  final int totalCacheReadTokens;

  /// Total tokens written to the prompt cache across all turns.
  final int totalCacheCreationTokens;

  /// UTC timestamp until which the container is kept warm after execution.
  /// Non-null only when [phase] is `'warm'`.
  final DateTime? warmUntil;

  /// UTC timestamp when the session was dispatched to the container.
  /// Null while still provisioning.
  final DateTime? startedAt;

  /// UTC timestamp when the session reached a terminal phase.
  /// Null while still active.
  final DateTime? completedAt;

  /// UTC timestamp when this session record was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this session record.
  final DateTime updatedAt;

  /// Per-turn token usage records. Empty list when the `usage_records`
  /// relation is not loaded.
  final List<SessionUsageRecord> usageRecords;

  /// Share grants exposing this session to other resources. Empty list when
  /// the `shares` relation is not loaded.
  final List<SessionShare> shares;

  // -------

  /// The execution mode for this session — `'native'` (CLI) or legacy.
  /// Null for legacy sessions created before the native CLI architecture.
  final String? executionMode;

  /// The Docker container name associated with this session
  /// (e.g. `'kodizm-proj-abc123'`). Null when not running in a container.
  final String? containerName;

  /// The absolute filesystem path to the git workspace used for this session
  /// (e.g. `'/workspace/feature-branch'`). Null when no workspace is active.
  final String? workspacePath;

  /// The git branch checked out in the workspace for this session
  /// (e.g. `'feature/auth-refactor'`). Null when no workspace is active.
  final String? workspaceBranch;

  /// The [ProjectContainer] associated with this session, loaded via the
  /// `project_container` relation. Null when the relation is not loaded or
  /// no container has been provisioned.
  final ProjectContainer? projectContainer;

  // -------

  /// Parses a [Session] from a JSON-decoded map.
  ///
  /// [totalCostUsd] is parsed via [double.tryParse] because the API returns it as
  /// a decimal string (e.g. `"0.012600"`). Nested [usageRecords] and [shares]
  /// default to empty lists when the keys are absent.
  factory Session.fromMap(Map<String, dynamic> map) {
    final rawUsageRecords = map['usage_records'] as List<dynamic>?;
    final rawShares = map['shares'] as List<dynamic>?;

    return Session(
      id: map['id'] as String,
      type: map['type'] as String,
      phase: map['phase'] as String,
      model: map['model'] as String?,
      totalCostUsd:
          double.tryParse(map['total_cost_usd']?.toString() ?? '') ?? 0.0,
      totalInputTokens: map['total_input_tokens'] as int,
      totalOutputTokens: map['total_output_tokens'] as int,
      totalCacheReadTokens: map['total_cache_read_tokens'] as int,
      totalCacheCreationTokens: map['total_cache_creation_tokens'] as int,
      warmUntil: map['warm_until'] != null
          ? DateTime.parse(map['warm_until'] as String)
          : null,
      startedAt: map['started_at'] != null
          ? DateTime.parse(map['started_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      executionMode: map['execution_mode'] as String?,
      containerName: map['container_name'] as String?,
      workspacePath: map['workspace_path'] as String?,
      workspaceBranch: map['workspace_branch'] as String?,
      projectContainer: map['project_container'] != null
          ? ProjectContainer.fromMap(
              map['project_container'] as Map<String, dynamic>,
            )
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      usageRecords: rawUsageRecords != null
          ? rawUsageRecords
                .map(
                  (e) => SessionUsageRecord.fromMap(e as Map<String, dynamic>),
                )
                .toList()
          : const [],
      shares: rawShares != null
          ? rawShares
                .map((e) => SessionShare.fromMap(e as Map<String, dynamic>))
                .toList()
          : const [],
    );
  }

  // -------

  /// Returns a copy of this [Session] with the specified fields replaced.
  ///
  /// All fields not provided retain their current values.
  Session copyWith({
    String? phase,
    String? model,
    double? totalCostUsd,
    int? totalInputTokens,
    int? totalOutputTokens,
    int? totalCacheReadTokens,
    int? totalCacheCreationTokens,
    DateTime? warmUntil,
    bool clearWarmUntil = false,
    DateTime? completedAt,
    List<SessionUsageRecord>? usageRecords,
    List<SessionShare>? shares,
    String? executionMode,
    String? containerName,
    String? workspacePath,
    String? workspaceBranch,
    ProjectContainer? projectContainer,
    bool clearProjectContainer = false,
  }) {
    return Session(
      id: id,
      type: type,
      phase: phase ?? this.phase,
      model: model ?? this.model,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      totalInputTokens: totalInputTokens ?? this.totalInputTokens,
      totalOutputTokens: totalOutputTokens ?? this.totalOutputTokens,
      totalCacheReadTokens: totalCacheReadTokens ?? this.totalCacheReadTokens,
      totalCacheCreationTokens:
          totalCacheCreationTokens ?? this.totalCacheCreationTokens,
      warmUntil: clearWarmUntil ? null : (warmUntil ?? this.warmUntil),
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      usageRecords: usageRecords ?? this.usageRecords,
      shares: shares ?? this.shares,
      executionMode: executionMode ?? this.executionMode,
      containerName: containerName ?? this.containerName,
      workspacePath: workspacePath ?? this.workspacePath,
      workspaceBranch: workspaceBranch ?? this.workspaceBranch,
      projectContainer: clearProjectContainer
          ? null
          : (projectContainer ?? this.projectContainer),
    );
  }
}
