import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/task_type_icon.dart';

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
// taskTypeIconData
// ---------------------------------------------------------------------------

void main() {
  group('taskTypeIconData', () {
    test('returns correct IconData for each known type', () {
      expect(taskTypeIconData('story'), Icons.auto_stories);
      expect(taskTypeIconData('task'), Icons.check_circle);
      expect(taskTypeIconData('bug'), Icons.bug_report);
      expect(taskTypeIconData('spike'), Icons.bolt);
    });

    test('falls back to help_outline for unknown type', () {
      expect(taskTypeIconData('unknown_type'), Icons.help_outline);
    });
  });

  // -----------------------------------------------------------------------
  // TaskTypeIcon widget
  // -----------------------------------------------------------------------

  group('TaskTypeIcon', () {
    testWidgets('renders WDiv, WIcon and WText for story type', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const TaskTypeIcon(type: 'story')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WIcon), findsOneWidget);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders WDiv, WIcon and WText for bug type', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const TaskTypeIcon(type: 'bug')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WIcon), findsOneWidget);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders for all known types without error', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      const types = ['story', 'task', 'bug', 'spike'];

      for (final type in types) {
        await tester.pumpWidget(_wrap(TaskTypeIcon(type: type)));
        expect(
          find.byType(WIcon),
          findsOneWidget,
          reason: 'Expected WIcon for type "$type"',
        );
        expect(
          find.byType(WText),
          findsOneWidget,
          reason: 'Expected WText for type "$type"',
        );
      }
    });
  });
}
