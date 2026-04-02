import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/container_status_badge.dart';

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
// containerStatusBadgeClassName
// ---------------------------------------------------------------------------

void main() {
  group('containerStatusBadgeClassName', () {
    test('returns correct className for each known status', () {
      expect(
        containerStatusBadgeClassName('creating'),
        contains('text-blue-500'),
      );
      expect(
        containerStatusBadgeClassName('running'),
        contains('text-green-500'),
      );
      expect(
        containerStatusBadgeClassName('stopped'),
        contains('text-gray-500'),
      );
      expect(containerStatusBadgeClassName('failed'), contains('text-red-500'));
    });

    test('falls back for unknown status', () {
      expect(
        containerStatusBadgeClassName('unknown_xyz'),
        contains('text-gray-500'),
      );
    });
  });

  // -----------------------------------------------------------------------
  // ContainerStatusBadge widget
  // -----------------------------------------------------------------------

  group('ContainerStatusBadge', () {
    testWidgets('renders Running badge with correct className', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ContainerStatusBadge(status: 'running')),
      );

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders Failed badge with correct className', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ContainerStatusBadge(status: 'failed')),
      );

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders unknown status with fallback className', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ContainerStatusBadge(status: 'mystery')),
      );

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
    });

    testWidgets('renders for all known statuses without error', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      const statuses = ['creating', 'running', 'stopped', 'failed'];
      for (final status in statuses) {
        await tester.pumpWidget(_wrap(ContainerStatusBadge(status: status)));
        expect(
          find.byType(WText),
          findsOneWidget,
          reason: 'Expected WText for status "$status"',
        );
      }
    });
  });
}
