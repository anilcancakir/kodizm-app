import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/chat_item.dart';
import 'package:app/app/models/conversation_message.dart';

void main() {
  group('ChatItem', () {
    // -------

    group('ChatMessageItem', () {
      final message = ConversationMessage(
        id: 'msg-uuid-1',
        conversationId: 'conv-uuid-1',
        role: 'assistant',
        content: 'Hello from the agent.',
        createdAt: DateTime.utc(2026, 3, 29, 12, 0, 0),
      );

      test('wraps ConversationMessage and delegates id', () {
        final item = ChatMessageItem(message: message);

        expect(item.id, 'msg-uuid-1');
        expect(item.message, same(message));
      });

      test('delegates occurredAt to message.createdAt', () {
        final item = ChatMessageItem(message: message);

        expect(item.occurredAt, DateTime.utc(2026, 3, 29, 12, 0, 0));
      });

      test('fromConversationMessage factory creates correctly', () {
        final item = ChatMessageItem.fromConversationMessage(message);

        expect(item.id, 'msg-uuid-1');
        expect(item.message.role, 'assistant');
        expect(item.message.content, 'Hello from the agent.');
      });
    });

    // -------

    group('ChatToolUseItem', () {
      test('stores toolName and input', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatToolUseItem(
          id: 'evt_123',
          occurredAt: now,
          toolName: 'Read',
          input: {'file_path': '/tmp/test.dart'},
        );

        expect(item.id, 'evt_123');
        expect(item.occurredAt, now);
        expect(item.toolName, 'Read');
        expect(item.input, {'file_path': '/tmp/test.dart'});
      });

      test('input can be null', () {
        final item = ChatToolUseItem(
          id: 'evt_456',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Bash',
        );

        expect(item.input, isNull);
      });

      test('toolUseId defaults to null when not provided', () {
        final item = ChatToolUseItem(
          id: 'evt_789',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Edit',
        );

        expect(item.toolUseId, isNull);
      });

      test('toolUseId stores the correlation id for tool_result matching', () {
        final item = ChatToolUseItem(
          id: 'evt_790',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Bash',
          toolUseId: 'toolu_abc123',
        );

        expect(item.toolUseId, 'toolu_abc123');
      });

      test('result defaults to null when not provided', () {
        final item = ChatToolUseItem(
          id: 'evt_791',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Read',
        );

        expect(item.result, isNull);
      });

      test('result stores the tool output payload', () {
        final item = ChatToolUseItem(
          id: 'evt_792',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Read',
          result: 'file contents here',
        );

        expect(item.result, 'file contents here');
      });

      test('result accepts a Map payload', () {
        final payload = {'exit_code': 0, 'stdout': 'ok'};
        final item = ChatToolUseItem(
          id: 'evt_793',
          occurredAt: DateTime.utc(2026, 3, 29),
          toolName: 'Bash',
          toolUseId: 'toolu_def456',
          result: payload,
        );

        expect(item.toolUseId, 'toolu_def456');
        expect(item.result, payload);
      });
    });

    // -------

    group('ChatThinkingItem', () {
      test('stores content and durationMs', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatThinkingItem(
          id: 'evt_789',
          occurredAt: now,
          content: 'Let me analyze the code...',
          durationMs: 1500,
        );

        expect(item.id, 'evt_789');
        expect(item.occurredAt, now);
        expect(item.content, 'Let me analyze the code...');
        expect(item.durationMs, 1500);
      });

      test('content and durationMs can be null', () {
        final item = ChatThinkingItem(
          id: 'evt_101',
          occurredAt: DateTime.utc(2026, 3, 29),
        );

        expect(item.content, isNull);
        expect(item.durationMs, isNull);
      });
    });

    // -------

    group('ChatSubagentItem', () {
      test('stores all fields for a start event', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatSubagentItem(
          id: 'evt_200',
          occurredAt: now,
          subagentId: 'sub-uuid-1',
          description: 'Researching architecture',
          isComplete: false,
        );

        expect(item.id, 'evt_200');
        expect(item.occurredAt, now);
        expect(item.subagentId, 'sub-uuid-1');
        expect(item.description, 'Researching architecture');
        expect(item.isComplete, isFalse);
        expect(item.toolUseCount, 0);
        expect(item.durationMs, isNull);
      });

      test('stores all fields for a stop event', () {
        final item = ChatSubagentItem(
          id: 'evt_201',
          occurredAt: DateTime.utc(2026, 3, 29, 12, 5, 0),
          subagentId: 'sub-uuid-1',
          isComplete: true,
          children: List.generate(
            12,
            (i) => ChatToolUseItem(
              id: 'tool_$i',
              occurredAt: DateTime.utc(2026, 3, 29, 12, 5, 0),
              toolName: 'Tool',
            ),
          ),
          durationMs: 30000,
        );

        expect(item.isComplete, isTrue);
        expect(item.toolUseCount, 12);
        expect(item.durationMs, 30000);
        expect(item.description, isNull);
      });
    });

    // -------

    group('ChatFileChangeItem', () {
      test('stores operation and filePath', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatFileChangeItem(
          id: 'evt_300',
          occurredAt: now,
          operation: 'M',
          filePath: 'lib/app/models/task.dart',
        );

        expect(item.id, 'evt_300');
        expect(item.occurredAt, now);
        expect(item.operation, 'M');
        expect(item.filePath, 'lib/app/models/task.dart');
      });
    });

    // -------

    group('ChatErrorItem', () {
      test('stores errorText', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatErrorItem(
          id: 'evt_400',
          occurredAt: now,
          errorText: 'Rate limit exceeded',
        );

        expect(item.id, 'evt_400');
        expect(item.occurredAt, now);
        expect(item.errorText, 'Rate limit exceeded');
      });
    });

    // -------

    group('ChatResultItem', () {
      test('stores isError and content', () {
        final now = DateTime.utc(2026, 3, 29, 12, 0, 0);
        final item = ChatResultItem(
          id: 'evt_500',
          occurredAt: now,
          isError: false,
          content: 'Task completed successfully.',
        );

        expect(item.id, 'evt_500');
        expect(item.occurredAt, now);
        expect(item.isError, isFalse);
        expect(item.content, 'Task completed successfully.');
      });

      test('content can be null', () {
        final item = ChatResultItem(
          id: 'evt_501',
          occurredAt: DateTime.utc(2026, 3, 29),
          isError: true,
        );

        expect(item.isError, isTrue);
        expect(item.content, isNull);
      });
    });

    // -------

    group('pattern matching', () {
      test('exhaustive switch covers all subtypes', () {
        final ChatItem item = ChatErrorItem(
          id: 'evt_600',
          occurredAt: DateTime.utc(2026, 3, 29),
          errorText: 'test error',
        );

        final label = switch (item) {
          ChatMessageItem() => 'message',
          ChatToolUseItem() => 'tool_use',
          ChatThinkingItem() => 'thinking',
          ChatSubagentItem() => 'subagent',
          ChatFileChangeItem() => 'file_change',
          ChatErrorItem() => 'error',
          ChatResultItem() => 'result',
        };

        expect(label, 'error');
      });
    });
  });
}
