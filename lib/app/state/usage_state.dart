import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/usage_record.dart';

// ---------------------------------------------------------------------------
// UsageState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for paginated AI token usage history.
///
/// Fetches the usage records for a team from `GET /teams/{teamId}/usage`,
/// supports filter parameters (period, projectId, agentRole), pagination via
/// [loadMore], and exposes aggregated totals from `meta.totals`.
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final usage = UsageState.instance;
///
/// // Load the first page with optional filters.
/// await usage.loadUsage(
///   'team-uuid-001',
///   period: '2025-03',
///   agentRole: 'Dev',
/// );
///
/// // Append the next page.
/// if (usage.hasMore) await usage.loadMore();
///
/// // Read aggregated cost.
/// print(usage.totalCostUsd);
/// ```
class UsageState extends MagicController
    with
        MagicStateMixin<List<UsageRecord>>,
        SentryStateMixin<List<UsageRecord>> {
  /// Creates a [UsageState].
  UsageState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static UsageState get instance => Magic.findOrPut(UsageState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  List<UsageRecord> _records = [];
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalRecords = 0;
  double _totalCostUsd = 0.0;
  String? _filterPeriod;
  String? _filterProjectId;
  String? _filterAgentRole;
  String? _teamId;

  /// The current page(s) of usage records.
  List<UsageRecord> get records => _records;

  /// The current page number from the last API response.
  int get currentPage => _currentPage;

  /// The last available page number from the last API response.
  int get lastPage => _lastPage;

  /// The total number of records across all pages.
  int get totalRecords => _totalRecords;

  /// The total cost in USD from `meta.totals.total_cost_usd`.
  double get totalCostUsd => _totalCostUsd;

  /// The active period filter value (e.g. `'2025-03'`).
  String? get filterPeriod => _filterPeriod;

  /// The active project ID filter value.
  String? get filterProjectId => _filterProjectId;

  /// The active agent role filter value (e.g. `'Dev'`).
  String? get filterAgentRole => _filterAgentRole;

  /// Whether more pages are available to load.
  bool get hasMore => _currentPage < _lastPage;

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  /// Set one or more filter values without triggering a reload.
  ///
  /// Pass `null` to a parameter to leave that filter unchanged.
  void setFilter({String? period, String? projectId, String? agentRole}) {
    if (period != null) _filterPeriod = period;
    if (projectId != null) _filterProjectId = projectId;
    if (agentRole != null) _filterAgentRole = agentRole;
  }

  /// Clear all active filters.
  ///
  /// Does NOT trigger an automatic reload — call [loadUsage] afterwards if
  /// needed.
  void clearFilters() {
    _filterPeriod = null;
    _filterProjectId = null;
    _filterAgentRole = null;
  }

  // ---------------------------------------------------------------------------
  // Load operations
  // ---------------------------------------------------------------------------

  /// Load the first page of usage records for [teamId].
  ///
  /// Optional filter parameters:
  /// - [period] — billing period slug (e.g. `'2025-03'`)
  /// - [projectId] — UUID of the project to filter by
  /// - [agentRole] — agent role name slug (e.g. `'Dev'`)
  ///
  /// Resets the record list and pagination state before fetching.
  /// Stores filter values for reuse by [loadMore].
  Future<void> loadUsage(
    String teamId, {
    String? period,
    String? projectId,
    String? agentRole,
  }) async {
    _teamId = teamId;
    _filterPeriod = period;
    _filterProjectId = projectId;
    _filterAgentRole = agentRole;
    _records = [];

    setLoading();

    final query = <String, dynamic>{};
    if (period != null) query['period'] = period;
    if (projectId != null) query['project_id'] = projectId;
    if (agentRole != null) query['agent_role'] = agentRole;

    final response = await Http.get(
      '/teams/$teamId/usage',
      query: query.isEmpty ? null : query,
    );

    if (response.successful) {
      _applyResponse(response, append: false);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch usage');
    }
  }

  /// Append the next page of records to [records].
  ///
  /// No-ops silently when [hasMore] is `false`. Reuses the stored [_teamId]
  /// and active filter values from the previous [loadUsage] call.
  Future<void> loadMore() async {
    if (!hasMore || _teamId == null) return;

    final nextPage = _currentPage + 1;

    final query = <String, dynamic>{'page': nextPage.toString()};
    if (_filterPeriod != null) query['period'] = _filterPeriod!;
    if (_filterProjectId != null) query['project_id'] = _filterProjectId!;
    if (_filterAgentRole != null) query['agent_role'] = _filterAgentRole!;

    final response = await Http.get('/teams/$_teamId/usage', query: query);

    if (response.successful) {
      _applyResponse(response, append: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Parse a successful paginated response and update state.
  ///
  /// When [append] is `true`, new records are appended to [_records].
  /// When `false`, [_records] is replaced.
  void _applyResponse(MagicResponse response, {required bool append}) {
    final raw = response.data as Map<String, dynamic>;
    final meta = raw['meta'] as Map<String, dynamic>?;
    final totals = meta?['totals'] as Map<String, dynamic>?;

    _currentPage = (meta?['current_page'] as int?) ?? 1;
    _lastPage = (meta?['last_page'] as int?) ?? 1;
    _totalRecords = (meta?['total'] as int?) ?? 0;
    _totalCostUsd =
        double.tryParse((totals?['total_cost_usd'] as String?) ?? '0') ?? 0.0;

    final items = raw['data'] as List<dynamic>;
    final parsed = items
        .map((item) => UsageRecord.fromMap(item as Map<String, dynamic>))
        .toList();

    if (append) {
      _records = [..._records, ...parsed];
    } else {
      _records = parsed;
    }

    _records.isEmpty ? setEmpty() : setSuccess(_records);
  }
}
