import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/conversation.dart';
import 'package:app/app/models/task.dart';
import 'package:app/resources/widgets/organisms/pipeline_progress.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _taskMap({String status = 'in_progress'}) => {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Implement login screen',
  'type': 'story',
  'priority': 'p1',
  'status': status,
  'created_at': '2026-03-20T10:00:00.000Z',
  'updated_at': '2026-03-25T14:00:00.000Z',
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

/// Wraps [PipelineProgress] in [WindTheme] + [MaterialApp] for widget tests.
Widget _buildTestWidget({
  required Task task,
  List<Conversation> conversations = const [],
  VoidCallback? onContinue,
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PipelineProgress(
            task: task,
            conversations: conversations,
            onContinue: onContinue,
          ),
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  // -------------------------------------------------------------------------
  // 1. Renders all 5 stage labels
  // -------------------------------------------------------------------------

  testWidgets('renders all 5 stage labels', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final task = Task.fromMap(_taskMap(status: 'analysis'));

    await tester.pumpWidget(_buildTestWidget(task: task));
    await tester.pump();

    expect(
      find.text(trans('pipeline_progress.stage_analysis')),
      findsOneWidget,
    );
    expect(
      find.text(trans('pipeline_progress.stage_planning')),
      findsOneWidget,
    );
    expect(
      find.text(trans('pipeline_progress.stage_in_progress')),
      findsOneWidget,
    );
    expect(find.text(trans('pipeline_progress.stage_review')), findsOneWidget);
    expect(find.text(trans('pipeline_progress.stage_done')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Marks stages before current as completed
  // -------------------------------------------------------------------------

  testWidgets('marks stages before current as completed', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final task = Task.fromMap(_taskMap(status: 'in_progress'));
    final activeConversation = Conversation.fromMap({
      ...kConversation,
      'status': 'running',
    });

    await tester.pumpWidget(
      _buildTestWidget(task: task, conversations: [activeConversation]),
    );
    await tester.pump();

    // Find all PipelineProgress widgets — the organism renders step circles
    // with Key values indicating state.
    final completedDots = find.byKey(const Key('pipeline-step-completed'));
    final runningDots = find.byKey(const Key('pipeline-step-running'));
    final pendingDots = find.byKey(const Key('pipeline-step-pending'));

    // analysis + planning = 2 completed
    expect(completedDots, findsNWidgets(2));
    // in_progress = 1 running
    expect(runningDots, findsOneWidget);
    // review + done = 2 pending
    expect(pendingDots, findsNWidgets(2));
  });

  // -------------------------------------------------------------------------
  // 3. Shows continue button on waiting stage
  // -------------------------------------------------------------------------

  testWidgets('shows continue button on waiting stage', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // A task in review with no active conversations → waiting state
    final task = Task.fromMap(_taskMap(status: 'review'));

    var continueTapped = false;
    await tester.pumpWidget(
      _buildTestWidget(
        task: task,
        conversations: [],
        onContinue: () => continueTapped = true,
      ),
    );
    await tester.pump();

    final continueBtn = find.text(trans('pipeline_progress.continue_action'));
    expect(continueBtn, findsOneWidget);

    await tester.tap(continueBtn);
    await tester.pump();

    expect(continueTapped, isTrue);
  });

  // -------------------------------------------------------------------------
  // 4. Running stage has active indicator
  // -------------------------------------------------------------------------

  testWidgets('running stage shows active indicator', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Task in_progress with active conversation → running state
    final task = Task.fromMap(_taskMap(status: 'in_progress'));
    final activeConversation = Conversation.fromMap({
      ...kConversation,
      'status': 'running',
    });

    await tester.pumpWidget(
      _buildTestWidget(task: task, conversations: [activeConversation]),
    );
    await tester.pump();

    // Running step should have indicator
    expect(find.byKey(const Key('pipeline-step-running')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Done status marks all stages as completed
  // -------------------------------------------------------------------------

  testWidgets('done status marks all stages as completed', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final task = Task.fromMap(_taskMap(status: 'done'));

    await tester.pumpWidget(_buildTestWidget(task: task));
    await tester.pump();

    final completedDots = find.byKey(const Key('pipeline-step-completed'));
    expect(completedDots, findsNWidgets(5));
  });

  // -------------------------------------------------------------------------
  // 6. Draft status marks all stages as pending
  // -------------------------------------------------------------------------

  testWidgets('draft status marks all stages as pending', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final task = Task.fromMap(_taskMap(status: 'draft'));

    await tester.pumpWidget(_buildTestWidget(task: task));
    await tester.pump();

    final pendingDots = find.byKey(const Key('pipeline-step-pending'));
    expect(pendingDots, findsNWidgets(5));
  });
}
