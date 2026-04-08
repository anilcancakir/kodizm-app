import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/git_provider.dart';
import 'package:app/app/state/git_provider_state.dart';
import 'package:app/resources/views/settings/integrations_view.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kProviderGithub = {
  'id': 'uuid-1',
  'team_id': 'team-1',
  'provider': 'github',
  'username': 'octocat',
  'display_name': 'The Octocat',
  'email': 'octocat@github.com',
  'avatar_url': null,
  'is_active': true,
  'connected_at': '2024-01-01T00:00:00.000Z',
  'last_used_at': null,
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

/// Pumps an [IntegrationsView] inside the standard test scaffold.
Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: IntegrationsView())),
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

  late GitProviderState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    Http.fake();

    state = GitProviderState();
    Magic.put<GitProviderState>(state);
  });

  // -------------------------------------------------------------------------
  // 1. Empty state — shows no providers message and Connect GitHub button
  // -------------------------------------------------------------------------

  testWidgets('shows no providers message and connect button when empty', (
    tester,
  ) async {
    // Pre-load empty state via fetch (Http.fake returns empty data).
    await state.loadProviders('team-001');

    await _pumpView(tester);

    // trans('integrations.no_providers_title') = 'No integrations connected'
    expect(find.textContaining('No integrations connected'), findsOneWidget);

    // trans('integrations.connect_github') = 'Connect GitHub'
    expect(find.textContaining('Connect GitHub'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Loading state — shows CircularProgressIndicator
  // -------------------------------------------------------------------------

  testWidgets('shows loading spinner while state is loading', (tester) async {
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: IntegrationsView()),
          ),
        ),
      ),
    );
    // Use pump() NOT pumpAndSettle() — animation never settles.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Connected state — shows provider username and disconnect button
  // -------------------------------------------------------------------------

  testWidgets('shows provider username and disconnect button when connected', (
    tester,
  ) async {
    final GitProvider provider = GitProvider.fromMap(kProviderGithub);
    state.setSuccess(<GitProvider>[provider]);

    await _pumpView(tester);

    // Username should be visible.
    expect(find.textContaining('octocat'), findsOneWidget);

    // trans('integrations.disconnect') = 'Disconnect'
    expect(find.textContaining('Disconnect'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Disconnect confirmation — shows AlertDialog with confirmation text
  // -------------------------------------------------------------------------

  testWidgets('shows disconnect confirmation dialog on disconnect tap', (
    tester,
  ) async {
    final GitProvider provider = GitProvider.fromMap(kProviderGithub);
    state.setSuccess(<GitProvider>[provider]);

    await _pumpView(tester);

    // Tap the disconnect button.
    await tester.tap(find.textContaining('Disconnect').first);
    await tester.pumpAndSettle();

    // AlertDialog should appear with confirmation message.
    expect(find.byType(AlertDialog), findsOneWidget);

    // trans('integrations.disconnect_confirm') = 'Are you sure you want to...'
    expect(
      find.textContaining('Are you sure you want to disconnect'),
      findsOneWidget,
    );
  });
}
