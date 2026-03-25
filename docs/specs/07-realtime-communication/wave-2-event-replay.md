# Spec 07, Wave 2 — Event Replay

> Stream event replay API for reconnection catch-up. Clients that disconnect and reconnect can fetch missed events.
> Dependencies: Wave 1 complete, 06-wave-2 (StreamEvent model must exist).

## Deliverables

1. Stream event replay API endpoint
2. Cursor-based pagination
3. Summary mode for completed runs with large event counts
4. Event TTL configuration and cleanup
5. Tests for replay endpoint, pagination, summary mode, TTL
6. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. API Endpoint

### GET /api/task-runs/{run}/stream-events

Replay stream events for a task run. Used by Flutter clients on reconnection to catch up on missed events.

**Route**: `GET /api/task-runs/{run}/stream-events`
**Auth**: Sanctum token — user must be member of the team that owns the task's project (same auth as task-run channel).

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `after_id` | integer, nullable | null | Return events with ID > this value. Null = from beginning. |
| `limit` | integer | 100 | Max events to return. Min 1, max 500. |

**Response** (200):
```json
{
  "data": [
    {
      "id": 1001,
      "type": "system",
      "data": { "session_id": "sess_abc", "model": "claude-sonnet-4-6" },
      "content_text": null,
      "is_question": false,
      "occurred_at": "2026-03-25T10:00:00Z"
    },
    {
      "id": 1002,
      "type": "assistant",
      "data": { "role": "assistant", "content": [{ "type": "text", "text": "Analyzing..." }] },
      "content_text": "Analyzing...",
      "is_question": false,
      "occurred_at": "2026-03-25T10:00:01Z"
    }
  ],
  "meta": {
    "has_more": true,
    "next_cursor": 1100,
    "total_count": 2450,
    "mode": "full"
  }
}
```

## 2. Pagination

- **Cursor-based** using stream event `id` (uuid PK, ordered by `occurred_at`)
- `after_id=N` returns events where `stream_events.id > N`, ordered by `id ASC`
- `limit` defaults to 100, clamped to range [1, 500]
- `meta.has_more` indicates whether more events exist beyond the returned set
- `meta.next_cursor` is the `id` of the last event in the response (use as `after_id` for next page)
- `meta.total_count` is the total number of events for this task run (for progress indication)

### Query Strategy

```sql
SELECT * FROM stream_events
WHERE task_run_id = ?
  AND id > ?           -- after_id (0 if null)
ORDER BY id ASC
LIMIT ?                -- limit (default 100)
```

Index used: `(task_run_id, id)` — composite index ensures efficient cursor queries. The existing `(task_run_id, occurred_at)` index does not cover this; add a new index if needed or rely on PK + FK index.

## 3. Summary Mode

For completed runs with very large event counts, return a summarized version to avoid overwhelming the client on initial load.

### Trigger Condition

- Task run status is `completed` or `failed`
- AND total event count for this run > 1000
- AND `after_id` is null (initial load, not pagination)

### Summary Behavior

When summary mode activates, return only:
1. **First system event** — session init info
2. **All question events** — `is_question = true`
3. **Last result event** — final cost/usage/completion info

This gives the client enough context to render a summary view without transferring thousands of events.

**Response in summary mode**:
```json
{
  "data": [
    { "id": 1, "type": "system", "data": { "session_id": "sess_abc", "model": "claude-sonnet-4-6" }, "occurred_at": "..." },
    { "id": 500, "type": "question", "data": { "question_id": 12, "question_text": "..." }, "is_question": true, "occurred_at": "..." },
    { "id": 2450, "type": "result", "data": { "is_error": false, "total_cost_usd": 1.23 }, "occurred_at": "..." }
  ],
  "meta": {
    "has_more": false,
    "next_cursor": null,
    "total_count": 2450,
    "mode": "summary",
    "full_replay_available": true
  }
}
```

- `meta.mode` is `"summary"` (vs `"full"` for normal mode)
- `meta.full_replay_available` indicates the client can paginate through all events using `after_id`
- Client can opt into full replay by passing `after_id=0` explicitly

## 4. Event TTL

Stream events are kept for a configurable period, then archived or deleted.

### Configuration

```php
// config/streaming.php
'event_ttl_days' => env('STREAM_EVENT_TTL_DAYS', 30),
```

### Cleanup

- Scheduled command: `stream-events:cleanup`
- Runs daily (configured in `routes/console.php` or `app/Console/Kernel.php`)
- Deletes stream events where `occurred_at < now() - event_ttl_days`
- Batch delete (chunk of 1000) to avoid long-running queries
- Log count of deleted events

### Behavior

- Events within TTL: returned normally via replay API
- Events beyond TTL: deleted, not available
- If all events for a run are deleted, the replay endpoint returns empty data with `total_count: 0`

## 5. File Structure

```
app/Http/Controllers/Api/
└── StreamEventController.php       # Replay endpoint

app/Console/Commands/
└── CleanupStreamEventsCommand.php  # stream-events:cleanup

config/
└── streaming.php                   # event_ttl_days
```

## Acceptance Criteria

### Basic Replay
- **Given** a task run with 50 stream events, **when** `GET /api/task-runs/{run}/stream-events` is called without parameters, **then** all 50 events are returned ordered by ID ascending, with `meta.mode = "full"` and `meta.has_more = false`.
- **Given** a task run with 250 events, **when** called with `limit=100`, **then** the first 100 events are returned with `meta.has_more = true` and `meta.next_cursor` set to the last event's ID.

### Cursor Pagination
- **Given** a task run with 250 events, **when** called with `after_id=100&limit=100`, **then** events with ID 101-200 are returned.
- **Given** `after_id` pointing to the last event, **when** called, **then** an empty data array is returned with `meta.has_more = false`.
- **Given** `limit=600`, **when** called, **then** limit is clamped to 500.
- **Given** `limit=0`, **when** called, **then** validation error is returned (min 1).

### Summary Mode
- **Given** a completed task run with 1500 events and `after_id` is null, **when** called, **then** only the first system event, all question events, and the last result event are returned, with `meta.mode = "summary"`.
- **Given** a completed task run with 1500 events and `after_id=0`, **when** called, **then** full replay mode is used (summary bypassed), returning the first 100 events with `meta.mode = "full"`.
- **Given** a running task run with 1500 events, **when** called, **then** full mode is used (summary only applies to completed/failed runs).
- **Given** a completed task run with 800 events (< 1000 threshold), **when** called, **then** full mode is used.

### Authorization
- **Given** a user who is a member of the team that owns the task's project, **when** they call the replay endpoint, **then** the response is 200.
- **Given** a user who is NOT a member of the team, **when** they call the replay endpoint, **then** the response is 403.
- **Given** a non-existent task run ID, **when** called, **then** the response is 404.

### Event TTL
- **Given** `event_ttl_days` is set to 30, **when** `stream-events:cleanup` runs, **then** events older than 30 days are deleted.
- **Given** events exactly 30 days old, **when** cleanup runs, **then** they are preserved (only events strictly older are deleted).
- **Given** 5000 events to delete, **when** cleanup runs, **then** deletion happens in batches of 1000 to avoid query timeouts.
- **Given** cleanup completes, **when** checked, **then** the count of deleted events is logged.
