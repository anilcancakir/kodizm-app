import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/molecules/chat_subagent_block.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pumps [widget] inside the standard Wind UI + MaterialApp scaffold.
///
/// Uses [tester.pump()] instead of [pumpAndSettle] because
/// [CircularProgressIndicator] animates indefinitely.
Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// ChatSubagentBlock
// ---------------------------------------------------------------------------

void main() {
  group('ChatSubagentBlock', () {
    // ---------------------------------------------------------------------
    // Running state
    // ---------------------------------------------------------------------

    testWidgets(
      'running state shows CircularProgressIndicator and running text',
      (tester) async {
        await _pump(
          tester,
          const ChatSubagentBlock(
            subagentId: 'sub-001',
            description: 'Analyzing codebase',
            isComplete: false,
            toolUseCount: 0,
          ),
        );

        // Should show spinner.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Should show "Running..." text via trans().
        final runningText = trans('conversation_chat.event_subagent_running');
        expect(find.text(runningText), findsOneWidget);

        // Should show description.
        expect(find.text('Analyzing codebase'), findsOneWidget);
      },
    );

    // ---------------------------------------------------------------------
    // Done state with tool count and duration
    // ---------------------------------------------------------------------

    testWidgets('done state shows summary line with tool count and duration', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatSubagentBlock(
          subagentId: 'sub-002',
          description: 'Code review complete',
          isComplete: true,
          toolUseCount: 5,
          durationMs: 12000,
        ),
      );

      // Should NOT show spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Should show summary with tool count and duration via trans().
      final doneText = trans('conversation_chat.event_subagent_done', {
        'tools': '5',
        'duration': '12s',
      });
      expect(find.text(doneText), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Sub-agent badge renders
    // ---------------------------------------------------------------------

    testWidgets('renders sub-agent badge with subagentId', (tester) async {
      await _pump(
        tester,
        const ChatSubagentBlock(
          subagentId: 'sub-003',
          isComplete: false,
          toolUseCount: 0,
        ),
      );

      // Should show the sub-agent name badge via trans().
      final badgeText = trans('conversation_chat.event_subagent_start', {
        'name': 'sub-003',
      });
      expect(find.text(badgeText), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Done state without duration
    // ---------------------------------------------------------------------

    testWidgets('done state without duration shows fallback', (tester) async {
      await _pump(
        tester,
        const ChatSubagentBlock(
          subagentId: 'sub-004',
          isComplete: true,
          toolUseCount: 3,
        ),
      );

      // Should NOT show spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Should show summary with tool count and fallback duration.
      final doneText = trans('conversation_chat.event_subagent_done', {
        'tools': '3',
        'duration': '?',
      });
      expect(find.text(doneText), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Description is optional
    // ---------------------------------------------------------------------

    testWidgets('renders without description when null', (tester) async {
      await _pump(
        tester,
        const ChatSubagentBlock(
          subagentId: 'sub-005',
          isComplete: false,
          toolUseCount: 0,
        ),
      );

      // Should still render without error.
      expect(find.byType(ChatSubagentBlock), findsOneWidget);

      // Should show spinner for running state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // SizedBox wraps CircularProgressIndicator
    // ---------------------------------------------------------------------

    testWidgets('CircularProgressIndicator is wrapped in SizedBox', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatSubagentBlock(
          subagentId: 'sub-006',
          isComplete: false,
          toolUseCount: 0,
        ),
      );

      // Find the CPI and verify it has a SizedBox ancestor.
      final cpi = find.byType(CircularProgressIndicator);
      expect(cpi, findsOneWidget);

      final sizedBox = find.ancestor(of: cpi, matching: find.byType(SizedBox));
      expect(sizedBox, findsWidgets);
    });
  });
}
