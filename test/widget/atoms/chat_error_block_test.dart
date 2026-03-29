import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/chat_error_block.dart';

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
// ChatErrorBlock
// ---------------------------------------------------------------------------

void main() {
  group('ChatErrorBlock', () {
    testWidgets('renders the error text', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ChatErrorBlock(errorText: 'Something went wrong')),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders error icon', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ChatErrorBlock(errorText: 'Connection lost')),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders WDiv and WText widgets', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ChatErrorBlock(errorText: 'Timeout')),
      );

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WText), findsOneWidget);
      expect(find.byType(WIcon), findsOneWidget);
    });

    testWidgets('renders with long error text', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      const longError =
          'A very long error message that spans multiple lines and '
          'contains detailed information about what went wrong during '
          'the streaming session.';

      await tester.pumpWidget(
        _wrap(const ChatErrorBlock(errorText: longError)),
      );

      expect(find.text(longError), findsOneWidget);
    });
  });
}
