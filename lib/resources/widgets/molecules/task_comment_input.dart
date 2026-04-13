import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_role.dart';

/// Comment input for triggering custom agent runs from the task detail page.
///
/// Renders a multiline text field with an inline agent role selector and send
/// button. The user types custom instructions, optionally picks a role, then
/// submits to start an autonomous run with that prompt.
///
/// Pre-selects the `main-agent` role when available in [roles], otherwise
/// falls back to the first role. The send button is disabled when the input
/// is empty or [enabled] is false.
///
/// ## Usage
///
/// ```dart
/// TaskCommentInput(
///   roles: state.agentRoles,
///   onSubmit: (prompt, roleId) async {
///     await state.startRun(teamId, projectId, taskId, roleId, prompt: prompt);
///   },
/// )
/// ```
class TaskCommentInput extends StatefulWidget {
  /// Creates a [TaskCommentInput].
  const TaskCommentInput({
    required this.roles,
    required this.onSubmit,
    this.enabled = true,
    super.key,
  });

  /// Available agent roles for the role selector dropdown.
  final List<AgentRole> roles;

  /// Callback fired on submit with the prompt text and selected role ID.
  /// Returns a [Future] — the widget disables input during execution.
  final Future<void> Function(String prompt, String agentRoleId) onSubmit;

  /// Whether the input is interactive. Set to `false` during active runs.
  final bool enabled;

  @override
  State<TaskCommentInput> createState() => _TaskCommentInputState();
}

class _TaskCommentInputState extends State<TaskCommentInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEmpty = true;
  bool _submitting = false;
  String? _selectedRoleId;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.onKeyEvent = _onKeyEvent;
    _selectedRoleId = _defaultRoleId();
  }

  @override
  void didUpdateWidget(covariant TaskCommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roles != oldWidget.roles) {
      final currentStillValid = widget.roles.any(
        (r) => r.id == _selectedRoleId,
      );
      if (!currentStillValid) {
        _selectedRoleId = _defaultRoleId();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.onKeyEvent = null;
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Resolves the default role ID — prefers `main-agent` slug, else first.
  String? _defaultRoleId() {
    if (widget.roles.isEmpty) return null;
    final mainAgent = widget.roles.cast<AgentRole?>().firstWhere(
      (r) => r?.slug == 'main-agent',
      orElse: () => null,
    );
    return mainAgent?.id ?? widget.roles.first.id;
  }

  void _onTextChanged() {
    final empty = _controller.text.trim().isEmpty;
    if (empty != _isEmpty) {
      setState(() => _isEmpty = empty);
    }
  }

  bool get _canSend =>
      !_isEmpty && !_submitting && widget.enabled && _selectedRoleId != null;

  /// Handles keyboard events — Enter sends, Shift+Enter inserts newline.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!isEnter) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    if (_canSend) _handleSubmit();

    return KeyEventResult.handled;
  }

  /// Submits the prompt and clears the input on success.
  Future<void> _handleSubmit() async {
    if (!_canSend) return;

    final prompt = _controller.text.trim();
    final roleId = _selectedRoleId!;

    setState(() => _submitting = true);

    try {
      await widget.onSubmit(prompt, roleId);
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WDiv(
      className: '''
        flex flex-col gap-3 p-4 rounded-2xl
        border border-slate-200 dark:border-slate-700
        bg-white dark:bg-slate-800
      ''',
      children: [
        // Input row — text field + send button
        WDiv(
          className: 'flex flex-row gap-3 items-end',
          children: [
            // Multiline text input
            WDiv(
              className:
                  'flex-1 px-4 py-2.5 rounded-xl bg-slate-100 dark:bg-slate-900',
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                readOnly: !widget.enabled || _submitting,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  fontFamily: 'AlbertSans',
                  fontSize: 14,
                  color: WindTheme.dataOf(
                    context,
                  ).getColor('slate', isDark ? 100 : 800),
                ),
                decoration: InputDecoration.collapsed(
                  hintText: trans('tasks.comment_placeholder'),
                  hintStyle: TextStyle(
                    fontFamily: 'AlbertSans',
                    fontSize: 14,
                    color: WindTheme.dataOf(context).getColor('slate', 400),
                  ),
                ),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),

            // Send button
            WAnchor(
              onTap: _canSend ? _handleSubmit : null,
              child: WDiv(
                className: _canSend
                    ? '''
                      w-10 h-10 rounded-full bg-amber-400
                      flex items-center justify-center
                    '''
                    : '''
                      w-10 h-10 rounded-full bg-slate-200 dark:bg-slate-700
                      flex items-center justify-center
                    ''',
                child: _submitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )
                    : WIcon(
                        Icons.send,
                        className: _canSend
                            ? 'text-base text-primary-900'
                            : 'text-base text-slate-400',
                      ),
              ),
            ),
          ],
        ),

        // Role selector row
        if (widget.roles.length > 1)
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WIcon(
                Icons.smart_toy_outlined,
                className: 'text-sm text-slate-400 dark:text-slate-500',
              ),
              WText(
                trans('tasks.comment_select_role'),
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
              // Native dropdown — no Wind UI equivalent for select menus
              Flexible(
                child: DropdownButton<String>(
                  value: _selectedRoleId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: TextStyle(
                    fontFamily: 'AlbertSans',
                    fontSize: 12,
                    color: WindTheme.dataOf(
                      context,
                    ).getColor('slate', isDark ? 300 : 600),
                  ),
                  dropdownColor: isDark
                      ? WindTheme.dataOf(context).getColor('slate', 800)
                      : Colors.white,
                  items: widget.roles.map((role) {
                    return DropdownMenuItem<String>(
                      value: role.id,
                      child: Text(role.name),
                    );
                  }).toList(),
                  onChanged: widget.enabled && !_submitting
                      ? (value) => setState(() => _selectedRoleId = value)
                      : null,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
