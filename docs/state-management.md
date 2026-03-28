# State Management

12 state classes. All except `SettingsState` extend `MagicController with MagicStateMixin<T>`.

## Architecture

- **Singleton access**: `Magic.findOrPut(StateClass.new)` -- lazy, shared across the app
- **Injectable HTTP clients**: Abstract interfaces for testability, production delegates to `Http` facade
- **Reactive updates**: `setLoading()` / `setSuccess(data)` / `setError(msg)` from MagicStateMixin, or manual `refreshUI()` for secondary state
- **View binding**: `ListenableBuilder(listenable: state, builder: ...)` rebuilds on changes

## State Class Inventory

| State Class | File | rxState Type | HTTP Interface | WS Channels |
|-------------|------|-------------|----------------|-------------|
| `DashboardState` | `dashboard_state.dart` | `DashboardData` | `DashboardHttpClient` (GET) | -- |
| `ProjectState` | `project_state.dart` | `List<Project>` | `HttpClient` (GET/POST/PUT/DELETE) | -- |
| `TaskState` | `task_state.dart` | `List<Task>` | `TaskHttpClient` (GET/POST/PUT/DELETE) | -- |
| `AgentRunState` | `agent_run_state.dart` | `void` | `AgentRunHttpClient` (GET/POST) + `SessionAgentHttpClient` (GET) | Via view: `private-task-run.{runId}` |
| `DocumentState` | `document_state.dart` | `List<ProjectDocument>` | `DocumentHttpClient` (GET) | -- |
| `ConversationListState` | `conversation_list_state.dart` | `List<Conversation>` | `ConversationListHttpClient` (GET/DELETE) | -- |
| `ConversationChatState` | `conversation_chat_state.dart` | `void` | `ConversationChatHttpClient` (GET/POST) | `private-conversation.{id}`, `private-session.{id}` |
| `SessionState` | `session_state.dart` | `void` | `SessionHttpClient` (GET/POST/DELETE) | `private-session.{id}` |
| `BillingState` | `billing_state.dart` | `TeamBalance` | `BillingHttpClient` (GET) | -- |
| `UsageState` | `usage_state.dart` | `List<UsageRecord>` | `UsageHttpClient` (GET) | -- |
| `AiTokenState` | `ai_token_state.dart` | `List<AiToken>` | `AiTokenHttpClient` (GET) | -- |
| `SettingsState` | `settings_state.dart` | -- (extends `ChangeNotifier` directly) | -- (uses `SettingsStorage` / `Vault`) | -- |

All files in `lib/app/state/`.

## Method Reference

### DashboardState

| Method | Description |
|--------|-------------|
| `fetchDashboard(teamId)` | GET `/teams/{teamId}/dashboard` |

### ProjectState

| Method | Description |
|--------|-------------|
| `fetchProjects`, `fetchProject` | Load list or single |
| `createProject`, `updateProject`, `deleteProject` | CRUD |
| `sortProjects(field)` | Local sort (name, lastUpdated) |
| `generateSshKey`, `fetchRepoStatus` | Project-specific actions |

### TaskState

| Method | Description |
|--------|-------------|
| `fetchTasks` (with filters), `fetchTask` | Load list or single |
| `createTask`, `updateTask`, `deleteTask` | CRUD |
| `transitionStatus` | Status change |
| `fetchSections`, `fetchRuns` | Load related data |
| `startRun` | Launch agent execution |
| `fetchAgentRoles` | Load agent roles for run dialog |
| `sortTasks(field)` | Local sort (priority, status, date) |

### AgentRunState

| Method | Description |
|--------|-------------|
| `loadRunDetail` | Load run + associated session |
| `loadExistingEvents` | Cursor-paginated event replay |
| `addEvent(WebSocketEvent)` | Process live WS event |
| `loadQuestions`, `answerQuestion` | Q&A lifecycle |
| `cancelRun` | Cancel active run |

### ConversationChatState

| Method | Description |
|--------|-------------|
| `createConversation` | Create + subscribe to WS |
| `loadConversation` | Load existing + messages + WS |
| `sendMessage` | Optimistic append + API call |
| `completeConversation` | Mark as completed |
| `answerQuestion` | Answer pending question/permission |

### SessionState

| Method | Description |
|--------|-------------|
| `loadSessions` (with filters), `loadSession` | Load list or single |
| `loadEvents` | Fetch stream events |
| `share`, `unshare` | Manage session shares |
| `subscribeToSession`, `unsubscribeFromSession` | WS lifecycle |
| `handleWebSocketEvent` | Route WS events to handlers |

### BillingState

| Method | Description |
|--------|-------------|
| `loadBalance` | Team balance |
| `loadMonthlySummary` | Monthly totals |
| `loadUsageByRole` | Per-agent-role breakdown |

### UsageState

| Method | Description |
|--------|-------------|
| `loadUsage` (with filters) | First page with period/project/role filters |
| `loadMore` | Append next page (infinite scroll) |
| `setFilter`, `clearFilters` | Filter management |

### AiTokenState

| Method | Description |
|--------|-------------|
| `loadTokens(teamId)` | Fetch AI token list |

### SettingsState

| Method | Description |
|--------|-------------|
| `init()` | Load preferences from Vault |
| `setNotificationPref(key, value)` | Persist boolean preference |
| Getters | `notifyRunCompleted`, `notifyRunFailed`, `notifyQuestionPending`, `notifyBalanceLow` |

## Cross-State Dependencies

| Consumer | Dependency | Purpose |
|----------|-----------|---------|
| `AgentRunState` | `SessionAgentHttpClient` | Fetch session for run detail |
| `ConversationChatState` | Agent roles API | Auto-select first agent role |
| `TaskState` | Agent roles API | Populate "start run" dialog |
| `BillingState` | `UsageRecord` model | Parse usage breakdown internally |

## Testing Pattern

All HTTP clients are injectable interfaces. Tests inject fakes returning canned `MagicResponse` objects.

## Related Docs

- [Data Flow](data-flow.md) -- HTTP and WS data flow patterns
- [WebSocket](websocket.md) -- WS channel integration details
- [Models](models.md) -- complete model inventory
