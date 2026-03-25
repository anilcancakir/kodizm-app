import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_question.dart';

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Slide-in panel that displays the current pending [AgentQuestion] and
/// collects a text answer from the user.
///
/// The panel is hidden (via [AnimatedSize]) when there are no pending
/// questions. Only the first pending question is shown at a time.
///
/// ## Usage
///
/// ```dart
/// QuestionPanel(
///   questions: state.questions,
///   onSubmitAnswer: (text) => state.submitAnswer(text),
///   isSubmitting: state.isSubmitting,
/// )
/// ```
class QuestionPanel extends StatefulWidget {
  /// Creates a [QuestionPanel].
  ///
  /// [questions] is the full question list; pending ones are filtered
  /// internally. [onSubmitAnswer] is called with the trimmed answer text
  /// when the user taps send. [isSubmitting] disables the send button while
  /// an answer is in-flight.
  const QuestionPanel({
    super.key,
    required this.questions,
    required this.onSubmitAnswer,
    required this.isSubmitting,
  });

  /// The full list of questions for the current task run.
  final List<AgentQuestion> questions;

  /// Callback invoked with the trimmed answer text when the user sends.
  final void Function(String answerText) onSubmitAnswer;

  /// Whether an answer submission is currently in progress.
  final bool isSubmitting;

  @override
  State<QuestionPanel> createState() => _QuestionPanelState();
}

// ---------------------------------------------------------------------------
// Private state
// ---------------------------------------------------------------------------

class _QuestionPanelState extends State<QuestionPanel> {
  // -------

  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Updates [_hasText] whenever the controller value changes.
  void _onTextChanged() {
    final bool nowHasText = _controller.text.trim().isNotEmpty;
    if (nowHasText != _hasText) {
      setState(() => _hasText = nowHasText);
    }
  }

  /// Returns questions that have not yet been answered.
  List<AgentQuestion> get _pending =>
      widget.questions.where((q) => q.answeredAt == null).toList();

  /// Whether the send button should accept taps.
  bool get _canSend => _hasText && !widget.isSubmitting;

  /// Submits the current answer text.
  void _submit() {
    if (!_canSend) return;
    final String text = _controller.text.trim();
    widget.onSubmitAnswer(text);
    _controller.clear();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final List<AgentQuestion> pending = _pending;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: pending.isEmpty
          ? const WDiv(className: '', children: [])
          : _buildPanel(pending.first),
    );
  }

  /// Builds the visible panel for [question].
  Widget _buildPanel(AgentQuestion question) {
    return WDiv(
      className: '''
        p-4
        bg-amber-50 dark:bg-amber-900/10
        border-t border-amber-200 dark:border-amber-800
        flex flex-col gap-3
      ''',
      children: [
        _buildHeader(),
        _buildQuestionText(question),
        _buildInputRow(),
      ],
    );
  }

  /// Builds the header row with icon and title.
  Widget _buildHeader() {
    return WDiv(
      className: 'flex flex-row items-center gap-2',
      children: [
        WIcon(Icons.help_outline, className: 'text-base text-amber-500'),
        WText(
          trans('question.panel_title'),
          className: 'text-sm font-semibold text-amber-600 dark:text-amber-400',
        ),
      ],
    );
  }

  /// Builds the question text display.
  Widget _buildQuestionText(AgentQuestion question) {
    return WText(
      question.questionText,
      className: 'text-sm text-slate-700 dark:text-slate-300',
    );
  }

  /// Builds the answer input row with [WFormInput] and send [WAnchor].
  Widget _buildInputRow() {
    return WDiv(
      className: 'flex flex-row items-end gap-2',
      children: [
        WDiv(
          className: 'flex-1',
          child: WFormInput(
            controller: _controller,
            type: InputType.multiline,
            label: trans('question.answer_placeholder'),
            maxLines: 3,
            minLines: 1,
          ),
        ),
        _buildSendButton(),
      ],
    );
  }

  /// Builds the send button — spinner when submitting, icon otherwise.
  Widget _buildSendButton() {
    return WAnchor(
      onTap: _canSend ? _submit : null,
      child: WDiv(
        className: '''
          p-2.5 rounded-lg
          bg-amber-500
          items-center justify-center
        ''',
        child: widget.isSubmitting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : WIcon(Icons.send, className: 'text-sm text-white'),
      ),
    );
  }
}
