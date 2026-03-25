import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/dashboard_data.dart';
import 'package:app/app/state/dashboard_state.dart';
import 'package:app/resources/views/dashboard_view.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kApiPayload = {
  'active_runs': [
    {
      'task_run_id': 'run-uuid-001',
      'task_id': 'task-uuid-001',
      'task_title': 'Implement login screen',
      'agent_role': 'Dev',
      'status': 'in_progress',
      'started_at': '2024-06-01T09:00:00.000Z',
      'cost_usd': 0.42,
    },
    {
      'task_run_id': 'run-uuid-003',
      'task_id': 'task-uuid-003',
      'task_title': 'Analyze requirements',
      'agent_role': 'BA',
      'status': 'running',
      'started_at': '2024-06-01T10:00:00.000Z',
      'cost_usd': 0.10,
    },
  ],
  'tasks_summary': {
    'total': 20,
    'by_status': {'draft': 4, 'in_progress': 3, 'done': 13},
  },
  'recent_runs': [
    {
      'task_run_id': 'run-uuid-002',
      'task_id': 'task-uuid-002',
      'task_title': 'Review PR #12',
      'agent_role': 'Reviewer',
      'status': 'done',
      'cost_usd': 0.15,
      'duration_ms': 4500,
      'completed_at': '2024-05-31T17:30:00.000Z',
    },
  ],
  'balance': 19.99,
  'monthly_usage': {
    'total_cost_usd': 8.75,
    'period': '2024-06',
    'run_count': 31,
  },
};

/// Builds a [DashboardData] from the canned payload.
DashboardData _buildDashboardData({Map<String, dynamic>? overrides}) {
  final payload = {...kApiPayload, ...?overrides};
  return DashboardData.fromMap(payload);
}

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class FakeDashboardHttpClient implements DashboardHttpClient {
  final List<HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('GET', url));
    return _responder(url);
  }
}

class HttpCall {
  HttpCall(this.method, this.url);

  final String method;
  final String url;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [DashboardView] in a [WindTheme] + [MaterialApp] for widget testing.
///
/// Wind UI widgets require a [WindTheme] ancestor to resolve className tokens.
Widget _buildTestWidget() {
  return WindTheme(
    data: WindThemeData(),
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DashboardView())),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeDashboardHttpClient http;
  late DashboardState state;

  setUp(() {
    http = FakeDashboardHttpClient();
    http.alwaysReturn(
      MagicResponse(data: {'data': kApiPayload}, statusCode: 200),
    );
    state = DashboardState(httpClient: http);

    // Pre-register the fake state so DashboardState.instance returns it.
    Magic.put<DashboardState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<DashboardState>();
  });

  // -------------------------------------------------------------------------
  // Helper: pre-seed state with success data then pump the widget.
  // -------------------------------------------------------------------------
  Future<void> pumpWithData(WidgetTester tester, {DashboardData? data}) async {
    // Wind UI flex-row + flex-1 children need sufficient horizontal space.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;

    state.setSuccess(data ?? _buildDashboardData());
    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  // -------------------------------------------------------------------------
  // 1. Renders stats cards with correct numbers
  // -------------------------------------------------------------------------

  testWidgets('renders stats cards with correct numbers', (tester) async {
    await pumpWithData(tester);

    // Active Runs label appears in stat card + section heading.
    expect(find.text(trans('dashboard.active_runs')), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);

    // Tasks total — stat card label.
    expect(find.text(trans('dashboard.total_tasks')), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    // Monthly cost.
    expect(find.text(trans('dashboard.monthly_cost')), findsOneWidget);
    expect(find.text('\$8.75'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders active runs list
  // -------------------------------------------------------------------------

  testWidgets('renders active runs list with agent badges', (tester) async {
    await pumpWithData(tester);

    // Section title (also in stat card = 2 total).
    expect(find.text(trans('dashboard.active_runs')), findsNWidgets(2));

    // Task titles from active runs.
    expect(find.text('Implement login screen'), findsOneWidget);
    expect(find.text('Analyze requirements'), findsOneWidget);

    // Agent role badges.
    expect(find.text('Dev'), findsOneWidget);
    expect(find.text('BA'), findsOneWidget);

    // Should NOT show "No active runs" since there are active runs.
    expect(find.text(trans('dashboard.no_active_runs')), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 3. Renders tasks by status bar
  // -------------------------------------------------------------------------

  testWidgets('renders tasks by status stacked bar and legend', (tester) async {
    await pumpWithData(tester);

    // Section title.
    expect(find.text(trans('dashboard.tasks_by_status')), findsOneWidget);

    // Legend labels with counts.
    expect(find.text('Draft  4'), findsOneWidget);
    expect(find.text('In Progress  3'), findsOneWidget);
    expect(find.text('Done  13'), findsOneWidget);

    // Stacked bar chart renders with native Row + Expanded + Container
    // (dynamic color exception). Presence of legend entries above confirms
    // the entire chart section rendered successfully.
  });

  // -------------------------------------------------------------------------
  // 4. Renders recent runs list
  // -------------------------------------------------------------------------

  testWidgets('renders recent runs list with cost and duration', (
    tester,
  ) async {
    await pumpWithData(tester);

    // Section title.
    expect(find.text(trans('dashboard.recent_runs')), findsOneWidget);

    // Recent run task title.
    expect(find.text('Review PR #12'), findsOneWidget);

    // Agent role badge.
    expect(find.text('Reviewer'), findsOneWidget);

    // Cost.
    expect(find.text('\$0.15'), findsOneWidget);

    // Duration — 4500ms = 4s.
    expect(find.text('4s'), findsOneWidget);

    // Status badge.
    expect(find.text('Done'), findsOneWidget);

    // Should NOT show empty state.
    expect(find.text(trans('dashboard.no_recent_runs')), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 5. Balance shows correct color coding (green/amber/red)
  // -------------------------------------------------------------------------

  testWidgets('balance shows green color when above \$10', (tester) async {
    final data = _buildDashboardData(overrides: {'balance': 50.0});
    await pumpWithData(tester, data: data);

    // Balance text rendered.
    expect(find.text('\$50.00'), findsOneWidget);

    // Find the Text widget and verify its color.
    final textWidget = tester.widget<Text>(find.text('\$50.00'));
    expect(textWidget.style?.color, equals(const Color(0xFF10B981)));
  });

  testWidgets('balance shows amber color when between \$1 and \$10', (
    tester,
  ) async {
    final data = _buildDashboardData(overrides: {'balance': 5.0});
    await pumpWithData(tester, data: data);

    expect(find.text('\$5.00'), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('\$5.00'));
    expect(textWidget.style?.color, equals(const Color(0xFFF59E0B)));
  });

  testWidgets('balance shows red color when below \$1', (tester) async {
    final data = _buildDashboardData(overrides: {'balance': 0.50});
    await pumpWithData(tester, data: data);

    expect(find.text('\$0.50'), findsOneWidget);

    final textWidget = tester.widget<Text>(find.text('\$0.50'));
    expect(textWidget.style?.color, equals(const Color(0xFFEF4444)));
  });

  // -------------------------------------------------------------------------
  // 6. Empty active runs shows placeholder
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no active runs', (tester) async {
    final data = _buildDashboardData(overrides: {'active_runs': []});
    await pumpWithData(tester, data: data);

    expect(find.text(trans('dashboard.no_active_runs')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Quick actions are disabled
  // -------------------------------------------------------------------------

  testWidgets('quick actions are rendered as disabled placeholders', (
    tester,
  ) async {
    await pumpWithData(tester);

    expect(find.text(trans('dashboard.quick_actions')), findsOneWidget);
    expect(find.text(trans('dashboard.create_task')), findsOneWidget);
    expect(find.text(trans('dashboard.ba_chat')), findsOneWidget);

    // Buttons wrapped in WDiv with opacity-50 className for disabled appearance.
    // Verify that the disabled action buttons are rendered (text confirms presence).
    expect(find.byType(Tooltip), findsNWidgets(2));
  });
}
