import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/conversation_message.dart';
import 'package:app/resources/widgets/organisms/chat_message_bubble.dart';

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
// Fixtures
// ---------------------------------------------------------------------------

ConversationMessage _makeUserMessage({String content = 'Hello!'}) {
  return ConversationMessage(
    id: 'msg-user-001',
    conversationId: 'conv-001',
    role: 'user',
    content: content,
    createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
  );
}

ConversationMessage _makeAssistantMessage({
  String content = '**Bold** answer',
  double? costUsd,
  int? durationMs,
}) {
  return ConversationMessage(
    id: 'msg-asst-001',
    conversationId: 'conv-001',
    role: 'assistant',
    content: content,
    costUsd: costUsd,
    durationMs: durationMs,
    createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
  );
}

// ---------------------------------------------------------------------------
// Test helpers
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
  // Test 1: User bubble — right-aligned with amber bg
  // -------------------------------------------------------------------------

  testWidgets('user bubble is right-aligned with amber background', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildBubble(
        ChatMessageBubble(message: _makeUserMessage(content: 'Hello!')),
      ),
    );
    await tester.pump();

    // Outer row is flex-row justify-end (right-align)
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('justify-end'));

    // Bubble content div contains secondary background token
    final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
    final bubbleDivs = wDivs.where(
      (d) => d.className?.contains('bg-secondary-400/15') == true,
    );
    expect(bubbleDivs, isNotEmpty);

    // Message text is present
    expect(find.text('Hello!'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 2: Assistant bubble — avatar + markdown content
  // -------------------------------------------------------------------------

  testWidgets('assistant bubble shows avatar monogram and renders content', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildBubble(
        ChatMessageBubble(
          message: _makeAssistantMessage(content: 'Plain answer'),
          agentRoleSlug: 'ba',
          agentRoleName: 'Business Analyst',
        ),
      ),
    );
    await tester.pump();

    // Outer row is flex-row (left-align)
    final outerDiv = tester.widget<WDiv>(find.byType(WDiv).first);
    expect(outerDiv.className, contains('flex-row'));
    expect(outerDiv.className, isNot(contains('flex-row-reverse')));

    // Avatar monogram 'BA' (role abbreviation for 'ba' slug)
    expect(find.text('BA'), findsOneWidget);

    // Avatar circle has indigo bg (ba role)
    final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
    final avatarDivs = wDivs.where(
      (d) => d.className?.contains('bg-indigo-500') == true,
    );
    expect(avatarDivs, isNotEmpty);

    // Bubble bg is slate-100
    final bubbleDivs = wDivs.where(
      (d) => d.className?.contains('bg-slate-100') == true,
    );
    expect(bubbleDivs, isNotEmpty);
  });

  // -------------------------------------------------------------------------
  // Test 3: Footer shows cost when costUsd is present
  // -------------------------------------------------------------------------

  testWidgets('assistant bubble shows cost footer when costUsd is set', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildBubble(
        ChatMessageBubble(
          message: _makeAssistantMessage(
            content: 'Cost test',
            costUsd: 0.0012,
            durationMs: 1234,
          ),
          agentRoleSlug: 'dev',
          agentRoleName: 'Developer',
        ),
      ),
    );
    await tester.pump();

    // cost_format: "$:amount" → "$0.0012"
    expect(find.text('\$0.0012'), findsOneWidget);

    // Duration label
    expect(find.text('1234ms'), findsOneWidget);
  });
}
