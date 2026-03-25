import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/stream_event.dart';

// ---------------------------------------------------------------------------
// TerminalEventTile
// ---------------------------------------------------------------------------

/// Renders a single [StreamEvent] in the agent terminal output.
///
/// Switches on [StreamEvent.type] to produce visually distinct rows for
/// system messages, assistant text, tool usage, results, file changes,
/// errors, and questions. All styling via Wind UI className tokens from
/// DESIGN.md.
///
/// ## Usage
///
/// ```dart
/// TerminalEventTile(
///   event: streamEvent,
///   isExpanded: _expandedIds.contains(streamEvent.id),
///   onToggleExpand: (id) => setState(() => _expandedIds.toggle(id)),
///   answerText: 'Yes, proceed.',
/// )
/// ```
class TerminalEventTile extends StatelessWidget {
  /// Creates a [TerminalEventTile] for the given [event].
  const TerminalEventTile({
    super.key,
    required this.event,
    this.isExpanded = false,
    this.onToggleExpand,
    this.answerText,
  });

  /// The stream event to render.
  final StreamEvent event;

  /// Whether tool_use details are expanded.
  final bool isExpanded;

  /// Callback to toggle expansion for a tool_use event.
  final void Function(String eventId)? onToggleExpand;

  /// The answer text for this question event, if answered.
  final String? answerText;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Tool use is a sub-type of assistant — check first.
    if (_isToolUse) return _buildToolUse();

    return switch (event.type) {
      'system' => _buildSystem(),
      'assistant' => _buildAssistant(),
      'result' => _buildResult(),
      'file_change' => _buildFileChange(),
      'error' => _buildError(),
      'question' => _buildQuestion(),
      _ => _buildFallback(),
    };
  }

  // -----------------------------------------------------------------------
  // Type checks
  // -----------------------------------------------------------------------

  // Whether this is an assistant event carrying tool_use data.
  bool get _isToolUse =>
      event.type == 'assistant' &&
      (event.data['type'] == 'tool_use' || event.data.containsKey('tool_name'));

  // -----------------------------------------------------------------------
  // Event renderers
  // -----------------------------------------------------------------------

  // System: grey italic monospace.
  Widget _buildSystem() {
    return WDiv(
      className: 'px-4 py-1.5',
      child: WText(
        event.contentText ?? '',
        className: 'text-xs text-slate-400 italic font-mono',
      ),
    );
  }

  // Assistant text: light monospace.
  Widget _buildAssistant() {
    return WDiv(
      className: 'px-4 py-1.5',
      child: WText(
        event.contentText ?? '',
        className: 'text-sm text-slate-100 font-mono',
      ),
    );
  }

  // Tool use: collapsible with icon + tool name.
  Widget _buildToolUse() {
    final toolName =
        event.data['tool_name'] as String? ?? trans('common.unknown');

    final Widget header = WDiv(
      className: 'px-4 py-1.5 flex flex-row items-center gap-2',
      children: [
        WIcon(Icons.build, className: 'text-sm text-blue-400'),
        WText(toolName, className: 'text-sm text-blue-400 font-mono'),
      ],
    );

    if (onToggleExpand == null && !isExpanded) return header;

    final Widget tappableHeader = WAnchor(
      onTap: () => onToggleExpand?.call(event.id),
      child: header,
    );

    if (!isExpanded) return tappableHeader;

    // Expanded: show input/output data below the header.
    final input = event.data['input'];
    final inputText = input != null
        ? const JsonEncoder.withIndent('  ').convert(input)
        : '';

    return WDiv(
      className: 'flex flex-col',
      children: [
        tappableHeader,
        WDiv(
          className:
              'px-6 py-2 mx-2 mb-1 bg-primary-800 rounded-lg overflow-hidden',
          child: WDiv(
            className: 'h-[120] overflow-y-auto',
            child: WText(
              inputText,
              className: 'text-xs text-slate-300 font-mono',
            ),
          ),
        ),
      ],
    );
  }

  // Result success or error.
  Widget _buildResult() {
    final isError = event.data['is_error'] == true;

    if (isError) {
      return WDiv(
        className: 'px-4 py-2 bg-red-500/10 rounded-lg mx-2 my-1',
        child: WText(
          trans('agent_run.result_error'),
          className: 'text-sm text-red-400 font-mono',
        ),
      );
    }

    return WDiv(
      className: 'px-4 py-2 bg-emerald-500/10 rounded-lg mx-2 my-1',
      child: WText(
        trans('agent_run.result_success'),
        className: 'text-sm text-emerald-400 font-mono',
      ),
    );
  }

  // File change: icon + operation badge + path.
  Widget _buildFileChange() {
    final operation = event.data['operation'] as String? ?? '?';
    final path = event.filePath ?? '';

    return WDiv(
      className: 'px-4 py-1.5 flex flex-row items-center gap-2',
      children: [
        WIcon(Icons.insert_drive_file, className: 'text-sm text-cyan-400'),
        WDiv(
          className:
              'px-1.5 py-0.5 rounded ${_operationBadgeClassName(operation)}',
          child: WText(operation, className: 'text-[11px] font-bold font-mono'),
        ),
        WText(path, className: 'text-sm text-cyan-400 font-mono'),
      ],
    );
  }

  // Error: red bold monospace.
  Widget _buildError() {
    return WDiv(
      className: 'px-4 py-1.5',
      child: WText(
        event.contentText ?? '',
        className: 'text-sm text-red-400 font-bold font-mono',
      ),
    );
  }

  // Question: amber container with help icon, and optional answer below.
  Widget _buildQuestion() {
    return WDiv(
      className: 'px-4 py-2 bg-amber-500/10 rounded-lg mx-2 my-1',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(Icons.help_outline, className: 'text-sm text-amber-400'),
            WText(
              event.contentText ?? '',
              className: 'text-sm text-amber-300 font-mono',
            ),
          ],
        ),
        if (answerText != null)
          WDiv(
            className: 'flex flex-row items-center gap-2 mt-1',
            children: [
              WIcon(Icons.check_circle, className: 'text-sm text-emerald-400'),
              WText(
                answerText!,
                className: 'text-sm text-emerald-300 font-mono',
              ),
            ],
          ),
      ],
    );
  }

  // Unknown type: grey italic fallback.
  Widget _buildFallback() {
    return WDiv(
      className: 'px-4 py-1.5',
      child: WText(
        event.contentText ?? '',
        className: 'text-xs text-slate-400 italic font-mono',
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  // Returns className for file operation badge.
  static String _operationBadgeClassName(String operation) {
    return switch (operation) {
      'A' => 'bg-emerald-500/15 text-emerald-400',
      'D' => 'bg-red-500/15 text-red-400',
      'M' => 'bg-blue-500/15 text-blue-400',
      _ => 'bg-slate-500/15 text-slate-400',
    };
  }
}
