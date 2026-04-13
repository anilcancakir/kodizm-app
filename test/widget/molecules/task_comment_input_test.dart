import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/agent_role.dart';
import 'package:app/resources/widgets/molecules/task_comment_input.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final List<AgentRole> kRoles = [
  AgentRole.fromMap({
    'id': 'role-main',
    'name': 'Main Agent',
    'slug': 'main-agent',
    'scope': 'full',
  }),
  AgentRole.fromMap({
    'id': 'role-dev',
    'name': 'Developer',
    'slug': 'developer',
    'scope': 'implementation',
  }),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [child] inside the standard Wind UI + MaterialApp scaffold.
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Renders placeholder text and send button
  // -------------------------------------------------------------------------

  testWidgets('renders placeholder text and send button', (tester) async {
    await _pump(
      tester,
      TaskCommentInput(roles: kRoles, onSubmit: (_, __) async {}),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Send button is disabled when input is empty
  // -------------------------------------------------------------------------

  testWidgets('send button WAnchor has null onTap when input is empty', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskCommentInput(roles: kRoles, onSubmit: (_, __) async {}),
    );

    // The send button WAnchor wraps the send icon. When disabled, its onTap
    // should be null — we verify by tapping and confirming no submit fires.
    final Completer<void> completer = Completer<void>();

    await _pump(
      tester,
      TaskCommentInput(
        roles: kRoles,
        onSubmit: (_, __) async {
          completer.complete();
        },
      ),
    );

    // Tap the send button area (icon) without entering text.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // The completer should NOT have completed — submit was not called.
    expect(completer.isCompleted, isFalse);
  });

  // -------------------------------------------------------------------------
  // 3. Send button is disabled when enabled is false
  // -------------------------------------------------------------------------

  testWidgets('send button does not fire when enabled is false', (
    tester,
  ) async {
    bool submitted = false;

    await _pump(
      tester,
      TaskCommentInput(
        roles: kRoles,
        enabled: false,
        onSubmit: (_, __) async {
          submitted = true;
        },
      ),
    );

    // Enter text and try to submit.
    await tester.enterText(find.byType(TextField), 'Review auth');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(submitted, isFalse);
  });

  // -------------------------------------------------------------------------
  // 4. Submitting with text calls onSubmit with prompt and role ID
  // -------------------------------------------------------------------------

  testWidgets('submitting calls onSubmit with prompt and selected role ID', (
    tester,
  ) async {
    String? receivedPrompt;
    String? receivedRoleId;

    await _pump(
      tester,
      TaskCommentInput(
        roles: kRoles,
        onSubmit: (prompt, roleId) async {
          receivedPrompt = prompt;
          receivedRoleId = roleId;
        },
      ),
    );

    // Type a prompt.
    await tester.enterText(find.byType(TextField), 'Fix the login bug');
    await tester.pump();

    // Tap send.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(receivedPrompt, equals('Fix the login bug'));
    // Default role should be main-agent.
    expect(receivedRoleId, equals('role-main'));
  });

  // -------------------------------------------------------------------------
  // 5. Input is cleared after successful submit
  // -------------------------------------------------------------------------

  testWidgets('input is cleared after successful submit', (tester) async {
    await _pump(
      tester,
      TaskCommentInput(roles: kRoles, onSubmit: (_, __) async {}),
    );

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Review security');
    await tester.pump();

    // Submit.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // TextField should be empty after submit.
    final TextField widget = tester.widget<TextField>(textField);
    expect(widget.controller?.text, isEmpty);
  });

  // -------------------------------------------------------------------------
  // 6. Role selector is shown when multiple roles exist
  // -------------------------------------------------------------------------

  testWidgets('shows role selector dropdown when multiple roles provided', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskCommentInput(roles: kRoles, onSubmit: (_, __) async {}),
    );

    // The role selector icon should be visible.
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    // DropdownButton should be present.
    expect(find.byType(DropdownButton<String>), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Role selector is hidden when single role provided
  // -------------------------------------------------------------------------

  testWidgets('hides role selector when only one role provided', (
    tester,
  ) async {
    await _pump(
      tester,
      TaskCommentInput(roles: [kRoles.first], onSubmit: (_, __) async {}),
    );

    // No dropdown when there's only one role.
    expect(find.byType(DropdownButton<String>), findsNothing);
  });
}
