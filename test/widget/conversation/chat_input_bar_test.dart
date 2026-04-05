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
  bool awaitingResponse = false,
  VoidCallback? onSend,
  VoidCallback? onStop,
  ValueChanged<List<PlatformFile>>? onAttachmentsChanged,
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
            awaitingResponse: awaitingResponse,
            onSend: onSend,
            onStop: onStop,
            onAttachmentsChanged: onAttachmentsChanged,
          ),
        ),
      ),
    ),
  );
}

/// Build a fake [PlatformFile] with controllable size for test validation.
PlatformFile _fakePlatformFile({required String name, required int size}) {
  return PlatformFile(name: name, size: size);
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

  // -----------------------------------------------------------------------
  // 8. Stop button shows when awaitingResponse is true
  // -----------------------------------------------------------------------

  testWidgets('shows stop button when awaitingResponse is true', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildWidget(controller: controller, awaitingResponse: true),
    );
    await tester.pump();

    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    // Send button remains visible alongside stop — messages can be queued.
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 9. Stop button fires onStop callback
  // -----------------------------------------------------------------------

  testWidgets('onStop callback fires when stop button tapped', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    var callCount = 0;

    await tester.pumpWidget(
      _buildWidget(
        controller: controller,
        awaitingResponse: true,
        onStop: () => callCount++,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();

    expect(callCount, equals(1));
  });

  // -----------------------------------------------------------------------
  // 10. Send button shows when awaitingResponse is false
  // -----------------------------------------------------------------------

  testWidgets('shows send button when awaitingResponse is false', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildWidget(controller: controller, awaitingResponse: false),
    );
    await tester.pump();

    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 11. onAttachmentsChanged callback is accepted without error
  // -----------------------------------------------------------------------

  testWidgets('accepts onAttachmentsChanged callback', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    List<PlatformFile>? received;

    await tester.pumpWidget(
      _buildWidget(
        controller: controller,
        onAttachmentsChanged: (files) => received = files,
      ),
    );
    await tester.pump();

    // Widget renders without error when callback is provided.
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    expect(received, isNull); // not fired yet
  });

  // -----------------------------------------------------------------------
  // 12. Attachment preview strip renders when attachments are pre-seeded
  //     via the internal state — verified through the ChatInputBar widget key
  // -----------------------------------------------------------------------

  testWidgets('attachment preview strip shows close icon per attachment', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final key = GlobalKey<ChatInputBarState>();

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatInputBar(
                key: key,
                controller: controller,
                isSending: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Seed two attachments directly into the state.
    key.currentState!.addAttachments([
      _fakePlatformFile(name: 'photo.jpg', size: 1024 * 100),
      _fakePlatformFile(name: 'doc.pdf', size: 1024 * 200),
    ]);
    await tester.pump();

    // One close icon per attachment.
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  // -----------------------------------------------------------------------
  // 13. Removing an attachment via close button removes it from the strip
  // -----------------------------------------------------------------------

  testWidgets('tapping close icon removes that attachment', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final key = GlobalKey<ChatInputBarState>();

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatInputBar(
                key: key,
                controller: controller,
                isSending: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.addAttachments([
      _fakePlatformFile(name: 'photo.jpg', size: 1024 * 100),
      _fakePlatformFile(name: 'report.pdf', size: 1024 * 300),
    ]);
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNWidgets(2));

    // Tap the first close icon.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // -----------------------------------------------------------------------
  // 14. File size validation: >5 MB triggers SnackBar error
  // -----------------------------------------------------------------------

  testWidgets('oversized file triggers validation SnackBar', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final key = GlobalKey<ChatInputBarState>();
    const fiveMbPlus = 5 * 1024 * 1024 + 1;

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatInputBar(
                key: key,
                controller: controller,
                isSending: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.validateAndAddAttachments([
      _fakePlatformFile(name: 'huge.jpg', size: fiveMbPlus),
    ]);
    await tester.pump();

    // SnackBar appears with the size-limit message.
    expect(
      find.text(trans('chat.attachment_limit_size', {'max': '5'})),
      findsOneWidget,
    );
    // No attachment added.
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 15. Count validation: >4 files triggers SnackBar error
  // -----------------------------------------------------------------------

  testWidgets('more than 4 files triggers validation SnackBar', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final key = GlobalKey<ChatInputBarState>();

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatInputBar(
                key: key,
                controller: controller,
                isSending: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.validateAndAddAttachments(
      List.generate(
        5,
        (i) => _fakePlatformFile(name: 'file_$i.jpg', size: 1024),
      ),
    );
    await tester.pump();

    expect(
      find.text(trans('chat.attachment_limit_count', {'max': '4'})),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close), findsNothing);
  });

  // -----------------------------------------------------------------------
  // 16. Attachments cleared after onSend fires via clearAttachments
  // -----------------------------------------------------------------------

  testWidgets('clearAttachments removes all previews', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();
    final key = GlobalKey<ChatInputBarState>();

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatInputBar(
                key: key,
                controller: controller,
                isSending: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    key.currentState!.addAttachments([
      _fakePlatformFile(name: 'photo.jpg', size: 512),
    ]);
    await tester.pump();

    expect(find.byIcon(Icons.close), findsOneWidget);

    key.currentState!.clearAttachments();
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
