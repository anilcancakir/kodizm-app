# Models

Complete inventory of 21 model classes. Two patterns: Magic ORM and Immutable Value Objects.

## Magic ORM Models

Extend `Model with HasTimestamps, InteractsWithPersistence`. All use `incrementing: false` (UUID PKs).

| Model | File | Table | Fillable Fields | Static Helpers |
|-------|------|-------|----------------|---------------|
| `User` | `user.dart` | `users` | name, email, phone, timezone, language | `find`, `all`, `fromMap`, `fromJson` |
| `Team` | `team.dart` | `teams` | name | `find`, `all`, `fromMap`, `fromJson` |
| `Project` | `project.dart` | `projects` | team_id, name, slug, description, tech_stack, execution_mode, settings | `find`, `all`, `fromMap`, `fromJson` |
| `Task` | `task.dart` | `tasks` | project_id, parent_task_id, title, type, priority, status, estimated_complexity, assigned_agent_role_id, created_by_user_id, source, design_needed, retry_count, branch_name, total_cost_usd, description, acceptance_criteria | `find`, `all`, `fromMap`, `fromJson` |

### Special Mixins

- `User` adds `Authenticatable` mixin for `Auth.user<User>()` support
- `Team` provides `toMagicStarterTeam()` for plugin interop

## Immutable Value Objects

Plain Dart classes with `const` constructors, `fromMap` factory, and optional `copyWith`.

| Model | File | Key Fields | copyWith | API Source |
|-------|------|-----------|----------|-----------|
| `Conversation` | `conversation.dart` | id, projectId, userId, agentRoleId, status, model, totalCostUsd, messagesCount, title, userName, agentRoleName/Slug, type, taskId, prompt | Yes | `/projects/{id}/conversations` |
| `ConversationMessage` | `conversation_message.dart` | id, conversationId, role, content, costUsd, usage, durationMs, numTurns, error, metadata | Yes | `/conversations/{id}/messages` |
| `ChatItem` | `chat_item.dart` | Sealed union: TextItem, ToolUseItem, ToolResultItem, ThinkingItem, ErrorItem | No | Parsed from ConversationMessage |
| `ProjectRepository` | `project_repository.dart` | id, projectId, name, repositoryUrl, defaultBranch, sshPublicKey, repoStatus, repoError, lastSyncedAt, mountPath | No | `/projects/{id}/repositories` |
| `DashboardData` | `dashboard_data.dart` | activeRuns, tasksSummary, recentRuns, balance, monthlyUsage | No | `/teams/{id}/dashboard` |
| `ActiveRun` | `dashboard_data.dart` | conversationId, taskId, taskTitle, agentRole, status, costUsd | No | Nested in DashboardData |
| `TasksSummary` | `dashboard_data.dart` | total, byStatus (Map) | No | Nested in DashboardData |
| `RecentRun` | `dashboard_data.dart` | conversationId, taskId, taskTitle, agentRole, status, costUsd, durationMs, completedAt | No | Nested in DashboardData |
| `MonthlyUsage` | `dashboard_data.dart` | totalCostUsd, period, runCount | No | Nested in DashboardData |
| `TaskSection` | `task_section.dart` | id, taskId, type, title, content, version, createdByAgentRoleName | No | `/tasks/{id}/sections` |
| `AgentRole` | `agent_role.dart` | id, name, slug, scope, cliBackend, preferredModel, systemPrompt, toolPermissions (17 fields) | No | `/teams/{id}/agent-roles` |
| `StreamEvent` | `stream_event.dart` | id, conversationId, type, data, contentText, filePath, isQuestion, sessionId, subagentId, parentEventId, model, turnNumber, metadata | No | `/conversations/{id}/stream-events` |
| `FileChange` | `file_change.dart` | filePath, operation (M/A/D) | No | Extracted from StreamEvent |
| `AgentQuestion` | `agent_question.dart` | id, conversationId, questionText, answerText, answeredAt | Yes | `/conversations/{id}/questions` |
| `ProjectDocument` | `project_document.dart` | id, projectId, title, content, category, createdByUserName, createdByAgentRoleName | No | `/projects/{id}/documents` |
| `Session` | `session.dart` | id, type, phase, model, totalCostUsd, token counts (4), warmUntil, usageRecords, shares | Yes | `/v1/sessions` |
| `SessionUsageRecord` | `session_usage_record.dart` | id, sessionId, turnNumber, model, token counts (4), costUsd, isSubagent, subagentType | No | Nested in Session |
| `SessionShare` | `session_share.dart` | id, sessionId, shareableType, shareableId, permission, sharedBy | No | Nested in Session |
| `TeamBalance` | `team_balance.dart` | balance, currency, maxConcurrentRuns | No | `/teams/{id}/balance` |
| `AiToken` | `ai_token.dart` | id, teamId, provider, authType, label, status, usageCount, settings | No | `/teams/{id}/ai-tokens` |
| `UsageRecord` | `usage_record.dart` | id, teamId, model, token counts, costUsd, period, agentRoleName, taskTitle | No | `/teams/{id}/usage` |
| `WebSocketEvent` | `lib/app/events/websocket_event.dart` | id, channel, eventName, data, receivedAt | No | Parsed from Pusher protocol frames |

## Conventions

- All IDs are `String` (UUID) -- never `int`
- Cost fields parsed from API decimal strings via `double.parse()`
- `fromMap()` uses `setRawAttributes(map, sync: true)` for ORM models
- Nested relations flattened in `fromMap()` (e.g., Conversation.userId from `user.id`)
- All files in `lib/app/models/` except `WebSocketEvent` in `lib/app/events/`
- `Conversation` serves dual purpose: interactive (user-driven chat) and autonomous (task execution) via `type` field
- Dashboard aggregate models (`ActiveRun`, `RecentRun`) reference `conversationId` (not legacy `taskRunId`)

## Related Docs

- [Projects and Tasks](projects-and-tasks.md) -- Project/Task model details
- [Sessions](sessions.md) -- Session model lifecycle
- [Conversations](conversations.md) -- Conversation model details
