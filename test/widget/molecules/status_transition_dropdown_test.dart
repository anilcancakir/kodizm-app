import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/molecules/status_transition_dropdown.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [widget] inside the standard Wind UI + MaterialApp scaffold.
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

/// Default allowed-transitions map used across tests.
const Map<String, List<String>> _transitions = {
  'draft': ['analysis'],
  'analysis': ['planning', 'failed'],
  'planning': ['in_progress', 'failed'],
  'in_progress': ['review', 'failed'],
  'review': ['done', 'in_progress', 'failed'],
  'done': [],
  'failed': ['draft'],
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Renders current status label
  // -------------------------------------------------------------------------

  testWidgets('renders current status label', (tester) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'in_progress',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    expect(find.text(trans('tasks.status_in_progress')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Shows dropdown arrow when transitions are available
  // -------------------------------------------------------------------------

  testWidgets('shows dropdown arrow icon when transitions are available', (
    tester,
  ) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'in_progress',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. No dropdown arrow for done status (no transitions)
  // -------------------------------------------------------------------------

  testWidgets('hides dropdown arrow when no transitions are available', (
    tester,
  ) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'done',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Tap opens popup menu with transition items
  // -------------------------------------------------------------------------

  testWidgets('tap opens popup menu with valid transition items', (
    tester,
  ) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'in_progress',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    await tester.tap(find.byType(StatusTransitionDropdown));
    await tester.pumpAndSettle();

    // in_progress → ['review', 'failed'] transitions
    expect(find.text(trans('tasks.transition_submit_review')), findsOneWidget);
    expect(find.text(trans('tasks.transition_mark_failed')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Selecting a transition calls onTransition with target status
  // -------------------------------------------------------------------------

  testWidgets('selecting a transition item calls onTransition callback', (
    tester,
  ) async {
    String? selected;

    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'in_progress',
        allowedTransitions: _transitions,
        onTransition: (status) => selected = status,
      ),
    );

    await tester.tap(find.byType(StatusTransitionDropdown));
    await tester.pumpAndSettle();

    await tester.tap(find.text(trans('tasks.transition_submit_review')));
    await tester.pumpAndSettle();

    expect(selected, equals('review'));
  });

  // -------------------------------------------------------------------------
  // 6. Tap is no-op when done (no transitions)
  // -------------------------------------------------------------------------

  testWidgets('done status — tap does not open popup menu', (tester) async {
    var called = false;

    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'done',
        allowedTransitions: _transitions,
        onTransition: (_) => called = true,
      ),
    );

    await tester.tap(find.byType(StatusTransitionDropdown));
    await tester.pumpAndSettle();

    // No popup items should appear
    expect(find.text(trans('tasks.transition_reopen')), findsNothing);
    expect(called, isFalse);
  });

  // -------------------------------------------------------------------------
  // 7. Uses Wind UI widgets — no native Row/Column/Text
  // -------------------------------------------------------------------------

  testWidgets('uses WDiv and WText — no native Text or Row at top level', (
    tester,
  ) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'draft',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    expect(find.byType(WDiv), findsWidgets);
    expect(find.byType(WText), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 8. Shows correct label for draft status
  // -------------------------------------------------------------------------

  testWidgets('renders correct status label for draft', (tester) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'draft',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    expect(find.text(trans('tasks.status_draft')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Popup menu contains only valid transitions (not all statuses)
  // -------------------------------------------------------------------------

  testWidgets('popup shows only transitions for current status', (
    tester,
  ) async {
    await _pump(
      tester,
      StatusTransitionDropdown(
        currentStatus: 'draft',
        allowedTransitions: _transitions,
        onTransition: (_) {},
      ),
    );

    await tester.tap(find.byType(StatusTransitionDropdown));
    await tester.pumpAndSettle();

    // draft → ['analysis'] only
    expect(find.text(trans('tasks.transition_start_analysis')), findsOneWidget);
    // Should NOT show transitions for other statuses
    expect(
      find.text(trans('tasks.transition_start_development')),
      findsNothing,
    );
    expect(find.text(trans('tasks.transition_approve_done')), findsNothing);
  });
}
