# Views and Routes

20 view files across 7 subdirectories. 27 routes in one auth-guarded group.

## Route Map

All routes are auth-guarded via `MagicRoute.group(middleware: ['auth'])` with `AppLayout`. Defined in `lib/routes/app.dart`.

| Path | View | Parameters |
|------|------|-----------|
| `/` | `DashboardView` | -- |
| `/dashboard` | `DashboardView` | -- |
| `/projects` | `ProjectListView` | -- |
| `/projects/create` | `ProjectCreateView` | -- |
| `/projects/:id` | `ProjectDetailView` | `id` |
| `/projects/:projectId/tasks` | `TaskListView` | `projectId` |
| `/projects/:projectId/tasks/create` | `TaskCreateView` | `projectId` |
| `/projects/:projectId/tasks/:taskId` | `TaskDetailView` | `projectId`, `taskId` |
| `/projects/:projectId/tasks/:taskId/runs/:runId` | `AgentRunView` | `projectId`, `taskId`, `runId` |
| `/projects/:projectId/chat` | `ConversationChatView` | `projectId` |
| `/projects/:projectId/knowledge` | `KnowledgeListView` | `projectId` |
| `/projects/:projectId/knowledge/:documentId` | `KnowledgeDetailView` | `projectId`, `documentId` |
| `/projects/:projectId/conversations` | `ConversationListView` | `projectId` |
| `/tasks` | `ProjectScopedNavView` | -- (redirects) |
| `/knowledge` | `ProjectScopedNavView` | -- (redirects) |
| `/conversations` | `ProjectScopedNavView` | -- (redirects) |
| `/sessions` | `SessionListView` | -- |
| `/sessions/:sessionId` | `SessionDetailView` | `sessionId` |
| `/billing` | `BillingView` | -- |
| `/usage` | `UsageHistoryView` | -- |
| `/settings/ai-tokens` | `AiTokenListView` | -- |
| `/settings/app` | `AppSettingsView` | -- |

Additional routes from magic_starter: auth (login, register, forgot password), profile, team management, notifications.

## View Inventory

| View | File | State Dependency | Description |
|------|------|-----------------|-------------|
| `DashboardView` | `views/dashboard_view.dart` | `DashboardState` | Active runs, task summary, recent runs, balance, monthly usage |
| `ProjectListView` | `views/project/project_list_view.dart` | `ProjectState` | Paginated project list with sort |
| `ProjectCreateView` | `views/project/project_create_view.dart` | `ProjectState` | Create project form |
| `ProjectDetailView` | `views/project/project_detail_view.dart` | `ProjectState` | Project settings, SSH key, repo status |
| `TaskListView` | `views/task/task_list_view.dart` | `TaskState` | Filtered/sorted task list |
| `TaskCreateView` | `views/task/task_create_view.dart` | `TaskState` | Create task form |
| `TaskDetailView` | `views/task/task_detail_view.dart` | `TaskState` | Sections, runs, status transitions |
| `AgentRunView` | `views/task/agent_run_view.dart` | `AgentRunState` | Live terminal, file changes, questions |
| `KnowledgeListView` | `views/knowledge/knowledge_list_view.dart` | `DocumentState` | Document list |
| `KnowledgeDetailView` | `views/knowledge/knowledge_detail_view.dart` | `DocumentState` | Markdown document viewer |
| `ConversationListView` | `views/conversation/conversation_list_view.dart` | `ConversationListState` | Conversation history |
| `ConversationChatView` | `views/conversation/conversation_chat_view.dart` | `ConversationChatState` | Live chat with WS |
| `SessionListView` | `views/session/session_list_view.dart` | `SessionState` | Filtered session list |
| `SessionDetailView` | `views/session/session_detail_view.dart` | `SessionState` | Usage records, shares, live WS |
| `BillingView` | `views/billing/billing_view.dart` | `BillingState` | Balance, monthly summary |
| `UsageHistoryView` | `views/billing/usage_history_view.dart` | `UsageState` | Paginated usage with filters |
| `AiTokenListView` | `views/settings/ai_token_list_view.dart` | `AiTokenState` | Provider tokens with status |
| `AppSettingsView` | `views/settings/app_settings_view.dart` | `SettingsState` | Notification preference toggles |
| `ProjectScopedNavView` | `views/nav/project_scoped_nav_view.dart` | -- | Resolves current project, redirects |
| `WelcomeView` | `views/welcome_view.dart` | -- | Unused, replaced by DashboardView |

All view paths relative to `lib/resources/`.

## Navigation Structure

### Sidebar (AppServiceProvider)

8 main navigation items configured in `lib/app/providers/app_service_provider.dart`:

| Icon | Label Key | Path |
|------|-----------|------|
| `dashboard_outlined` | `nav.dashboard` | `/` (home) |
| `folder_outlined` | `nav.projects` | `/projects` |
| `task_alt_outlined` | `nav.tasks` | `/tasks` |
| `library_books_outlined` | `nav.knowledge` | `/knowledge` |
| `chat_outlined` | `nav.conversations` | `/conversations` |
| `account_balance_wallet_outlined` | `nav.billing` | `/billing` |
| `devices_outlined` | `nav.sessions` | `/sessions` |
| `settings_outlined` | `nav.settings` | profile route |

Bottom bar mirrors the same 8 items for mobile.

### Project-Scoped Navigation

`/tasks`, `/knowledge`, `/conversations` use `ProjectScopedNavView` to resolve the current project and redirect to the project-scoped route (e.g., `/projects/:id/tasks`).

## View Layout Standard

All views follow the pattern from `CLAUDE.md`:

```dart
WDiv(
  className: 'p-4 lg:p-6 flex flex-col gap-6',
  children: [PageHeader(...), SectionCard(...)],
)
```

See `CLAUDE.md` for widget rules and coding conventions.

## Related Docs

- [State Management](state-management.md) -- state class details
- [Widgets](widgets.md) -- reusable widget inventory
- [Data Flow](data-flow.md) -- how views connect to state and data
