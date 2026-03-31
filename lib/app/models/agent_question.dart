/// A question raised by an agent during a conversation, awaiting a user answer.
///
/// Maps directly to `AgentQuestionResource` from the Kodizm API.
/// Questions are created when an agent requires human input to proceed.
/// Use [copyWith] to apply optimistic answer updates in the UI.
///
/// ## Usage
/// ```dart
/// final question = AgentQuestion.fromMap(json['question']);
/// final answered = question.copyWith(
///   answerText: 'Yes, proceed.',
///   answeredAt: DateTime.now().toUtc(),
///   answeredByUserId: Auth.id(),
/// );
/// ```
class AgentQuestion {
  // -------

  /// Creates an [AgentQuestion] with all fields.
  const AgentQuestion({
    required this.id,
    required this.conversationId,
    required this.questionText,
    required this.createdAt,
    this.streamEventId,
    this.answerText,
    this.answeredByUserId,
    this.answeredAt,
  });

  // -------

  /// The unique identifier of this question (UUID).
  final String id;

  /// The identifier of the parent conversation (UUID).
  final String conversationId;

  /// The stream event that triggered this question. Null if not event-linked.
  final String? streamEventId;

  /// The question text posed by the agent to the user.
  final String questionText;

  /// The answer provided by the user. Null if not yet answered.
  final String? answerText;

  /// The UUID of the user who answered. Null if not yet answered.
  final String? answeredByUserId;

  /// UTC timestamp when the user submitted the answer. Null if unanswered.
  final DateTime? answeredAt;

  /// UTC timestamp when this question was created.
  final DateTime createdAt;

  // -------

  /// Parses an [AgentQuestion] from a JSON-decoded map.
  ///
  /// Expects the `AgentQuestionResource` shape from the Kodizm API.
  /// All UUID fields are parsed as [String]; DateTime fields via [DateTime.parse].
  factory AgentQuestion.fromMap(Map<String, dynamic> map) {
    return AgentQuestion(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      streamEventId: map['stream_event_id'] as String?,
      questionText: map['question_text'] as String,
      answerText: map['answer_text'] as String?,
      answeredByUserId: map['answered_by_user_id'] as String?,
      answeredAt: map['answered_at'] != null
          ? DateTime.parse(map['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // -------

  /// Returns a copy of this [AgentQuestion] with the specified fields replaced.
  ///
  /// Intended for optimistic answer updates — replace [answerText],
  /// [answeredAt], and [answeredByUserId] without refetching from the API.
  /// All fields not provided retain their current values.
  AgentQuestion copyWith({
    String? answerText,
    DateTime? answeredAt,
    String? answeredByUserId,
  }) {
    return AgentQuestion(
      id: id,
      conversationId: conversationId,
      streamEventId: streamEventId,
      questionText: questionText,
      answerText: answerText ?? this.answerText,
      answeredByUserId: answeredByUserId ?? this.answeredByUserId,
      answeredAt: answeredAt ?? this.answeredAt,
      createdAt: createdAt,
    );
  }
}
