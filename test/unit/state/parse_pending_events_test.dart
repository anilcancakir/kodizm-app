import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/chat_item.dart';
import 'package:app/app/state/conversation_chat_state.dart';

// ---------------------------------------------------------------------------
// Minimal fake WebSocket (no-op — not needed for _parsePendingEvents tests)
// ---------------------------------------------------------------------------

class _FakeWebSocket implements ConversationChatWebSocket {
  final StreamController<void> _reconnect = StreamController<void>.broadcast();

  @override
  Stream<void> get onReconnect => _reconnect.stream;

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {}

  @override
  void unsubscribe(String channel) {}
}

// ---------------------------------------------------------------------------
// Helpers — build event maps in StreamEventResource format
// ---------------------------------------------------------------------------

Map<String, dynamic> _toolUseEvent({
  required String id,
  required String toolName,
  required String toolUseId,
  Map<String, dynamic>? input,
  Map<String, dynamic>? metadata,
}) {
  return {
    'id': id,
    'type': 'tool_use',
    'content_text': null,
    'metadata': metadata,
    'data': {
      'toolName': toolName,
      'toolUseId': toolUseId,
      'input': input ?? {},
    },
    'occurred_at': '2025-01-01T00:00:00Z',
  };
}

Map<String, dynamic> _toolResultEvent({
  required String id,
  required String toolUseId,
  String? content,
}) {
  return {
    'id': id,
    'type': 'tool_result',
    'content_text': content,
    'metadata': null,
    'data': {'toolUseId': toolUseId},
    'occurred_at': '2025-01-01T00:00:01Z',
  };
}

Map<String, dynamic> _subagentStartEvent({
  required String id,
  required String subagentId,
  String? toolUseId,
  String? description,
}) {
  return {
    'id': id,
    'type': 'subagent_start',
    'content_text': description,
    'metadata': null,
    'data': {
      'agentId': subagentId,
      'task_id': subagentId,
      'tool_use_id': toolUseId,
      'description': description,
    },
    'occurred_at': '2025-01-01T00:00:00Z',
  };
}

Map<String, dynamic> _subagentProgressEvent({
  required String id,
  required String subagentId,
}) {
  return {
    'id': id,
    'type': 'subagent_progress',
    'content_text': null,
    'metadata': null,
    'data': {'task_id': subagentId, 'agentId': subagentId},
    'occurred_at': '2025-01-01T00:00:01Z',
  };
}

Map<String, dynamic> _subagentStopEvent({
  required String id,
  required String subagentId,
}) {
  return {
    'id': id,
    'type': 'subagent_stop',
    'content_text': null,
    'metadata': null,
    'data': {'agentId': subagentId, 'task_id': subagentId},
    'occurred_at': '2025-01-01T00:00:02Z',
  };
}

Map<String, dynamic> _thinkingEvent({
  required String id,
  String content = 'I am thinking...',
}) {
  return {
    'id': id,
    'type': 'thinking',
    'content_text': content,
    'metadata': null,
    'data': null,
    'occurred_at': '2025-01-01T00:00:00Z',
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late ConversationChatState state;

  setUp(() {
    state = ConversationChatState(webSocket: _FakeWebSocket());
  });

  tearDown(() {
    state.reset();
  });

  // -------------------------------------------------------------------------
  // 1. Metadata extraction — toolName from `data` when `metadata` is null
  // -------------------------------------------------------------------------

  group('tool_use with null metadata — toolName from data', () {
    test('resolves toolName from data field when metadata is null', () {
      final events = [
        _toolUseEvent(
          id: 'evt_1',
          toolName: 'Read',
          toolUseId: 'tu_001',
          input: {'file_path': '/tmp/test.txt'},
          // metadata intentionally omitted → null in event map
        ),
      ];

      final items = state.parsePendingEventsForTest(events);

      expect(items, hasLength(1));
      final tool = items.first as ChatToolUseItem;
      expect(tool.toolName, equals('Read'));
      expect(tool.toolUseId, equals('tu_001'));
    });

    test('toolName is not "Unknown" when data contains toolName', () {
      final events = [
        _toolUseEvent(
          id: 'evt_2',
          toolName: 'Bash',
          toolUseId: 'tu_002',
          input: {'command': 'ls -la'},
        ),
      ];

      final items = state.parsePendingEventsForTest(events);

      final tool = items.first as ChatToolUseItem;
      expect(tool.toolName, isNot('Unknown'));
      expect(tool.toolName, equals('Bash'));
    });
  });

  // -------------------------------------------------------------------------
  // 2. Subagent nesting — tools nested within subagent start/stop block
  // -------------------------------------------------------------------------

  group('subagent nesting', () {
    test('tools between subagent_start and subagent_stop are nested', () {
      final events = [
        _subagentStartEvent(
          id: 'evt_s1',
          subagentId: 'agent-abc',
          toolUseId: 'tu_agent_1',
          description: 'Explore codebase',
        ),
        _subagentProgressEvent(id: 'evt_p1', subagentId: 'agent-abc'),
        _toolUseEvent(id: 'evt_t1', toolName: 'Read', toolUseId: 'tu_read_1'),
        _toolUseEvent(id: 'evt_t2', toolName: 'Grep', toolUseId: 'tu_grep_1'),
        _subagentStopEvent(id: 'evt_s2', subagentId: 'agent-abc'),
      ];

      final items = state.parsePendingEventsForTest(events);

      // Exactly one top-level item: the subagent.
      expect(items, hasLength(1));
      final subagent = items.first as ChatSubagentItem;
      expect(subagent.subagentId, equals('agent-abc'));
      expect(subagent.isComplete, isTrue);
      expect(subagent.children, hasLength(2));
      expect(
        (subagent.children[0] as ChatToolUseItem).toolName,
        equals('Read'),
      );
      expect(
        (subagent.children[1] as ChatToolUseItem).toolName,
        equals('Grep'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3. Root-level tools — no active subagent
  // -------------------------------------------------------------------------

  group('root-level tool_use without active subagent', () {
    test('tool_use without any subagent context stays at root', () {
      final events = [
        _toolUseEvent(id: 'evt_r1', toolName: 'Write', toolUseId: 'tu_write_1'),
        _toolUseEvent(id: 'evt_r2', toolName: 'Edit', toolUseId: 'tu_edit_1'),
      ];

      final items = state.parsePendingEventsForTest(events);

      expect(items, hasLength(2));
      expect(items[0], isA<ChatToolUseItem>());
      expect(items[1], isA<ChatToolUseItem>());
      expect((items[0] as ChatToolUseItem).toolName, equals('Write'));
      expect((items[1] as ChatToolUseItem).toolName, equals('Edit'));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Agent tool stays at root even during active subagent
  // -------------------------------------------------------------------------

  group('Agent tool_use stays root during active subagent', () {
    test('tool_use with toolName="Agent" is not nested', () {
      final events = [
        _subagentStartEvent(
          id: 'evt_s1',
          subagentId: 'agent-outer',
          toolUseId: 'tu_outer',
        ),
        _subagentProgressEvent(id: 'evt_p1', subagentId: 'agent-outer'),
        // Agent tool — should stay root even though subagent is active.
        _toolUseEvent(
          id: 'evt_agent',
          toolName: 'Agent',
          toolUseId: 'tu_inner_agent',
          input: {'subagent_type': 'ac:explore'},
        ),
        // Regular tool — should be nested.
        _toolUseEvent(id: 'evt_read', toolName: 'Read', toolUseId: 'tu_read'),
        _subagentStopEvent(id: 'evt_stop', subagentId: 'agent-outer'),
      ];

      final items = state.parsePendingEventsForTest(events);

      // Root should have: subagent + Agent tool (2 items total).
      expect(items, hasLength(2));
      final agentTool =
          items.firstWhere(
                (i) => i is ChatToolUseItem && (i).toolName == 'Agent',
                orElse: () => throw StateError('Agent tool not found at root'),
              )
              as ChatToolUseItem;
      expect(agentTool.toolName, equals('Agent'));

      // Read tool must be inside the subagent children.
      final subagent =
          items.firstWhere((i) => i is ChatSubagentItem) as ChatSubagentItem;
      expect(subagent.children, hasLength(1));
      expect(
        (subagent.children.first as ChatToolUseItem).toolName,
        equals('Read'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 5. tool_result correlates to its tool_use via toolUseId
  // -------------------------------------------------------------------------

  group('tool_result correlation', () {
    test('tool_result patches the matching tool_use with result content', () {
      final events = [
        _toolUseEvent(
          id: 'evt_use',
          toolName: 'Bash',
          toolUseId: 'tu_bash_1',
          input: {'command': 'echo hello'},
        ),
        _toolResultEvent(
          id: 'evt_result',
          toolUseId: 'tu_bash_1',
          content: 'hello',
        ),
      ];

      final items = state.parsePendingEventsForTest(events);

      expect(items, hasLength(1));
      final tool = items.first as ChatToolUseItem;
      expect(tool.toolUseId, equals('tu_bash_1'));
      expect(tool.result, equals('hello'));
    });

    test('tool_result correlates to tool_use nested inside a subagent', () {
      final events = [
        _subagentStartEvent(
          id: 'evt_sa_start',
          subagentId: 'agent-nested',
          toolUseId: 'tu_agent',
        ),
        _subagentProgressEvent(id: 'evt_sa_prog', subagentId: 'agent-nested'),
        _toolUseEvent(
          id: 'evt_inner_use',
          toolName: 'Read',
          toolUseId: 'tu_read_nested',
        ),
        _toolResultEvent(
          id: 'evt_inner_result',
          toolUseId: 'tu_read_nested',
          content: 'file content here',
        ),
        _subagentStopEvent(id: 'evt_sa_stop', subagentId: 'agent-nested'),
      ];

      final items = state.parsePendingEventsForTest(events);

      final subagent = items.first as ChatSubagentItem;
      final nested = subagent.children.first as ChatToolUseItem;
      expect(nested.result, equals('file content here'));
    });
  });

  // -------------------------------------------------------------------------
  // 6. Thinking events parsed correctly
  // -------------------------------------------------------------------------

  group('thinking events', () {
    test('thinking event produces ChatThinkingItem', () {
      final events = [
        _thinkingEvent(id: 'evt_think', content: 'Analyzing dependencies'),
      ];

      final items = state.parsePendingEventsForTest(events);

      expect(items, hasLength(1));
      final thinking = items.first as ChatThinkingItem;
      expect(thinking.content, equals('Analyzing dependencies'));
    });
  });

  // -------------------------------------------------------------------------
  // 7. Dedup — repeated event IDs skipped
  // -------------------------------------------------------------------------

  group('deduplication', () {
    test('duplicate event IDs are skipped in the same parse call', () {
      final events = [
        _toolUseEvent(id: 'evt_dup', toolName: 'Read', toolUseId: 'tu_1'),
        _toolUseEvent(id: 'evt_dup', toolName: 'Write', toolUseId: 'tu_2'),
      ];

      final items = state.parsePendingEventsForTest(events);

      // Second event with same ID is skipped.
      expect(items, hasLength(1));
      expect((items.first as ChatToolUseItem).toolName, equals('Read'));
    });
  });
}
