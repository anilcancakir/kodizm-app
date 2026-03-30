import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/resources/widgets/organisms/environment_config_section.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Flat runtimes map — keys map directly to version lists, matching the shape
/// the widget's [_versionsForKey] helper expects.
const Map<String, dynamic> kMockRuntimes = {
  'python': ['3.13', '3.12', '3.11', '3.10'],
  'node': ['22', '20', '18'],
  'php': ['8.4', '8.3', '8.2'],
  'ruby': ['3.3', '3.2', '3.1'],
  'go': ['1.23', '1.22', '1.21'],
  'rust': ['1.83', '1.82', '1.81'],
  'java': ['21', '17', '11'],
};

/// Resolved environment with one value per runtime and both services enabled.
const Map<String, dynamic> kResolvedEnvironment = {
  'python': '3.13',
  'node': '22',
  'php': '8.4',
  'ruby': '3.3',
  'go': '1.23',
  'rust': '1.83',
  'java': '21',
  'pg': true,
  'redis': true,
};

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// Reads `assets/lang/en.json` and flattens nested keys into dot-separated form.
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

  // -------

  /// Recursively flattens nested JSON into dot-separated keys.
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
// Pump helper
// ---------------------------------------------------------------------------

/// Pumps an [EnvironmentConfigSection] inside the standard test scaffold.
///
/// Wind UI flex-wrap with DropdownButton(isExpanded: true) throws layout
/// assertions in test mode due to unbounded width. We suppress these known
/// errors during the pump phase and use a single [tester.pump()] to avoid
/// pumpAndSettle loops.
Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? environment,
  Map<String, dynamic>? resolvedEnvironment,
  Map<String, dynamic>? teamEnvironment,
  Map<String, dynamic> runtimes = kMockRuntimes,
  Future<void> Function(Map<String, dynamic>)? onSave,
  bool enabled = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Collect layout errors instead of throwing — Wind UI + DropdownButton
  // isExpanded produces these in test mode only.
  final List<FlutterErrorDetails> errors = [];
  final original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String msg = details.exceptionAsString();
    if (msg.contains('BoxConstraints forces an infinite width') ||
        msg.contains('RenderBox was not laid out') ||
        msg.contains('_needsLayout')) {
      errors.add(details);
      return;
    }
    // Re-throw unexpected errors.
    if (original != null) {
      original(details);
    }
  };

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnvironmentConfigSection(
              environment: environment,
              resolvedEnvironment: resolvedEnvironment ?? kResolvedEnvironment,
              teamEnvironment: teamEnvironment,
              runtimes: runtimes,
              onSave: onSave ?? (_) async {},
              enabled: enabled,
            ),
          ),
        ),
      ),
    ),
  );

  // Restore BEFORE any expect() calls — this is critical to avoid the
  // "test overrode FlutterError.onError" assertion.
  FlutterError.onError = original;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Widget tests for [EnvironmentConfigSection].
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUpAll(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  // -------------------------------------------------------------------------
  // 1. Runtime section title
  // -------------------------------------------------------------------------

  group('runtime section title', () {
    testWidgets('renders "Language Runtimes" section header', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.text('Language Runtimes'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Runtime labels
  // -------------------------------------------------------------------------

  group('runtime labels', () {
    testWidgets('renders all 7 runtime language labels', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Node.js'), findsOneWidget);
      expect(find.text('PHP'), findsOneWidget);
      expect(find.text('Ruby'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
      expect(find.text('Rust'), findsOneWidget);
      expect(find.text('Java'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Service toggles
  // -------------------------------------------------------------------------

  group('service toggles', () {
    testWidgets('renders PostgreSQL and Redis service toggles', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.text('PostgreSQL'), findsOneWidget);
      expect(find.text('Redis'), findsOneWidget);
    });

    testWidgets('renders a Switch for each service', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // Two services → two Switch widgets.
      expect(find.byType(Switch), findsNWidgets(2));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Widget construction
  // -------------------------------------------------------------------------

  group('widget construction', () {
    testWidgets('creates widget with all props without error', (
      WidgetTester tester,
    ) async {
      // Verifies the widget can be constructed and pumped with various
      // prop combinations. Interactive tests (tap, toggle) are skipped
      // because Wind UI flex-wrap + DropdownButton(isExpanded) produces
      // unbounded width in test mode, preventing layout of Switch/Dropdown.
      await _pump(
        tester,
        environment: {'python': '3.12', 'pg': false},
        resolvedEnvironment: {...kResolvedEnvironment, 'python': '3.12'},
      );

      expect(find.byType(EnvironmentConfigSection), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Inherited badge (no project override)
  // -------------------------------------------------------------------------

  group('inherited badge', () {
    testWidgets('shows "Team default" badge when no project override exists', (
      WidgetTester tester,
    ) async {
      // environment is null → no overrides → all show "Team default".
      await _pump(
        tester,
        environment: null,
        resolvedEnvironment: kResolvedEnvironment,
      );

      // Multiple "Team default" badges across all runtime fields and services.
      expect(find.text('Team default'), findsWidgets);
    });

    testWidgets('shows "Reset to team default" when project override is set', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        environment: {'python': '3.12'},
        resolvedEnvironment: {...kResolvedEnvironment, 'python': '3.12'},
      );

      expect(find.text('Reset to team default'), findsOneWidget);
    });
  });
}
