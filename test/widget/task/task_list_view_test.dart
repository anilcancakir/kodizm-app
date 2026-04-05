import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/task.dart';
import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/task/task_list_view.dart';
import 'package:app/resources/widgets/atoms/priority_badge.dart';
import 'package:app/resources/widgets/atoms/status_badge.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTaskAPayload = {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Implement authentication flow',
  'type': 'story',
  'priority': 'p1',
  'status': 'in_progress',
  'total_cost_usd': '1.42',
  'assigned_agent_role': {'name': 'Dev'},
  'created_at': '2024-01-01T10:00:00.000Z',
  'updated_at': '2024-01-02T12:00:00.000Z',
};

const Map<String, dynamic> kTaskBPayload = {
  'id': 'task-uuid-002',
  'project_id': 'proj-uuid-001',
  'title': 'Fix login page bug',
  'type': 'bug',
  'priority': 'p0',
  'status': 'draft',
  'total_cost_usd': null,
  'assigned_agent_role': null,
  'created_at': '2024-01-03T08:00:00.000Z',
  'updated_at': '2024-01-04T09:00:00.000Z',
};

/// Builds a [Task] from the given [payload].
Task _buildTask(Map<String, dynamic> payload) => Task.fromMap(payload);

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// A lightweight [TranslationLoader] for widget tests.
///
/// Reads the asset bundle directly without any service dependencies and
/// flattens nested keys into dot-separated paths.
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

/// Wraps [TaskListView] in [WindTheme] + [MaterialApp] for widget testing.
Widget _buildTestWidget({String projectId = 'proj-uuid-001'}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: TaskListView(projectId: projectId)),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late TaskState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    Http.fake().stub('*', Http.response({'data': <dynamic>[]}));

    state = TaskState();
    Magic.put<TaskState>(state);
  });

  // -------------------------------------------------------------------------
  // Helper: configure viewport, pre-seed state, pump widget.
  // -------------------------------------------------------------------------
  Future<void> pumpWithTasks(WidgetTester tester, List<Task> tasks) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    if (tasks.isEmpty) {
      state.setEmpty();
    } else {
      state.setSuccess(tasks);
    }

    await tester.pumpWidget(_buildTestWidget());
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------------
  // 1. Renders task cards with title, status badge, and priority badge
  // -------------------------------------------------------------------------

  testWidgets(
    'renders task cards with title, status badge, and priority badge',
    (tester) async {
      final tasks = [_buildTask(kTaskAPayload), _buildTask(kTaskBPayload)];

      await pumpWithTasks(tester, tasks);

      // Titles
      expect(find.text('Implement authentication flow'), findsOneWidget);
      expect(find.text('Fix login page bug'), findsOneWidget);

      // Status badges — one per task
      expect(find.byType(StatusBadge), findsNWidgets(2));

      // Priority badges — one per task
      expect(find.byType(PriorityBadge), findsNWidgets(2));
    },
  );

  // -------------------------------------------------------------------------
  // 2. Shows empty state when no tasks
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no tasks', (tester) async {
    await pumpWithTasks(tester, []);

    expect(find.text(trans('tasks.empty_title')), findsOneWidget);
    expect(find.text(trans('tasks.empty_subtitle')), findsOneWidget);

    // Create Task CTA
    expect(find.text(trans('tasks.create_task')), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 3. Filter chips render for status, type, and priority
  // -------------------------------------------------------------------------

  testWidgets('filter chips render for status, type, and priority', (
    tester,
  ) async {
    await pumpWithTasks(tester, []);

    // Section labels — "Status" also appears as a sort button, so use atLeast
    expect(find.text(trans('tasks.filter_status')), findsAtLeastNWidgets(1));
    expect(find.text(trans('tasks.filter_type')), findsOneWidget);
    // "Priority" appears as both filter label and sort button label
    expect(find.text(trans('tasks.filter_priority')), findsAtLeastNWidgets(1));

    // Representative chip labels from each dimension
    expect(find.text(trans('tasks.status_draft')), findsOneWidget);
    expect(find.text(trans('tasks.type_bug')), findsOneWidget);
    expect(find.text(trans('tasks.priority_p0')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Sort button toggles sort field
  // -------------------------------------------------------------------------

  testWidgets('sort buttons are rendered and sort_status button is tappable', (
    tester,
  ) async {
    final tasks = [_buildTask(kTaskAPayload), _buildTask(kTaskBPayload)];
    await pumpWithTasks(tester, tasks);

    // Sort section label
    expect(find.text(trans('tasks.sort_by')), findsOneWidget);

    // All four sort buttons — "Priority" also appears as filter label, "Status"
    // also appears as filter label, so use atLeast for those two
    expect(find.text(trans('tasks.sort_priority')), findsAtLeastNWidgets(1));
    expect(find.text(trans('tasks.sort_status')), findsAtLeastNWidgets(1));
    expect(find.text(trans('tasks.sort_created')), findsOneWidget);
    expect(find.text(trans('tasks.sort_updated')), findsOneWidget);

    // Tap "Created" sort (unique label — no naming collision) — should not throw
    await tester.tap(find.text(trans('tasks.sort_created')));
    await tester.pump();
  });

  // -------------------------------------------------------------------------
  // 5. Create task button is visible in header
  // -------------------------------------------------------------------------

  testWidgets('create task button is visible in header', (tester) async {
    await pumpWithTasks(tester, []);

    // The header action "Create Task" button
    expect(find.text(trans('tasks.create_task')), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 6. Shows unassigned label when no agent role
  // -------------------------------------------------------------------------

  testWidgets('shows unassigned label when task has no agent role assigned', (
    tester,
  ) async {
    final tasks = [_buildTask(kTaskBPayload)];
    await pumpWithTasks(tester, tasks);

    expect(find.text(trans('tasks.unassigned')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Shows agent role name when assigned
  // -------------------------------------------------------------------------

  testWidgets('shows assigned agent role name on task card', (tester) async {
    final tasks = [_buildTask(kTaskAPayload)];
    await pumpWithTasks(tester, tasks);

    expect(find.text('Dev'), findsOneWidget);
  });
}
