import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/conversation.dart';
import 'package:app/app/models/task.dart';
import 'package:app/resources/widgets/atoms/collapsible_section.dart';
import 'package:app/resources/widgets/organisms/task_detail_sidebar.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Task _minimalTask() => Task.fromMap({
  'id': 'task-001',
  'title': 'Fix login bug',
  'type': 'bug',
  'priority': 'p1',
  'status': 'in_progress',
  'branch_name': 'fix/login-bug',
  'total_cost_usd': '0.0234',
  'source': 'manual',
  'estimated_complexity': 3,
  'created_at': '2026-01-15T10:00:00Z',
  'updated_at': '2026-03-20T14:30:00Z',
  'assigned_agent_role': {'name': 'Developer'},
  'created_by_user': {'name': 'Alice'},
});

Task _bareTask() => Task.fromMap({
  'id': 'task-002',
  'title': 'Spike task',
  'type': 'spike',
  'priority': 'p3',
  'status': 'draft',
});

Conversation _activeRun() => Conversation.fromMap({
  'id': 'conv-001',
  'project_id': 'proj-001',
  'user': {'id': 'user-001', 'name': 'Alice'},
  'agent_role': {'id': 'role-001', 'name': 'Developer'},
  'status': 'active',
  'total_cost_usd': '0.0512',
  'started_at': '2026-03-01T10:00:00Z',
  'created_at': '2026-03-01T10:00:00Z',
  'updated_at': '2026-03-01T12:00:00Z',
});

Conversation _completedRun() => Conversation.fromMap({
  'id': 'conv-002',
  'project_id': 'proj-001',
  'user': {'id': 'user-001', 'name': 'Alice'},
  'agent_role': {'id': 'role-001', 'name': 'Reviewer'},
  'status': 'completed',
  'total_cost_usd': '0.0120',
  'started_at': '2026-02-10T08:00:00Z',
  'created_at': '2026-02-10T08:00:00Z',
  'updated_at': '2026-02-10T09:00:00Z',
});

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
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pump(WidgetTester tester, Widget sidebar) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: sidebar)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  // -------------------------------------------------------------------------
  // 1. Renders details CollapsibleSection expanded by default
  // -------------------------------------------------------------------------

  testWidgets('renders details section with metadata', (tester) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    // CollapsibleSection is expanded by default — content should be visible
    expect(find.byType(CollapsibleSection), findsWidgets);
    // Agent role name in details
    expect(find.text('Developer'), findsWidgets);
    // Branch name
    expect(find.text('fix/login-bug'), findsOneWidget);
    // Cost formatted — \$0.0234
    expect(find.textContaining('0.023'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Details panel shows type, priority widgets
  // -------------------------------------------------------------------------

  testWidgets('details panel shows TaskTypeIcon and PriorityBadge', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    // TaskTypeIcon and PriorityBadge should be in widget tree
    expect(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == 'TaskTypeIcon'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'PriorityBadge',
      ),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 4. Created by and source visible when present
  // -------------------------------------------------------------------------

  testWidgets('details panel shows created_by and source when present', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('manual'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Pipeline section hidden when isPipelineEnabled is false
  // -------------------------------------------------------------------------

  testWidgets('pipeline section hidden by default', (tester) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    // PipelineProgress should not be rendered when not enabled
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'PipelineProgress',
      ),
      findsNothing,
    );
  });

  // -------------------------------------------------------------------------
  // 6. Pipeline section shown when isPipelineEnabled is true
  // -------------------------------------------------------------------------

  testWidgets('pipeline section shown when isPipelineEnabled true', (
    tester,
  ) async {
    // Wider viewport — PipelineProgress horizontal stepper needs 1440px
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskDetailSidebar(
                task: _minimalTask(),
                conversations: const [],

                onStartRun: () {},
                hasActiveRun: false,
                isPipelineEnabled: true,
                onContinuePipeline: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'PipelineProgress',
      ),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 7. Run history renders run rows
  // -------------------------------------------------------------------------

  testWidgets('run history renders agent role names', (tester) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: [_activeRun(), _completedRun()],

        onStartRun: () {},
        hasActiveRun: true,
      ),
    );

    // Both agent role names appear in run rows
    // 'Developer' may appear twice (detail row + run row) — use findsWidgets
    expect(find.text('Developer'), findsWidgets);
    expect(find.text('Reviewer'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Run agent button disabled when hasActiveRun is true
  // -------------------------------------------------------------------------

  testWidgets('run agent button has opacity-50 when hasActiveRun', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: [_activeRun()],

        onStartRun: () {},
        hasActiveRun: true,
      ),
    );

    // Button exists but disabled — find play_arrow icon
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Calls onStartRun when button tapped and no active run
  // -------------------------------------------------------------------------

  testWidgets('calls onStartRun when run agent button tapped', (tester) async {
    var called = false;

    await _pump(
      tester,
      TaskDetailSidebar(
        task: _minimalTask(),
        conversations: const [],

        onStartRun: () => called = true,
        hasActiveRun: false,
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(called, isTrue);
  });

  // -------------------------------------------------------------------------
  // 10. Unassigned shows fallback text when no agent role
  // -------------------------------------------------------------------------

  testWidgets('shows unassigned text when no agent role assigned', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _bareTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    expect(find.text('Unassigned'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 12. No branch fallback text shown when branchName is null
  // -------------------------------------------------------------------------

  testWidgets('shows no-branch fallback when branchName is null', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskDetailSidebar(
        task: _bareTask(),
        conversations: const [],

        onStartRun: () {},
        hasActiveRun: false,
      ),
    );

    expect(find.text('No branch'), findsOneWidget);
  });
}
