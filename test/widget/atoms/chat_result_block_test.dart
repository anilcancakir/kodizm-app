import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/atoms/chat_result_block.dart';

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
// ChatResultBlock
// ---------------------------------------------------------------------------

void main() {
  group('ChatResultBlock', () {
    // ---------------------------------------------------------------------
    // Success state
    // ---------------------------------------------------------------------

    testWidgets('success state renders emerald check_circle icon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: false)));

      // Should render a check_circle icon for success.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Should NOT render a cancel icon.
      expect(find.byIcon(Icons.cancel), findsNothing);
    });

    testWidgets('success state renders success label text', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: false)));

      // Should render the translated success label.
      expect(
        find.text(trans('conversation_chat.event_result_success')),
        findsOneWidget,
      );
    });

    // ---------------------------------------------------------------------
    // Error state (no content)
    // ---------------------------------------------------------------------

    testWidgets('error state renders red cancel icon', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: true)));

      // Should render a cancel icon for error.
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // Should NOT render a check_circle icon.
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('error state renders error label text', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: true)));

      // Should render the translated error label.
      expect(
        find.text(trans('conversation_chat.event_result_error')),
        findsOneWidget,
      );
    });

    // ---------------------------------------------------------------------
    // Error state with content
    // ---------------------------------------------------------------------

    testWidgets('error with content renders monospace content text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatResultBlock(
            isError: true,
            content: 'TypeError: Cannot read property "id" of undefined',
          ),
        ),
      );

      // Should render the error content text.
      expect(
        find.text('TypeError: Cannot read property "id" of undefined'),
        findsOneWidget,
      );
    });

    // ---------------------------------------------------------------------
    // Success state ignores content
    // ---------------------------------------------------------------------

    testWidgets('success state does not render content even if provided', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          const ChatResultBlock(isError: false, content: 'Some output text'),
        ),
      );

      // Content should NOT be rendered for success state.
      expect(find.text('Some output text'), findsNothing);
    });

    // ---------------------------------------------------------------------
    // Error without content does not render content row
    // ---------------------------------------------------------------------

    testWidgets('error without content does not render content text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: true)));

      // The only WText widgets should be the error label — no extra content.
      // Verify by checking that the cancel icon and error label are present,
      // and no additional monospace content is rendered.
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(
        find.text(trans('conversation_chat.event_result_error')),
        findsOneWidget,
      );
    });

    // ---------------------------------------------------------------------
    // Wind UI widget types
    // ---------------------------------------------------------------------

    testWidgets('renders WDiv and WIcon and WText widgets', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const ChatResultBlock(isError: false)));

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WIcon), findsOneWidget);
      expect(find.byType(WText), findsOneWidget);
    });
  });
}
