# Wave 3 — Q&A Flow & Resume

> Spec: 06-Agent Execution
> Dependencies: 06-wave-2 (StreamEvent model and normalization), 04-wave-2 (container lifecycle warm/dead)

## Deliverables

- [ ] AgentQuestion model + migration + factory
- [ ] Answer API endpoint
- [ ] Questions list API endpoint
- [ ] Answer delivery IPC — warm container (Redis pub/sub → stdin pipe)
- [ ] Answer delivery IPC — dead container (new container + resume)
- [ ] Session resume logic
- [ ] Container lifecycle integration (warm/dead detection on answer)
- [ ] Feature tests for Q&A flow
- [ ] Feature tests for warm answer delivery
- [ ] Feature tests for dead resume
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## AgentQuestion Schema

```
agent_questions
├── id: uuid PK
├── task_run_id: uuid FK → task_runs
├── stream_event_id: uuid FK → stream_events nullable  // correlate with terminal stream
├── question_text: text
├── answer_text: text nullable
├── answered_by_user_id: uuid FK → users nullable
├── answered_at: timestamp nullable
├── created_at: timestamp
```

**Migration notes**:
- FK on `task_run_id` references `task_runs.id`, cascade delete.
- FK on `stream_event_id` references `stream_events.id`, set null on delete.
- FK on `answered_by_user_id` references `users.id`, set null on delete.
- Index: `(task_run_id, answered_at)`.
- No `updated_at` — answers are write-once (answered_at is the only update).

## Question Detection

When the NDJSON normalizer produces a `question` type event (from wave-2):

```php
// In AgentRunner streaming loop (called from wave-2 integration)
private function handleQuestionEvent(
    TaskRun $taskRun,
    StreamEvent $streamEvent,
    NormalizedEvent $normalized,
): void {
    // 1. Create AgentQuestion record
    $question = AgentQuestion::create([
        'task_run_id' => $taskRun->id,
        'stream_event_id' => $streamEvent->id,
        'question_text' => $normalized->data['question_text'],
    ]);

    // 2. Update TaskRun status
    $taskRun->update([
        'status' => TaskRunStatus::WaitingForInput,
        'warm_until' => now()->addSeconds(config('docker.warm_timeout')),
    ]);

    // 3. Set Redis warm state
    Redis::setex(
        "warm:{$taskRun->id}",
        config('docker.warm_timeout') + 60, // TTL with buffer
        now()->addSeconds(config('docker.warm_timeout'))->timestamp,
    );

    // 4. Broadcast question event
    broadcast(new AgentQuestionAsked($taskRun, $question))->toOthers();

    // 5. Broadcast on team channel too
    broadcast(new TeamRunQuestion($taskRun, $question))->toOthers();
}
```

## Answer Delivery Mechanism

Two paths depending on container state when user answers.

### Path 1: WARM Container (Container Still Alive)

```
User answers question via Flutter UI
         │
         ▼
POST /api/task-runs/{run}/answer { answer_text }
         │
         ▼
┌─ WARM CONTAINER (container still alive) ─────────────────┐
│ 1. Laravel publishes to Redis channel: agent:answer:{id}  │
│ 2. Streaming worker (running docker exec) subscribes to   │
│    this channel in a parallel thread/fiber                 │
│ 3. On message: write answer to process stdin pipe          │
│ 4. Claude Code receives answer via elicitation response    │
│ 5. Agent resumes execution, streaming continues            │
└───────────────────────────────────────────────────────────┘
```

**Implementation detail**: The streaming worker (which is reading stdout from `docker exec`) must simultaneously listen for answers on the Redis pub/sub channel. Options:

1. **Laravel fiber** (preferred): Use a fiber to subscribe to Redis pub/sub while the main fiber reads stdout.
2. **Separate process**: Fork a process that subscribes to Redis and writes to stdin when a message arrives.
3. **Polling**: Periodically check Redis for answers between stdout reads (less responsive).

```php
// In AgentRunner — warm answer delivery
private function subscribeForAnswers(TaskRun $taskRun, Process $process): void
{
    $channel = "agent:answer:{$taskRun->id}";

    Redis::subscribe([$channel], function (string $message) use ($process) {
        $answer = json_decode($message, true);
        $answerText = $answer['answer_text'] ?? '';

        // Write answer to process stdin (Claude Code reads from stdin for elicitation)
        $process->getInput()->write($answerText . "\n");
    });
}
```

### Path 2: DEAD Container (Container Removed)

```
User answers question via Flutter UI
         │
         ▼
POST /api/task-runs/{run}/answer { answer_text }
         │
         ▼
┌─ DEAD CONTAINER (container removed) ─────────────────────┐
│ 1. Laravel starts new container + session volume mount     │
│ 2. Builds resume command:                                  │
│    claude -p "User answered: {answer}" --resume {id}       │
│      --output-format stream-json ...                       │
│ 3. docker exec -i {new_container} {command}               │
│ 4. Fresh streaming worker picks up NDJSON output           │
│ 5. Standard execution flow from here                       │
└───────────────────────────────────────────────────────────┘
```

**Implementation**:

```php
private function resumeFromDead(TaskRun $taskRun, string $answerText): void
{
    // 1. Start new container with session volume
    $volumeMounts = $this->buildVolumeMounts($taskRun); // includes session volume
    $envVars = $this->buildEnvVars($taskRun);
    $containerName = $this->containerManager->start($taskRun, $volumeMounts, $envVars);

    // 2. Build resume command via strategy
    $command = $this->strategy->buildResumeCommand($taskRun, $answerText);
    // Claude Code: claude -p "User answered: {answer}" --resume {session_id}
    //   --output-format stream-json --model {model} ...

    // 3. Execute in new container
    $process = $this->containerManager->exec($containerName, $command);
    $process->start();

    // 4. Update TaskRun
    $taskRun->update([
        'status' => TaskRunStatus::Running,
        'container_name' => $containerName,
        'warm_until' => null,
    ]);

    // 5. Clear Redis warm state (safety — should already be cleared)
    Redis::del("warm:{$taskRun->id}");

    // 6. Dispatch new ExecuteAgentTask job to continue streaming
    // OR continue streaming in the current context
    $this->streamNdjsonOutput($taskRun, $process);
}
```

## Answer Delivery Service

```php
class AnswerDeliveryService
{
    public function __construct(
        private ContainerManager $containerManager,
        private AgentRunner $agentRunner,
    ) {}

    public function deliver(TaskRun $taskRun, AgentQuestion $question, string $answerText, User $user): void
    {
        // 1. Update question record
        $question->update([
            'answer_text' => $answerText,
            'answered_by_user_id' => $user->id,
            'answered_at' => now(),
        ]);

        // 2. Determine container state
        $isWarm = $taskRun->container_name
            && $this->containerManager->exists($taskRun->container_name);

        if ($isWarm) {
            // Publish answer to Redis channel — streaming worker will pipe to stdin
            Redis::publish("agent:answer:{$taskRun->id}", json_encode([
                'answer_text' => $answerText,
                'question_id' => $question->id,
            ]));

            // Update TaskRun status
            $taskRun->update([
                'status' => TaskRunStatus::Running,
                'warm_until' => null,
            ]);

            // Clear warm state
            Redis::del("warm:{$taskRun->id}");
        } else {
            // Dead container — resume with new container
            // Dispatch job to handle resume (container start + exec is heavy)
            ResumeAgentTask::dispatch($taskRun, $answerText);
        }

        // 3. Broadcast answer event
        broadcast(new AgentQuestionAnswered($taskRun, $question))->toOthers();
    }
}
```

## API Endpoints

### POST /api/task-runs/{run}/answer

Answer an agent's question.

**Headers**: `Authorization: Bearer {token}`

**Request**:
```json
{
    "answer_text": "string|required|max:10000"
}
```

**Response** `200 OK`:
```json
{
    "data": {
        "question": {
            "id": 1,
            "task_run_id": 1,
            "question_text": "Should I use Fortify or Breeze for authentication?",
            "answer_text": "Use Fortify — we need API-only auth, no frontend scaffolding.",
            "answered_by_user_id": 1,
            "answered_at": "2026-03-25T10:15:00Z",
            "created_at": "2026-03-25T10:10:00Z"
        },
        "delivery_method": "warm",
        "task_run_status": "running"
    }
}
```

**Business logic**:
1. Find the latest unanswered AgentQuestion for this TaskRun.
2. If no unanswered question exists: return 409 "No pending question."
3. Validate TaskRun status is `waiting_for_input`.
4. Call `AnswerDeliveryService::deliver()`.
5. Return the updated question and delivery method (warm/dead).

**Errors**:
- `409` — No pending question, or TaskRun not in waiting_for_input state
- `422` — Validation failed
- `403` — User does not have permission
- `404` — Run not found

---

### GET /api/task-runs/{run}/questions

List all questions for a run.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "task_run_id": 1,
            "stream_event_id": 15,
            "question_text": "Should I use Fortify or Breeze for authentication?",
            "answer_text": "Use Fortify — we need API-only auth, no frontend scaffolding.",
            "answered_by_user_id": 1,
            "answered_by_user": {
                "id": 1,
                "name": "John Doe"
            },
            "answered_at": "2026-03-25T10:15:00Z",
            "created_at": "2026-03-25T10:10:00Z"
        },
        {
            "id": 2,
            "task_run_id": 1,
            "stream_event_id": 28,
            "question_text": "The tests are failing. Should I fix them or continue?",
            "answer_text": null,
            "answered_by_user_id": null,
            "answered_at": null,
            "created_at": "2026-03-25T10:20:00Z"
        }
    ]
}
```

**Errors**:
- `404` — Run not found or user not authorized

## Container Lifecycle Integration

The Q&A flow integrates with the container lifecycle (04-wave-2):

### On Question Detected
1. TaskRun status → `waiting_for_input`
2. Container enters warm phase (Redis `warm:{task_run_id}` set)
3. Streaming worker pauses (waiting for stdin input)
4. Flutter UI shows question prompt

### On Answer — Warm Container
1. Redis pub/sub delivers answer to streaming worker
2. Worker writes to stdin → Claude Code resumes
3. TaskRun status → `running`
4. Streaming continues normally

### On Answer — Dead Container (Warm Expired)
1. `containers:cleanup-warm` already removed the container
2. Answer triggers `ResumeAgentTask` job
3. New container started with session volume mount
4. CLI invoked with `--resume {session_id}` and answer in prompt
5. TaskRun status → `running` with new container_name
6. Fresh streaming loop begins

### On No Answer — Session Expired (24h)
1. `sessions:cleanup` deletes session volume
2. TaskRun status → `timed_out`
3. Question remains unanswered

## Acceptance Criteria

### Question Detection

**Given** a running agent that emits an elicitation event,
**When** the NDJSON normalizer processes it,
**Then** an AgentQuestion record is created, the TaskRun status is set to `waiting_for_input`, a Redis warm key is set, and question events are broadcast on both the task-run and team channels.

### Answer — Warm Container

**Given** a TaskRun in `waiting_for_input` with a running container (warm phase),
**When** the user POSTs an answer,
**Then** the AgentQuestion is updated with the answer text and user, the answer is published to Redis channel `agent:answer:{task_run_id}`, the streaming worker pipes it to stdin, the TaskRun status returns to `running`, and the Redis warm key is deleted.

### Answer — Dead Container

**Given** a TaskRun in `waiting_for_input` with no container (dead phase, warm expired),
**When** the user POSTs an answer,
**Then** the AgentQuestion is updated with the answer, a `ResumeAgentTask` job is dispatched, a new container is started with the session volume mounted, the CLI is invoked with `--resume {session_id}` and the answer in the prompt, and the TaskRun is updated with the new container_name and status `running`.

### Answer — No Pending Question

**Given** a TaskRun where all questions have been answered,
**When** the user POSTs an answer,
**Then** a 409 response is returned with error "No pending question."

### Answer — Wrong Status

**Given** a TaskRun in `completed` status,
**When** the user POSTs an answer,
**Then** a 409 response is returned because the run is not in `waiting_for_input` state.

### Questions List

**Given** a TaskRun with 2 questions (1 answered, 1 pending),
**When** GET questions,
**Then** both questions are returned ordered by created_at, with the answered one showing answer_text and answered_at, and the pending one showing nulls.

### Session Resume

**Given** a dead container with a session volume preserved,
**When** a new container is started for resume,
**Then** the session volume is mounted at the correct path, the CLI command includes `--resume {session_id}`, and the agent continues from where it left off.

### Session ID Persistence

**Given** the first `system` event from Claude Code containing a `session_id`,
**When** it is processed,
**Then** the `session_id` is stored on the TaskRun and used for any future resume.

## Implementation Notes

- The Redis pub/sub for warm answer delivery requires the streaming worker to subscribe in a non-blocking way. Consider using Laravel's `Redis::subscribe()` in a fiber, or a separate subscriber process.
- `ResumeAgentTask` is a separate job from `ExecuteAgentTask` — it handles the dead resume flow (start new container, build resume command, stream output).
- The answer delivery mechanism is the most complex part of the system. The warm path (IPC via stdin) must be thoroughly tested.
- For Claude Code, the `--resume {session_id}` flag restores the conversation context from the session volume. The answer is included in the prompt (`-p "User answered: {answer}"`) so the agent knows the response.
- Concurrency: only one answer can be delivered at a time per TaskRun. The API should use a lock (Redis lock) to prevent race conditions.
- Broadcasting uses two channels: `private-task-run.{id}` for the run-specific view, and `private-team.{teamId}` for the team dashboard.
