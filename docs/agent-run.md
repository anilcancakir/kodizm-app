# Agent Run

Real-time agent execution monitoring with terminal streaming, file changes, questions, and cost tracking.

## State

`AgentRunState` (`lib/app/state/agent_run_state.dart`) extends `MagicController with MagicStateMixin<void>`.

| Field | Type | Description |
|-------|------|-------------|
| `runDetail` | `TaskRunDetail?` | Loaded run metadata |
| `session` | `Session?` | Associated session (fetched via sessionId) |
| `events` | `List<StreamEvent>` | All stream events (replay + live) |
| `turnCount` | `int` | Assistant turn counter |
| `currentCost` | `double` | Running cost in USD |
| `fileChanges` | `List<FileChange>` | Extracted file change records |
| `questions` | `List<AgentQuestion>` | All questions (answered + pending) |

### HTTP Interfaces

Two injectable clients for separation of concerns:

| Interface | Verbs | Purpose |
|-----------|-------|---------|
| `AgentRunHttpClient` | GET, POST | Run detail, events, questions, answer, cancel |
| `SessionAgentHttpClient` | GET | Fetch associated session |

### Key Methods

| Method | API Endpoint | Description |
|--------|-------------|-------------|
| `loadRunDetail` | `GET /teams/{t}/projects/{p}/tasks/{t}/runs/{r}` | Load run + auto-fetch session |
| `loadExistingEvents` | `GET /task-runs/{id}/stream-events` | Cursor-paginated event replay |
| `loadQuestions` | `GET .../runs/{id}/questions` | Fetch all questions |
| `answerQuestion` | `POST .../runs/{id}/answer` | Submit answer, optimistic update |
| `cancelRun` | `POST .../runs/{id}/cancel` | Cancel active run |

### WebSocket Event Processing

Events arrive via `addEvent(WebSocketEvent)` -- the view subscribes to the WS channel and forwards events to the state.

| WS Event | StreamEvent.type | Side Effect |
|----------|-----------------|-------------|
| `.agent.system` | `system` | Extract sessionId + model, update runDetail |
| `.agent.assistant` | `assistant` | Increment turnCount |
| `.agent.result` | `result` | Update cost + duration on runDetail |
| `.agent.question` | `question` | Append AgentQuestion to questions list |
| `.agent.status` | -- (no StreamEvent) | Update runDetail.status only |

Event deduplication uses `_seenEventIds` set to prevent duplicate processing on replay + live overlap.

## View

`AgentRunView` (`lib/resources/views/task/agent_run_view.dart`) -- route `/projects/:pid/tasks/:tid/runs/:rid`.

### Layout

- **Header**: Back nav, title, agent role badge, StatusBadge
- **Desktop** (>=768px): Terminal left + sidebar right (run info, session info, file changes)
- **Mobile**: Stacked vertically
- **QuestionPanel**: Appears below terminal when pending questions exist
- **Cancel button**: Shown for active runs only

### WS Channel Management

The view manages two WS channels:

| Channel | Subscribed When | Handler |
|---------|----------------|---------|
| `private-task-run.{runId}` | `initState` | `_state.addEvent` |
| `private-session.{sessionId}` | Session loads (via listener) | `_state.updateSessionFromEvent` |

### Timer

Elapsed timer ticks every second for active runs. Uses `durationMs` from API for terminal (completed/failed/cancelled) runs.

## Widgets Used

| Widget | Purpose |
|--------|---------|
| `StatusBadge` | Run status pill |
| `ModelCostBreakdown` | Per-model cost table from session usage records |
| `SectionCard` | Card containers for info sections |
| `QuestionPanel` | Slide-in Q&A panel |
| `TerminalEventList` | Scrollable dark terminal with TerminalEventTile items |

## Related Docs

- [Sessions](sessions.md) -- session model and lifecycle
- [Projects and Tasks](projects-and-tasks.md) -- task run context
- [WebSocket](websocket.md) -- WS service details
- [Widgets](widgets.md) -- widget inventory
