import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/chat_item.dart';
import 'package:app/app/models/conversation_message.dart';
import 'package:app/resources/widgets/atoms/chat_error_block.dart';
import 'package:app/resources/widgets/atoms/chat_file_change_row.dart';
import 'package:app/resources/widgets/atoms/chat_result_block.dart';
import 'package:app/resources/widgets/atoms/chat_thinking_block.dart';
import 'package:app/resources/widgets/molecules/chat_subagent_block.dart';
import 'package:app/resources/widgets/organisms/chat_message_bubble.dart';
import 'package:app/resources/widgets/organisms/chat_stream_event_renderer.dart';
import 'package:app/resources/widgets/organisms/chat_tool_use_card.dart';

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

/// Sets a large viewport to avoid Wind UI flex layout overflow.
void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime.now().toUtc();

ConversationMessage _makeMessage({
  String role = 'assistant',
  String content = 'Hello from the agent.',
}) {
  return ConversationMessage(
    id: 'msg-001',
    conversationId: 'conv-001',
    role: role,
    content: content,
    createdAt: _now.subtract(const Duration(minutes: 1)),
  );
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
  // ChatMessageItem -> ChatMessageBubble
  // -------------------------------------------------------------------------

  group('ChatMessageItem', () {
    testWidgets('routes to ChatMessageBubble', (tester) async {
      _setViewport(tester);

      final item = ChatMessageItem(message: _makeMessage());

      await tester.pumpWidget(
        _wrap(
          ChatStreamEventRenderer(
            item: item,
            agentRoleSlug: 'ba',
            agentRoleName: 'Business Analyst',
            userName: 'Anil',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ChatMessageBubble), findsOneWidget);
    });

    testWidgets('passes agentRoleSlug and userName to bubble', (tester) async {
      _setViewport(tester);

      final item = ChatMessageItem(
        message: _makeMessage(role: 'assistant', content: 'Agent reply'),
      );

      await tester.pumpWidget(
        _wrap(
          ChatStreamEventRenderer(
            item: item,
            agentRoleSlug: 'dev',
            agentRoleName: 'Developer',
            userName: 'Anil',
          ),
        ),
      );
      await tester.pump();

      final bubble = tester.widget<ChatMessageBubble>(
        find.byType(ChatMessageBubble),
      );
      expect(bubble.agentRoleSlug, 'dev');
      expect(bubble.agentRoleName, 'Developer');
      expect(bubble.userName, 'Anil');
    });
  });

  // -------------------------------------------------------------------------
  // ChatToolUseItem -> ChatToolUseCard
  // -------------------------------------------------------------------------

  group('ChatToolUseItem', () {
    testWidgets('routes to ChatToolUseCard wrapped in pl-9 WDiv', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatToolUseItem(
        id: 'evt-tool-1',
        occurredAt: _now,
        toolName: 'Read',
        input: {'file_path': '/tmp/test.dart'},
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatToolUseCard), findsOneWidget);

      // Verify wrapping WDiv has pl-9 mb-2 className
      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });

    testWidgets('passes result to ChatToolUseCard', (tester) async {
      _setViewport(tester);

      final item = ChatToolUseItem(
        id: 'evt-tool-2',
        occurredAt: _now,
        toolName: 'Read',
        input: {'file_path': '/tmp/test.dart'},
        result: {'content': 'file contents here'},
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      final card = tester.widget<ChatToolUseCard>(find.byType(ChatToolUseCard));
      expect(card.result, {'content': 'file contents here'});
    });

    testWidgets('passes null result to ChatToolUseCard when not provided', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatToolUseItem(
        id: 'evt-tool-3',
        occurredAt: _now,
        toolName: 'Write',
        input: {'path': '/tmp/out.dart'},
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      final card = tester.widget<ChatToolUseCard>(find.byType(ChatToolUseCard));
      expect(card.result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ChatThinkingItem -> ChatThinkingBlock
  // -------------------------------------------------------------------------

  group('ChatThinkingItem', () {
    testWidgets('routes to ChatThinkingBlock wrapped in pl-9 WDiv', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatThinkingItem(
        id: 'evt-think-1',
        occurredAt: _now,
        content: 'Deep thinking...',
        durationMs: 2300,
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatThinkingBlock), findsOneWidget);

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // ChatSubagentItem -> ChatSubagentBlock
  // -------------------------------------------------------------------------

  group('ChatSubagentItem', () {
    testWidgets('routes to ChatSubagentBlock wrapped in pl-9 WDiv', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatSubagentItem(
        id: 'evt-sub-1',
        occurredAt: _now,
        subagentId: 'sa-abc123',
        description: 'Researching architecture',
        isComplete: false,
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatSubagentBlock), findsOneWidget);

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });

    testWidgets('passes all fields to ChatSubagentBlock', (tester) async {
      _setViewport(tester);

      final item = ChatSubagentItem(
        id: 'evt-sub-2',
        occurredAt: _now,
        subagentId: 'sa-xyz',
        description: 'Analyzing code',
        isComplete: true,
        children: List.generate(
          12,
          (i) => ChatToolUseItem(
            id: 'tool_$i',
            occurredAt: _now,
            toolName: 'Tool',
          ),
        ),
        durationMs: 8500,
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      final block = tester.widget<ChatSubagentBlock>(
        find.byType(ChatSubagentBlock),
      );
      expect(block.subagentId, 'sa-xyz');
      expect(block.description, 'Analyzing code');
      expect(block.isComplete, isTrue);
      expect(block.toolUseCount, 12);
      expect(block.durationMs, 8500);
    });
  });

  // -------------------------------------------------------------------------
  // ChatFileChangeItem -> ChatFileChangeRow
  // -------------------------------------------------------------------------

  group('ChatFileChangeItem', () {
    testWidgets('routes to ChatFileChangeRow wrapped in pl-9 WDiv', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatFileChangeItem(
        id: 'evt-file-1',
        occurredAt: _now,
        operation: 'M',
        filePath: 'lib/main.dart',
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatFileChangeRow), findsOneWidget);

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // ChatErrorItem -> ChatErrorBlock
  // -------------------------------------------------------------------------

  group('ChatErrorItem', () {
    testWidgets('routes to ChatErrorBlock wrapped in pl-9 WDiv', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatErrorItem(
        id: 'evt-err-1',
        occurredAt: _now,
        errorText: 'Rate limit exceeded',
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatErrorBlock), findsOneWidget);

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // ChatResultItem -> ChatResultBlock
  // -------------------------------------------------------------------------

  group('ChatResultItem', () {
    testWidgets('routes success result to ChatResultBlock', (tester) async {
      _setViewport(tester);

      final item = ChatResultItem(
        id: 'evt-res-1',
        occurredAt: _now,
        isError: false,
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatResultBlock), findsOneWidget);

      final block = tester.widget<ChatResultBlock>(
        find.byType(ChatResultBlock),
      );
      expect(block.isError, isFalse);
    });

    testWidgets('routes error result to ChatResultBlock with content', (
      tester,
    ) async {
      _setViewport(tester);

      final item = ChatResultItem(
        id: 'evt-res-2',
        occurredAt: _now,
        isError: true,
        content: 'Something failed',
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      expect(find.byType(ChatResultBlock), findsOneWidget);

      final block = tester.widget<ChatResultBlock>(
        find.byType(ChatResultBlock),
      );
      expect(block.isError, isTrue);
      expect(block.content, 'Something failed');
    });

    testWidgets('wraps ChatResultBlock in pl-9 WDiv', (tester) async {
      _setViewport(tester);

      final item = ChatResultItem(
        id: 'evt-res-3',
        occurredAt: _now,
        isError: false,
      );

      await tester.pumpWidget(_wrap(ChatStreamEventRenderer(item: item)));
      await tester.pump();

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final wrapperDivs = wDivs.where(
        (d) =>
            d.className?.contains('pl-9') == true &&
            d.className?.contains('mb-2') == true,
      );
      expect(wrapperDivs, isNotEmpty);
    });
  });
}
