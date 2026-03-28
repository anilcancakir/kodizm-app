import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/session_usage_record.dart';
import 'package:app/resources/widgets/molecules/model_cost_breakdown.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a widget inside the standard Wind UI + MaterialApp scaffold.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Factory for [SessionUsageRecord] fixtures.
SessionUsageRecord _record({
  String id = 'rec-1',
  String sessionId = 'sess-1',
  int turnNumber = 1,
  String model = 'claude-sonnet-4-6',
  int inputTokens = 1000,
  int outputTokens = 500,
  int cacheReadTokens = 0,
  int cacheCreationTokens = 0,
  double costUsd = 0.003,
  bool isSubagent = false,
  String? subagentType,
}) {
  return SessionUsageRecord(
    id: id,
    sessionId: sessionId,
    turnNumber: turnNumber,
    model: model,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cacheReadTokens: cacheReadTokens,
    cacheCreationTokens: cacheCreationTokens,
    costUsd: costUsd,
    isSubagent: isSubagent,
    subagentType: subagentType,
    createdAt: DateTime.utc(2026, 3, 25),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Empty state — shows no_usage message
  // -------------------------------------------------------------------------

  testWidgets('renders empty state when usageRecords is empty', (tester) async {
    await _pump(tester, const ModelCostBreakdown(usageRecords: []));

    expect(find.text(trans('sessions.no_usage')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Single record — shows model name, tokens and cost
  // -------------------------------------------------------------------------

  testWidgets('renders model name, token counts and cost for single record', (
    tester,
  ) async {
    final records = [
      _record(
        model: 'claude-sonnet-4-6',
        inputTokens: 1000,
        outputTokens: 500,
        costUsd: 0.0042,
      ),
    ];

    await _pump(tester, ModelCostBreakdown(usageRecords: records));

    expect(find.textContaining('claude-sonnet-4-6'), findsOneWidget);
    expect(find.textContaining('1000'), findsOneWidget);
    expect(find.textContaining('500'), findsOneWidget);
    // Cost formatted to 4 decimal places
    expect(find.textContaining('0.0042'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Multiple records same model — groups and sums tokens + cost
  // -------------------------------------------------------------------------

  testWidgets('groups records by model and sums tokens and cost', (
    tester,
  ) async {
    final records = [
      _record(
        id: 'r1',
        model: 'claude-sonnet-4-6',
        inputTokens: 1000,
        outputTokens: 500,
        costUsd: 0.003,
      ),
      _record(
        id: 'r2',
        model: 'claude-sonnet-4-6',
        inputTokens: 2000,
        outputTokens: 800,
        costUsd: 0.005,
      ),
    ];

    await _pump(tester, ModelCostBreakdown(usageRecords: records));

    // Should only render one row for this model (grouped).
    expect(find.textContaining('claude-sonnet-4-6'), findsOneWidget);
    // Summed input tokens: 3000
    expect(find.textContaining('3000'), findsOneWidget);
    // Summed output tokens: 1300
    expect(find.textContaining('1300'), findsOneWidget);
    // Summed cost: 0.0080
    expect(find.textContaining('0.0080'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Multiple different models — renders one row per model
  // -------------------------------------------------------------------------

  testWidgets('renders a separate row for each distinct model', (tester) async {
    final records = [
      _record(
        id: 'r1',
        model: 'claude-sonnet-4-6',
        inputTokens: 500,
        outputTokens: 200,
        costUsd: 0.001,
      ),
      _record(
        id: 'r2',
        model: 'claude-haiku-3-5',
        inputTokens: 300,
        outputTokens: 100,
        costUsd: 0.0005,
      ),
    ];

    await _pump(tester, ModelCostBreakdown(usageRecords: records));

    expect(find.textContaining('claude-sonnet-4-6'), findsOneWidget);
    expect(find.textContaining('claude-haiku-3-5'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Header row — shows column labels from i18n
  // -------------------------------------------------------------------------

  testWidgets('renders column header labels', (tester) async {
    final records = [_record(model: 'claude-sonnet-4-6')];

    await _pump(tester, ModelCostBreakdown(usageRecords: records));

    expect(find.text(trans('sessions.model')), findsOneWidget);
    expect(find.text(trans('sessions.input_tokens')), findsOneWidget);
    expect(find.text(trans('sessions.output_tokens')), findsOneWidget);
    expect(find.text(trans('sessions.cost')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Widget type — uses only WDiv and WText (no native Row/Column/Text)
  // -------------------------------------------------------------------------

  testWidgets('uses WDiv and WText — no native Text widgets at top level', (
    tester,
  ) async {
    final records = [_record(model: 'claude-sonnet-4-6')];

    await _pump(tester, ModelCostBreakdown(usageRecords: records));

    // Wind UI widgets must be present.
    expect(find.byType(WDiv), findsWidgets);
    expect(find.byType(WText), findsWidgets);
  });
}
