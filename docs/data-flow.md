# Data Flow

HTTP request-response and WebSocket real-time data flow patterns.

## HTTP Flow (Request-Response)

```
View initState
  -> State.fetchX(teamId, ...)
    -> HttpClient.get('/teams/{teamId}/...')
      -> MagicResponse
    -> Model.fromMap(response.data['data'])
    -> setSuccess(model) / setError(message)
  -> ListenableBuilder rebuilds view
```

### Key Patterns

| Pattern | Description |
|---------|-------------|
| Injectable HTTP clients | Abstract interfaces (`TaskHttpClient`, etc.) with production `Http` facade delegation |
| MagicStateMixin lifecycle | `setLoading()` -> `setSuccess(data)` or `setError(msg)` -> `refreshUI()` |
| Manual refreshUI | For `void`-typed states (`ConversationChatState`, `SessionState`) managing secondary fields |
| Singleton state | `Magic.findOrPut(StateClass.new)` -- lazy, shared across views |
| Optimistic updates | `ConversationChatState.sendMessage` appends user message before API response |

## WebSocket Flow (Real-Time)

```
AppServiceProvider.boot()
  -> WebSocketService.connect()
    -> Pusher handshake (connection_established)

View initState
  -> ws.subscribe('private-channel.{id}', state.addEvent)

Server broadcasts event
  -> WebSocketService._onMessage
    -> JSON decode + dedup check (ring buffer)
    -> WebSocketEvent.fromPusherPayload
    -> state.addEvent(wsEvent)
      -> state.refreshUI()
        -> ListenableBuilder rebuilds

View dispose
  -> ws.unsubscribe('private-channel.{id}')
```

### Channel Subscription Patterns

| Pattern | Used By | Description |
|---------|---------|-------------|
| Hybrid (state-internal) | `ConversationChatState` | State subscribes internally, view triggers via `createConversation`/`reset` |
| State-managed | `SessionState` | State owns subscribe/unsubscribe via public methods |
| Dynamic secondary | `ConversationChatState` | Session channel subscribed when sessionId becomes known |

### Event Routing

State classes route WebSocket events by `eventName`:

| State | Event Name | Mutation |
|-------|-----------|----------|
| `ConversationChatState` | `.conversation.message` | Route by type: text/question/permission/tool_use |
| `ConversationChatState` | `.conversation.status` | Update conversation status, extract sessionId |
| `SessionState` | `.session.status` | Update session phase |
| `SessionState` | `.session.cost` | Update cost totals, append usage record |
| `SessionState` | `.session.stream` | Append StreamEvent |
| `SessionState` | `.session.question` | Store pending question |

## Service Registration

`AppServiceProvider` (`lib/app/providers/app_service_provider.dart`):

| Phase | Action |
|-------|--------|
| `register()` | Bind `WebSocketService` as singleton `'websocket'` |
| `boot()` | Set user factory, configure navigation (8 items), register logout callback, connect WebSocket, set locale options, set team resolver |

## State Singleton Pattern

All state classes use lazy singleton via IoC:

```dart
static TaskState get instance => Magic.findOrPut(TaskState.new);
```

Views access state via `Magic.findOrPut<StateClass>(StateClass.new)` in `initState`.

## Related Docs

- [State Management](state-management.md) -- all state classes and methods
- [WebSocket](websocket.md) -- WS service implementation details
- [Models](models.md) -- model parsing patterns
