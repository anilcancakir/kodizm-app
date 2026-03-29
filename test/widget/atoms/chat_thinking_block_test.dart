import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/chat_thinking_block.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pumps [widget] inside the standard Wind UI + MaterialApp scaffold.
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
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// ChatThinkingBlock
// ---------------------------------------------------------------------------

void main() {
  group('ChatThinkingBlock', () {
    // ---------------------------------------------------------------------
    // Collapsed with duration
    // ---------------------------------------------------------------------

    testWidgets('collapsed with duration renders formatted duration text', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatThinkingBlock(
          content: 'Some thinking content',
          durationMs: 2300,
        ),
      );

      // Should render the thinking label with duration "2.3s".
      final label = trans('conversation_chat.event_thinking_duration', {
        'duration': '2.3s',
      });
      expect(find.textContaining(label), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Collapsed without duration
    // ---------------------------------------------------------------------

    testWidgets('collapsed without duration renders thinking label only', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatThinkingBlock(content: 'Some thinking content'),
      );

      // Should render the plain thinking label.
      final thinkingLabel = trans('conversation_chat.event_thinking');
      expect(find.textContaining(thinkingLabel), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Expanded with content
    // ---------------------------------------------------------------------

    testWidgets('expanded with content renders italic content text', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatThinkingBlock(
          content: 'I am reasoning about the problem.',
          durationMs: 1500,
        ),
      );

      // Content should NOT be visible when collapsed.
      expect(find.text('I am reasoning about the problem.'), findsNothing);

      // Tap to expand.
      await tester.tap(find.byType(WAnchor));
      await tester.pumpAndSettle();

      // Content should now be visible.
      expect(find.text('I am reasoning about the problem.'), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Null content hides expand chevron
    // ---------------------------------------------------------------------

    testWidgets('null content hides expand chevron and is not tappable', (
      tester,
    ) async {
      await _pump(tester, const ChatThinkingBlock(durationMs: 500));

      // Should render thinking label.
      final thinkingLabel = trans('conversation_chat.event_thinking_duration', {
        'duration': '0.5s',
      });
      expect(find.textContaining(thinkingLabel), findsOneWidget);

      // Should NOT render expand/collapse chevron icon.
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Should NOT have a WAnchor (not tappable).
      expect(find.byType(WAnchor), findsNothing);
    });

    // ---------------------------------------------------------------------
    // Chevron visible when content is provided
    // ---------------------------------------------------------------------

    testWidgets('chevron visible when content is provided', (tester) async {
      await _pump(
        tester,
        const ChatThinkingBlock(
          content: 'Deep thinking here.',
          durationMs: 3200,
        ),
      );

      // Should render expand chevron when collapsed.
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    // ---------------------------------------------------------------------
    // Chevron toggles on tap
    // ---------------------------------------------------------------------

    testWidgets('chevron toggles from expand_more to expand_less on tap', (
      tester,
    ) async {
      await _pump(
        tester,
        const ChatThinkingBlock(content: 'Thinking...', durationMs: 1000),
      );

      // Initially collapsed — expand_more visible.
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // Tap to expand.
      await tester.tap(find.byType(WAnchor));
      await tester.pumpAndSettle();

      // Now expanded — expand_less visible.
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    // ---------------------------------------------------------------------
    // Duration formatting edge cases
    // ---------------------------------------------------------------------

    testWidgets('formats sub-second duration correctly', (tester) async {
      await _pump(tester, const ChatThinkingBlock(durationMs: 500));

      final label = trans('conversation_chat.event_thinking_duration', {
        'duration': '0.5s',
      });
      expect(find.textContaining(label), findsOneWidget);
    });

    testWidgets('formats whole-second duration correctly', (tester) async {
      await _pump(tester, const ChatThinkingBlock(durationMs: 5000));

      final label = trans('conversation_chat.event_thinking_duration', {
        'duration': '5.0s',
      });
      expect(find.textContaining(label), findsOneWidget);
    });
  });
}
