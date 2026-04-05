import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/project_state.dart';
import 'package:app/app/state/session_state.dart';
import 'package:app/resources/views/session/session_list_view.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kSession1 = {
  'id': 'sess-uuid-001',
  'type': 'autonomous',
  'phase': 'executing',
  'model': 'claude-sonnet-4-6',
  'total_cost_usd': '0.042000',
  'total_input_tokens': 1200,
  'total_output_tokens': 800,
  'total_cache_read_tokens': 0,
  'total_cache_creation_tokens': 0,
  'warm_until': null,
  'started_at': '2025-06-10T08:00:00.000Z',
  'completed_at': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T08:30:00.000Z',
};

const Map<String, dynamic> kSession2 = {
  'id': 'sess-uuid-002',
  'type': 'interactive',
  'phase': 'warm',
  'model': 'claude-opus-4',
  'total_cost_usd': '0.180000',
  'total_input_tokens': 4500,
  'total_output_tokens': 3200,
  'total_cache_read_tokens': 200,
  'total_cache_creation_tokens': 100,
  'warm_until': '2025-06-10T11:00:00.000Z',
  'started_at': '2025-06-10T09:00:00.000Z',
  'completed_at': '2025-06-10T10:00:00.000Z',
  'created_at': '2025-06-10T09:00:00.000Z',
  'updated_at': '2025-06-10T10:00:00.000Z',
};

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

/// Pumps a [SessionListView] inside the standard test scaffold.
Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SessionListView())),
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
  late SessionState state;
  late ProjectState projectState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response({'data': <dynamic>[]}));

    state = SessionState();
    Magic.put<SessionState>(state);

    // Provide an empty ProjectState so the filter row doesn't crash.
    projectState = ProjectState();
    Magic.put<ProjectState>(projectState);
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed
  // -------------------------------------------------------------------------

  testWidgets('widget can be constructed', (tester) async {
    await _pumpView(tester);

    expect(find.byType(SessionListView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders MagicStarterPageHeader with sessions.title text
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    // trans('sessions.title') = 'Sessions'
    expect(find.text('Sessions'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state while sessions are loading', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.reset();
    });

    // Verify loading state is observable at the state level:
    // loadSessions sets _isLoading = true before the HTTP await.
    // Http.fake() responds synchronously so loading is transient;
    // verify that isLoading returns true during the call.
    bool wasLoading = false;
    state.addListener(() {
      if (state.isLoading) wasLoading = true;
    });

    await state.loadSessions();
    expect(wasLoading, isTrue, reason: 'isLoading should be true during fetch');

    // After loadSessions completes, isLoading is false.
    expect(state.isLoading, isFalse);
  });

  // -------------------------------------------------------------------------
  // 4. Shows empty state when no sessions exist
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no sessions exist', (tester) async {
    await state.loadSessions();

    await _pumpView(tester);

    // trans('sessions.empty_title') = 'No Sessions'
    expect(find.textContaining('No Sessions'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders session rows when sessions are loaded
  // -------------------------------------------------------------------------

  testWidgets('renders session rows when sessions are loaded', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': [kSession1, kSession2],
      }),
    );

    await state.loadSessions();

    await _pumpView(tester);

    // Session type + model visible (autonomous — claude-sonnet-4-6)
    expect(find.textContaining('autonomous'), findsOneWidget);
    expect(find.textContaining('claude-sonnet-4-6'), findsOneWidget);

    // MagicStarterCard wraps the list.
    expect(find.byType(MagicStarterCard), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Session rows are wrapped in WAnchor for navigation
  // -------------------------------------------------------------------------

  testWidgets('session rows are wrapped in WAnchor for navigation', (
    tester,
  ) async {
    driver.stub(
      '*',
      Http.response({
        'data': [kSession1],
      }),
    );

    await state.loadSessions();

    await _pumpView(tester);

    expect(find.byType(WAnchor), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 7. Renders filter row inside MagicStarterCard
  // -------------------------------------------------------------------------

  testWidgets('renders filter row with type and phase dropdowns', (
    tester,
  ) async {
    await state.loadSessions();

    await _pumpView(tester);

    // The filter buttons display "All Types" / "All Phases" when no filter
    // is selected — trans('sessions.all_types') / trans('sessions.all_phases').
    expect(find.textContaining('All Types'), findsOneWidget);
    expect(find.textContaining('All Phases'), findsOneWidget);
    // Project filter button displays "All Projects" by default.
    expect(find.textContaining('All Projects'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Renders phase badge with correct label
  // -------------------------------------------------------------------------

  testWidgets('renders phase badge with phase label', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': [kSession1],
      }),
    );

    await state.loadSessions();

    await _pumpView(tester);

    // trans('sessions.phase_executing') = 'Executing'
    expect(find.textContaining('Executing'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Renders cost in session row
  // -------------------------------------------------------------------------

  testWidgets('renders cost formatted as currency', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': [kSession1],
      }),
    );

    await state.loadSessions();

    await _pumpView(tester);

    // kSession1.total_cost_usd = '0.042000' → '$0.04'
    expect(find.textContaining('\$0.04'), findsOneWidget);
  });
}
