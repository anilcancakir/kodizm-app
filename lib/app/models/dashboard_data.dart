/// A task run that is currently active (running or queued).
///
/// ## Usage
/// ```dart
/// final run = ActiveRun.fromMap(json['active_runs'][0]);
/// print(run.taskTitle); // 'Implement login'
/// ```
class ActiveRun {
  // -------

  /// Creates an [ActiveRun] with all fields.
  const ActiveRun({
    required this.taskRunId,
    required this.taskId,
    required this.taskTitle,
    required this.agentRole,
    required this.status,
    required this.startedAt,
    this.costUsd,
  });

  // -------

  /// The unique identifier of the task run (UUID).
  final String taskRunId;

  /// The identifier of the parent task (UUID).
  final String taskId;

  /// Human-readable title of the task.
  final String taskTitle;

  /// The agent role executing this run (e.g. `'Dev'`, `'QA'`, `'Lead'`).
  final String agentRole;

  /// Current execution status (e.g. `'in_progress'`, `'running'`).
  final String status;

  /// UTC timestamp when this run started.
  final DateTime startedAt;

  /// Accumulated cost in USD so far. Nullable if billing is not yet computed.
  final double? costUsd;

  // -------

  /// Parses an [ActiveRun] from a JSON-decoded map.
  factory ActiveRun.fromMap(Map<String, dynamic> map) {
    return ActiveRun(
      taskRunId: map['task_run_id'] as String,
      taskId: map['task_id'] as String,
      taskTitle: map['task_title'] as String,
      agentRole: map['agent_role'] as String,
      status: map['status'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      costUsd: (map['cost_usd'] as num?)?.toDouble(),
    );
  }
}

// ---------------------------------------------------------------------------
// TasksSummary
// ---------------------------------------------------------------------------

/// Aggregated task counts for the current team.
///
/// ## Usage
/// ```dart
/// final summary = TasksSummary.fromMap(json['tasks_summary']);
/// print(summary.total);               // 42
/// print(summary.byStatus['done']);    // 25
/// ```
class TasksSummary {
  // -------

  /// Creates a [TasksSummary] with all fields.
  const TasksSummary({required this.total, required this.byStatus});

  // -------

  /// Total number of tasks regardless of status.
  final int total;

  /// Task counts keyed by status slug (e.g. `'draft'`, `'in_progress'`, `'done'`).
  final Map<String, int> byStatus;

  // -------

  /// Parses a [TasksSummary] from a JSON-decoded map.
  factory TasksSummary.fromMap(Map<String, dynamic> map) {
    final rawByStatus = map['by_status'] as Map<String, dynamic>;
    return TasksSummary(
      total: map['total'] as int,
      byStatus: rawByStatus.map((key, value) => MapEntry(key, value as int)),
    );
  }
}

// ---------------------------------------------------------------------------
// RecentRun
// ---------------------------------------------------------------------------

/// A completed (or failed) task run from recent history.
///
/// ## Usage
/// ```dart
/// final run = RecentRun.fromMap(json['recent_runs'][0]);
/// print(run.durationMs); // 4500
/// ```
class RecentRun {
  // -------

  /// Creates a [RecentRun] with all fields.
  const RecentRun({
    required this.taskRunId,
    required this.taskId,
    required this.taskTitle,
    required this.agentRole,
    required this.status,
    required this.costUsd,
    this.durationMs,
    this.completedAt,
  });

  // -------

  /// The unique identifier of the task run (UUID).
  final String taskRunId;

  /// The identifier of the parent task (UUID).
  final String taskId;

  /// Human-readable title of the task.
  final String taskTitle;

  /// The agent role that executed this run (e.g. `'Reviewer'`, `'QA'`).
  final String agentRole;

  /// Final execution status (e.g. `'done'`, `'failed'`).
  final String status;

  /// Total cost of the run in USD.
  final double costUsd;

  /// Wall-clock duration in milliseconds. Nullable for aborted runs.
  final int? durationMs;

  /// UTC timestamp when this run completed or failed. Nullable if not yet finalised.
  final DateTime? completedAt;

  // -------

  /// Parses a [RecentRun] from a JSON-decoded map.
  factory RecentRun.fromMap(Map<String, dynamic> map) {
    return RecentRun(
      taskRunId: map['task_run_id'] as String,
      taskId: map['task_id'] as String,
      taskTitle: map['task_title'] as String,
      agentRole: map['agent_role'] as String,
      status: map['status'] as String,
      costUsd: (map['cost_usd'] as num).toDouble(),
      durationMs: map['duration_ms'] as int?,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// MonthlyUsage
// ---------------------------------------------------------------------------

/// Aggregated billing usage for a calendar month.
///
/// ## Usage
/// ```dart
/// final usage = MonthlyUsage.fromMap(json['monthly_usage']);
/// print('${usage.period}: \$${usage.totalCostUsd}');
/// ```
class MonthlyUsage {
  // -------

  /// Creates a [MonthlyUsage] with all fields.
  const MonthlyUsage({
    required this.totalCostUsd,
    required this.period,
    required this.runCount,
  });

  // -------

  /// Total spend in USD for the billing period.
  final double totalCostUsd;

  /// ISO-8601 year-month string identifying the billing period (e.g. `'2024-01'`).
  final String period;

  /// Number of task runs executed during the period.
  final int runCount;

  // -------

  /// Parses a [MonthlyUsage] from a JSON-decoded map.
  factory MonthlyUsage.fromMap(Map<String, dynamic> map) {
    return MonthlyUsage(
      totalCostUsd: (map['total_cost_usd'] as num).toDouble(),
      period: map['period'] as String,
      runCount: map['run_count'] as int,
    );
  }
}

// ---------------------------------------------------------------------------
// DashboardData
// ---------------------------------------------------------------------------

/// Root payload returned by the `/api/dashboard` endpoint.
///
/// Aggregates active runs, task summary, recent history, account balance
/// and monthly billing usage into a single read-only snapshot.
///
/// ## Usage
/// ```dart
/// final response = await Http.get('/api/dashboard');
/// final dashboard = DashboardData.fromMap(
///   response.data as Map<String, dynamic>,
/// );
/// ```
class DashboardData {
  // -------

  /// Creates a [DashboardData] snapshot with all fields.
  const DashboardData({
    required this.activeRuns,
    required this.tasksSummary,
    required this.recentRuns,
    required this.balance,
    required this.monthlyUsage,
  });

  // -------

  /// Task runs that are currently executing or queued.
  final List<ActiveRun> activeRuns;

  /// Aggregated task counts across all statuses.
  final TasksSummary tasksSummary;

  /// Recently completed or failed task runs.
  final List<RecentRun> recentRuns;

  /// Current account balance in USD.
  final double balance;

  /// Billing usage summary for the current calendar month.
  final MonthlyUsage monthlyUsage;

  // -------

  /// Parses a [DashboardData] from the real API response.
  ///
  /// Handles two shapes:
  /// - **Spec shape**: `active_runs: [...]`, `tasks_summary`, `recent_runs`, `monthly_usage`
  /// - **Real API shape**: `active_runs: 0`, `tasks_by_status`, `costs_this_month`, `runs_this_month`
  factory DashboardData.fromMap(Map<String, dynamic> map) {
    // active_runs — array of run objects OR int count.
    final rawActiveRuns = map['active_runs'];
    final activeRuns = rawActiveRuns is List
        ? rawActiveRuns
              .map((e) => ActiveRun.fromMap(e as Map<String, dynamic>))
              .toList()
        : const <ActiveRun>[];

    // tasks summary — spec uses 'tasks_summary', real API uses 'tasks_by_status'.
    final TasksSummary tasksSummary;
    if (map['tasks_summary'] is Map) {
      tasksSummary = TasksSummary.fromMap(
        map['tasks_summary'] as Map<String, dynamic>,
      );
    } else if (map['tasks_by_status'] is Map) {
      final byStatus = (map['tasks_by_status'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
      final total = byStatus.values.fold(0, (sum, count) => sum + count);
      tasksSummary = TasksSummary(total: total, byStatus: byStatus);
    } else {
      tasksSummary = const TasksSummary(total: 0, byStatus: {});
    }

    // recent_runs — array or absent.
    final rawRecentRuns = map['recent_runs'];
    final recentRuns = rawRecentRuns is List
        ? rawRecentRuns
              .map((e) => RecentRun.fromMap(e as Map<String, dynamic>))
              .toList()
        : const <RecentRun>[];

    // balance — can be num or string.
    final rawBalance = map['balance'];
    final balance = rawBalance is num
        ? rawBalance.toDouble()
        : double.tryParse(rawBalance?.toString() ?? '') ?? 0.0;

    // monthly usage — spec uses 'monthly_usage', real API uses
    // 'costs_this_month' + 'runs_this_month'.
    final MonthlyUsage monthlyUsage;
    if (map['monthly_usage'] is Map) {
      monthlyUsage = MonthlyUsage.fromMap(
        map['monthly_usage'] as Map<String, dynamic>,
      );
    } else if (map['costs_this_month'] is Map) {
      final costs = map['costs_this_month'] as Map<String, dynamic>;
      final totalUsd = costs['total_usd'];
      monthlyUsage = MonthlyUsage(
        totalCostUsd: totalUsd is num
            ? totalUsd.toDouble()
            : double.tryParse(totalUsd?.toString() ?? '') ?? 0.0,
        period: costs['period'] as String? ?? _currentPeriod(),
        runCount: (map['runs_this_month'] as num?)?.toInt() ?? 0,
      );
    } else {
      monthlyUsage = MonthlyUsage(
        totalCostUsd: 0.0,
        period: _currentPeriod(),
        runCount: (map['runs_this_month'] as num?)?.toInt() ?? 0,
      );
    }

    return DashboardData(
      activeRuns: activeRuns,
      tasksSummary: tasksSummary,
      recentRuns: recentRuns,
      balance: balance,
      monthlyUsage: monthlyUsage,
    );
  }

  /// Returns the current year-month string (e.g. `'2025-03'`).
  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}
