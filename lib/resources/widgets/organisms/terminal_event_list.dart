import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_question.dart';
import '../../../app/models/stream_event.dart';
import '../atoms/terminal_event_tile.dart';

// ---------------------------------------------------------------------------
// TerminalEventList
// ---------------------------------------------------------------------------

/// A scrollable list of [TerminalEventTile] widgets rendered inside a
/// dark terminal-style container.
///
/// Manages local expansion state for tool_use events via an internal
/// `Set<String>` of expanded event IDs. Threads answer text from [questions]
/// to matching question events via `event.data['question_id']`.
///
/// ## Usage
///
/// ```dart
/// TerminalEventList(
///   events: taskRunState.events,
///   scrollController: _terminalScrollController,
///   questions: agentRunState.questions,
/// )
/// ```
class TerminalEventList extends StatefulWidget {
  /// Creates a [TerminalEventList].
  const TerminalEventList({
    super.key,
    required this.events,
    required this.scrollController,
    this.questions = const [],
  });

  /// The ordered list of stream events to display.
  final List<StreamEvent> events;

  /// External scroll controller — allows parent to auto-scroll to bottom.
  final ScrollController scrollController;

  /// Questions for the current run — used to thread answer text to question events.
  final List<AgentQuestion> questions;

  @override
  State<TerminalEventList> createState() => _TerminalEventListState();
}

class _TerminalEventListState extends State<TerminalEventList> {
  // IDs of tool_use events that are currently expanded.
  final Set<String> _expandedToolUseIds = {};

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final items = _buildItemsWithSeparators();

    return WDiv(
      className: 'bg-primary-900 rounded-2xl overflow-hidden',
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build items with turn separators
  // -----------------------------------------------------------------------

  /// Builds the list of widgets including turn separators between groups
  /// of events that have different [StreamEvent.turnNumber] values.
  List<Widget> _buildItemsWithSeparators() {
    final List<Widget> items = [];
    int? lastTurnNumber;

    for (final event in widget.events) {
      // Insert turn separator when turnNumber changes.
      if (event.turnNumber != null &&
          lastTurnNumber != null &&
          event.turnNumber != lastTurnNumber) {
        items.add(WDiv(className: 'border-t border-slate-100 my-1'));
      }

      if (event.turnNumber != null) {
        lastTurnNumber = event.turnNumber;
      }

      // Match question events to their answers.
      String? answerText;
      if (event.type == 'question' || event.isQuestion) {
        final questionId = event.data['question_id'] as String?;
        if (questionId != null) {
          final match = widget.questions
              .where((q) => q.id == questionId)
              .firstOrNull;
          answerText = match?.answerText;
        }
      }

      items.add(
        TerminalEventTile(
          event: event,
          isExpanded: _expandedToolUseIds.contains(event.id),
          onToggleExpand: _handleToggleExpand,
          answerText: answerText,
          subagentId: event.subagentId,
          turnNumber: event.turnNumber,
        ),
      );
    }

    return items;
  }

  // -----------------------------------------------------------------------
  // Handlers
  // -----------------------------------------------------------------------

  // Toggles expansion state for a tool_use event.
  void _handleToggleExpand(String eventId) {
    setState(() {
      if (_expandedToolUseIds.contains(eventId)) {
        _expandedToolUseIds.remove(eventId);
      } else {
        _expandedToolUseIds.add(eventId);
      }
    });
  }
}
