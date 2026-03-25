import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/stream_event.dart';
import 'package:app/resources/widgets/atoms/terminal_event_tile.dart';
import 'package:app/resources/widgets/organisms/terminal_event_list.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a widget inside the standard Wind UI + MaterialApp scaffold.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Shorthand factory for StreamEvent fixtures.
StreamEvent _event({
  String id = 'evt-1',
  String type = 'system',
  String? contentText,
  String? filePath,
  bool isQuestion = false,
  Map<String, dynamic> data = const {},
}) {
  return StreamEvent(
    id: id,
    taskRunId: 'run-1',
    type: type,
    data: data,
    contentText: contentText,
    filePath: filePath,
    isQuestion: isQuestion,
    occurredAt: DateTime.utc(2026, 3, 25),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. System event — grey italic text
  // -------------------------------------------------------------------------

  testWidgets('system event renders grey italic text', (tester) async {
    final event = _event(
      type: 'system',
      contentText: 'Agent container started',
    );

    await _pump(tester, TerminalEventTile(event: event));

    expect(find.text('Agent container started'), findsOneWidget);
    // The WText should exist with the system styling.
    expect(find.byType(WText), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Assistant text event — light text
  // -------------------------------------------------------------------------

  testWidgets('assistant text event renders light content', (tester) async {
    final event = _event(
      type: 'assistant',
      contentText: 'Analyzing the codebase...',
    );

    await _pump(tester, TerminalEventTile(event: event));

    expect(find.text('Analyzing the codebase...'), findsOneWidget);
    expect(find.byType(WText), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Tool use — collapsed by default, shows tool name + icon
  // -------------------------------------------------------------------------

  testWidgets('tool_use event renders collapsed with icon and tool name', (
    tester,
  ) async {
    final event = _event(
      id: 'evt-tool-1',
      type: 'assistant',
      data: {
        'type': 'tool_use',
        'tool_name': 'Read',
        'input': {'file': 'main.dart'},
      },
    );

    await _pump(tester, TerminalEventTile(event: event));

    // Tool name visible.
    expect(find.text('Read'), findsOneWidget);
    // Build icon for tool_use.
    expect(find.byIcon(Icons.build), findsOneWidget);
    // Input details should NOT be visible when collapsed.
    expect(find.text('main.dart'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Tool use — expanded shows input data
  // -------------------------------------------------------------------------

  testWidgets('tool_use event expanded shows input data', (tester) async {
    final event = _event(
      id: 'evt-tool-2',
      type: 'assistant',
      data: {
        'type': 'tool_use',
        'tool_name': 'Edit',
        'input': {'file': 'lib/main.dart', 'content': 'void main() {}'},
      },
    );

    await _pump(
      tester,
      TerminalEventTile(event: event, isExpanded: true, onToggleExpand: (_) {}),
    );

    // Tool name visible.
    expect(find.text('Edit'), findsOneWidget);
    // Expanded content should show input key/value.
    expect(find.textContaining('lib/main.dart'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Result success — green background
  // -------------------------------------------------------------------------

  testWidgets('result success event renders green container', (tester) async {
    final event = _event(
      type: 'result',
      data: {'is_error': false, 'duration_ms': 1200, 'cost': 0.003},
    );

    await _pump(tester, TerminalEventTile(event: event));

    // Should show the success label.
    expect(
      find.textContaining(trans('agent_run.result_success')),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 6. Result error — red background
  // -------------------------------------------------------------------------

  testWidgets('result error event renders red container', (tester) async {
    final event = _event(
      type: 'result',
      contentText: 'Process exited with code 1',
      data: {'is_error': true},
    );

    await _pump(tester, TerminalEventTile(event: event));

    // Should show the error label.
    expect(
      find.textContaining(trans('agent_run.result_error')),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 7. File change — operation badge + file path in cyan
  // -------------------------------------------------------------------------

  testWidgets('file_change event renders operation badge and path', (
    tester,
  ) async {
    final event = _event(
      type: 'file_change',
      filePath: 'lib/main.dart',
      data: {'operation': 'M'},
    );

    await _pump(tester, TerminalEventTile(event: event));

    // File icon present.
    expect(find.byIcon(Icons.insert_drive_file), findsOneWidget);
    // Operation badge text.
    expect(find.text('M'), findsOneWidget);
    // File path.
    expect(find.text('lib/main.dart'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Error event — red bold text
  // -------------------------------------------------------------------------

  testWidgets('error event renders red bold text', (tester) async {
    final event = _event(
      type: 'error',
      contentText: 'Fatal: container OOM killed',
    );

    await _pump(tester, TerminalEventTile(event: event));

    expect(find.text('Fatal: container OOM killed'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Question event — amber styled container
  // -------------------------------------------------------------------------

  testWidgets('question event renders amber container with icon', (
    tester,
  ) async {
    final event = _event(
      type: 'question',
      contentText: 'Which database should I use?',
      isQuestion: true,
    );

    await _pump(tester, TerminalEventTile(event: event));

    expect(find.text('Which database should I use?'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 10. Unknown type — grey italic fallback
  // -------------------------------------------------------------------------

  testWidgets('unknown event type renders grey italic fallback', (
    tester,
  ) async {
    final event = _event(
      type: 'some_future_type',
      contentText: 'Unexpected payload',
    );

    await _pump(tester, TerminalEventTile(event: event));

    expect(find.text('Unexpected payload'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 11. TerminalEventList — renders multiple events in a ListView
  // -------------------------------------------------------------------------

  testWidgets('TerminalEventList renders multiple TerminalEventTile widgets', (
    tester,
  ) async {
    final events = [
      _event(id: 'e1', type: 'system', contentText: 'Started'),
      _event(id: 'e2', type: 'assistant', contentText: 'Working...'),
      _event(id: 'e3', type: 'error', contentText: 'Oops'),
    ];

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      SizedBox(
        height: 600,
        width: 800,
        child: TerminalEventList(events: events, scrollController: controller),
      ),
    );

    expect(find.byType(TerminalEventTile), findsNWidgets(3));
    expect(find.text('Started'), findsOneWidget);
    expect(find.text('Working...'), findsOneWidget);
    expect(find.text('Oops'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 12. TerminalEventList — tool_use expansion toggle
  // -------------------------------------------------------------------------

  testWidgets('TerminalEventList toggles tool_use expansion on tap', (
    tester,
  ) async {
    final events = [
      _event(
        id: 'tool-evt',
        type: 'assistant',
        data: {
          'type': 'tool_use',
          'tool_name': 'Grep',
          'input': {'pattern': 'TODO'},
        },
      ),
    ];

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pump(
      tester,
      SizedBox(
        height: 600,
        width: 800,
        child: TerminalEventList(events: events, scrollController: controller),
      ),
    );

    // Initially collapsed — input not visible.
    expect(find.text('Grep'), findsOneWidget);
    expect(find.textContaining('TODO'), findsNothing);

    // Tap to expand.
    await tester.tap(find.byType(WAnchor));
    await tester.pumpAndSettle();

    // Now input data should be visible.
    expect(find.textContaining('TODO'), findsOneWidget);

    // Tap again to collapse.
    await tester.tap(find.byType(WAnchor).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('TODO'), findsNothing);
  });
}
