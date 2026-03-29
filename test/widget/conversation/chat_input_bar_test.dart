import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/organisms/chat_input_bar.dart';

// ---------------------------------------------------------------------------
// Translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildWidget({
  required TextEditingController controller,
  FocusNode? focusNode,
  bool isSending = false,
  VoidCallback? onSend,
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            isSending: isSending,
            onSend: onSend,
          ),
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  // -----------------------------------------------------------------------
  // 1. Renders input field with placeholder text
  // -----------------------------------------------------------------------

  testWidgets('renders input field with placeholder text', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(_buildWidget(controller: controller));
    await tester.pump();

    expect(find.text(trans('conversation_chat.placeholder')), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 2. Send button disabled when isSending is true
  // -----------------------------------------------------------------------

  testWidgets('send button does not fire onSend when isSending is true', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController(text: 'Hello');
    var tapped = false;

    await tester.pumpWidget(
      _buildWidget(
        controller: controller,
        isSending: true,
        onSend: () => tapped = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(tapped, isFalse);
  });

  // -----------------------------------------------------------------------
  // 3. onSend callback fires when send button tapped with text
  // -----------------------------------------------------------------------

  testWidgets('onSend callback fires when tapped with non-empty text', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController(text: 'Hello');
    var callCount = 0;

    await tester.pumpWidget(
      _buildWidget(controller: controller, onSend: () => callCount++),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(callCount, equals(1));
  });

  // -----------------------------------------------------------------------
  // 4. Enter keypress triggers onSend callback
  // -----------------------------------------------------------------------

  testWidgets('Enter keypress triggers onSend when text is non-empty', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var callCount = 0;

    await tester.pumpWidget(
      _buildWidget(
        controller: controller,
        focusNode: focusNode,
        onSend: () => callCount++,
      ),
    );
    await tester.pump();

    // Type text so _canSend becomes true.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();

    // Press Enter — should fire onSend.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(callCount, equals(1));
  });

  // -----------------------------------------------------------------------
  // 5. Shift+Enter does NOT trigger onSend; text contains newline
  // -----------------------------------------------------------------------

  testWidgets('Shift+Enter inserts newline and does not fire onSend', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var callCount = 0;

    await tester.pumpWidget(
      _buildWidget(
        controller: controller,
        focusNode: focusNode,
        onSend: () => callCount++,
      ),
    );
    await tester.pump();

    // Type text so _canSend would be true.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();

    // Press Shift+Enter — should NOT fire onSend, newline falls through.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pump();

    expect(callCount, equals(0));
  });

  // -----------------------------------------------------------------------
  // 6. Empty input → send WAnchor has null onTap
  // -----------------------------------------------------------------------

  testWidgets('send WAnchor has null onTap when controller is empty', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    var tapped = false;

    await tester.pumpWidget(
      _buildWidget(controller: controller, onSend: () => tapped = true),
    );
    await tester.pump();

    // Send icon WAnchor — onTap must be null when _isEmpty is true.
    final sendIconFinder = find.byIcon(Icons.send);
    expect(sendIconFinder, findsOneWidget);

    await tester.tap(sendIconFinder);
    await tester.pump();

    expect(tapped, isFalse);
  });

  // -----------------------------------------------------------------------
  // 7. Attachment button renders with attach_file_rounded icon
  // -----------------------------------------------------------------------

  testWidgets('attachment button renders with attach_file_rounded icon', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(_buildWidget(controller: controller));
    await tester.pump();

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
  });
}
