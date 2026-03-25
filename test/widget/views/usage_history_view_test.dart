import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/usage_state.dart';
import 'package:app/resources/views/billing/usage_history_view.dart';
import 'package:app/resources/widgets/molecules/page_header.dart';
import 'package:app/resources/widgets/molecules/section_card.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kUsageResponse = {
  'data': [
    {
      'id': 'usage-001',
      'team_id': 'team-001',
      'task_run_id': 'run-001',
      'model': 'claude-3-5-sonnet',
      'input_tokens': 1500,
      'output_tokens': 300,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '0.00420',
      'period': '2025-03',
      'recorded_at': '2025-03-15T10:00:00.000Z',
      'task_run': {
        'agent_role_name': 'Dev',
        'task': {'title': 'Implement login', 'project_id': 'proj-001'},
      },
    },
  ],
  'meta': {
    'current_page': 1,
    'last_page': 2,
    'total': 15,
    'totals': {
      'total_cost_usd': '12.50',
      'total_input_tokens': 150000,
      'total_output_tokens': 30000,
    },
  },
};

const Map<String, dynamic> kUsageResponseEmpty = {
  'data': <dynamic>[],
  'meta': {
    'current_page': 1,
    'last_page': 1,
    'total': 0,
    'totals': {
      'total_cost_usd': '0.00',
      'total_input_tokens': 0,
      'total_output_tokens': 0,
    },
  },
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeUsageHttpClient implements UsageHttpClient {
  final List<String> calls = [];
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
    calls.add('GET $url');
    return _responder(url);
  }
}

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
// Helper — pump UsageHistoryView in standard test scaffold
// ---------------------------------------------------------------------------

Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: UsageHistoryView())),
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
  late _FakeUsageHttpClient http;
  late UsageState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeUsageHttpClient();
    state = UsageState(httpClient: http);
    Magic.put<UsageState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<UsageState>();
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed
  // -------------------------------------------------------------------------

  testWidgets('widget constructor creates UsageHistoryView', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: kUsageResponseEmpty, statusCode: 200),
    );

    await _pumpView(tester);

    expect(find.byType(UsageHistoryView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders PageHeader with usage.title
  // -------------------------------------------------------------------------

  testWidgets('renders PageHeader with title', (tester) async {
    http.alwaysReturn(MagicResponse(data: kUsageResponse, statusCode: 200));

    await state.loadUsage('team-001');
    await _pumpView(tester);

    expect(find.byType(PageHeader), findsOneWidget);
    // trans('usage.title') = 'Usage History'
    expect(find.textContaining('Usage History'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state while usage is loading', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: kUsageResponseEmpty, statusCode: 200),
    );

    // Manually set loading state before pumping.
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: UsageHistoryView()),
          ),
        ),
      ),
    );
    // Use pump() — animation never settles while loading.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Shows empty state when no records exist
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no usage records exist', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: kUsageResponseEmpty, statusCode: 200),
    );

    await state.loadUsage('team-001');
    await _pumpView(tester);

    // trans('usage.empty_title') = 'No Usage Records'
    expect(find.textContaining('No Usage Records'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders record rows with model name and cost
  // -------------------------------------------------------------------------

  testWidgets('renders record rows with model name and cost', (tester) async {
    http.alwaysReturn(MagicResponse(data: kUsageResponse, statusCode: 200));

    await state.loadUsage('team-001');
    await _pumpView(tester);

    // Model name visible.
    expect(find.textContaining('claude-3-5-sonnet'), findsOneWidget);
    // Cost formatted to 4 decimal places.
    expect(find.textContaining('0.0042'), findsOneWidget);
    // SectionCard wrapping the list.
    expect(find.byType(SectionCard), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 6. Displays total cost from meta.totals
  // -------------------------------------------------------------------------

  testWidgets('displays total cost from meta.totals', (tester) async {
    http.alwaysReturn(MagicResponse(data: kUsageResponse, statusCode: 200));

    await state.loadUsage('team-001');
    await _pumpView(tester);

    // totalCostUsd = 12.50 → displayed as '$12.50'
    expect(find.textContaining('12.50'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Agent role badge text is visible for record
  // -------------------------------------------------------------------------

  testWidgets('renders agent role badge for record', (tester) async {
    http.alwaysReturn(MagicResponse(data: kUsageResponse, statusCode: 200));

    await state.loadUsage('team-001');
    await _pumpView(tester);

    // agentRoleName = 'Dev' — rendered as a badge label.
    expect(find.textContaining('Dev'), findsOneWidget);
  });
}
