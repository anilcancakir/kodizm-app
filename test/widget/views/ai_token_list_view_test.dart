import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/ai_token_state.dart';
import 'package:app/resources/views/settings/ai_token_list_view.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTokenActive = {
  'id': 'tok-001',
  'team_id': 'team-001',
  'provider': 'anthropic',
  'auth_type': 'api_key',
  'label': 'Production Key',
  'status': 'active',
  'rotation_algorithm': null,
  'last_used_at': '2025-06-10T12:00:00.000Z',
  'usage_count': 150,
  'cooldown_until': null,
  'health_checked_at': '2025-06-10T11:00:00.000Z',
  'settings': <String, dynamic>{},
  'created_at': '2025-01-01T00:00:00.000Z',
  'updated_at': '2025-06-10T12:00:00.000Z',
};

const Map<String, dynamic> kTokenRateLimited = {
  'id': 'tok-002',
  'team_id': 'team-001',
  'provider': 'openai',
  'auth_type': 'api_key',
  'label': 'OpenAI Shared Key',
  'status': 'rate_limited',
  'rotation_algorithm': null,
  'last_used_at': '2025-06-09T08:00:00.000Z',
  'usage_count': 42,
  'cooldown_until': '2025-06-10T14:00:00.000Z',
  'health_checked_at': null,
  'settings': <String, dynamic>{},
  'created_at': '2025-02-01T00:00:00.000Z',
  'updated_at': '2025-06-09T08:00:00.000Z',
};

const Map<String, dynamic> kTokenResponse = {
  'data': [kTokenActive],
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

/// Pumps an [AiTokenListView] inside the standard test scaffold.
Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AiTokenListView())),
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
  late AiTokenState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response({'data': <dynamic>[]}));

    state = AiTokenState();
    Magic.put<AiTokenState>(state);
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed
  // -------------------------------------------------------------------------

  testWidgets('widget constructor instantiates correctly', (tester) async {
    await _pumpView(tester);

    expect(find.byType(AiTokenListView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state before tokens load', (tester) async {
    // Manually set loading state before pumping.
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: AiTokenListView())),
        ),
      ),
    );
    // Use pump() NOT pumpAndSettle() — animation never settles.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows empty state when no tokens exist
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no tokens exist', (tester) async {
    // Pre-load empty state.
    await state.loadTokens('team-001');

    await _pumpView(tester);

    // trans('ai_tokens.empty_title') = 'No AI Tokens'
    expect(find.textContaining('No AI Tokens'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders MagicStarterPageHeader with title
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    // Pre-load empty state to get past loading.
    await state.loadTokens('team-001');

    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    // trans('ai_tokens.title') = 'AI Tokens' — MagicStarterPageHeader title text
    expect(find.text('AI Tokens'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders token cards with label and provider badge
  // -------------------------------------------------------------------------

  testWidgets('renders token cards with label and provider badge', (
    tester,
  ) async {
    driver.stub(
      '*',
      Http.response({
        'data': <dynamic>[kTokenActive],
      }),
    );

    // Pre-load tokens.
    await state.loadTokens('team-001');

    await _pumpView(tester);

    // Token label should be visible.
    expect(find.text('Production Key'), findsOneWidget);

    // Provider badge — trans('ai_tokens.provider_anthropic') = 'Anthropic'
    expect(find.textContaining('Anthropic'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Shows status dot className matching token status
  // -------------------------------------------------------------------------

  testWidgets('shows status text matching token status', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': <dynamic>[kTokenActive, kTokenRateLimited],
      }),
    );

    // Pre-load tokens.
    await state.loadTokens('team-001');

    await _pumpView(tester);

    // trans('ai_tokens.status_active') = 'Active'
    expect(find.textContaining('Active'), findsOneWidget);

    // trans('ai_tokens.status_rate_limited') = 'Rate Limited'
    expect(find.textContaining('Rate Limited'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Shows usage count for tokens
  // -------------------------------------------------------------------------

  testWidgets('shows usage count for each token', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': <dynamic>[kTokenActive],
      }),
    );

    // Pre-load tokens.
    await state.loadTokens('team-001');

    await _pumpView(tester);

    // trans('ai_tokens.usage_count', {'count': '150'}) = '150 uses'
    expect(find.textContaining('150 uses'), findsOneWidget);
  });
}
