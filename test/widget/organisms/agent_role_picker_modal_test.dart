import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/app/models/agent_role.dart';
import 'package:app/resources/widgets/organisms/agent_role_picker_modal.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

AgentRole _baRole() => AgentRole(
  id: 'role-ba',
  name: 'Business Analyst',
  scope: 'analysis',
  slug: 'ba',
  description: 'Gathers and refines requirements.',
);

AgentRole _devRole() => AgentRole(
  id: 'role-dev',
  name: 'Developer',
  scope: 'implementation',
  slug: 'dev',
  description: 'Implements the feature end-to-end.',
);

AgentRole _qaRole() => AgentRole(
  id: 'role-qa',
  name: 'QA Engineer',
  scope: 'testing',
  slug: 'qa',
  description: 'Validates quality and correctness.',
);

AgentRole _noDescriptionRole() =>
    AgentRole(id: 'role-lead', name: 'Lead', scope: 'lead', slug: 'lead');

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
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a button that opens [AgentRolePickerModal.show] and waits until the
/// dialog is visible.
///
/// The caller can then interact with the dialog and assert its contents.
Future<void> _pumpModal(WidgetTester tester, List<AgentRole> roles) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => AgentRolePickerModal.show(context, roles),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Widget tests for [AgentRolePickerModal].
///
/// All tests drive the public [AgentRolePickerModal.show] static entry point
/// and verify behaviour through rendered widgets and return values.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUpAll(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
    // Use a wider maxWidth so the footer row ("Cancel" + "Start Conversation")
    // does not overflow in the test environment's 400px dialog constraint.
    MagicStarter.useModalTheme(const MagicStarterModalTheme(maxWidth: 560));
  });

  // -------------------------------------------------------------------------
  // 1. Renders list of roles with names and descriptions
  // -------------------------------------------------------------------------

  /// Verifies that all role names and non-null descriptions appear in the modal.
  group('role list rendering', () {
    testWidgets('renders role names and descriptions for each role', (
      WidgetTester tester,
    ) async {
      await _pumpModal(tester, [_baRole(), _devRole(), _qaRole()]);

      expect(find.text('Business Analyst'), findsOneWidget);
      expect(find.text('Gathers and refines requirements.'), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Implements the feature end-to-end.'), findsOneWidget);
      expect(find.text('QA Engineer'), findsOneWidget);
      expect(find.text('Validates quality and correctness.'), findsOneWidget);
    });

    testWidgets('does not render description row when description is null', (
      WidgetTester tester,
    ) async {
      await _pumpModal(tester, [_noDescriptionRole()]);

      expect(find.text('Lead'), findsOneWidget);
      // Only name text should render; no additional description WText.
      // The WText for description is conditionally omitted, so the widget tree
      // should contain exactly one WText matching the role name.
      expect(find.text(''), findsNothing);
    });

    testWidgets('renders scope chip label for each role', (
      WidgetTester tester,
    ) async {
      await _pumpModal(tester, [_baRole(), _devRole()]);

      // Scope chips render the raw scope string.
      expect(find.text('analysis'), findsOneWidget);
      expect(find.text('implementation'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. BA role (or first role) is pre-selected on open
  // -------------------------------------------------------------------------

  /// Confirms BA pre-selection and fallback-to-first logic.
  group('pre-selection', () {
    testWidgets('pre-selects BA role by slug when present', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AgentRole? captured;

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    // BA is intentionally last in the list.
                    captured = await AgentRolePickerModal.show(context, [
                      _devRole(),
                      _qaRole(),
                      _baRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRolePickerModal), findsOneWidget);

      // Confirm without changing selection — BA should be pre-selected.
      await tester.tap(find.text('Start Conversation'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.slug, equals('ba'));
    });

    testWidgets('pre-selects first role when no BA slug present', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AgentRole? captured;

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    captured = await AgentRolePickerModal.show(context, [
                      _devRole(),
                      _qaRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Confirm without changing selection — first role (dev) should return.
      await tester.tap(find.text('Start Conversation'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.slug, equals('dev'));
    });
  });

  // -------------------------------------------------------------------------
  // 3. Tapping a different role changes selection
  // -------------------------------------------------------------------------

  /// Ensures tapping a non-selected row updates the selection.
  group('selection change', () {
    testWidgets('tapping a different role selects it', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AgentRole? captured;

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    captured = await AgentRolePickerModal.show(context, [
                      _baRole(),
                      _devRole(),
                      _qaRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // BA is pre-selected; tap Developer to switch.
      await tester.tap(find.text('Developer'));
      await tester.pumpAndSettle();

      // Confirm — result should be the dev role.
      await tester.tap(find.text('Start Conversation'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.slug, equals('dev'));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Confirm button returns selected role
  // -------------------------------------------------------------------------

  /// Verifies that tapping confirm closes the dialog and returns the selection.
  group('confirm button', () {
    testWidgets('returns selected role when confirm is tapped', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AgentRole? result;

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await AgentRolePickerModal.show(context, [
                      _baRole(),
                      _devRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRolePickerModal), findsOneWidget);

      await tester.tap(find.text('Start Conversation'));
      await tester.pumpAndSettle();

      // Dialog dismissed.
      expect(find.byType(AgentRolePickerModal), findsNothing);

      // BA was pre-selected; result carries the BA role.
      expect(result, isNotNull);
      expect(result!.slug, equals('ba'));
    });
  });

  // -------------------------------------------------------------------------
  // 5. Cancel button returns null
  // -------------------------------------------------------------------------

  /// Verifies that tapping cancel (or the barrier) closes the dialog with null.
  group('cancel / close', () {
    testWidgets('cancel button closes dialog and returns null', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Sentinel to distinguish "not yet resolved" from explicit null.
      AgentRole? result = AgentRole(id: 'sentinel', name: 'x', scope: 'x');

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await AgentRolePickerModal.show(context, [
                      _baRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRolePickerModal), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRolePickerModal), findsNothing);
      expect(result, isNull);
    });

    testWidgets('barrier tap closes dialog and returns null', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      AgentRole? result = AgentRole(id: 'sentinel', name: 'x', scope: 'x');

      await tester.pumpWidget(
        WindTheme(
          data: WindThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => ElevatedButton(
                  onPressed: () async {
                    result = await AgentRolePickerModal.show(context, [
                      _baRole(),
                    ]);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap well outside the dialog bounds.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AgentRolePickerModal), findsNothing);
      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Empty roles list shows error message
  // -------------------------------------------------------------------------

  /// Ensures the empty / error state renders when roles is an empty list.
  group('empty roles list', () {
    testWidgets('shows no_roles_available error message', (
      WidgetTester tester,
    ) async {
      await _pumpModal(tester, []);

      expect(
        find.text(
          'No agent roles available. Please configure agent roles first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('still shows confirm and cancel buttons when empty', (
      WidgetTester tester,
    ) async {
      await _pumpModal(tester, []);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Start Conversation'), findsOneWidget);
    });
  });
}
