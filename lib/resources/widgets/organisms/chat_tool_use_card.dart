import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// A collapsible card displaying a tool use block within a chat message.
///
/// Shows the tool name in a compact header. When expanded, displays
/// the JSON input and result payloads in a mono-spaced, selectable format.
///
/// ## Usage
///
/// ```dart
/// ChatToolUseCard(
///   toolName: 'ReadFile',
///   input: {'path': '/src/main.dart'},
///   result: {'content': '...'},
/// )
/// ```
class ChatToolUseCard extends StatefulWidget {
  /// Creates a [ChatToolUseCard].
  const ChatToolUseCard({
    required this.toolName,
    this.input,
    this.result,
    super.key,
  });

  /// The name of the tool that was invoked.
  final String toolName;

  /// The input parameters passed to the tool. Null if not available.
  final dynamic input;

  /// The result returned by the tool. Null if not available.
  final dynamic result;

  @override
  State<ChatToolUseCard> createState() => _ChatToolUseCardState();
}

class _ChatToolUseCardState extends State<ChatToolUseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'rounded-lg border border-slate-200 dark:border-slate-700',
      children: [
        // Header — always visible, tappable
        WAnchor(
          onTap: () => setState(() => _expanded = !_expanded),
          child: WDiv(
            className: '''
              flex flex-row items-center gap-2
              px-3 py-2 bg-slate-50 dark:bg-slate-800
              rounded-lg cursor-pointer
            ''',
            children: [
              WIcon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                className: 'text-sm text-slate-400',
              ),
              WIcon(Icons.build_outlined, className: 'text-sm text-slate-500'),
              WText(
                trans('conversation_chat.tool_name', {'name': widget.toolName}),
                className:
                    'text-xs font-medium font-mono text-slate-600 dark:text-slate-300',
              ),
            ],
          ),
        ),

        // Expanded content — input + result JSON
        if (_expanded) ...[
          // Input section
          if (widget.input != null)
            WDiv(
              className: 'px-3 py-2',
              children: [
                WText(
                  trans('conversation_chat.tool_input'),
                  className: 'text-[11px] font-semibold text-slate-400 mb-1',
                ),
                WDiv(
                  className: '''
                    bg-slate-100 dark:bg-slate-900
                    p-2 rounded overflow-hidden
                  ''',
                  child: SelectableText(
                    _formatJson(widget.input),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
              ],
            ),

          // Result section
          if (widget.result != null)
            WDiv(
              className: 'px-3 py-2',
              children: [
                WText(
                  trans('conversation_chat.tool_result'),
                  className: 'text-[11px] font-semibold text-slate-400 mb-1',
                ),
                WDiv(
                  className: '''
                    bg-slate-100 dark:bg-slate-900
                    p-2 rounded overflow-hidden
                  ''',
                  child: SelectableText(
                    _formatJson(widget.result),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  /// Pretty-prints a JSON-serialisable value with 2-space indentation.
  String _formatJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
