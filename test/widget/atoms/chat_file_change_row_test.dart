import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/chat_file_change_row.dart';

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
// operationBadgeClassName
// ---------------------------------------------------------------------------

void main() {
  group('operationBadgeClassName', () {
    test('returns emerald className for A (added)', () {
      expect(
        operationBadgeClassName('A'),
        'bg-emerald-500/15 text-emerald-500',
      );
    });

    test('returns blue className for M (modified)', () {
      expect(operationBadgeClassName('M'), 'bg-blue-500/15 text-blue-500');
    });

    test('returns red className for D (deleted)', () {
      expect(operationBadgeClassName('D'), 'bg-red-500/15 text-red-500');
    });

    test('returns slate className for unknown operation', () {
      expect(operationBadgeClassName('?'), 'bg-slate-500/15 text-slate-400');
    });
  });

  // -------------------------------------------------------------------------
  // operationLabel
  // -------------------------------------------------------------------------

  group('operationLabel', () {
    test('returns trans key for A', () {
      expect(
        operationLabel('A'),
        trans('conversation_chat.event_file_created'),
      );
    });

    test('returns trans key for M', () {
      expect(
        operationLabel('M'),
        trans('conversation_chat.event_file_modified'),
      );
    });

    test('returns trans key for D', () {
      expect(
        operationLabel('D'),
        trans('conversation_chat.event_file_deleted'),
      );
    });

    test('returns raw operation for unknown', () {
      expect(operationLabel('X'), 'X');
    });
  });

  // -------------------------------------------------------------------------
  // ChatFileChangeRow widget
  // -------------------------------------------------------------------------

  group('ChatFileChangeRow', () {
    testWidgets('renders file icon, badge and path for A operation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatFileChangeRow(operation: 'A', filePath: 'lib/main.dart'),
        ),
      );

      // File icon present.
      expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
      // Badge text via trans().
      expect(
        find.text(trans('conversation_chat.event_file_created')),
        findsOneWidget,
      );
      // File path visible.
      expect(find.text('lib/main.dart'), findsOneWidget);
    });

    testWidgets('renders correct badge for M operation', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatFileChangeRow(
            operation: 'M',
            filePath: 'lib/app/models/user.dart',
          ),
        ),
      );

      expect(
        find.text(trans('conversation_chat.event_file_modified')),
        findsOneWidget,
      );
      expect(find.text('lib/app/models/user.dart'), findsOneWidget);
    });

    testWidgets('renders correct badge for D operation', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatFileChangeRow(
            operation: 'D',
            filePath: 'test/old_test.dart',
          ),
        ),
      );

      expect(
        find.text(trans('conversation_chat.event_file_deleted')),
        findsOneWidget,
      );
      expect(find.text('test/old_test.dart'), findsOneWidget);
    });

    testWidgets('renders fallback badge for unknown operation', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ChatFileChangeRow(operation: '?', filePath: 'README.md')),
      );

      expect(find.text('?'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('uses WDiv, WText, and WIcon — no Row or Container', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatFileChangeRow(operation: 'A', filePath: 'lib/main.dart'),
        ),
      );

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsWidgets);
      expect(find.byType(WIcon), findsOneWidget);
    });
  });
}
