import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/priority_badge.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [widget] in the Wind + Material test scaffolding.
Widget _wrap(Widget widget) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
}

// ---------------------------------------------------------------------------
// priorityBadgeClassName
// ---------------------------------------------------------------------------

void main() {
  group('priorityBadgeClassName', () {
    test('returns correct className for each known priority', () {
      expect(priorityBadgeClassName('p0'), contains('text-red-500'));
      expect(priorityBadgeClassName('p1'), contains('text-amber-500'));
      expect(priorityBadgeClassName('p2'), contains('text-blue-500'));
      expect(priorityBadgeClassName('p3'), contains('text-slate-400'));
    });

    test('falls back for unknown priority', () {
      expect(priorityBadgeClassName('unknown'), contains('text-slate-400'));
    });
  });

  // -----------------------------------------------------------------------
  // PriorityBadge widget
  // -----------------------------------------------------------------------

  group('PriorityBadge', () {
    testWidgets('renders WDiv and WText for p0 (Critical)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 'p0')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders WDiv and WText for p3 (Low)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const PriorityBadge(priority: 'p3')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders for all known priorities without error', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      const priorities = ['p0', 'p1', 'p2', 'p3'];

      for (final priority in priorities) {
        await tester.pumpWidget(_wrap(PriorityBadge(priority: priority)));
        expect(
          find.byType(WText),
          findsOneWidget,
          reason: 'Expected WText for priority "$priority"',
        );
      }
    });
  });
}
