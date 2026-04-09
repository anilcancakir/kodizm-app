import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/team_balance.dart';
import '../models/usage_record.dart';

// ---------------------------------------------------------------------------
// BillingState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for team billing: balance, monthly usage summary,
/// and usage breakdown by agent role.
///
/// The primary state (`rxState`) holds the [TeamBalance] fetched via
/// [loadBalance]. Secondary state fields ([totalCostUsd], [runCount],
/// [avgCostPerRun], [usageByRole]) are populated by [loadMonthlySummary] and
/// [loadUsageByRole] respectively, with manual [refreshUI] calls.
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final billing = BillingState.instance;
///
/// // Load the current balance.
/// await billing.loadBalance('team-uuid-001');
/// final balance = billing.rxState; // TeamBalance?
///
/// // Load the monthly summary (reads meta.totals from the API).
/// await billing.loadMonthlySummary('team-uuid-001', period: '2025-03');
/// print(billing.totalCostUsd);
/// print(billing.avgCostPerRun);
///
/// // Load per-role breakdown.
/// await billing.loadUsageByRole('team-uuid-001');
/// print(billing.usageByRole); // Map<String, double>
/// ```
class BillingState extends MagicController
    with MagicStateMixin<TeamBalance>, SentryStateMixin<TeamBalance> {
  /// Creates a [BillingState].
  BillingState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static BillingState get instance => Magic.findOrPut(BillingState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  double _totalCostUsd = 0.0;
  int _runCount = 0;
  double _avgCostPerRun = 0.0;
  Map<String, double> _usageByRole = {};
  bool _isSummaryLoading = false;
  bool _isRoleLoading = false;

  /// Total cost in USD for the requested billing period, from `meta.totals`.
  double get totalCostUsd => _totalCostUsd;

  /// Number of task runs executed in the requested billing period, from `meta.total`.
  int get runCount => _runCount;

  /// Average cost per task run in USD. Zero when [runCount] is 0.
  double get avgCostPerRun => _avgCostPerRun;

  /// Usage breakdown keyed by agent role name, with summed cost in USD.
  Map<String, double> get usageByRole => _usageByRole;

  /// Whether [loadMonthlySummary] is currently in-flight.
  bool get isSummaryLoading => _isSummaryLoading;

  /// Whether [loadUsageByRole] is currently in-flight.
  bool get isRoleLoading => _isRoleLoading;

  // ---------------------------------------------------------------------------
  // Balance
  // ---------------------------------------------------------------------------

  /// Fetch the current billing balance for the given [teamId].
  ///
  /// Sets loading state, calls `GET /teams/{teamId}/balance`, then transitions
  /// to success with the parsed [TeamBalance] or to error with the API message
  /// on failure.
  Future<void> loadBalance(String teamId) async {
    setLoading();

    final response = await Http.get('/teams/$teamId/balance');

    if (response.successful) {
      final raw = response.data as Map<String, dynamic>;
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      setSuccess(TeamBalance.fromMap(data));
    } else {
      setError(response.errorMessage ?? 'Failed to fetch balance');
    }
  }

  // ---------------------------------------------------------------------------
  // Monthly summary
  // ---------------------------------------------------------------------------

  /// Fetch the monthly usage summary for the given [teamId].
  ///
  /// Calls `GET /teams/{teamId}/usage` with `per_page=1` to retrieve only the
  /// pagination meta. Reads totals from `meta.totals.total_cost_usd` and the
  /// run count from `meta.total`. Computes [avgCostPerRun] (guarded against
  /// division by zero). Calls [refreshUI] on completion.
  Future<void> loadMonthlySummary(String teamId, {String? period}) async {
    _isSummaryLoading = true;
    refreshUI();

    final Map<String, dynamic> query = {'per_page': '1'};
    if (period != null) {
      query['period'] = period;
    }

    final response = await Http.get('/teams/$teamId/usage', query: query);

    if (response.successful) {
      final raw = response.data as Map<String, dynamic>;
      final meta = raw['meta'] as Map<String, dynamic>?;
      final totals = meta?['totals'] as Map<String, dynamic>?;

      _runCount = (meta?['total'] as int?) ?? 0;
      _totalCostUsd = double.parse(
        (totals?['total_cost_usd'] as String?) ?? '0.0',
      );
      _avgCostPerRun = _runCount > 0 ? _totalCostUsd / _runCount : 0.0;
    }

    _isSummaryLoading = false;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Usage by role
  // ---------------------------------------------------------------------------

  /// Fetch usage records for the given [teamId] and group them by agent role.
  ///
  /// Calls `GET /teams/{teamId}/usage` with `per_page=100`, parses each record
  /// into a [UsageRecord], and groups them by [UsageRecord.agentRoleName],
  /// summing [UsageRecord.costUsd] per role. Stores results in [usageByRole].
  /// Calls [refreshUI] on completion.
  Future<void> loadUsageByRole(String teamId, {String? period}) async {
    _isRoleLoading = true;
    refreshUI();

    final Map<String, dynamic> query = {'per_page': '100'};
    if (period != null) {
      query['period'] = period;
    }

    final response = await Http.get('/teams/$teamId/usage', query: query);

    if (response.successful) {
      final raw = response.data as Map<String, dynamic>;
      final List<dynamic> items = (raw['data'] as List<dynamic>?) ?? [];

      final Map<String, double> grouped = {};
      for (final item in items) {
        final record = UsageRecord.fromMap(item as Map<String, dynamic>);
        final role = record.agentRoleName ?? 'Unknown';
        grouped[role] = (grouped[role] ?? 0.0) + record.costUsd;
      }

      _usageByRole = grouped;
    }

    _isRoleLoading = false;
    refreshUI();
  }
}
