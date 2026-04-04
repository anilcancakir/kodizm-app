import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A card widget that presents a pending agent question to the user.
///
/// Displays the question message with an amber left-border accent, clickable
/// option cards for structured choices, and a free-form text input with a
/// submit button aligned on the same row.
///
/// ## Usage
///
/// ```dart
/// ChatQuestionCard(
///   question: {
///     'questionId': 'q-uuid',
///     'message': 'Which approach should I use?',
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
  ///   "options": [{"label": "String", "description": "String?"}]?
  /// }
  /// ```
  final Map<String, dynamic> question;

  /// Whether answer submission is currently in progress.
  final bool isDisabled;

  /// Controller for the free-form answer input.
  final TextEditingController answerController;

  /// Callback invoked when the user selects an option or submits free-form
  /// input. Parameters: `(questionId, answerText)`.
  final void Function(String questionId, String answer) onAnswer;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final questionId = question['questionId'] as String? ?? '';
    final message = question['message'] as String? ?? '';
    final options = question['options'] as List<dynamic>?;

    return WDiv(
      className: '''
        mx-4 mb-3 rounded-xl border-l-4 border-amber-400
        bg-white dark:bg-slate-800
        shadow-sm
      ''',
      children: [
        // -------
        // Header row — icon + title
        // -------
        WDiv(
          className: 'px-4 pt-4 pb-2 flex flex-row items-center gap-2',
          children: [
            WIcon(
              Icons.help_outline_rounded,
              className: 'text-amber-500 text-base',
            ),
            WText(
              trans('conversation_chat.question_title'),
              className:
                  'text-xs font-semibold tracking-wide uppercase text-amber-600 dark:text-amber-400',
            ),
          ],
        ),

        // -------
        // Question message
        // -------
        if (message.isNotEmpty)
          WDiv(
            className: 'px-4 pb-3',
            child: WText(
              message,
              className: 'text-sm text-slate-700 dark:text-slate-300',
            ),
          ),

        // -------
        // Option cards
        // -------
        if (options != null)
          WDiv(
            className: 'px-4 pb-2 flex flex-col gap-2',
            children: options.map((raw) {
              final option = raw as Map<String, dynamic>;
              final label = option['label'] as String? ?? '';
              final description = option['description'] as String?;

              return WAnchor(
                onTap: isDisabled ? null : () => onAnswer(questionId, label),
                child: WDiv(
                  className:
                      '''
                    p-3 rounded-lg
                    border border-slate-200 dark:border-slate-700
                    bg-slate-50 dark:bg-slate-800/50
                    ${isDisabled ? 'opacity-50' : ''}
                  ''',
                  children: [
                    WText(
                      label,
                      className:
                          'text-sm font-medium text-slate-800 dark:text-slate-200',
                    ),
                    if (description != null)
                      WText(
                        description,
                        className:
                            'text-xs text-slate-500 dark:text-slate-400 mt-0.5',
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

        // -------
        // Free-form input + submit button — same row, aligned
        // -------
        WDiv(
          className: 'px-4 pb-4 pt-1 flex flex-row items-end gap-2',
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
                    '''
                  px-4 py-2.5 rounded-lg
                  ${isDisabled ? 'bg-secondary-400 opacity-50' : 'bg-secondary-400'}
                ''',
                child: WText(
                  isDisabled
                      ? trans('conversation_chat.question_submitting')
                      : trans('conversation_chat.question_submit'),
                  className: 'text-sm font-medium text-primary-900',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
