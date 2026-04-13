import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/conversation_message.dart';
import 'package:app/resources/widgets/atoms/collapsible_section.dart';
import 'package:app/resources/widgets/organisms/chat_message_bubble.dart';
import 'package:app/resources/widgets/organisms/markdown_viewer.dart';

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

Widget _buildBubble(ChatMessageBubble bubble) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: bubble)),
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

  // -------------------------------------------------------------------------
  // Test A: system_dispatch message renders collapsible card
  // -------------------------------------------------------------------------

  testWidgets(
    'system_dispatch message renders collapsible card collapsed by default',
    (tester) async {
      _setViewport(tester);

      final message = ConversationMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Phase 1: do X. Phase 2: do Y.',
        metadata: const {'kind': 'system_dispatch'},
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _buildBubble(ChatMessageBubble(message: message, userName: 'Anilcan')),
      );
      await tester.pump();

      // Header title is rendered.
      expect(
        find.text(trans('conversation_chat.system_dispatch_title')),
        findsOneWidget,
      );

      // Body content is NOT visible while collapsed.
      expect(find.text('Phase 1: do X.'), findsNothing);

      // Tap the header to expand.
      await tester.tap(
        find.text(trans('conversation_chat.system_dispatch_title')),
      );
      await tester.pumpAndSettle();

      // Body content is now visible.
      expect(find.byType(MarkdownViewer), findsOneWidget);

      // No right-aligned user bubble background in any WDiv.
      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final bubbleDivs = wDivs.where(
        (d) => d.className?.contains('bg-secondary-400/15') == true,
      );
      expect(bubbleDivs, isEmpty);
    },
  );

  // -------------------------------------------------------------------------
  // Test B: regular user message still renders the existing bubble
  // -------------------------------------------------------------------------

  testWidgets(
    'regular user message (no metadata) renders right-aligned user bubble',
    (tester) async {
      _setViewport(tester);

      final message = ConversationMessage(
        id: 'm2',
        conversationId: 'c1',
        role: 'user',
        content: 'Hello there!',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _buildBubble(ChatMessageBubble(message: message, userName: 'Anilcan')),
      );
      await tester.pump();

      // Secondary bubble background is rendered.
      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final bubbleDivs = wDivs.where(
        (d) => d.className?.contains('bg-secondary-400/15') == true,
      );
      expect(bubbleDivs, isNotEmpty);

      // Content is immediately visible — no collapsible.
      expect(find.text('Hello there!'), findsOneWidget);
      expect(find.byType(CollapsibleSection), findsNothing);

      // No system_dispatch title.
      expect(
        find.text(trans('conversation_chat.system_dispatch_title')),
        findsNothing,
      );
    },
  );
}
