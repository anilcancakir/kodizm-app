# Spec 11 — Flutter App

> Flutter web + mobile application — all user-facing screens, state management, real-time communication.
> Dependencies: ALL backend specs (01-10) must be complete.
> Built on **magic** + **magic_starter** boilerplate — auth, team management, profile, layout, and routing come pre-built.

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Magic Starter Integration & Core Setup | Configure magic_starter for Kodizm, theme/branding, verify auth + team flows work |
| 2 | Project & Dashboard Screens | Project CRUD, dashboard with stats and active runs overview |
| 3 | Task Management Screens | Task CRUD, state machine visualization, section viewer |
| 4 | Agent Execution & Streaming | Real-time terminal view, WebSocket streaming (Reverb), start/view agent runs |
| 5 | Agent Q&A & Knowledge | Q&A flow for agent questions, knowledge document browser |
| 6 | Billing, Settings & Polish | Team billing/credits, usage history, app settings, responsive polish |

## What magic + magic_starter Provides (Pre-built)

The `magic` package and `magic_starter` scaffold provide a full production-ready base:

### Screens (already implemented)
- **Auth screens**: Login, Register, Forgot Password, Verify Email
- **Team screens**: Create Team, Team List, Team Switch, Invite Members, Manage Members
- **Profile screens**: Edit Profile, Avatar Upload, Change Password
- **Notifications**: In-app notification system

### Infrastructure (already implemented)
- **Responsive app layout**: Sidebar/drawer + header + bottom navigation (adaptive per breakpoint)
- **Go Router** with middleware (auth guards, team guards, redirect logic)
- **ChangeNotifier state management** with `MagicStateMixin` for loading/error states
- **Dio HTTP client** via `Http` facade (auth interceptor, error handling, retry)
- **Vault** secure storage for tokens (cross-platform)
- **DI system** for provider injection

### What We Build (Kodizm-specific)
- Project management screens
- Task management with state machine
- Agent execution with real-time streaming
- Agent Q&A flow
- Knowledge document browser
- Billing & usage views
- Dashboard with live stats

## Dependencies on Other Specs

- **01-Platform Core**: Auth endpoints (Sanctum token), team/role APIs
- **02-Project Management**: Project CRUD APIs, SSH key endpoints
- **03-Agent System**: Agent role APIs (role list for run selection)
- **04-Container Infrastructure**: Container lifecycle awareness (status display)
- **05-Task Management**: Task CRUD APIs, sections, state machine
- **06-Agent Execution**: Task run APIs, streaming endpoints, Q&A endpoints
- **07-Real-time Communication**: Reverb WebSocket channels, event formats
- **08-Knowledge System**: Document APIs (referenced in project detail)
- **09-Billing & Credits**: Balance/usage APIs, cost display
- **10-Git Integration**: Repo status display, SSH key setup flow

## Tech Decisions

### State Management: ChangeNotifier + MagicStateMixin

- All state classes extend `ChangeNotifier` and mix in `MagicStateMixin`
- `MagicStateMixin` provides standardized loading/error state handling (`isLoading`, `error`, `setLoading()`, `setError()`, `clearError()`)
- Provider injection via magic's DI system (service locator pattern)
- No Riverpod, no Bloc — ChangeNotifier is the standard across the entire app

### HTTP Client: magic's `Http` Facade

- Dio-based HTTP client accessed via `Http` facade (singleton)
- Auth interceptor automatically attaches `Authorization: Bearer {token}`
- Error interceptor maps HTTP status codes to typed exceptions
- Retry interceptor for transient failures (503, network errors)
- Base URL configuration per environment
- **Never use raw `http` or `dio` directly** — always go through `Http`

### All Model IDs: UUID (String)

- Every model ID field is `String` type in Dart (UUIDs from backend)
- This applies to: teams, projects, tasks, task runs, users, agent roles, documents, etc.
- No `int` IDs anywhere in the codebase

### Platform: Flutter Web + Mobile

- Responsive from day 1 — single codebase for web and mobile
- magic_starter provides responsive layout (sidebar on desktop, drawer + bottom nav on mobile)
- Mobile-first design, desktop-enhanced

### Auth: Sanctum Token

- Token stored in `Vault` (magic's secure storage abstraction)
- Token attached to every API request via Http facade's auth interceptor
- Auto-redirect to login on 401 responses

### WebSocket: Laravel Reverb

- `web_socket_channel` package for cross-platform WebSocket
- Private channels with Sanctum token auth
- Singleton service with auto-reconnect and exponential backoff
- Event deduplication by stream event ID

### Navigation: Go Router (via magic)

- Declarative routing with auth guards (pre-configured by magic)
- Deep linking support (web URLs, mobile deep links)
- Nested navigation for team/project/task hierarchy
- Middleware: unauthenticated -> login, no team selected -> team picker

### Key Packages

| Package | Purpose |
|---------|---------|
| `magic` | Core framework — Http facade, Vault, DI, MagicStateMixin |
| `magic_starter` | Scaffold — auth, team, profile screens, responsive layout |
| `go_router` | Navigation (configured by magic) |
| `web_socket_channel` | WebSocket |
| `freezed` + `json_serializable` | Immutable models, JSON serialization |
| `flutter_markdown` | Markdown rendering for task sections |
| `intl` | Date/number formatting |

## WebSocket Channel Reference

### private-task-run.{taskRunId}

| Event | Payload | UI Action |
|-------|---------|-----------|
| `.agent.system` | `{type, session_id, model}` | Show session start in terminal |
| `.agent.assistant` | `{type, role, content[]}` | Render text/tool output in terminal |
| `.agent.result` | `{type, is_error, total_cost_usd, duration_ms, usage}` | Show completion, update cost |
| `.agent.question` | `{type, question_id, question_text}` | Show question panel, highlight |
| `.agent.status` | `{status, task_run_id}` | Update status badge |

### private-team.{teamId}

| Event | Payload | UI Action |
|-------|---------|-----------|
| `.run.started` | `{task_run_id, task_id, agent_role}` | Add to active runs on dashboard |
| `.run.completed` | `{task_run_id, task_id, cost_usd}` | Move to completed, update balance |
| `.run.question` | `{task_run_id, task_id, question_text}` | Show notification badge |
| `.balance.updated` | `{team_id, new_balance, deducted}` | Update balance display |

## API Endpoints Consumed

### Auth (handled by magic_starter)
```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/logout
GET    /api/auth/user
POST   /api/auth/forgot-password
POST   /api/auth/reset-password
POST   /api/auth/verify-email
```

### Teams (handled by magic_starter)
```
GET    /api/teams
POST   /api/teams
GET    /api/teams/{team}
PUT    /api/teams/{team}
DELETE /api/teams/{team}
GET    /api/teams/{team}/members
POST   /api/teams/{team}/members
PUT    /api/teams/{team}/members/{id}
DELETE /api/teams/{team}/members/{id}
GET    /api/teams/{team}/balance
```

### Projects
```
GET    /api/teams/{team}/projects
POST   /api/teams/{team}/projects
GET    /api/teams/{team}/projects/{project}
PUT    /api/teams/{team}/projects/{project}
DELETE /api/teams/{team}/projects/{project}
GET    /api/teams/{team}/projects/{project}/repo-status
GET    /api/teams/{team}/projects/{project}/ssh-public-key
POST   /api/teams/{team}/projects/{project}/generate-ssh-key
```

### Agent Roles
```
GET    /api/teams/{team}/agent-roles
```

### Tasks
```
GET    /api/teams/{team}/projects/{project}/tasks
POST   /api/teams/{team}/projects/{project}/tasks
GET    /api/teams/{team}/projects/{project}/tasks/{task}
PUT    /api/teams/{team}/projects/{project}/tasks/{task}
DELETE /api/teams/{team}/projects/{project}/tasks/{task}
GET    /api/teams/{team}/projects/{project}/tasks/{task}/sections
```

### Task Runs
```
POST   /api/teams/{team}/projects/{project}/tasks/{task}/runs
GET    /api/teams/{team}/projects/{project}/tasks/{task}/runs
GET    /api/task-runs/{run}
POST   /api/task-runs/{run}/answer
POST   /api/task-runs/{run}/cancel
GET    /api/task-runs/{run}/stream-events
GET    /api/task-runs/{run}/questions
GET    /api/task-runs/{run}/file-changes
```

### Knowledge
```
GET    /api/teams/{team}/projects/{project}/documents
GET    /api/teams/{team}/projects/{project}/documents/{document}
```

### Dashboard & Usage
```
GET    /api/teams/{team}/dashboard
GET    /api/teams/{team}/usage
```

### AI Tokens
```
GET    /api/teams/{team}/ai-tokens
```
