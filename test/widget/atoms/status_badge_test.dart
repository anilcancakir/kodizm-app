import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/status_badge.dart';

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
// statusBadgeClassName
// ---------------------------------------------------------------------------

void main() {
  group('statusBadgeClassName', () {
    test('returns correct className for each known status', () {
      expect(statusBadgeClassName('draft'), contains('text-slate-400'));
      expect(statusBadgeClassName('analysis'), contains('text-indigo-500'));
      expect(statusBadgeClassName('planning'), contains('text-blue-500'));
      expect(statusBadgeClassName('design'), contains('text-violet-500'));
      expect(statusBadgeClassName('in_progress'), contains('text-amber-500'));
      expect(statusBadgeClassName('review'), contains('text-orange-500'));
      expect(statusBadgeClassName('testing'), contains('text-teal-500'));
      expect(statusBadgeClassName('done'), contains('text-emerald-500'));
      expect(statusBadgeClassName('failed'), contains('text-red-500'));
    });

    test('falls back for unknown status', () {
      expect(statusBadgeClassName('unknown_xyz'), contains('text-slate-400'));
    });
  });

  // -----------------------------------------------------------------------
  // statusDotClassName
  // -----------------------------------------------------------------------

  group('statusDotClassName', () {
    test('returns correct dot className for each known status', () {
      expect(statusDotClassName('draft'), 'bg-slate-300');
      expect(statusDotClassName('analysis'), 'bg-indigo-500');
      expect(statusDotClassName('planning'), 'bg-blue-500');
      expect(statusDotClassName('design'), 'bg-violet-500');
      expect(statusDotClassName('in_progress'), 'bg-amber-400');
      expect(statusDotClassName('review'), 'bg-orange-500');
      expect(statusDotClassName('testing'), 'bg-teal-500');
      expect(statusDotClassName('done'), 'bg-emerald-500');
      expect(statusDotClassName('failed'), 'bg-red-500');
    });

    test('falls back for unknown status', () {
      expect(statusDotClassName('unknown_xyz'), 'bg-slate-400');
    });
  });

  // -----------------------------------------------------------------------
  // StatusBadge widget
  // -----------------------------------------------------------------------

  group('StatusBadge', () {
    testWidgets('renders WDiv and WText for draft status', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const StatusBadge(status: 'draft')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders WDiv and WText for in_progress status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const StatusBadge(status: 'in_progress')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders WDiv and WText for done status', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const StatusBadge(status: 'done')));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders for all known statuses without error', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      const statuses = [
        'draft',
        'analysis',
        'planning',
        'design',
        'in_progress',
        'review',
        'testing',
        'done',
        'failed',
      ];

      for (final status in statuses) {
        await tester.pumpWidget(_wrap(StatusBadge(status: status)));
        expect(
          find.byType(WText),
          findsOneWidget,
          reason: 'Expected WText for status "$status"',
        );
      }
    });
  });
}
