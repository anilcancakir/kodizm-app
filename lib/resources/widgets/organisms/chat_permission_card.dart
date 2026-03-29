import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A card displayed in the chat stream when the AI requests a tool permission.
///
/// Renders a blue-accented card with the tool name, optional JSON input
/// preview, and approve/deny action buttons.
///
/// ## Usage
///
/// ```dart
/// ChatPermissionCard(
///   permission: {
///     'questionId': 'abc-123',
///     'toolName': 'WriteFile',
///     'input': {'path': '/tmp/out.txt'},
///   },
///   isDisabled: false,
///   onAnswer: (questionId, answer) { ... },
/// )
/// ```
class ChatPermissionCard extends StatelessWidget {
  /// Creates a [ChatPermissionCard].
  const ChatPermissionCard({
    required this.permission,
    required this.isDisabled,
    required this.onAnswer,
    super.key,
  });

  /// Permission payload: `{questionId: String, toolName: String, input: dynamic}`.
  final Map<String, dynamic> permission;

  /// Whether answer submission is in progress; disables action buttons when true.
  final bool isDisabled;

  /// Called with `(questionId, answer)` when the user taps approve or deny.
  final void Function(String questionId, String answer) onAnswer;

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  String get _questionId => permission['questionId'] as String? ?? '';
  String get _toolName => permission['toolName'] as String? ?? '';
  dynamic get _input => permission['input'];

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className:
          'mx-4 mb-3 p-4 rounded-xl border-l-4 border-blue-400 bg-blue-50 dark:bg-blue-900/10',
      children: [
        // -------
        // Header
        // -------
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-3',
          children: [
            WIcon(Icons.shield_outlined, className: 'text-blue-600 text-lg'),
            WText(
              trans('conversation_chat.permission_title'),
              className: 'text-sm font-semibold text-blue-700',
            ),
          ],
        ),

        // -------
        // Tool name
        // -------
        WText(
          trans('conversation_chat.permission_tool', {'tool': _toolName}),
          className: 'font-mono text-sm',
        ),

        // -------
        // Input JSON (optional)
        // -------
        if (_input != null)
          WDiv(
            className:
                'bg-slate-100 dark:bg-slate-800 p-3 rounded-lg overflow-hidden mt-2',
            child: SelectableText(
              jsonEncode(_input),
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),

        // -------
        // Action buttons
        // -------
        WDiv(
          className: 'w-full flex flex-row gap-3 mt-3',
          children: [
            WAnchor(
              onTap: isDisabled ? null : () => onAnswer(_questionId, 'approve'),
              child: WDiv(
                className: 'px-4 py-2 bg-emerald-500 rounded-lg',
                child: WText(
                  trans('conversation_chat.permission_approve'),
                  className: 'text-white text-sm font-medium',
                ),
              ),
            ),
            WAnchor(
              onTap: isDisabled ? null : () => onAnswer(_questionId, 'deny'),
              child: WDiv(
                className: 'px-4 py-2 border border-red-500 rounded-lg',
                child: WText(
                  trans('conversation_chat.permission_deny'),
                  className: 'text-red-500 text-sm font-medium',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
