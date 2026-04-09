import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/dashboard_data.dart';

// ---------------------------------------------------------------------------
// DashboardState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the team dashboard.
///
/// Fetches the aggregated dashboard snapshot for a team from
/// `GET /teams/{teamId}/dashboard` and exposes it via [MagicStateMixin].
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final dashboard = DashboardState.instance;
///
/// // Trigger a fetch — typically called from onInit or a view lifecycle.
/// await dashboard.fetchDashboard('team-uuid-001');
///
/// // React to state in a widget.
/// dashboard.renderState(
///   (data) => DashboardView(data: data),
///   onLoading: const LoadingSpinner(),
///   onError: (msg) => ErrorBanner(message: msg),
/// );
/// ```
class DashboardState extends MagicController
    with MagicStateMixin<DashboardData>, SentryStateMixin<DashboardData> {
  /// Creates a [DashboardState].
  DashboardState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static DashboardState get instance => Magic.findOrPut(DashboardState.new);

  // ---------------------------------------------------------------------------
  // Dashboard fetch
  // ---------------------------------------------------------------------------

  /// Fetch the dashboard snapshot for the given [teamId].
  ///
  /// Sets loading state, calls `GET /teams/{teamId}/dashboard`, then
  /// transitions to success with the parsed [DashboardData] or to error
  /// with the API message on failure.
  Future<void> fetchDashboard(String teamId) async {
    setLoading();

    final response = await Http.get('/teams/$teamId/dashboard');

    if (response.successful) {
      final raw = response.data as Map<String, dynamic>;
      // Support both `{ "data": { ... } }` (Laravel resource envelope)
      // and `{ ... }` (direct response) shapes.
      final data = raw.containsKey('data') && raw['data'] is Map
          ? raw['data'] as Map<String, dynamic>
          : raw;
      setSuccess(DashboardData.fromMap(data));
    } else {
      setError(response.errorMessage ?? 'Failed to fetch dashboard');
    }
  }
}
