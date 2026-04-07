import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/collapsible_section.dart';

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

void main() {
  group('CollapsibleSection', () {
    testWidgets('renders title text', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Section Title',
          child: Text('Content'),
        ),
      );

      expect(find.text('Section Title'), findsOneWidget);
    });

    testWidgets('hides child when collapsed by default', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Section',
          child: Text('Hidden Content'),
        ),
      );

      expect(find.text('Hidden Content'), findsNothing);
    });

    testWidgets('shows child when initiallyExpanded is true', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Section',
          initiallyExpanded: true,
          child: Text('Visible Content'),
        ),
      );

      expect(find.text('Visible Content'), findsOneWidget);
    });

    testWidgets('toggles child visibility on header tap', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Toggle Section',
          child: Text('Toggle Content'),
        ),
      );

      // Initially collapsed — content hidden.
      expect(find.text('Toggle Content'), findsNothing);

      // Tap header to expand.
      await tester.tap(find.byType(WAnchor));
      await tester.pump();

      expect(find.text('Toggle Content'), findsOneWidget);

      // Tap again to collapse.
      await tester.tap(find.byType(WAnchor));
      await tester.pump();

      expect(find.text('Toggle Content'), findsNothing);
    });

    testWidgets('shows expand_more icon when collapsed', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(title: 'Section', child: Text('Content')),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is WIcon && w.icon == Icons.expand_more,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows expand_less icon when expanded', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Section',
          initiallyExpanded: true,
          child: Text('Content'),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is WIcon && w.icon == Icons.expand_less,
        ),
        findsOneWidget,
      );
    });

    testWidgets('chevron toggles from expand_more to expand_less on tap', (
      tester,
    ) async {
      await _pump(
        tester,
        const CollapsibleSection(title: 'Section', child: Text('Content')),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is WIcon && w.icon == Icons.expand_more,
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(WAnchor));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is WIcon && w.icon == Icons.expand_less,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await _pump(
        tester,
        const CollapsibleSection(
          title: 'Section',
          trailing: Text('Trailing'),
          child: Text('Content'),
        ),
      );

      expect(find.text('Trailing'), findsOneWidget);
    });

    testWidgets('does not render trailing widget when not provided', (
      tester,
    ) async {
      await _pump(
        tester,
        const CollapsibleSection(title: 'Section', child: Text('Content')),
      );

      // The trailing slot should be empty — no extra Text widgets beyond title.
      expect(find.text('Trailing'), findsNothing);
    });
  });
}
