# Spec 16 — External Integrations (Post-MVP)

> Bidirectional sync with project management tools, push notifications, GitHub/GitLab webhooks.
> Dependencies: 05-Task Management.
>
> **TDD**: All code developed test-first (red-green-refactor).

## Overview

External integrations connect Kodizm with existing development workflows. Rather than replacing existing tools, Kodizm syncs with them — tasks flow bidirectionally, notifications reach users on their preferred channels, and code changes automatically trigger PR workflows.

## Jira Bidirectional Sync

### Setup

- Per-project Jira integration config stored in `projects.settings`:
```json
{
    "integrations": {
        "jira": {
            "enabled": true,
            "base_url": "https://company.atlassian.net",
            "project_key": "KOD",
            "auth_type": "oauth2",
            "credentials_token_id": 42,
            "sync_mode": "bidirectional",
            "field_mapping": {},
            "webhook_secret": "whsec_..."
        }
    }
}
```

### Jira Auth
- OAuth 2.0 (recommended) or API token
- Credentials stored as AiToken with `provider: jira` (new enum value)
- Scoped to team

### Sync: Kodizm → Jira

| Kodizm Event | Jira Action |
|-------------|-------------|
| Task created | Create Jira issue (type mapping: story→Story, task→Task, bug→Bug, spike→Spike) |
| Task status changed | Transition Jira issue to mapped status |
| TaskSection created (analysis, plan) | Add Jira comment with section content |
| Task priority changed | Update Jira priority |
| Task description updated | Update Jira description |
| Agent run completed | Add comment: "Agent run completed — role: {role}, cost: ${cost}" |

### Sync: Jira → Kodizm

| Jira Event (via webhook) | Kodizm Action |
|--------------------------|--------------|
| Issue created | Create Kodizm task (if sync_mode includes inbound) |
| Issue status changed | Update Kodizm task status (mapped) |
| Issue updated (description, priority) | Update Kodizm task fields |
| Comment added | Add TaskSection (type: comments) |
| Issue deleted | Soft-delete Kodizm task |

### Status Mapping

| Kodizm Status | Default Jira Status | Configurable |
|--------------|--------------------| ------------|
| draft | To Do | Yes |
| analysis | In Analysis | Yes |
| planning | In Planning | Yes |
| in_progress | In Progress | Yes |
| review | In Review | Yes |
| testing | In QA | Yes |
| done | Done | Yes |
| failed | Failed | Yes |

### Field Mapping

Configurable per project in `field_mapping`:
```json
{
    "field_mapping": {
        "kodizm_title": "jira_summary",
        "kodizm_description": "jira_description",
        "kodizm_priority": "jira_priority",
        "kodizm_type": "jira_issuetype",
        "kodizm_acceptance_criteria": "jira_customfield_10001",
        "kodizm_estimated_complexity": "jira_story_points"
    }
}
```

### Conflict Resolution

- **Last-write-wins** with timestamps
- Each sync records `last_synced_at` on both sides
- If both updated since last sync → flag as conflict, user resolves in Kodizm UI
- Sync metadata stored in `task.settings.jira`:
```json
{
    "jira": {
        "issue_key": "KOD-123",
        "issue_id": "10042",
        "last_synced_at": "2026-03-25T10:00:00Z",
        "sync_status": "synced"
    }
}
```

### Implementation

```php
// Services
class JiraSyncService
{
    public function syncTaskToJira(Task $task): void;
    public function syncJiraToTask(array $webhookPayload): void;
    public function resolveConflict(Task $task, string $resolution): void;
    public function mapStatus(string $kodizmStatus): string;
    public function mapFields(Task $task): array;
}

// Event Listeners
class SyncTaskToJiraOnUpdate // listens to TaskUpdated event
class ProcessJiraWebhook     // handles incoming Jira webhooks

// Webhook endpoint
POST /api/webhooks/jira/{project} → JiraWebhookController@handle
```

## ClickUp Sync

Same architecture as Jira, with ClickUp-specific mappings:

### Setup
```json
{
    "integrations": {
        "clickup": {
            "enabled": true,
            "workspace_id": "123456",
            "space_id": "789",
            "list_id": "456",
            "auth_type": "api_key",
            "credentials_token_id": 43,
            "sync_mode": "bidirectional"
        }
    }
}
```

### ClickUp API
- REST API v2
- Auth via API key or OAuth2
- Webhooks for inbound sync

### Status Mapping

| Kodizm Status | Default ClickUp Status |
|--------------|----------------------|
| draft | To Do |
| analysis | In Analysis |
| planning | Planning |
| in_progress | In Progress |
| review | Review |
| testing | Testing |
| done | Complete |
| failed | Blocked |

### Implementation
- `ClickUpSyncService` — same interface pattern as `JiraSyncService`
- Webhook endpoint: `POST /api/webhooks/clickup/{project}`

## Push Notifications

### Channels

| Channel | Technology | Use Case |
|---------|-----------|----------|
| Mobile Push | Firebase Cloud Messaging (FCM) | Agent questions, run completions, pipeline stages |
| Email | Laravel Mail (Mailgun/SES) | Daily digest, escalation, critical alerts |

### FCM Integration (Mobile)

#### Setup
- Flutter: `firebase_messaging` package
- Backend: `laravel-notification-channels/fcm` package
- FCM server key stored in environment config

#### Device Registration
```
POST /api/devices/register
{
    "fcm_token": "device_token_here",
    "platform": "ios|android",
    "device_name": "iPhone 15 Pro"
}
```

#### Notification Types

| Event | Title | Body | Priority |
|-------|-------|------|----------|
| Agent question | "Agent needs your input" | "Developer asks: {question_preview}" | High |
| Run completed | "Run completed" | "{agent_role} finished — {task_title} ($cost)" | Normal |
| Run failed | "Run failed" | "{agent_role} failed — {task_title}: {error_preview}" | High |
| Pipeline awaiting approval | "Approval needed" | "Design for {task_title} ready for review" | High |
| Pipeline escalation | "Human intervention needed" | "{task_title}: {reason}" | Critical |
| Balance low | "Low balance" | "Team {team_name} balance: ${balance}" | Normal |

#### User Notification Preferences
```json
{
    "notifications": {
        "agent_question": { "push": true, "email": false },
        "run_completed": { "push": true, "email": false },
        "run_failed": { "push": true, "email": true },
        "pipeline_approval": { "push": true, "email": true },
        "escalation": { "push": true, "email": true },
        "balance_low": { "push": false, "email": true },
        "daily_digest": { "push": false, "email": true }
    }
}
```

### Email Notifications

#### Transactional Emails
- Agent question → immediate email (if enabled)
- Pipeline escalation → immediate email
- Run failure → immediate email (if enabled)

#### Digest Emails
- Daily digest: summary of all runs, costs, open questions, pending approvals
- Weekly digest: usage trends, cost breakdown by model, productivity metrics
- Schedule: configurable per user

### Implementation

```php
// Notification classes (Laravel Notifications)
class AgentQuestionNotification extends Notification implements ShouldQueue
{
    public function via($notifiable): array
    {
        return $this->resolveChannels($notifiable, 'agent_question');
        // Returns: ['fcm', 'mail'] based on user preferences
    }

    public function toFcm($notifiable): FcmMessage { ... }
    public function toMail($notifiable): MailMessage { ... }
}

// User preferences
// Stored in users.settings JSON column
```

## Slack Integration

### Setup
```json
{
    "integrations": {
        "slack": {
            "enabled": true,
            "webhook_url": "https://hooks.slack.com/services/...",
            "channel": "#kodizm-updates",
            "bot_token": "xoxb-...",
            "notification_types": ["run_completed", "run_failed", "pipeline_approval"]
        }
    }
}
```

### Slack Notifications

| Event | Slack Message Format |
|-------|---------------------|
| Run completed | `✅ *Developer* completed *{task_title}* — $0.47, 3m` |
| Run failed | `❌ *QA* failed on *{task_title}* — {error_preview}` |
| Agent question | `❓ *Developer* asks: "{question}" — <answer_url\|Answer>` |
| Pipeline approval | `🔍 Design for *{task_title}* needs approval — <review_url\|Review>` |
| Balance low | `⚠️ Team *{team_name}* balance low: $2.50` |

### Interactive Messages (Optional)
- "Answer" button → opens Kodizm in browser at the question screen
- "Approve/Reject" buttons → direct API calls from Slack (requires bot token)

### Implementation
- Slack notification channel: `laravel-notification-channels/slack`
- Webhook for outgoing messages
- Bot token for interactive features (slash commands, buttons)

## GitHub/GitLab Webhook Integration

### GitHub Integration

#### Setup
```json
{
    "integrations": {
        "github": {
            "enabled": true,
            "repo_full_name": "org/repo",
            "app_installation_id": 12345,
            "auto_pr": true,
            "auto_merge": false,
            "pr_template": "default"
        }
    }
}
```

#### Auto-PR Creation

When an agent run completes and has code changes on a feature branch:

1. Agent pushes changes to `feature/task-{id}` branch
2. Kodizm creates PR via GitHub API:
```
POST /repos/{owner}/{repo}/pulls
{
    "title": "[Kodizm] {task_title}",
    "body": "## Task\n{task_description}\n\n## Agent\n{agent_role} ({model})\n\n## Changes\n{file_changes_summary}\n\n## Acceptance Criteria\n{acceptance_criteria}",
    "head": "feature/task-{id}",
    "base": "{default_branch}"
}
```

3. Add labels: `kodizm`, `agent-{role_slug}`
4. Request reviewers (if configured)

#### Auto-Merge (Optional)

- After PR is approved (by human reviewers) AND Code Reviewer agent approves
- Merge strategy: squash merge (configurable: merge, squash, rebase)
- Only if all CI checks pass

#### PR Status Updates

When PR status changes (via webhook):
- PR merged → update task status to `done`
- PR closed without merge → add TaskSection comment
- CI checks failed → notify user, optionally trigger QA agent

#### Webhook Events Handled

| GitHub Event | Action |
|-------------|--------|
| `pull_request.opened` | Record PR URL on task |
| `pull_request.closed` | Update task status (merged → done) |
| `pull_request.review_submitted` | Add review feedback to task |
| `check_suite.completed` | Notify on CI failure |
| `push` | Detect changes to default branch |

### GitLab Integration

Same functionality as GitHub, adapted for GitLab API:
- Merge Requests instead of Pull Requests
- GitLab webhook events
- GitLab API for MR creation
- CI/CD pipeline status via webhooks

### Implementation

```php
// Services
class GitHubIntegrationService
{
    public function createPullRequest(Task $task, TaskRun $run): PullRequest;
    public function updatePRStatus(Task $task, string $status): void;
    public function handleWebhook(string $event, array $payload): void;
    public function mergePullRequest(Task $task): void;
}

// Webhook endpoint
POST /api/webhooks/github/{project} → GitHubWebhookController@handle
POST /api/webhooks/gitlab/{project} → GitLabWebhookController@handle

// Events
class CreatePullRequestOnRunCompletion // listens to TaskRunCompleted
```

## Database Additions

### integration_sync_logs (for debugging and conflict resolution)
```
integration_sync_logs
├── id: uuid PK
├── project_id: uuid FK → projects
├── integration_type: enum(jira, clickup, github, gitlab, slack)
├── direction: enum(inbound, outbound)
├── entity_type: string (task, comment, status)
├── entity_id: uuid
├── external_id: string nullable
├── payload: json
├── status: enum(success, failed, conflict)
├── error: text nullable
├── timestamps
```

### device_tokens (for FCM)
```
device_tokens
├── id: uuid PK
├── user_id: uuid FK → users
├── fcm_token: string
├── platform: enum(ios, android)
├── device_name: string nullable
├── last_used_at: timestamp nullable
├── timestamps
```

## API Endpoints

```
// Integration management
GET    /api/teams/{team}/projects/{project}/integrations          → List active integrations
PUT    /api/teams/{team}/projects/{project}/integrations/{type}   → Configure integration
DELETE /api/teams/{team}/projects/{project}/integrations/{type}   → Disable integration
POST   /api/teams/{team}/projects/{project}/integrations/{type}/test → Test connection

// Webhooks (public, verified by secret)
POST   /api/webhooks/jira/{project}
POST   /api/webhooks/clickup/{project}
POST   /api/webhooks/github/{project}
POST   /api/webhooks/gitlab/{project}
POST   /api/webhooks/slack/interactions

// Device registration
POST   /api/devices/register
DELETE /api/devices/{id}

// Notification preferences
GET    /api/auth/notification-preferences
PUT    /api/auth/notification-preferences
```
