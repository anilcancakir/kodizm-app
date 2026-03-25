import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/stream_event.dart';
import 'package:app/resources/widgets/atoms/terminal_event_tile.dart';

// ---------------------------------------------------------------------------
// TerminalEventList
// ---------------------------------------------------------------------------

/// A scrollable list of [TerminalEventTile] widgets rendered inside a
/// dark terminal-style container.
///
/// Manages local expansion state for tool_use events via an internal
/// `Set<String>` of expanded event IDs.
///
/// ## Usage
///
/// ```dart
/// TerminalEventList(
///   events: taskRunState.events,
///   scrollController: _terminalScrollController,
/// )
/// ```
class TerminalEventList extends StatefulWidget {
  /// Creates a [TerminalEventList].
  const TerminalEventList({
    super.key,
    required this.events,
    required this.scrollController,
  });

  /// The ordered list of stream events to display.
  final List<StreamEvent> events;

  /// External scroll controller — allows parent to auto-scroll to bottom.
  final ScrollController scrollController;

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
    return WDiv(
      className: 'bg-primary-900 rounded-2xl overflow-hidden',
      child: ListView.builder(
        controller: widget.scrollController,
        itemCount: widget.events.length,
        itemBuilder: (context, index) {
          final event = widget.events[index];

          return TerminalEventTile(
            event: event,
            isExpanded: _expandedToolUseIds.contains(event.id),
            onToggleExpand: _handleToggleExpand,
          );
        },
      ),
    );
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
