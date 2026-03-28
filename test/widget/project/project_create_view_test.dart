import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/views/project/project_create_view.dart';

void main() {
  /// Wraps the [ProjectCreateView] in a [WindTheme] + [MaterialApp] so that
  /// Wind UI tokens and navigation context are available during widget tests.
  Widget buildSubject() {
    return WindTheme(
      data: WindThemeData(),
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ProjectCreateView())),
      ),
    );
  }

  /// Finder for the primary submit button via its ValueKey.
  final submitButtonFinder = find.byKey(const ValueKey('btn_create_project'));

  group('ProjectCreateView', () {
    testWidgets('renders all expected form fields', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Four WFormInputs: name, short_name, description, tech stack.
      expect(find.byType(WFormInput), findsNWidgets(4));
    });

    testWidgets('shows validation error when name is empty on submit', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Scroll to and tap the primary submit button without filling in the name.
      expect(submitButtonFinder, findsOneWidget);
      await tester.ensureVisible(submitButtonFinder);
      await tester.pump();
      await tester.tap(submitButtonFinder);
      await tester.pump();

      expect(find.text(trans('projects.name_required')), findsOneWidget);
    });

    testWidgets('shows validation error when name exceeds 255 characters', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The first WFormInput is the name field.
      final nameField = find.byType(WFormInput).first;
      await tester.enterText(nameField, 'A' * 256);

      await tester.ensureVisible(submitButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text(trans('projects.name_max')), findsOneWidget);
    });

    testWidgets(
      'renders page title, Create Project button, and Cancel button',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(submitButtonFinder, findsOneWidget);
        expect(find.text(trans('common.cancel')), findsOneWidget);
        // Page title translation key is present (at least one occurrence).
        expect(
          find.text(trans('projects.create_project')),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets('submit button is tappable', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(submitButtonFinder, findsOneWidget);

      // Scroll to button then tap — should not throw.
      await tester.ensureVisible(submitButtonFinder);
      await tester.pump();
      await tester.tap(submitButtonFinder);
      await tester.pump();
    });

    testWidgets('short_name field is the second form field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The second WFormInput is the short_name field.
      final shortNameField = find.byType(WFormInput).at(1);
      expect(shortNameField, findsOneWidget);
    });

    testWidgets('tech stack field is the fourth form field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The fourth WFormInput is the tech stack field (after short_name insert).
      final techStackField = find.byType(WFormInput).at(3);
      expect(techStackField, findsOneWidget);
    });

    testWidgets(
      'short_name auto-populates from project name as uppercase initials',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Type a project name — "My Cool App" → short_name should auto-fill "MCA".
        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'My Cool App');
        await tester.pump();

        // The short_name field (second WFormInput) should show "MCA".
        final shortNameField = find.byType(WFormInput).at(1);
        final shortNameWidget = tester.widget<WFormInput>(shortNameField);
        expect(shortNameWidget.controller?.text, equals('MCA'));
      },
    );

    testWidgets('short_name field is editable by the user', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Auto-populate by typing a name first.
      final nameField = find.byType(WFormInput).first;
      await tester.enterText(nameField, 'My Cool App');
      await tester.pump();

      // Clear the short_name field and type a custom value.
      final shortNameField = find.byType(WFormInput).at(1);
      await tester.enterText(shortNameField, 'MC');
      await tester.pump();

      // Short name field should reflect the user's custom value.
      final shortNameWidget = tester.widget<WFormInput>(shortNameField);
      expect(shortNameWidget.controller?.text, equals('MC'));
    });

    testWidgets(
      'shows validation error when short_name is too short (< 2 chars)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Fill the name to pass its validation.
        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        // Overwrite short_name with a single character.
        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'A');
        await tester.pump();

        await tester.ensureVisible(submitButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );

    testWidgets(
      'shows validation error when short_name is too long (> 5 chars)',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Fill the name to pass its validation.
        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        // Overwrite short_name with too many chars.
        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'TOOLONG');
        await tester.pump();

        await tester.ensureVisible(submitButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );

    testWidgets(
      'shows validation error when short_name contains lowercase letters',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Fill the name to pass its validation.
        final nameField = find.byType(WFormInput).first;
        await tester.enterText(nameField, 'Alpha');
        await tester.pump();

        // Overwrite short_name with lowercase letters.
        final shortNameField = find.byType(WFormInput).at(1);
        await tester.enterText(shortNameField, 'abc');
        await tester.pump();

        await tester.ensureVisible(submitButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        expect(find.text(trans('projects.short_name_invalid')), findsOneWidget);
      },
    );
  });
}
