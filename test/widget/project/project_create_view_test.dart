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

      // Five WFormInputs: name, description, repo URL, tech stack, branch.
      expect(find.byType(WFormInput), findsNWidgets(5));
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

      expect(find.text('Project name is required.'), findsOneWidget);
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
      await tester.pump();
      await tester.tap(submitButtonFinder);
      await tester.pump();

      expect(
        find.text('Project name must not exceed 255 characters.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders page title, Create Project button, and Cancel button',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(submitButtonFinder, findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        // Page title "Create Project" is present (at least one occurrence).
        expect(find.text('Create Project'), findsAtLeastNWidgets(1));
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

    testWidgets('default branch field is pre-filled with "main"', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The fifth WFormInput is the default branch field.
      final branchField = find.byType(WFormInput).at(4);
      final editableText = tester.widget<EditableText>(
        find.descendant(of: branchField, matching: find.byType(EditableText)),
      );

      expect(editableText.controller.text, equals('main'));
    });
  });
}
