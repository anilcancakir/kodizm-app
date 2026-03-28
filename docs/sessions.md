# Sessions

Session lifecycle tracking for AI agent execution containers.

## Models

| Model | File | Pattern | Key Fields |
|-------|------|---------|------------|
| `Session` | `lib/app/models/session.dart` | Immutable VO + copyWith | id, type, phase, model, totalCostUsd, token counts (4), warmUntil, startedAt, completedAt, usageRecords, shares |
| `SessionUsageRecord` | `lib/app/models/session_usage_record.dart` | Immutable VO | id, sessionId, turnNumber, model, token counts (4), costUsd, isSubagent, subagentType |
| `SessionShare` | `lib/app/models/session_share.dart` | Immutable VO | id, sessionId, shareableType, shareableId, permission, sharedBy |

## Session Types and Phases

| Dimension | Values |
|-----------|--------|
| Type | `autonomous`, `interactive`, `system` |
| Phase | `provisioning`, `executing`, `warm`, `dead` |

## State

`SessionState` (`lib/app/state/session_state.dart`) extends `MagicController with MagicStateMixin<void>`.

| Field | Type | Description |
|-------|------|-------------|
| `sessions` | `List<Session>` | Loaded session list |
| `currentSession` | `Session?` | Active detail view session |
| `events` | `List<StreamEvent>` | Stream events for current session |
| `pendingQuestion` | `Map?` | Latest `.session.question` payload |
| Filters | `projectFilter`, `typeFilter`, `phaseFilter` | Active list filters |

### HTTP Interface

`SessionHttpClient` -- GET, POST, DELETE. Production: `Http` facade.

| Method | API Endpoint |
|--------|-------------|
| `loadSessions` | `GET /v1/sessions?project_id=&type=&phase=` |
| `loadSession` | `GET /v1/sessions/{id}` |
| `loadEvents` | `GET /v1/sessions/{id}/events?type=` |
| `share` | `POST /v1/sessions/{id}/share` |
| `unshare` | `DELETE /v1/sessions/{id}/shares/{shareId}` |

### WebSocket Integration

Channel: `private-session.{sessionId}`. See [WebSocket](websocket.md) for protocol details.

| WS Event | Handler | Mutation |
|----------|---------|----------|
| `.session.status` | `_handleStatusEvent` | Updates `currentSession.phase` via copyWith |
| `.session.cost` | `_handleCostEvent` | Updates cost/token totals, appends usage record |
| `.session.stream` | `_handleStreamEvent` | Appends `StreamEvent` to events list |
| `.session.question` | `_handleQuestionEvent` | Stores pending question payload |

## Views

| View | File | Route | Description |
|------|------|-------|-------------|
| `SessionListView` | `lib/resources/views/session/session_list_view.dart` | `/sessions` | Filterable list (project, type, phase), pull-to-refresh |
| `SessionDetailView` | `lib/resources/views/session/session_detail_view.dart` | `/sessions/:sessionId` | Responsive layout: events terminal, cost breakdown (ModelCostBreakdown), usage records, shares |

### View Lifecycle

1. `initState` -- loads session detail + events, subscribes to WS channel
2. `ListenableBuilder` rebuilds on `SessionState` changes
3. `dispose` -- unsubscribes from WS channel

## Related Docs

- [State Management](state-management.md) -- full state class reference
- [WebSocket](websocket.md) -- WS service and channel patterns
- [Models](models.md) -- complete model inventory
