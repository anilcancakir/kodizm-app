import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/resources/widgets/organisms/project_create_modal.dart';

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
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  /// Wraps the [ProjectCreateModal] in a [WindTheme] + [MaterialApp] inside
  /// a dialog context so that Wind UI tokens and navigation are available.
  Widget buildSubject() {
    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => WAnchor(
              key: const ValueKey('open_modal'),
              onTap: () => ProjectCreateModal.show(context),
              child: const WText('Open'),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the modal by tapping the trigger button with a large viewport.
  Future<void> openModal(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open_modal')));
    await tester.pumpAndSettle();
  }

  group('ProjectCreateModal', () {
    testWidgets('renders all expected form fields', (tester) async {
      await openModal(tester);

      // Four WFormInputs: name, short_name, description, tech stack.
      expect(find.byType(WFormInput), findsNWidgets(4));
    });

    testWidgets('shows validation error when name is empty on submit', (
      tester,
    ) async {
      await openModal(tester);

      // Tap the Create Project button without filling in the name.
      final createButton = find.text(trans('projects.create_project')).last;
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text(trans('projects.name_required')), findsOneWidget);
    });

    testWidgets('shows validation error when name exceeds 255 characters', (
      tester,
    ) async {
      await openModal(tester);

      final nameField = find.byType(WFormInput).first;
      await tester.enterText(nameField, 'A' * 256);

      final createButton = find.text(trans('projects.create_project')).last;
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text(trans('projects.name_max')), findsOneWidget);
    });

    testWidgets(
      'renders dialog title, Create Project button, and Cancel button',
      (tester) async {
        await openModal(tester);

        expect(find.text(trans('common.cancel')), findsOneWidget);
        expect(
          find.text(trans('projects.create_project')),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets('short_name field is the second form field', (tester) async {
      await openModal(tester);

      final shortNameField = find.byType(WFormInput).at(1);
      expect(shortNameField, findsOneWidget);
    });

    testWidgets('tech stack field is the fourth form field', (tester) async {
      await openModal(tester);

      final techStackField = find.byType(WFormInput).at(3);
      expect(techStackField, findsOneWidget);
    });

    testWidgets(
      'short_name auto-populates from project name as uppercase initials',
      (tester) async {
        await openModal(tester);

        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'My Cool App');
        await tester.pump();

        final shortNameField = find.byType(WFormInput).at(1);
        final shortNameWidget = tester.widget<WFormInput>(shortNameField);
        expect(shortNameWidget.controller?.text, equals('MCA'));
      },
    );

    testWidgets('short_name field is editable by the user', (tester) async {
      await openModal(tester);

      final nameField = find.byType(WFormInput).first;
      await tester.enterText(nameField, 'My Cool App');
      await tester.pump();

      final shortNameField = find.byType(WFormInput).at(1);
      await tester.enterText(shortNameField, 'MC');
      await tester.pump();

      final shortNameWidget = tester.widget<WFormInput>(shortNameField);
      expect(shortNameWidget.controller?.text, equals('MC'));
    });

    testWidgets(
      'shows validation error when short_name is too short (< 2 chars)',
      (tester) async {
        await openModal(tester);

        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'A');
        await tester.pump();

        final createButton = find.text(trans('projects.create_project')).last;
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );

    testWidgets(
      'shows validation error when short_name is too long (> 5 chars)',
      (tester) async {
        await openModal(tester);

        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'TOOLONG');
        await tester.pump();

        final createButton = find.text(trans('projects.create_project')).last;
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );

    testWidgets(
      'shows validation error when short_name contains lowercase letters',
      (tester) async {
        await openModal(tester);

        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'abc');
        await tester.pump();

        final createButton = find.text(trans('projects.create_project')).last;
        await tester.tap(createButton);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );

    testWidgets('cancel button closes the dialog', (tester) async {
      await openModal(tester);

      // Dialog should be open — form fields visible.
      expect(find.byType(WFormInput), findsNWidgets(4));

      // Tap cancel.
      await tester.tap(find.text(trans('common.cancel')));
      await tester.pumpAndSettle();

      // Dialog should be closed — no form fields.
      expect(find.byType(WFormInput), findsNothing);
    });
  });
}
