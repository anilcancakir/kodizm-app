import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/billing_state.dart';
import 'package:app/resources/views/billing/billing_view.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kBalanceResponse = {
  'data': {'balance': '25.50', 'currency': 'USD', 'max_concurrent_runs': 3},
};

const Map<String, dynamic> kMonthlySummaryResponse = {
  'data': <dynamic>[],
  'meta': {
    'total': 12,
    'totals': {'total_cost_usd': '8.4200'},
  },
};

const Map<String, dynamic> kUsageByRoleResponse = {
  'data': [
    {
      'id': 'usage-001',
      'team_id': 'team-uuid-001',
      'conversation_id': 'run-001',
      'model': 'claude-3-5-sonnet',
      'input_tokens': 1000,
      'output_tokens': 500,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '2.5000',
      'period': '2026-03',
      'recorded_at': '2026-03-10T08:00:00.000Z',
      'conversation': {
        'agent_role_name': 'Dev',
        'task': {'title': 'Implement login', 'project_id': 'proj-001'},
      },
    },
    {
      'id': 'usage-002',
      'team_id': 'team-uuid-001',
      'conversation_id': 'run-002',
      'model': 'claude-3-5-sonnet',
      'input_tokens': 800,
      'output_tokens': 400,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '1.2000',
      'period': '2026-03',
      'recorded_at': '2026-03-10T09:00:00.000Z',
      'conversation': {
        'agent_role_name': 'QA',
        'task': {'title': 'Test login', 'project_id': 'proj-001'},
      },
    },
  ],
};

const Map<String, dynamic> kEmptyBalanceResponse = {'data': <dynamic>[]};

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final String content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final Map<String, dynamic> nested =
          jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = {};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [BillingView] inside the standard test scaffold.
Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: BillingView())),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late FakeNetworkDriver driver;
  late BillingState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response({}, 404));

    state = BillingState();
    Magic.put<BillingState>(state);
  });

  /// Configures standard billing stubs.
  void stubBillingResponses() {
    driver.stub('*/balance*', Http.response(kBalanceResponse));
    driver.stub('*/usage*', Http.response(kUsageByRoleResponse));
  }

  /// Loads all billing data into state.
  Future<void> loadBillingData() async {
    await state.loadBalance('team-uuid-001');
    await state.loadMonthlySummary('team-uuid-001');
    await state.loadUsageByRole('team-uuid-001');
  }

  // -------------------------------------------------------------------------
  // 1. Renders MagicStarterPageHeader with billing.title text
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    stubBillingResponses();
    // Monthly summary needs its own stub with per_page=1 query.
    // Since stub matches on URL pattern only, we re-stub usage for summary.
    driver.stub('*/usage*', Http.response(kMonthlySummaryResponse));
    driver.stub('*/usage*', Http.response(kUsageByRoleResponse));

    await loadBillingData();

    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    expect(find.textContaining('Billing'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 2. Displays balance with correct color class (emerald for > 10)
  // -------------------------------------------------------------------------

  testWidgets('displays balance with correct color class', (tester) async {
    stubBillingResponses();
    driver.stub('*/usage*', Http.response(kMonthlySummaryResponse));
    driver.stub('*/usage*', Http.response(kUsageByRoleResponse));

    await loadBillingData();

    await _pumpView(tester);

    // Balance is 25.50 (> 10) → should show emerald color.
    expect(find.textContaining('\$25.50'), findsOneWidget);

    // Verify a WText with emerald class wraps the balance.
    final balanceTexts = tester.widgetList<WText>(find.byType(WText));
    final emeraldBalance = balanceTexts.where(
      (w) =>
          w.data.contains('\$25.50') &&
          w.className?.contains('text-emerald-500') == true,
    );
    expect(emeraldBalance, isNotEmpty);
  });

  // -------------------------------------------------------------------------
  // 3. Displays monthly summary stats
  // -------------------------------------------------------------------------

  testWidgets('displays monthly summary stats', (tester) async {
    stubBillingResponses();
    // Monthly summary and usage-by-role share /usage — stub once with
    // the monthly-summary shape so loadMonthlySummary parses meta.totals.
    driver.stub('*/usage*', Http.response(kMonthlySummaryResponse));

    await state.loadBalance('team-uuid-001');
    await state.loadMonthlySummary('team-uuid-001');

    await _pumpView(tester);

    // Total spent: $8.42
    expect(find.textContaining('\$8.42'), findsOneWidget);
    // Run count: 12
    expect(find.textContaining('12'), findsWidgets);
    // Avg cost/run: $0.7017 (8.42 / 12)
    expect(find.textContaining('\$0.70'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Displays usage by role section
  // -------------------------------------------------------------------------

  testWidgets('displays usage by role section', (tester) async {
    stubBillingResponses();
    driver.stub('*/usage*', Http.response(kMonthlySummaryResponse));
    driver.stub('*/usage*', Http.response(kUsageByRoleResponse));

    await loadBillingData();

    await _pumpView(tester);

    // Agent role names should be visible.
    expect(find.textContaining('Dev'), findsWidgets);
    expect(find.textContaining('QA'), findsWidgets);

    // Section title from trans('billing.usage_by_role').
    expect(find.textContaining('Usage by Agent Role'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Shows loading state
  // -------------------------------------------------------------------------

  testWidgets('shows loading state', (tester) async {
    // Manually set loading state before pumping.
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: BillingView())),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Shows empty state when no balance data
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no balance data', (tester) async {
    // Set empty state manually.
    state.setEmpty();

    await _pumpView(tester);

    // trans('billing.empty') = 'No billing data available'
    expect(find.textContaining('No billing data available'), findsOneWidget);
  });
}
