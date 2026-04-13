import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/task/task_create_view.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTaskResponse = {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'New Task',
  'type': 'task',
  'priority': 'p2',
  'status': 'draft',
  'created_at': '2024-06-01T10:00:00.000Z',
  'updated_at': '2024-06-01T10:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// Lightweight [TranslationLoader] for widget tests.
///
/// Reads `assets/lang/en.json` from the asset bundle directly and flattens
/// nested keys into dot-separated form (e.g., `tasks.create_task`).
class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
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
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
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
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [TaskCreateView] in [WindTheme] + [MaterialApp] for widget testing.
Widget _buildTestWidget() {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskCreateView(projectId: 'proj-uuid-001'),
        ),
      ),
    ),
  );
}

/// Pumps [TaskCreateView] with a wide 1440x900 viewport.
Future<void> _pumpTestWidget(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_buildTestWidget());
  await tester.pump();
}

/// Pumps the widget — form is shown directly (no modal gate).
Future<void> _pumpForm(WidgetTester tester) async {
  await _pumpTestWidget(tester);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    Http.fake().stub('*', Http.response({'data': kTaskResponse}, 201));

    final state = TaskState();
    Magic.put<TaskState>(state);
  });

  // -------------------------------------------------------------------------
  // 1. Renders form fields for title, description, and acceptance criteria
  // -------------------------------------------------------------------------

  testWidgets(
    'renders form fields for title, description, and acceptance criteria',
    (tester) async {
      await _pumpForm(tester);

      // All three WFormInput widgets must be present.
      expect(find.byType(WFormInput), findsNWidgets(3));

      // Title label.
      expect(find.text('Title *'), findsOneWidget);

      // Description label.
      expect(find.text(trans('tasks.description_label')), findsOneWidget);

      // Acceptance criteria label.
      expect(
        find.text(trans('tasks.acceptance_criteria_label')),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // 2. Validates empty title on submit
  // -------------------------------------------------------------------------

  testWidgets('validates empty title on submit', (tester) async {
    await _pumpForm(tester);

    // Scroll the submit button into view, then tap without entering a title.
    await tester.ensureVisible(find.byKey(const ValueKey('btn_create_task')));
    await tester.tap(find.byKey(const ValueKey('btn_create_task')));
    await tester.pump();

    // Validation error for empty title should appear.
    expect(find.text(trans('tasks.title_required')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Type segmented control renders all options
  // -------------------------------------------------------------------------

  testWidgets('type segmented control renders all options', (tester) async {
    await _pumpForm(tester);

    // All four type options must be visible.
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Task'), findsAtLeastNWidgets(1));
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Spike'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Priority segmented control renders all options
  // -------------------------------------------------------------------------

  testWidgets('priority segmented control renders all options', (tester) async {
    await _pumpForm(tester);

    // All four priority options must be visible.
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Cancel button is visible
  // -------------------------------------------------------------------------

  testWidgets('cancel button is visible', (tester) async {
    await _pumpForm(tester);

    // The cancel button should be rendered with the i18n key text.
    expect(find.text(trans('common.cancel')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Complexity segmented control renders None option
  // -------------------------------------------------------------------------

  testWidgets('complexity segmented control renders None option by default', (
    tester,
  ) async {
    await _pumpForm(tester);

    // The "None" complexity option should be rendered.
    expect(find.text(trans('tasks.complexity_none')), findsOneWidget);

    // All complexity size options must be present.
    expect(find.text(trans('tasks.complexity_xs')), findsOneWidget);
    expect(find.text(trans('tasks.complexity_m')), findsOneWidget);
    expect(find.text(trans('tasks.complexity_xl')), findsOneWidget);
  });
}
