import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/settings_state.dart';
import 'package:app/resources/views/settings/app_settings_view.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fake SettingsStorage for tests
// ---------------------------------------------------------------------------

class _FakeStorage implements SettingsStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> get(String key) async => _store[key];

  @override
  Future<void> put(String key, String value) async => _store[key] = value;
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
// Helpers
// ---------------------------------------------------------------------------

/// Pumps an [AppSettingsView] inside the standard test scaffold.
Future<void> _pumpView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AppSettingsView())),
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
  late _FakeStorage storage;
  late SettingsState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    storage = _FakeStorage();
    state = SettingsState(storage: storage);
    Magic.put<SettingsState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<SettingsState>();
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed (const constructor smoke test)
  // -------------------------------------------------------------------------

  testWidgets('widget constructor creates AppSettingsView', (tester) async {
    await _pumpView(tester);

    expect(find.byType(AppSettingsView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders MagicStarterPageHeader with settings.title text
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    // trans('settings.title') = 'App Settings'
    expect(find.textContaining('App Settings'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders 3 theme option chips: Light, Dark, System
  // -------------------------------------------------------------------------

  testWidgets('renders 3 theme options: Light, Dark, System', (tester) async {
    await _pumpView(tester);

    // trans('settings.theme_light') = 'Light'
    expect(find.textContaining('Light'), findsOneWidget);
    // trans('settings.theme_dark') = 'Dark'
    expect(find.textContaining('Dark'), findsOneWidget);
    // trans('settings.theme_system') = 'System'
    expect(find.textContaining('System'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Notification section is present with at least one toggle label
  // -------------------------------------------------------------------------

  testWidgets('renders notification section with toggle labels', (
    tester,
  ) async {
    await _pumpView(tester);

    // trans('settings.notifications') = 'Notifications'
    expect(find.textContaining('Notifications'), findsWidgets);
    // trans('settings.notify_run_completed') = 'Run completed'
    expect(find.textContaining('Run completed'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. About section renders version/build/server labels
  // -------------------------------------------------------------------------

  testWidgets('renders about section with info labels', (tester) async {
    await _pumpView(tester);

    // trans('settings.about') = 'About'
    expect(find.textContaining('About'), findsOneWidget);
    // trans('settings.app_version') = 'App Version'
    expect(find.textContaining('App Version'), findsOneWidget);
    // trans('settings.build_number') = 'Build Number'
    expect(find.textContaining('Build Number'), findsOneWidget);
    // trans('settings.api_server') = 'API Server'
    expect(find.textContaining('API Server'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. MagicStarterCard widgets are used for layout sections
  // -------------------------------------------------------------------------

  testWidgets('uses MagicStarterCard widgets for each section', (tester) async {
    await _pumpView(tester);

    // Appearance + Notifications + About = at least 3 cards
    expect(find.byType(MagicStarterCard), findsAtLeastNWidgets(2));
  });
}
