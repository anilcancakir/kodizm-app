import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/stream_event.dart';

void main() {
  group('StreamEvent', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'event-uuid-1',
      'task_run_id': 'run-uuid-1',
      'type': 'system',
      'data': {'key': 'value', 'count': 3},
      'content_text': 'Agent started successfully.',
      'file_path': 'lib/app/models/task.dart',
      'is_question': false,
      'occurred_at': '2026-03-25T10:00:00.000000Z',
      'created_at': '2026-03-25T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'event-uuid-2',
      'task_run_id': 'run-uuid-2',
      'type': 'tool_result',
      'data': <String, dynamic>{},
      'content_text': null,
      'file_path': null,
      'is_question': true,
      'occurred_at': '2026-03-25T11:00:00.000000Z',
      'created_at': '2026-03-25T11:00:00.000000Z',
    };

    const Map<String, dynamic> typePreservationFixture = {
      'id': 'event-uuid-3',
      'task_run_id': 'run-uuid-3',
      'type': 'assistant_delta',
      'data': <String, dynamic>{},
      'content_text': null,
      'file_path': null,
      'is_question': false,
      'occurred_at': '2026-03-25T12:00:00.000000Z',
      'created_at': '2026-03-25T12:00:00.000000Z',
    };

    // -------

    test('fromMap parses all required fields from a full payload', () {
      final event = StreamEvent.fromMap(fullFixture);

      expect(event.id, 'event-uuid-1');
      expect(event.taskRunId, 'run-uuid-1');
      expect(event.type, 'system');
      expect(event.data, {'key': 'value', 'count': 3});
      expect(event.contentText, 'Agent started successfully.');
      expect(event.filePath, 'lib/app/models/task.dart');
      expect(event.isQuestion, isFalse);
      expect(event.occurredAt, DateTime.parse('2026-03-25T10:00:00.000000Z'));
    });

    test('fromMap leaves optional fields null when absent from payload', () {
      final event = StreamEvent.fromMap(minimalFixture);

      expect(event.contentText, isNull);
      expect(event.filePath, isNull);
      expect(event.isQuestion, isTrue);
    });

    test(
      'fromMap preserves the type string value as-is without transformation',
      () {
        final event = StreamEvent.fromMap(typePreservationFixture);

        expect(event.type, 'assistant_delta');
      },
    );

    test('fromMap parses occurredAt as UTC DateTime', () {
      final event = StreamEvent.fromMap(fullFixture);

      expect(event.occurredAt.isUtc, isTrue);
      expect(event.occurredAt.year, 2026);
      expect(event.occurredAt.month, 3);
      expect(event.occurredAt.day, 25);
    });

    test('fromMap parses data as Map<String, dynamic>', () {
      final event = StreamEvent.fromMap(fullFixture);

      expect(event.data, isA<Map<String, dynamic>>());
      expect(event.data['key'], 'value');
      expect(event.data['count'], 3);
    });
  });
}
