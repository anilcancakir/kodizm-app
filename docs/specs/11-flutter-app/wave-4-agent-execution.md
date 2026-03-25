# Wave 4 — Agent Execution & Streaming

> Spec: 11-Flutter App
> Dependencies: Wave 3 complete, 06-Agent Execution complete (streaming, Q&A endpoints), 07-Real-time Communication complete (Reverb channels, event formats)

## Deliverables

- [ ] AgentRunScreen with real-time terminal view
- [ ] WebSocket integration (Laravel Reverb) for NDJSON streaming
- [ ] Start run, view streaming output, see file changes
- [ ] NDJSON stream rendering with virtual scrolling
- [ ] Run info sidebar (agent role, model, status, elapsed time, cost)
- [ ] File changes panel
- [ ] Cancel run action
- [ ] WebSocket subscription to `private-task-run.{id}` channel
- [ ] Event replay for late-joining (load existing events on screen open)
- [ ] AgentRunState (ChangeNotifier + MagicStateMixin)
- [ ] Freezed models: TaskRun (detail), StreamEvent with UUID `String` ids

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## Agent Run Screen (`/projects/{projectId}/tasks/{taskId}/runs/{runId}`)

This is THE core UX screen of Kodizm. It must feel like a real-time terminal with rich agent interaction.

### Layout (Responsive)

**Desktop/Tablet (>= 768px)**:
```
+--------------------------------------------------------------+
|  [<- Back to Task]   Run #42 -- Developer (claude-sonnet-4-6)  |
|  Status: * Running   Elapsed: 2m 34s   Cost: $0.47            |
+--------------------------------------+-----------------------+
|                                      |  Run Info Sidebar     |
|                                      |  -----------------    |
|        Terminal Output               |  Agent: Developer     |
|        (scrollable, real-time)       |  Model: sonnet-4-6    |
|                                      |  Status: * Running    |
|                                      |  Elapsed: 2m 34s      |
|                                      |  Cost: $0.47          |
|                                      |  Turns: 12            |
|                                      |  -----------------    |
|                                      |  File Changes (3)     |
|                                      |  -----------------    |
|                                      |  M src/app.dart       |
|                                      |  A src/service.dart   |
|                                      |  M pubspec.yaml       |
+--------------------------------------+-----------------------+
|                                              [Cancel Run]     |
+--------------------------------------------------------------+
```

**Mobile (< 768px)**:
- Terminal output: full width, scrollable
- Run info: collapsible top bar (tap to expand)
- File changes: bottom sheet (swipe up)
- Cancel: in app bar actions

## Terminal Output

### Event Type Rendering

| Event Type | StreamEventType | Visual Style |
|-----------|----------------|--------------|
| System | `system` | Grey text, italic, smaller font. "Session started", "Model: claude-sonnet-4-6" |
| Assistant Text | `assistant` (content type: text) | White/default text, regular weight. Main agent output. |
| Tool Use | `assistant` (content type: tool_use) | Blue text with tool icon. Shows: tool name, truncated input. Expandable to show full input/output. |
| Result | `result` | Green background (success) or red background (error). Shows: cost, tokens, duration. |
| File Change | `file_change` | Cyan text with file icon. Shows: operation (M/A/D) + file path. |
| Error | `error` | Red text, bold. Error message. |

### Virtual Scrolling
- Agent runs can produce thousands of events (large codebases)
- Use `ListView.builder` with lazy rendering — only build visible items
- Keep event list in memory as `List<StreamEvent>` — state property
- Estimated item height for scroll position calculation
- Performance target: smooth at 10,000+ events

### Auto-Scroll Behavior
- **Default**: auto-scroll to bottom as new events arrive
- **Manual scroll up**: pause auto-scroll, show "Scroll to bottom" FAB
- **Tap "Scroll to bottom"**: resume auto-scroll
- Detection: if user scrolls up more than 100px from bottom -> pause auto-scroll

### Tool Use Expansion
- Tool use events show collapsed by default: `[tool] Read src/app.dart`
- Tap to expand: shows full tool input and output (if available)
- Tool output can be large — render in scrollable container with max height
- Tool result: green check (success) or red X (error)

## Run Info Sidebar

### Content
- **Agent Role**: name + slug (e.g., "Developer (developer)")
- **Model**: actual model used (e.g., "claude-sonnet-4-6")
- **Status Badge**: real-time status from WebSocket
  - `pending` -> grey, pulsing
  - `running` -> green, animated dot
  - `waiting_for_input` -> amber, pulsing
  - `completed` -> green, checkmark
  - `failed` -> red, X
  - `cancelled` -> grey, slash
  - `timed_out` -> orange, clock
- **Elapsed Time**: live counter (updated every second while running)
- **Cost**: accumulating `$X.XX` — updated from `.agent.result` event
- **Turns**: number of assistant turns so far
- **Session ID**: copyable (for debugging)

### Elapsed Time Counter
- Start counting from `run.started_at`
- Update every second via `Timer.periodic`
- Format: `Xm Ys` or `Xh Ym Zs` for long runs
- Stop counting when status becomes terminal

## File Changes Panel

### Data Source
- GET `/api/task-runs/{run}/file-changes` via `Http` — fetched on load and from `file_change` stream events
- Real-time updates via `.agent.assistant` events that contain file operations

### Display
- List of file paths with operation badges:
  - **M** (Modified) — blue
  - **A** (Added) — green
  - **D** (Deleted) — red
- Sorted: added first, then modified, then deleted
- Count badge in panel header: "File Changes (7)"
- Tap file: no action in MVP (post-MVP: show diff)

## Cancel Run

- Button: "Cancel Run" (red, with confirmation dialog)
- POST `/api/task-runs/{run}/cancel` via `Http`
- On success: status updates to `cancelled`, terminal shows cancellation message
- Only visible when run status is `running` or `waiting_for_input`
- Confirmation dialog: "Are you sure? The agent will be stopped and the container will be removed."

## WebSocket Subscription

### Subscribe on Screen Mount
```dart
// On screen init:
final subscription = webSocketService.subscribe(
  'private-task-run.$runId',
  (event) => agentRunState.addEvent(event),
);

// On screen dispose:
subscription.cancel();
webSocketService.unsubscribe('private-task-run.$runId');
```

### Event Handling
| WebSocket Event | Action |
|----------------|--------|
| `.agent.system` | Add system event to terminal, extract session_id + model |
| `.agent.assistant` | Add assistant event to terminal, increment turn count |
| `.agent.result` | Add result event, update cost/duration/status, stop elapsed timer |
| `.agent.question` | Add question event to terminal (Q&A handled in Wave 5) |
| `.agent.status` | Update run status badge |

### Event Replay (Late Join)
- On screen mount: GET `/api/task-runs/{run}/stream-events` via `Http` to load all existing events
- Then subscribe to WebSocket for new events
- Dedup: events from HTTP and WebSocket may overlap — dedup by event ID
- Order: events are appended in `occurred_at` order

## State Management

### AgentRunState (ChangeNotifier + MagicStateMixin)

```dart
class AgentRunState extends ChangeNotifier with MagicStateMixin {
  TaskRunDetail? _runDetail;
  List<StreamEvent> _events = [];
  final Set<String> _seenEventIds = {};
  int _turnCount = 0;
  double _currentCost = 0.0;
  List<FileChange> _fileChanges = [];

  TaskRunDetail? get runDetail => _runDetail;
  List<StreamEvent> get events => _events;
  int get turnCount => _turnCount;
  double get currentCost => _currentCost;
  List<FileChange> get fileChanges => _fileChanges;

  Future<void> loadRunDetail(String runId) async {
    await run(() async {
      final response = await Http.get('/task-runs/$runId');
      _runDetail = TaskRunDetail.fromJson(response.data['data']);
      notifyListeners();
    });
  }

  Future<void> loadExistingEvents(String runId) async {
    await run(() async {
      final response = await Http.get('/task-runs/$runId/stream-events');
      final events = (response.data['data'] as List)
          .map((json) => StreamEvent.fromJson(json))
          .toList();
      for (final event in events) {
        _seenEventIds.add(event.id);
      }
      _events = events;
      notifyListeners();
    });
  }

  void addEvent(Map<String, dynamic> rawEvent) {
    final event = StreamEvent.fromJson(rawEvent);
    // Dedup by ID
    if (_seenEventIds.contains(event.id)) return;
    _seenEventIds.add(event.id);
    _events = [..._events, event];

    // Update derived state
    if (event.type == 'assistant') _turnCount++;
    if (event.type == 'result') {
      _currentCost = event.data['total_cost_usd']?.toDouble() ?? _currentCost;
    }
    if (event.type == 'file_change') {
      _fileChanges = [..._fileChanges, FileChange.fromJson(event.data)];
    }

    notifyListeners();
  }

  void updateStatus(String status) {
    if (_runDetail == null) return;
    _runDetail = _runDetail!.copyWith(status: status);
    notifyListeners();
  }

  Future<void> cancelRun(String runId) async {
    await run(() async {
      await Http.post('/task-runs/$runId/cancel');
      updateStatus('cancelled');
    });
  }

  Future<void> loadFileChanges(String runId) async {
    await run(() async {
      final response = await Http.get('/task-runs/$runId/file-changes');
      _fileChanges = (response.data['data'] as List)
          .map((json) => FileChange.fromJson(json))
          .toList();
      notifyListeners();
    });
  }
}
```

## Freezed Models

### StreamEvent

```dart
@freezed
class StreamEvent with _$StreamEvent {
  const factory StreamEvent({
    required String id,              // UUID
    required String taskRunId,       // UUID
    required String type,            // StreamEventType: system, assistant, result, question, file_change, error
    required Map<String, dynamic> data,
    String? contentText,
    String? filePath,
    required bool isQuestion,
    required DateTime occurredAt,
  }) = _StreamEvent;

  factory StreamEvent.fromJson(Map<String, dynamic> json) => _$StreamEventFromJson(json);
}
```

### TaskRunDetail

```dart
@freezed
class TaskRunDetail with _$TaskRunDetail {
  const factory TaskRunDetail({
    required String id,              // UUID
    required String taskId,          // UUID
    required String agentRoleId,     // UUID
    required String agentRoleName,
    required String agentRoleSlug,
    String? aiTokenId,               // UUID
    required String status,
    required String prompt,
    String? model,
    String? sessionId,
    String? containerName,
    double? totalCostUsd,
    Map<String, dynamic>? usage,
    int? durationMs,
    int? numTurns,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) = _TaskRunDetail;

  factory TaskRunDetail.fromJson(Map<String, dynamic> json) => _$TaskRunDetailFromJson(json);
}
```

### FileChange

```dart
@freezed
class FileChange with _$FileChange {
  const factory FileChange({
    required String filePath,
    required String operation,  // M, A, D
  }) = _FileChange;

  factory FileChange.fromJson(Map<String, dynamic> json) => _$FileChangeFromJson(json);
}
```

## Acceptance Criteria

### Terminal Output

**Given** an active agent run,
**When** the user opens the Agent Run Screen,
**Then** existing stream events are loaded via `Http` and displayed in the terminal, followed by new events via WebSocket in real-time.

**Given** a running agent producing output,
**When** new `.agent.assistant` events arrive via WebSocket,
**Then** the text is appended to the terminal and auto-scrolls to the bottom.

**Given** the terminal auto-scrolling,
**When** the user scrolls up manually,
**Then** auto-scroll pauses and a "Scroll to bottom" FAB appears.

**Given** auto-scroll is paused,
**When** the user taps "Scroll to bottom",
**Then** the terminal scrolls to the latest event and auto-scroll resumes.

**Given** a terminal with 5,000+ events,
**When** the user scrolls through the terminal,
**Then** scrolling is smooth with no jank (virtual scrolling / lazy rendering).

### Event Type Styling

**Given** a `system` event in the terminal,
**When** it is rendered,
**Then** it appears in grey italic text.

**Given** an `assistant` event with tool_use content,
**When** it is rendered,
**Then** it appears in blue with a tool icon, collapsed by default, expandable on tap.

**Given** a `result` event with `is_error: false`,
**When** it is rendered,
**Then** it appears with a green background showing cost, tokens, and duration.

**Given** a `result` event with `is_error: true`,
**When** it is rendered,
**Then** it appears with a red background showing the error message.

### Run Info

**Given** a running agent,
**When** the user views the run info sidebar,
**Then** the status badge shows "Running" (green), elapsed time counts up every second, and cost updates as result events arrive.

**Given** a completed run,
**When** the user views the run info sidebar,
**Then** the status shows "Completed" (green checkmark), elapsed time is frozen, and final cost is displayed.

### File Changes

**Given** an agent run that modifies 3 files,
**When** file_change events arrive,
**Then** the file changes panel shows 3 entries with operation badges (M/A/D) and file paths.

### Cancel Run

**Given** a running agent,
**When** the user taps "Cancel Run" and confirms,
**Then** `Http.post('/task-runs/{run}/cancel')` is called, the status updates to "cancelled", and the terminal shows a cancellation message.

**Given** a completed or failed run,
**When** the user views the screen,
**Then** the "Cancel Run" button is not visible.

### Event Dedup

**Given** events loaded via HTTP replay and new events arriving via WebSocket,
**When** there is overlap (same event ID in both sources),
**Then** duplicate events are silently dropped — no duplicate entries in the terminal.

### Late Join

**Given** a run that has been executing for 5 minutes,
**When** the user opens the Agent Run Screen,
**Then** all historical events are loaded via HTTP first, then WebSocket subscribes for new events, producing a seamless timeline.

## Implementation Notes

- Use `Http` facade for ALL API calls — never instantiate Dio directly.
- All model IDs are `String` (UUID) — no `int` IDs.
- State classes: `extends ChangeNotifier with MagicStateMixin`.
- Terminal output should use a monospace font (e.g., `JetBrains Mono`, `Fira Code`, or system monospace).
- Consider a custom `TerminalEventWidget` that renders differently based on event type.
- Elapsed time: use a separate `Timer.periodic(Duration(seconds: 1))` that updates a local state. Dispose on screen unmount.
- Cost display: start at $0.00, update when result event arrives.
- Virtual scrolling: `ListView.builder` with `itemCount: events.length` is sufficient for Flutter's built-in virtualization.
- WebSocket reconnect: if the WebSocket drops during a run, the service reconnects and resubscribes. On reconnect, fetch missed events via HTTP (`?after_id=lastEventId`).
