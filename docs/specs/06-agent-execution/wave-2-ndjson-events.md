# Wave 2 — NDJSON Events

> Spec: 06-Agent Execution
> Dependencies: 06-wave-1 (AgentRunner and TaskRun model must be complete)

## Deliverables

- [ ] StreamEvent model + migration + factory
- [ ] StreamEventType enum
- [ ] NDJSON normalization logic (strategy pattern — per CLI backend)
- [ ] Event persistence to stream_events table
- [ ] Broadcast via Reverb on `private-task-run.{taskRunId}` channel
- [ ] Integration with AgentRunner's streaming loop
- [ ] Feature tests for normalization
- [ ] Feature tests for event persistence
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## StreamEvent Schema

```
stream_events
├── id: uuid PK
├── task_run_id: uuid FK → task_runs
├── type: enum(system, assistant, result, question, auto_answer, file_change, error)
├── data: json                    // raw normalized event data
├── content_text: text nullable   // extracted text content (searchable)
├── file_path: string nullable    // if file_change type
├── is_question: boolean default false
├── occurred_at: timestamp
├── timestamps
```

**Migration notes**:
- FK on `task_run_id` references `task_runs.id`, cascade delete.
- Indexes: `(task_run_id, occurred_at)`, `(task_run_id, is_question)`.
- `data` column stores the full normalized event payload as JSON.
- `content_text` is extracted for searchability — used for replaying runs and searching agent output.
- `occurred_at` is the event timestamp from the NDJSON stream (not the DB insert time).

## StreamEventType Enum

```php
enum StreamEventType: string
{
    case System = 'system';
    case Assistant = 'assistant';
    case Result = 'result';
    case Question = 'question';
    case AutoAnswer = 'auto_answer';
    case FileChange = 'file_change';
    case Error = 'error';
}
```

## Claude Code Event Normalization

Claude Code outputs NDJSON (one JSON object per line) with `--output-format stream-json`. Each line has a `type` field.

### Normalization Table

| CC Event Type | CC Subtype | Canonical Type | Transform |
|--------------|------------|---------------|-----------|
| `system` | `init` | `system` | Extract `session_id`, `model` from event data. Store `session_id` on TaskRun if not set. |
| `assistant` | — | `assistant` | Pass `content` array (may contain `text` and `tool_use` blocks). Extract text into `content_text`. |
| `user` | — | *(drop)* | Tool results from the agent. Not broadcast to user — internal agent loop. |
| `result` | — | `result` | Map `is_error`, `total_cost_usd`, `duration_ms`, `usage` (input_tokens, output_tokens, cache_read, cache_write). This is the terminal event. |
| `elicitation` | — | `question` | Extract question text from the elicitation payload. Set `is_question = true`. Triggers Q&A flow (wave-3). |

### Normalization Service

```php
interface EventNormalizer
{
    /**
     * Normalize a raw NDJSON event into a canonical format.
     * Returns null if the event should be dropped.
     */
    public function normalize(array $rawEvent): ?NormalizedEvent;
}

class NormalizedEvent
{
    public function __construct(
        public StreamEventType $type,
        public array $data,
        public ?string $contentText,
        public ?string $filePath,
        public bool $isQuestion,
        public Carbon $occurredAt,
    ) {}
}
```

### ClaudeCodeNormalizer

```php
class ClaudeCodeNormalizer implements EventNormalizer
{
    public function normalize(array $rawEvent): ?NormalizedEvent
    {
        $type = $rawEvent['type'] ?? null;

        return match ($type) {
            'system' => $this->normalizeSystem($rawEvent),
            'assistant' => $this->normalizeAssistant($rawEvent),
            'user' => null,  // drop — tool results
            'result' => $this->normalizeResult($rawEvent),
            'elicitation' => $this->normalizeQuestion($rawEvent),
            default => null,  // unknown event types are dropped
        };
    }
}
```

### System Event Normalization

```php
private function normalizeSystem(array $raw): NormalizedEvent
{
    return new NormalizedEvent(
        type: StreamEventType::System,
        data: [
            'session_id' => $raw['session_id'] ?? null,
            'model' => $raw['model'] ?? null,
            'tools' => $raw['tools'] ?? [],
            'mcp_servers' => $raw['mcp_servers'] ?? [],
        ],
        contentText: null,
        filePath: null,
        isQuestion: false,
        occurredAt: Carbon::parse($raw['timestamp'] ?? now()),
    );
}
```

### Assistant Event Normalization

```php
private function normalizeAssistant(array $raw): NormalizedEvent
{
    $content = $raw['content'] ?? [];
    $textParts = collect($content)
        ->filter(fn ($block) => ($block['type'] ?? '') === 'text')
        ->pluck('text')
        ->implode("\n");

    return new NormalizedEvent(
        type: StreamEventType::Assistant,
        data: [
            'content' => $content,  // full content array (text + tool_use blocks)
            'role' => $raw['role'] ?? 'assistant',
        ],
        contentText: $textParts ?: null,
        filePath: null,
        isQuestion: false,
        occurredAt: Carbon::parse($raw['timestamp'] ?? now()),
    );
}
```

### Result Event Normalization

```php
private function normalizeResult(array $raw): NormalizedEvent
{
    return new NormalizedEvent(
        type: StreamEventType::Result,
        data: [
            'is_error' => $raw['is_error'] ?? false,
            'total_cost_usd' => $raw['total_cost_usd'] ?? null,
            'duration_ms' => $raw['duration_ms'] ?? null,
            'duration_api_ms' => $raw['duration_api_ms'] ?? null,
            'num_turns' => $raw['num_turns'] ?? null,
            'usage' => [
                'input_tokens' => $raw['usage']['input_tokens'] ?? 0,
                'output_tokens' => $raw['usage']['output_tokens'] ?? 0,
                'cache_read' => $raw['usage']['cache_read_input_tokens'] ?? 0,
                'cache_write' => $raw['usage']['cache_creation_input_tokens'] ?? 0,
            ],
            'result_text' => $raw['result'] ?? null,
        ],
        contentText: $raw['result'] ?? null,
        filePath: null,
        isQuestion: false,
        occurredAt: Carbon::parse($raw['timestamp'] ?? now()),
    );
}
```

### Question (Elicitation) Event Normalization

```php
private function normalizeQuestion(array $raw): NormalizedEvent
{
    // Claude Code elicitation events contain the question in the content
    $questionText = $raw['content'] ?? $raw['text'] ?? $raw['message'] ?? 'Agent asked a question';

    return new NormalizedEvent(
        type: StreamEventType::Question,
        data: [
            'question_text' => $questionText,
            'elicitation_id' => $raw['id'] ?? null,
        ],
        contentText: $questionText,
        filePath: null,
        isQuestion: true,
        occurredAt: Carbon::parse($raw['timestamp'] ?? now()),
    );
}
```

## OpenCode Event Normalization (Post-MVP Stub)

```php
class OpenCodeNormalizer implements EventNormalizer
{
    public function normalize(array $rawEvent): ?NormalizedEvent
    {
        // POST-MVP: Implement when OpenCode backend is added
        // Mapping reference:
        // | OC Event     | Canonical | Transform                     |
        // |-------------|-----------|-------------------------------|
        // | step_start  | system    | Session init equivalent       |
        // | text        | assistant | Text content                  |
        // | tool_use    | assistant | Tool call details             |
        // | step_finish | result    | Completion with cost/usage    |
        // | error       | error     | Error details                 |

        throw new \RuntimeException('OpenCode normalization not yet implemented.');
    }
}
```

## Event Persistence

### StreamEventService

```php
class StreamEventService
{
    public function persist(TaskRun $taskRun, NormalizedEvent $event): StreamEvent
    {
        return StreamEvent::create([
            'task_run_id' => $taskRun->id,
            'type' => $event->type,
            'data' => $event->data,
            'content_text' => $event->contentText,
            'file_path' => $event->filePath,
            'is_question' => $event->isQuestion,
            'occurred_at' => $event->occurredAt,
        ]);
    }
}
```

## Broadcasting

Each persisted StreamEvent is broadcast via Laravel Reverb on a private channel.

**Channel**: `private-task-run.{taskRunId}`

**Event mapping**:

| StreamEventType | Broadcast Event Name | Payload |
|----------------|---------------------|---------|
| system | `.agent.system` | `{type: 'system', session_id, model}` |
| assistant | `.agent.assistant` | `{type: 'assistant', role, content: [...]}` |
| result | `.agent.result` | `{type: 'result', is_error, total_cost_usd, duration_ms, usage}` |
| question | `.agent.question` | `{type: 'question', question_id, question_text}` |
| error | `.agent.error` | `{type: 'error', message}` |

**Channel authorization**:
```php
Broadcast::channel('task-run.{taskRunId}', function (User $user, int $taskRunId) {
    $taskRun = TaskRun::findOrFail($taskRunId);
    return $taskRun->task->project->team->hasMember($user);
});
```

## Integration with AgentRunner

Update the streaming loop in `AgentRunner::execute()` (from wave-1):

```php
// In the NDJSON reading loop:
foreach ($this->readNdjsonLines($process) as $line) {
    $rawEvent = json_decode($line, true);
    if ($rawEvent === null) continue; // skip malformed lines

    $normalized = $this->normalizer->normalize($rawEvent);
    if ($normalized === null) continue; // dropped event (e.g., 'user' type)

    // Persist
    $streamEvent = $this->streamEventService->persist($taskRun, $normalized);

    // Broadcast
    broadcast(new AgentStreamEvent($taskRun, $streamEvent))->toOthers();

    // Handle system event — store session_id on TaskRun
    if ($normalized->type === StreamEventType::System) {
        $taskRun->update([
            'session_id' => $normalized->data['session_id'] ?? $taskRun->session_id,
            'model' => $normalized->data['model'] ?? $taskRun->model,
        ]);
    }

    // Handle result event — update TaskRun with final data
    if ($normalized->type === StreamEventType::Result) {
        $this->handleResultEvent($taskRun, $normalized);
    }

    // Handle question event — delegate to wave-3
    if ($normalized->type === StreamEventType::Question) {
        $this->handleQuestionEvent($taskRun, $streamEvent, $normalized);
    }
}
```

## API Endpoint

### GET /api/task-runs/{run}/stream-events

Replay stream events for a run. Paginated, supports cursor-based pagination for real-time catch-up.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
```
?after_id=100          // return events with id > 100 (cursor for catch-up)
?per_page=50           // default: 50, max: 200
?type=assistant,result // filter by event type
```

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "task_run_id": 1,
            "type": "system",
            "data": {
                "session_id": "abc-123",
                "model": "claude-sonnet-4-6"
            },
            "content_text": null,
            "file_path": null,
            "is_question": false,
            "occurred_at": "2026-03-25T10:01:00Z",
            "created_at": "2026-03-25T10:01:00Z"
        },
        {
            "id": 2,
            "task_run_id": 1,
            "type": "assistant",
            "data": {
                "content": [
                    {"type": "text", "text": "I'll start by setting up the authentication..."}
                ],
                "role": "assistant"
            },
            "content_text": "I'll start by setting up the authentication...",
            "file_path": null,
            "is_question": false,
            "occurred_at": "2026-03-25T10:01:05Z",
            "created_at": "2026-03-25T10:01:05Z"
        }
    ],
    "meta": {
        "has_more": true,
        "last_id": 2
    }
}
```

**Errors**:
- `404` — Run not found or user not authorized

## Acceptance Criteria

### Event Normalization — System

**Given** a Claude Code NDJSON line with `type: "system"` and `subtype: "init"`,
**When** `ClaudeCodeNormalizer::normalize()` is called,
**Then** it returns a NormalizedEvent with type `system`, data containing `session_id` and `model`, and the TaskRun's `session_id` is updated.

### Event Normalization — Assistant

**Given** a Claude Code NDJSON line with `type: "assistant"` containing text and tool_use content blocks,
**When** `ClaudeCodeNormalizer::normalize()` is called,
**Then** it returns a NormalizedEvent with type `assistant`, data containing the full content array, and `content_text` containing only the text parts joined by newlines.

### Event Normalization — User (Drop)

**Given** a Claude Code NDJSON line with `type: "user"`,
**When** `ClaudeCodeNormalizer::normalize()` is called,
**Then** it returns null (event is dropped, not persisted or broadcast).

### Event Normalization — Result

**Given** a Claude Code NDJSON line with `type: "result"`,
**When** `ClaudeCodeNormalizer::normalize()` is called,
**Then** it returns a NormalizedEvent with type `result`, data containing `is_error`, `total_cost_usd`, `duration_ms`, and `usage` with token counts.

### Event Normalization — Elicitation

**Given** a Claude Code NDJSON line with `type: "elicitation"`,
**When** `ClaudeCodeNormalizer::normalize()` is called,
**Then** it returns a NormalizedEvent with type `question`, `is_question = true`, and `content_text` containing the question text.

### Event Persistence

**Given** a NormalizedEvent from the streaming loop,
**When** `StreamEventService::persist()` is called,
**Then** a StreamEvent record is created in the database with the correct type, data, content_text, file_path, is_question, and occurred_at.

### Broadcasting

**Given** a persisted StreamEvent,
**When** the broadcast is triggered,
**Then** an event is broadcast on the `private-task-run.{taskRunId}` channel with the correct event name and payload.

**Given** a user who is not a member of the task's team,
**When** they attempt to subscribe to `private-task-run.{taskRunId}`,
**Then** authorization fails and they cannot receive events.

### Stream Events API

**Given** a completed TaskRun with 10 stream events,
**When** GET `/api/task-runs/{run}/stream-events`,
**Then** all 10 events are returned ordered by `occurred_at`.

**Given** a TaskRun with 50 events and `?after_id=20`,
**When** GET stream events,
**Then** only events with id > 20 are returned (cursor-based pagination for real-time catch-up).

### OpenCode Normalizer Stub

**Given** a raw event passed to `OpenCodeNormalizer::normalize()`,
**When** the method is called,
**Then** it throws a RuntimeException indicating OpenCode normalization is not yet implemented.

## Implementation Notes

- Use Laravel's `BroadcastEvent` or custom event classes implementing `ShouldBroadcast`.
- Channel authorization is defined in `routes/channels.php`.
- `occurred_at` uses the timestamp from the NDJSON event, not `now()`. This preserves the agent's timeline even if there's processing delay.
- For the stream events API, cursor-based pagination (`after_id`) is preferred over offset pagination for real-time catch-up scenarios. Flutter connects via WebSocket for live events, then uses this API to backfill any missed events.
- Malformed NDJSON lines (invalid JSON) are silently skipped with a log warning.
- The normalizer is resolved via the strategy pattern — `ClaudeCodeStrategy` returns `ClaudeCodeNormalizer`, `OpenCodeStrategy` returns `OpenCodeNormalizer`.
