import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/task/task_detail_view.dart';
import 'package:app/resources/widgets/atoms/priority_badge.dart';
import 'package:app/resources/widgets/atoms/status_badge.dart';
import 'package:app/resources/widgets/atoms/task_type_icon.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTaskDetail = {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Implement login screen',
  'type': 'story',
  'priority': 'p1',
  'status': 'in_progress',
  'description': 'Build the login screen with email/password.',
  'acceptance_criteria': '- User can sign in\n- Error shown on failure',
  'assigned_agent_role': {'id': 'role-uuid-001', 'name': 'Developer'},
  'created_by_user': {'id': 'user-uuid-001', 'name': 'Anilcan'},
  'branch_name': 'feature/login',
  'total_cost_usd': '1.2345',
  'estimated_complexity': 3,
  'source': 'manual',
  'design_needed': false,
  'retry_count': 0,
  'created_at': '2026-03-20T10:00:00.000Z',
  'updated_at': '2026-03-25T14:00:00.000Z',
};

const Map<String, dynamic> kSection = {
  'id': 'section-uuid-001',
  'task_id': 'task-uuid-001',
  'type': 'analysis',
  'title': 'Requirements Analysis',
  'content': '## Summary\nThe login screen needs...',
  'version': 2,
  'created_by_agent_role_id': 'role-uuid-002',
  'created_by_agent_role': {'name': 'Business Analyst'},
  'created_at': '2026-03-21T09:00:00.000Z',
  'updated_at': '2026-03-21T10:00:00.000Z',
};

const Map<String, dynamic> kConversation = {
  'id': 'conv-uuid-001',
  'project_id': 'proj-uuid-001',
  'user': {'id': 'user-uuid-001', 'name': 'Test User'},
  'agent_role': {'id': 'role-uuid-001', 'name': 'Developer', 'slug': 'dev'},
  'title': null,
  'status': 'completed',
  'model': 'claude-3-5-sonnet',
  'total_cost_usd': '0.42',
  'total_input_tokens': 1000,
  'total_output_tokens': 500,
  'messages_count': 12,
  'last_activity_at': '2026-03-22T08:45:00.000Z',
  'started_at': '2026-03-22T08:00:00.000Z',
  'completed_at': '2026-03-22T08:45:00.000Z',
  'created_at': '2026-03-22T08:00:00.000Z',
  'updated_at': '2026-03-22T08:45:00.000Z',
  'type': 'autonomous',
  'task_id': 'task-uuid-001',
};

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// A lightweight [TranslationLoader] for widget tests.
///
/// Reads the asset bundle directly without any service dependencies.
/// Flattens nested keys (e.g., `{"tasks":{"status_draft":"Draft"}}`
/// becomes `{"tasks.status_draft": "Draft"}`).
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

/// Wraps [TaskDetailView] in a [WindTheme] + [MaterialApp] for widget testing.
Widget _buildTestWidget({
  String projectId = 'proj-uuid-001',
  String taskId = 'task-uuid-001',
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskDetailView(projectId: projectId, taskId: taskId),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late FakeNetworkDriver driver;
  late TaskState state;

  setUpAll(() async {
    // Ensure Flutter bindings are initialized so rootBundle is available.
    TestWidgetsFlutterBinding.ensureInitialized();
    // Pre-load translations so trans() resolves actual strings (not raw keys).
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response({'data': kTaskDetail}));
    driver.stub(
      '*/sections*',
      Http.response({
        'data': [kSection],
      }),
    );
    driver.stub(
      '*/conversations*',
      Http.response({
        'data': [kConversation],
      }),
    );

    state = TaskState();

    // Pre-register the fake state so TaskState.instance returns it.
    Magic.put<TaskState>(state);
  });

  // -------------------------------------------------------------------------
  // Helper: pre-seed state with success data then pump the widget.
  // -------------------------------------------------------------------------

  Future<void> pumpWithData(WidgetTester tester) async {
    // Wind UI flex layouts need sufficient horizontal space.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-seed state by calling fetch methods directly.
    await Future.wait([
      state.fetchTask('team-uuid-001', 'proj-uuid-001', 'task-uuid-001'),
      state.fetchSections('team-uuid-001', 'proj-uuid-001', 'task-uuid-001'),
      state.fetchConversations(
        'team-uuid-001',
        'proj-uuid-001',
        'task-uuid-001',
      ),
    ]);

    await tester.pumpWidget(_buildTestWidget());
    await tester.pump();
  }

  // -------------------------------------------------------------------------
  // 1. Renders task title and badges
  // -------------------------------------------------------------------------

  testWidgets('renders task title and badges', (tester) async {
    await pumpWithData(tester);

    // Title in PageHeader.
    expect(find.text('Implement login screen'), findsOneWidget);

    // Status, priority, and type badges are rendered.
    expect(find.byType(StatusBadge), findsWidgets);
    expect(find.byType(PriorityBadge), findsWidgets);
    expect(find.byType(TaskTypeIcon), findsOneWidget);

    // Status badge text resolves to i18n label.
    expect(find.text(trans('tasks.status_in_progress')), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 2. Renders description with markdown
  // -------------------------------------------------------------------------

  testWidgets('renders description with markdown', (tester) async {
    await pumpWithData(tester);

    // Description card heading.
    expect(find.text(trans('tasks.description_label')), findsWidgets);

    // Description content from fixture is visible (rendered by MarkdownViewer).
    expect(find.textContaining('Build the login screen'), findsOneWidget);

    // Acceptance criteria content from fixture is visible.
    expect(find.textContaining('User can sign in'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders sections as individual cards
  // -------------------------------------------------------------------------

  testWidgets('renders sections with type and title', (tester) async {
    await pumpWithData(tester);

    // Section title from fixture (may appear in section card + activity feed).
    expect(find.text('Requirements Analysis'), findsWidgets);

    // Section type badge label ("Analysis") — may appear in both.
    expect(find.text(trans('tasks.section_type_analysis')), findsWidgets);

    // Version badge — may appear in section card and activity feed.
    expect(
      find.text(trans('tasks.version_label', {'version': '2'})),
      findsWidgets,
    );
  });

  // -------------------------------------------------------------------------
  // 5. Renders run history with agent name and status
  // -------------------------------------------------------------------------

  testWidgets('renders run data in activity feed', (tester) async {
    await pumpWithData(tester);

    // Agent role name from fixture (in activity feed + sidebar details).
    expect(find.text('Developer'), findsWidgets);

    // The run cost appears in the activity feed.
    expect(find.text('\$0.42'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 6. Shows run agent button
  // -------------------------------------------------------------------------

  testWidgets('shows run agent button', (tester) async {
    await pumpWithData(tester);

    // The "Run Agent" button exists.
    expect(find.text(trans('tasks.run_agent')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Renders task info fields
  // -------------------------------------------------------------------------

  testWidgets('renders sidebar detail fields', (tester) async {
    await pumpWithData(tester);

    // Branch field (in sidebar).
    expect(find.text(trans('tasks.branch')), findsOneWidget);
    expect(find.text('feature/login'), findsOneWidget);

    // Total cost field (in sidebar).
    expect(find.text(trans('tasks.total_cost')), findsOneWidget);
    expect(find.text('\$1.2345'), findsOneWidget);

    // Created by field (in sidebar).
    expect(find.text(trans('tasks.created_by')), findsOneWidget);
    expect(find.text('Anilcan'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Copy as Markdown
  // -------------------------------------------------------------------------

  group('copy as markdown', () {
    testWidgets('renders copy as markdown button in description card', (
      tester,
    ) async {
      await pumpWithData(tester);

      // The copy icon should be visible in the description card.
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('copies formatted markdown to clipboard on tap', (
      tester,
    ) async {
      await pumpWithData(tester);

      // Set up clipboard mock to capture the copied text.
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      // Tap the copy button.
      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();

      // Verify clipboard received formatted markdown with section headers.
      expect(clipboardContent, isNotNull);
      expect(
        clipboardContent,
        contains('## ${trans('tasks.description_label')}'),
      );
      expect(clipboardContent, contains('Build the login screen'));
      expect(
        clipboardContent,
        contains('## ${trans('tasks.acceptance_criteria')}'),
      );
      expect(clipboardContent, contains('User can sign in'));

      // Icon should change to check mark as visual feedback.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsNothing);

      // After 2 seconds, icon resets back.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
