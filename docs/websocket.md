# WebSocket

Pusher-compatible WebSocket client for Laravel Reverb real-time events.

## WebSocketService

`lib/app/services/websocket_service.dart` -- singleton registered as `'websocket'` in IoC.

### Connection Lifecycle

1. `AppServiceProvider.register()` binds `WebSocketService` as singleton
2. `AppServiceProvider.boot()` calls `connect()` -- ready before any view subscribes
3. Reads `websocket.url` and `websocket.app_key` from config
4. Opens connection, waits for `pusher:connection_established`
5. Stores `socketId` for private channel authentication

### Channel Management

| Method | Description |
|--------|-------------|
| `subscribe(channel, onEvent)` | Register listener. Private channels auto-authenticate first |
| `unsubscribe(channel)` | Remove all listeners, send `pusher:unsubscribe` frame |

### Private Channel Authentication

Private channels (`private-*`) require auth before subscribing:

1. `POST /broadcasting/auth` with `socket_id` + `channel_name`
2. Response contains `auth` token
3. Token sent in `pusher:subscribe` data payload

Auth endpoint configurable via `websocket.auth_endpoint` config key.

### Auto-Reconnect

Exponential backoff: `min(2^attempt, maxDelay)` seconds. Max delay configurable via `websocket.reconnect_max_delay_seconds` (default 30).

On reconnect, all previously active channels are automatically resubscribed (with re-authentication for private channels).

### Event Deduplication

Ring buffer of 100 entries. Dedup key: `$channel:$eventName:$rawData`. Duplicate events are silently dropped before reaching listeners.

### Pusher Protocol Handling

| Pusher Event | Handler |
|-------------|---------|
| `pusher:connection_established` | Store socketId, mark connected |
| `pusher:ping` | Reply with `pusher:pong` |
| `pusher:subscription_succeeded` | Log success |
| `pusher:error` | Log error, schedule reconnect for code >= 4000 |
| Application events | Route to channel subscribers |

## WebSocketEvent

`lib/app/events/websocket_event.dart` -- parsed Pusher protocol event.

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Composite: `$channel:$eventName:${data.hashCode}` |
| `channel` | String | e.g. `private-project.abc` |
| `eventName` | String | e.g. `.agent.system`, `.conversation.message` |
| `data` | Map | Decoded JSON payload |
| `receivedAt` | DateTime | Local receive timestamp |

## Channel Patterns

| Channel Pattern | Subscribed By | Events |
|----------------|--------------|--------|
| `private-task-run.{runId}` | `AgentRunView` | `.agent.system`, `.agent.assistant`, `.agent.result`, `.agent.question`, `.agent.status` |
| `private-conversation.{id}` | `ConversationChatState` | `.conversation.message`, `.conversation.status` |
| `private-session.{sessionId}` | `SessionState`, `ConversationChatState`, `AgentRunView` | `.session.status`, `.session.cost`, `.session.stream`, `.session.question` |

## Per-State Integration

| State Class | Subscribe Method | Unsubscribe Method | Event Handler |
|-------------|-----------------|-------------------|---------------|
| `AgentRunState` | Via view (`AgentRunView.initState`) | Via view (`dispose`) | `addEvent(WebSocketEvent)` |
| `ConversationChatState` | Internal (`_ws.subscribe`) | `reset()` | `addEvent(WebSocketEvent)` |
| `SessionState` | `subscribeToSession(id)` | `unsubscribeFromSession()` | `handleWebSocketEvent(WebSocketEvent)` |

### AgentRunView Dual-Channel Pattern

The `AgentRunView` manages two channels simultaneously:

1. `private-task-run.{runId}` -- subscribed immediately in `initState`
2. `private-session.{sessionId}` -- subscribed dynamically when session loads (via state listener)

### ConversationChatState Dynamic Session Channel

The conversation chat state subscribes to a session channel dynamically when `session_id` first appears in a `.conversation.status` event. This enables cost and phase tracking for the underlying session.

## Testing

`WebSocketService` accepts injectable `channelFactory` and `configProvider` for test isolation. State classes accept injectable `SessionWebSocket` / `ConversationChatWebSocket` abstractions.

## Related Docs

- [Agent Run](agent-run.md) -- run-level WS event processing
- [Conversations](conversations.md) -- conversation WS events
- [Sessions](sessions.md) -- session WS events
- [Data Flow](data-flow.md) -- full data flow patterns
