# Kodizm App

Flutter frontend for Kodizm -- a multi-agent SDLC orchestrator. Single codebase targeting web and mobile. Built on **magic** framework (Laravel-inspired Flutter) with **Wind UI** (Tailwind-for-Flutter).

## Architecture Overview

| Layer | Technology | Notes |
|-------|-----------|-------|
| Framework | magic + magic_starter | ServiceProvider, IoC, Config, Auth, Http, Vault, MagicRoute |
| UI toolkit | Wind UI | WDiv, WText, WIcon, WSpacer, WAnchor, WFormInput with Tailwind className |
| State | ChangeNotifier + MagicStateMixin | Singleton per feature, injectable HTTP clients |
| HTTP | Http facade (wraps Dio) | Abstracted behind per-state interfaces |
| WebSocket | WebSocketService (Pusher protocol) | Auto-reconnect, exponential backoff, private channel auth |
| Routing | MagicRoute | Auth-guarded group with AppLayout, GoRouter under the hood |
| Auth | Sanctum token via magic_starter | Auth.check(), Auth.user<User>(), Auth.logout() |
| Models | Magic ORM + Immutable VOs | 21 models, all IDs are String UUIDs |
| Widgets | Atomic design | 9 atoms, 2 molecules, 14 organisms |
| i18n | trans() from en.json | 37 sections, 765+ keys |
| Design | docs/DESIGN.md | Primary Navy + Amber Gold, Albert Sans + JetBrains Mono |

## Feature Map

| Feature | Views | State | Models | Routes |
|---------|-------|-------|--------|--------|
| Dashboard | DashboardView | DashboardState | DashboardData, ActiveRun, TasksSummary, RecentRun, MonthlyUsage | `/`, `/dashboard` |
| Projects | ProjectListView, ProjectDetailView | ProjectState | Project, ProjectRepository | `/projects` |
| Tasks | TaskListView, TaskCreateView, TaskDetailView | TaskState | Task, TaskSection, AgentRole | `/projects/:id/tasks` |
| Conversations | ConversationListView, ConversationChatView | ConversationListState, ConversationChatState | Conversation, ConversationMessage, ChatItem | `/projects/:id/conversations`, `/projects/:id/chat`, `/projects/:id/chats/:conversationId` |
| Knowledge | KnowledgeListView, KnowledgeDetailView | DocumentState | ProjectDocument | `.../knowledge` |
| Sessions | SessionListView, SessionDetailView | SessionState | Session, SessionUsageRecord, SessionShare | `/sessions` |
| Billing | BillingView, UsageHistoryView | BillingState, UsageState | TeamBalance, UsageRecord | `/billing`, `/usage` |
| AI Tokens | AiTokenListView | AiTokenState | AiToken | `/settings/ai-tokens` |
| Settings | AppSettingsView | SettingsState | -- | `/settings/app` |
| Auth | Pre-built (magic_starter) | magic_starter | User, Team | `/login`, `/register` |

## Documentation Index

| Document | Description |
|----------|-------------|
| [sessions.md](sessions.md) | Session models, SessionState, session views, WebSocket events |
| [conversations.md](conversations.md) | Conversation models (interactive + autonomous), state classes, chat views |
| [projects-and-tasks.md](projects-and-tasks.md) | Project/Task models, state, views, routes |
| [models.md](models.md) | Complete 21-model inventory (ORM + immutable VOs) |
| [state-management.md](state-management.md) | All 11 state classes with interfaces and methods |
| [views-and-routes.md](views-and-routes.md) | All 16 views, 22+ routes, navigation structure |
| [widgets.md](widgets.md) | Atoms, molecules, organisms inventory |
| [design-system.md](design-system.md) | Design token quick reference (links to DESIGN.md) |
| [websocket.md](websocket.md) | WebSocketService, channel patterns, per-state integration |
| [data-flow.md](data-flow.md) | HTTP and WebSocket data flow patterns |
| [DESIGN.md](DESIGN.md) | Full design system source of truth |

For coding conventions, widget rules, and testing patterns, see `CLAUDE.md`.
