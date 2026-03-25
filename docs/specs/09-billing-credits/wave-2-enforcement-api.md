# Spec 09, Wave 2 — Enforcement & API

> Pre-dispatch balance check, usage API endpoints, dashboard stats, and usage flush command.
> Dependencies: Wave 1 complete, 06-wave-4 (AgentRunner dispatches runs and records cost).

## Deliverables

1. Pre-dispatch balance check (402 enforcement)
2. Usage API endpoint (filterable)
3. Dashboard stats API endpoint
4. Scheduled `usage:flush` command for hourly aggregation
5. Tests for enforcement, API endpoints, flush command
6. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. Pre-dispatch Balance Check

Before dispatching any agent run, verify the team has sufficient balance.

### Logic

```
1. Load team for the task's project
2. Check: team.balance >= config('billing.min_balance', 0.10)
3. If insufficient → return 402 Payment Required
4. If sufficient → proceed with dispatch
```

### Integration Point

This check happens in the task run creation endpoint (`POST /api/teams/{team}/projects/{project}/tasks/{task}/runs`) BEFORE the `ExecuteAgentTask` job is dispatched to the queue.

### Configuration

```php
// config/billing.php
'min_balance' => env('BILLING_MIN_BALANCE', 0.10),
```

### 402 Response

```json
{
  "error": "insufficient_balance",
  "message": "Team balance is insufficient to start an agent run.",
  "current_balance": 0.05,
  "minimum_required": 0.10
}
```

## 2. Usage API Endpoint

### GET /api/teams/{team}/usage

List usage records for a team with optional filters.

**Auth**: Sanctum token — user must be Admin or Owner of the team.

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `from` | date (Y-m-d) | null | Start date (inclusive) |
| `to` | date (Y-m-d) | null | End date (inclusive) |
| `model` | string | null | Filter by model name |
| `project_id` | integer | null | Filter by project (via task_run → task → project) |
| `per_page` | integer | 20 | Pagination size (max 100) |

**Response** (200):
```json
{
  "data": [
    {
      "id": 1,
      "task_run_id": 123,
      "model": "claude-sonnet-4-6",
      "input_tokens": 15000,
      "output_tokens": 3500,
      "cache_read_tokens": 10000,
      "cache_write_tokens": 2000,
      "cost_usd": 0.097500,
      "period": "2026-03",
      "recorded_at": "2026-03-25T14:30:00Z",
      "task_run": {
        "id": 123,
        "task": {
          "id": 45,
          "title": "Implement auth",
          "project": {
            "id": 12,
            "name": "Backend"
          }
        }
      }
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 20,
    "total": 95,
    "totals": {
      "total_cost_usd": 12.450000,
      "total_input_tokens": 1500000,
      "total_output_tokens": 350000
    }
  }
}
```

- `meta.totals` provides aggregated totals for the filtered result set (not just the current page)
- Filter by date uses `recorded_at` column
- Filter by project joins through `task_runs → tasks → projects`

## 3. Dashboard Stats Endpoint

### GET /api/teams/{team}/dashboard

Aggregated stats for the team dashboard.

**Auth**: Sanctum token — user must be a member of the team (any role).

**Response** (200):
```json
{
  "data": {
    "active_runs": 2,
    "tasks_by_status": {
      "draft": 5,
      "in_progress": 3,
      "review": 1,
      "done": 42,
      "failed": 2
    },
    "costs_this_month": {
      "total_usd": 45.230000,
      "by_model": {
        "claude-sonnet-4-6": 32.100000,
        "claude-opus-4-6": 13.130000
      },
      "by_project": [
        { "project_id": 12, "project_name": "Backend", "cost_usd": 30.500000 },
        { "project_id": 13, "project_name": "Mobile", "cost_usd": 14.730000 }
      ]
    },
    "balance": 154.770000,
    "runs_this_month": 28
  }
}
```

### Query Details

| Stat | Query |
|------|-------|
| `active_runs` | Count of task_runs where status IN (pending, running, waiting_for_input) AND task.project.team_id = team |
| `tasks_by_status` | Count grouped by status for all tasks in team's projects |
| `costs_this_month` | Sum from team_usage_records where period = current YYYY-MM |
| `by_model` | Group by model for current period |
| `by_project` | Join to tasks/projects, group by project for current period |
| `balance` | `team.balance` |
| `runs_this_month` | Count of task_runs started this month |

## 4. Usage Flush Command

### Command: `usage:flush`

Scheduled hourly. Aggregates fine-grained usage records for performance.

### Behavior

```
1. Select team_usage_records older than 7 days
2. Group by: team_id, model, period
3. For each group:
   a. Sum: input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, cost_usd
   b. Create one aggregated record with task_run_id = null
   c. Delete the original individual records
4. Log: "Flushed {count} records into {aggregated} aggregated records"
```

### Schedule

```php
// routes/console.php or Kernel.php
Schedule::command('usage:flush')->hourly();
```

### Safety

- Only aggregates records older than 7 days (recent records stay individual for debugging)
- Runs in a DB transaction per group (atomic per team+model+period)
- Idempotent — running twice doesn't double-count (originals are deleted after aggregation)
- Aggregated records have `task_run_id = null` (no single run attribution)

### Configuration

```php
// config/billing.php
'flush_after_days' => env('USAGE_FLUSH_AFTER_DAYS', 7),
```

## 5. File Structure

```
app/Http/Controllers/Api/
├── UsageController.php          # Usage list endpoint
└── DashboardController.php      # Dashboard stats endpoint

app/Http/Resources/
└── TeamUsageRecordResource.php

app/Console/Commands/
└── FlushUsageRecordsCommand.php # usage:flush

config/
└── billing.php                  # min_balance, flush_after_days
```

## Acceptance Criteria

### Pre-dispatch Balance Check
- **Given** a team with balance 5.00, **when** a run is dispatched, **then** the run proceeds (balance > min_balance).
- **Given** a team with balance 0.05 and min_balance = 0.10, **when** a run is dispatched, **then** 402 is returned with `insufficient_balance` error.
- **Given** a team with balance exactly 0.10 and min_balance = 0.10, **when** a run is dispatched, **then** the run proceeds (>= check).
- **Given** a team with balance -0.50 (went negative from previous run), **when** a new run is dispatched, **then** 402 is returned.
- **Given** `BILLING_MIN_BALANCE=0.50` in env, **when** a team with balance 0.30 tries to dispatch, **then** 402 is returned (config respected).

### Usage API
- **Given** a team with 50 usage records, **when** `GET /api/teams/{team}/usage` is called, **then** a paginated list is returned with `meta.totals` for the full filtered set.
- **Given** `?from=2026-03-01&to=2026-03-15`, **when** called, **then** only records with `recorded_at` in that range are returned.
- **Given** `?model=claude-sonnet-4-6`, **when** called, **then** only records for that model are returned.
- **Given** `?project_id=12`, **when** called, **then** only records for runs in that project are returned.
- **Given** a user with Member role, **when** they call the usage endpoint, **then** 403 is returned (Admin/Owner only).
- **Given** a user with Admin role, **when** they call the usage endpoint, **then** 200 is returned.

### Dashboard Stats
- **Given** a team with 2 active runs and 42 completed tasks, **when** `GET /api/teams/{team}/dashboard` is called, **then** correct stats are returned.
- **Given** usage records for March 2026, **when** the dashboard is called in March 2026, **then** `costs_this_month` reflects the current month's total.
- **Given** a user with Viewer role, **when** they call the dashboard endpoint, **then** 200 is returned (any team member can view).

### Usage Flush Command
- **Given** 100 usage records older than 7 days for team 1, model `claude-sonnet-4-6`, period `2026-02`, **when** `usage:flush` runs, **then** those 100 records are replaced by 1 aggregated record with summed tokens and cost.
- **Given** records that are only 3 days old, **when** `usage:flush` runs, **then** those records are NOT aggregated (too recent).
- **Given** the aggregated record, **when** inspected, **then** `task_run_id` is null.
- **Given** `usage:flush` is run twice, **when** checked, **then** no double-counting occurs (idempotent).
- **Given** the command completes, **when** logs are checked, **then** the count of flushed and aggregated records is logged.
