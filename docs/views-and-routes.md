# Views and Routes

16 view files across 6 subdirectories. 22 routes in two auth-guarded groups.

## Route Map

All routes are auth-guarded via `MagicRoute.group(middleware: ['auth'])`. Two layout groups: standard `AppLayout` and responsive `ChatLayout` (desktop: AppLayout shell, mobile: fullscreen). Defined in `lib/routes/app.dart`.

| Path | View | Parameters | Layout |
|------|------|-----------|--------|
| `/` | `DashboardView` | -- | App |
| `/dashboard` | `DashboardView` | -- | App |
| `/projects` | `ProjectListView` | -- | App |
| `/projects/:id` | `ProjectDetailView` | `id` | App |
| `/projects/:projectId/tasks` | `TaskListView` | `projectId` | App |
| `/projects/:projectId/tasks/create` | `TaskCreateView` | `projectId` | App |
| `/projects/:projectId/tasks/:taskId` | `TaskDetailView` | `projectId`, `taskId` | App |
| `/projects/:projectId/conversations` | `ConversationListView` | `projectId` | App |
| `/projects/:projectId/chat` | `ConversationChatView` | `projectId` | Chat |
| `/projects/:projectId/chats/:conversationId` | `ConversationChatView` | `projectId`, `conversationId` | Chat |
| `/tasks` | `ProjectScopedNavView` | -- (redirects) | App |
| `/conversations` | `ProjectScopedNavView` | -- (redirects) | App |
| `/sessions` | `SessionListView` | -- | App |
| `/sessions/:sessionId` | `SessionDetailView` | `sessionId` | App |
| `/billing` | `BillingView` | -- | App |
| `/usage` | `UsageHistoryView` | -- | App |
| `/settings/ai-tokens` | `AiTokenListView` | -- | App |
| `/settings/app` | `AppSettingsView` | -- | App |

Additional routes from magic_starter: auth (login, register, forgot password), profile, team management, notifications.

## View Inventory

| View | File | State Dependency | Description |
|------|------|-----------------|-------------|
| `DashboardView` | `views/dashboard_view.dart` | `DashboardState` | Active conversations, task summary, recent runs, balance, monthly usage |
| `ProjectListView` | `views/project/project_list_view.dart` | `ProjectState` | Paginated project list with sort |
| `ProjectDetailView` | `views/project/project_detail_view.dart` | `ProjectState` | Project settings, SSH key, repo status, environment config |
| `TaskListView` | `views/task/task_list_view.dart` | `TaskState` | Filtered/sorted task list |
| `TaskCreateView` | `views/task/task_create_view.dart` | `TaskState` | Create task form |
| `TaskDetailView` | `views/task/task_detail_view.dart` | `TaskState` | Sections, linked conversations, status transitions |
| `ConversationListView` | `views/conversation/conversation_list_view.dart` | `ConversationListState` | Conversation history with type filter |
| `ConversationChatView` | `views/conversation/conversation_chat_view.dart` | `ConversationChatState` | Live chat with WS, tool use cards, question/permission handling |
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

`/tasks`, `/conversations` use `ProjectScopedNavView` to resolve the current project and redirect to the project-scoped route (e.g., `/projects/:id/tasks`).

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
