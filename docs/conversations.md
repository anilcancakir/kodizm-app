# Conversations

Unified execution model for both interactive chat and autonomous task execution.

## Dual-Mode Architecture

Conversations serve two purposes, distinguished by `type`:

| Type | Purpose | Trigger | Task Link |
|------|---------|---------|-----------|
| `interactive` | User-driven chat with agent | User starts conversation | Optional (via `conversation_task` pivot) |
| `autonomous` | Task execution by agent | System launches for task | Required (`task_id` FK + pivot) |

Both modes share the same model, API resources, state classes, and WebSocket channels.

## Models

| Model | File | Pattern | Key Fields |
|-------|------|---------|------------|
| `Conversation` | `lib/app/models/conversation.dart` | Immutable VO + copyWith | id, projectId, userId, agentRoleId, status, model, totalCostUsd, messagesCount, title, userName, agentRoleName/Slug, type, taskId, prompt |
| `ConversationMessage` | `lib/app/models/conversation_message.dart` | Immutable VO + copyWith | id, conversationId, role, content, costUsd, usage, durationMs, numTurns, error, metadata |
| `ChatItem` | `lib/app/models/chat_item.dart` | Sealed union | TextItem, ToolUseItem, ToolResultItem, ThinkingItem, ErrorItem |

### Key Fields (added for MCP dual-mode)

| Field | Type | Description |
|-------|------|-------------|
| `type` | `String` | `'interactive'` or `'autonomous'` |
| `taskId` | `String?` | FK to task (always set for autonomous, optional for interactive) |
| `prompt` | `String?` | Initial prompt (autonomous mode starting instructions) |
| `linkedConversationsCount` | `int?` | Count of linked conversations via pivot table (on Task model) |

### Nested Relations

`Conversation.fromMap` flattens nested `user` and `agent_role` relations into top-level fields (userId, userName, agentRoleId, agentRoleName, agentRoleSlug).

## State Classes

### ConversationListState

`lib/app/state/conversation_list_state.dart` -- extends `MagicController with MagicStateMixin<List<Conversation>>`.

| Method | API Endpoint | Description |
|--------|-------------|-------------|
| `loadConversations` | `GET /teams/{t}/projects/{p}/conversations` | Fetch all conversations for a project |
| `deleteConversation` | `DELETE /teams/{t}/projects/{p}/conversations/{id}` | Delete + reload list |
| `reset` | -- | Clear state |

### ConversationChatState

`lib/app/state/conversation_chat_state.dart` -- extends `MagicController with MagicStateMixin<void>`.

| Field | Type | Description |
|-------|------|-------------|
| `conversation` | `Conversation?` | Active conversation |
| `messages` | `List<ConversationMessage>` | Chronological messages |
| `rawEvents` | `List<WebSocketEvent>` | All WS events (debug display) |
| `isSending` | `bool` | Message send in progress |
| `sessionId` | `String?` | Linked session (from WS status event) |
| `runningCostUsd` | `String?` | Session cost (from WS) |
| `sessionPhase` | `String?` | Session phase (from WS) |
| `pendingQuestion` | `Map?` | Awaiting user answer |
| `pendingPermission` | `Map?` | Awaiting tool permission approval |

#### Key Methods

| Method | API Endpoint |
|--------|-------------|
| `createConversation` | `POST /teams/{t}/projects/{p}/conversations` (auto-selects first agent role) |
| `loadConversation` | `GET /teams/{t}/projects/{p}/conversations/{id}` |
| `sendMessage` | `POST .../conversations/{id}/messages` (optimistic append) |
| `completeConversation` | `POST .../conversations/{id}/complete` |
| `answerQuestion` | `POST .../conversations/{id}/answer` |
| `loadMessages` | `GET .../conversations/{id}/messages` |

#### WebSocket Integration

Two channels managed by the state class:

| Channel | Events | Mutations |
|---------|--------|-----------|
| `private-conversation.{id}` | `.conversation.message`, `.conversation.status` | Append messages, update status, extract sessionId, detect questions/permissions |
| `private-session.{sessionId}` | `.session.cost`, `.session.status` | Update runningCostUsd, sessionPhase |

The session channel is subscribed dynamically when `session_id` first appears in a `.conversation.status` event.

#### Message Event Routing

`.conversation.message` events are routed by `type` field:

| Type | Behavior |
|------|----------|
| `tool_use` (AskUserQuestion) | Store options for question correlation |
| `question` | Create pendingQuestion with correlated options |
| `permission` | Create pendingPermission (toolName, input) |
| text (default) | Append as ConversationMessage |

## Views

| View | File | Route |
|------|------|-------|
| `ConversationListView` | `lib/resources/views/conversation/conversation_list_view.dart` | `/projects/:projectId/conversations` |
| `ConversationChatView` | `lib/resources/views/conversation/conversation_chat_view.dart` | `/projects/:projectId/chat` (new), `/projects/:projectId/chats/:conversationId` (existing) |

### Chat Layout

`ConversationChatView` uses a dedicated `ChatLayout` (defined in `routes/app.dart`):
- **Desktop** (lg+): AppLayout shell with bounded content area
- **Mobile**: Bare fullscreen with SafeArea for immersive chat

## Related Docs

- [WebSocket](websocket.md) -- WS channel patterns
- [State Management](state-management.md) -- all state classes
- [Widgets](widgets.md) -- ChatMessageBubble, ChatToolUseCard, StreamingIndicator, ChatInputBar
