import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/agent_question.dart';

void main() {
  group('AgentQuestion', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'question-uuid-1',
      'conversation_id': 'run-uuid-1',
      'stream_event_id': 'event-uuid-1',
      'question_text': 'Should I proceed with the refactor?',
      'answer_text': 'Yes, go ahead.',
      'answered_by_user_id': 'user-uuid-1',
      'answered_at': '2026-03-25T12:00:00.000000Z',
      'created_at': '2026-03-25T10:00:00.000000Z',
    };

    const Map<String, dynamic> minimalFixture = {
      'id': 'question-uuid-2',
      'conversation_id': 'run-uuid-2',
      'stream_event_id': null,
      'question_text': 'Which branch should I target?',
      'answer_text': null,
      'answered_by_user_id': null,
      'answered_at': null,
      'created_at': '2026-03-25T11:00:00.000000Z',
    };

    // -------

    test('fromMap parses all fields from a full payload', () {
      final question = AgentQuestion.fromMap(fullFixture);

      expect(question.id, 'question-uuid-1');
      expect(question.conversationId, 'run-uuid-1');
      expect(question.streamEventId, 'event-uuid-1');
      expect(question.questionText, 'Should I proceed with the refactor?');
      expect(question.answerText, 'Yes, go ahead.');
      expect(question.answeredByUserId, 'user-uuid-1');
      expect(
        question.answeredAt,
        DateTime.parse('2026-03-25T12:00:00.000000Z'),
      );
      expect(question.createdAt, DateTime.parse('2026-03-25T10:00:00.000000Z'));
    });

    test('fromMap leaves optional fields null when absent from payload', () {
      final question = AgentQuestion.fromMap(minimalFixture);

      expect(question.streamEventId, isNull);
      expect(question.answerText, isNull);
      expect(question.answeredByUserId, isNull);
      expect(question.answeredAt, isNull);
    });

    test('fromMap parses DateTime fields as UTC', () {
      final question = AgentQuestion.fromMap(fullFixture);

      expect(question.createdAt.isUtc, isTrue);
      expect(question.answeredAt!.isUtc, isTrue);
      expect(question.createdAt.year, 2026);
      expect(question.createdAt.month, 3);
      expect(question.createdAt.day, 25);
    });

    test(
      'copyWith replaces answerText and answeredAt for optimistic update',
      () {
        final original = AgentQuestion.fromMap(minimalFixture);
        final answered = DateTime.parse('2026-03-26T09:00:00.000000Z');

        final updated = original.copyWith(
          answerText: 'Use the main branch.',
          answeredAt: answered,
          answeredByUserId: 'user-uuid-99',
        );

        expect(updated.answerText, 'Use the main branch.');
        expect(updated.answeredAt, answered);
        expect(updated.answeredByUserId, 'user-uuid-99');
        // Immutable fields must be preserved.
        expect(updated.id, original.id);
        expect(updated.conversationId, original.conversationId);
        expect(updated.questionText, original.questionText);
        expect(updated.createdAt, original.createdAt);
      },
    );

    test('copyWith without arguments returns equivalent instance', () {
      final original = AgentQuestion.fromMap(fullFixture);
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.answerText, original.answerText);
      expect(copy.answeredAt, original.answeredAt);
      expect(copy.answeredByUserId, original.answeredByUserId);
    });
  });
}
