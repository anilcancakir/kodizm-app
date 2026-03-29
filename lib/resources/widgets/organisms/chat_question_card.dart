import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A card widget that presents a pending agent question to the user.
///
/// Displays the question message with an amber left-border accent, an optional
/// header, clickable option cards for structured choices, and a free-form
/// fallback text input for open-ended answers.
///
/// ## Usage
///
/// ```dart
/// ChatQuestionCard(
///   question: {
///     'questionId': 'q-uuid',
///     'message': 'Which approach should I use?',
///     'header': 'Design Decision',
///     'options': [
///       {'label': 'Option A', 'description': 'Faster but less flexible'},
///       {'label': 'Option B'},
///     ],
///   },
///   isDisabled: false,
///   answerController: _controller,
///   onAnswer: (questionId, answer) => state.submitAnswer(questionId, answer),
/// )
/// ```
class ChatQuestionCard extends StatelessWidget {
  /// Creates a [ChatQuestionCard].
  const ChatQuestionCard({
    required this.question,
    required this.isDisabled,
    required this.answerController,
    required this.onAnswer,
    super.key,
  });

  /// The question payload from the agent.
  ///
  /// Expected shape:
  /// ```json
  /// {
  ///   "questionId": "String",
  ///   "message": "String",
  ///   "header": "String?",
  ///   "options": [{"label": "String", "description": "String?"}]?
  /// }
  /// ```
  final Map<String, dynamic> question;

  /// Whether answer submission is currently in progress.
  final bool isDisabled;

  /// Controller for the free-form answer input.
  final TextEditingController answerController;

  /// Callback invoked when the user selects an option or submits free-form input.
  final void Function(String questionId, String answer) onAnswer;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final questionId = question['questionId'] as String? ?? '';
    final message = question['message'] as String? ?? '';
    final header = question['header'] as String?;
    final options = question['options'] as List<dynamic>?;

    return WDiv(
      className:
          'mx-4 mb-3 p-4 rounded-xl border-l-4 border-amber-400 bg-amber-50 dark:bg-amber-900/10',
      children: [
        // -------
        // Header row — icon + title
        // -------
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-3',
          children: [
            WIcon(Icons.help_outline, className: 'text-amber-600 text-lg'),
            WText(
              trans('conversation_chat.question_title'),
              className: 'text-sm font-semibold text-amber-700',
            ),
          ],
        ),

        // -------
        // Optional header text
        // -------
        if (header != null)
          WText(header, className: 'text-base font-medium mb-2'),

        // -------
        // Question message
        // -------
        WText(
          message,
          className: 'text-sm text-slate-700 dark:text-slate-300 mb-3',
        ),

        // -------
        // Option cards
        // -------
        if (options != null)
          ...options.map((raw) {
            final option = raw as Map<String, dynamic>;
            final label = option['label'] as String? ?? '';
            final description = option['description'] as String?;

            return WAnchor(
              onTap: isDisabled ? null : () => onAnswer(questionId, label),
              child: WDiv(
                className:
                    'p-3 rounded-lg border border-slate-200 dark:border-slate-700 hover:border-amber-400 mb-2',
                children: [
                  WText(label, className: 'text-sm font-medium'),
                  if (description != null)
                    WText(description, className: 'text-xs text-slate-500'),
                ],
              ),
            );
          }),

        // -------
        // Free-form fallback input row
        // -------
        WDiv(
          className: 'flex flex-row gap-2 mt-2',
          children: [
            WDiv(
              className: 'flex-1',
              child: WFormInput(
                controller: answerController,
                label: trans('conversation_chat.answer_placeholder'),
              ),
            ),
            WAnchor(
              onTap: isDisabled
                  ? null
                  : () {
                      final answer = answerController.text.trim();
                      if (answer.isEmpty) return;
                      onAnswer(questionId, answer);
                      answerController.clear();
                    },
              child: WDiv(
                className:
                    'px-4 py-2 rounded-lg ${isDisabled ? 'bg-slate-300 dark:bg-slate-600' : 'bg-amber-400'}',
                child: WText(
                  isDisabled
                      ? trans('conversation_chat.question_submitting')
                      : trans('conversation_chat.question_submit'),
                  className: 'text-sm font-medium text-slate-900',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
