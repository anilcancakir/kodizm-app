# Wave 4 — Cost Recording

> Spec: 06-Agent Execution
> Dependencies: 06-wave-1 (TaskRun model, AgentRunner), 09-wave-1 (Team balance — can be built in parallel)

## Deliverables

- [ ] TeamUsageRecord model + migration + factory
- [ ] `config/model-pricing.php` config file
- [ ] CostCalculationService
- [ ] Balance deduction logic
- [ ] Handling missing result event (crash/timeout fallback)
- [ ] Usage API endpoint
- [ ] Feature tests for cost calculation
- [ ] Feature tests for balance deduction
- [ ] Feature tests for usage API
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## TeamUsageRecord Schema

```
team_usage_records
├── id: uuid PK
├── team_id: uuid FK → teams
├── task_run_id: uuid FK → task_runs nullable
├── model: string nullable
├── input_tokens: bigint unsigned nullable
├── output_tokens: bigint unsigned nullable
├── cost_usd: decimal(10,6)
├── period: string                    // '2026-03' (month)
├── recorded_at: timestamp
├── timestamps
```

**Migration notes**:
- FK on `team_id` references `teams.id`, cascade delete.
- FK on `task_run_id` references `task_runs.id`, set null on delete.
- Indexes: `(team_id, recorded_at)`, `(team_id, period)`.
- `cost_usd` uses `decimal(10,6)` for precision — individual runs can cost fractions of a cent.
- `period` is a string in `YYYY-MM` format for monthly aggregation.
- `model` stores the actual model used (from TaskRun.model).

## Config: Model Pricing

### config/model-pricing.php

```php
<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Model Pricing (per million tokens)
    |--------------------------------------------------------------------------
    | NOTE: These are placeholder prices. For production, move to DB
    | (Filament-editable ModelPricing resource) so admins can update
    | without deployment.
    */

    'models' => [
        'claude-opus-4-6' => [
            'input' => 5.00,
            'output' => 25.00,
        ],
        'claude-sonnet-4-6' => [
            'input' => 3.00,
            'output' => 15.00,
        ],
        'claude-haiku-4-5' => [
            'input' => 0.80,
            'output' => 4.00,
        ],
        // Post-MVP models:
        // 'gpt-5.4' => [
        //     'input' => 6.00,
        //     'output' => 18.00,
        // ],
        // 'gemini-3.1-pro' => [
        //     'input' => 3.00,
        //     'output' => 12.00,
        // ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Fallback Pricing
    |--------------------------------------------------------------------------
    | Used when model is not in the pricing table.
    */
    'fallback' => [
        'input' => 5.00,
        'output' => 25.00,
    ],
];
```

## CostCalculationService

```php
class CostCalculationService
{
    /**
     * Calculate cost in USD from token usage.
     *
     * Formula: (input_tokens / 1_000_000 * input_price) + (output_tokens / 1_000_000 * output_price)
     */
    public function calculate(string $model, int $inputTokens, int $outputTokens): float
    {
        $pricing = config("model-pricing.models.{$model}")
            ?? config('model-pricing.fallback');

        $inputCost = ($inputTokens / 1_000_000) * $pricing['input'];
        $outputCost = ($outputTokens / 1_000_000) * $pricing['output'];

        return round($inputCost + $outputCost, 6);
    }

    /**
     * Get model pricing or fallback.
     */
    public function getPricing(string $model): array
    {
        return config("model-pricing.models.{$model}")
            ?? config('model-pricing.fallback');
    }
}
```

## Balance Deduction Flow

Triggered when a `result` event is received during NDJSON streaming (from wave-2).

```php
// In AgentRunner — called from handleResultEvent()
private function recordCostAndDeductBalance(TaskRun $taskRun, NormalizedEvent $resultEvent): void
{
    $team = $taskRun->task->project->team;
    $model = $taskRun->model;
    $usage = $resultEvent->data['usage'] ?? [];

    $inputTokens = $usage['input_tokens'] ?? 0;
    $outputTokens = $usage['output_tokens'] ?? 0;

    // 1. Calculate cost
    $costUsd = $this->costCalculationService->calculate($model, $inputTokens, $outputTokens);

    // 2. Create usage record
    $usageRecord = TeamUsageRecord::create([
        'team_id' => $team->id,
        'task_run_id' => $taskRun->id,
        'model' => $model,
        'input_tokens' => $inputTokens,
        'output_tokens' => $outputTokens,
        'cost_usd' => $costUsd,
        'period' => now()->format('Y-m'),
        'recorded_at' => now(),
    ]);

    // 3. Deduct from team balance (atomic)
    DB::transaction(function () use ($team, $costUsd) {
        $team->lockForUpdate();
        $team->decrement('balance', $costUsd);
    });

    // 4. Update TaskRun with cost data
    $taskRun->update([
        'total_cost_usd' => $costUsd,
        'usage' => [
            'input_tokens' => $inputTokens,
            'output_tokens' => $outputTokens,
            'cache_read' => $usage['cache_read'] ?? 0,
            'cache_write' => $usage['cache_write'] ?? 0,
        ],
    ]);

    // 5. Update Task total cost
    $taskRun->task->increment('total_cost_usd', $costUsd);

    // 6. Broadcast balance update on team channel
    broadcast(new TeamBalanceUpdated($team, $costUsd))->toOthers();
}
```

## Handling Missing Result Event

When an agent run crashes, times out, or is cancelled, the `result` NDJSON event may never arrive. In these cases, cost must still be estimated.

```php
private function handleMissingResultEvent(TaskRun $taskRun): void
{
    $team = $taskRun->task->project->team;

    // Use max_budget_usd from agent role config as estimated cost
    $agentRole = $taskRun->agentRole;
    $maxBudget = $agentRole->backend_config['claude-code']['max_budget_usd']
        ?? config('execution.default_max_budget_usd', 5.00);

    // Use a conservative estimate: 50% of max budget
    // This prevents over-charging while still accounting for costs
    $estimatedCost = round($maxBudget * 0.50, 6);

    // Create usage record with null tokens (unknown)
    TeamUsageRecord::create([
        'team_id' => $team->id,
        'task_run_id' => $taskRun->id,
        'model' => $taskRun->model,
        'input_tokens' => null,
        'output_tokens' => null,
        'cost_usd' => $estimatedCost,
        'period' => now()->format('Y-m'),
        'recorded_at' => now(),
    ]);

    // Deduct estimated cost
    DB::transaction(function () use ($team, $estimatedCost) {
        $team->lockForUpdate();
        $team->decrement('balance', $estimatedCost);
    });

    // Update TaskRun
    $taskRun->update([
        'total_cost_usd' => $estimatedCost,
    ]);

    // Update Task total cost
    $taskRun->task->increment('total_cost_usd', $estimatedCost);

    // Broadcast
    broadcast(new TeamBalanceUpdated($team, $estimatedCost))->toOthers();
}
```

**When to call**: In the `ExecuteAgentTask::failed()` handler and in the orphan detection scheduled command, check if a usage record already exists for this TaskRun. If not, call `handleMissingResultEvent()`.

## API Endpoint

### GET /api/teams/{team}/usage

Team usage records, filterable by date range, model, and project.

**Headers**: `Authorization: Bearer {token}`

**Query Parameters**:
```
?from=2026-03-01        // start date (inclusive)
?to=2026-03-31          // end date (inclusive)
?model=claude-sonnet-4-6  // filter by model
?project_id=1           // filter by project
?period=2026-03         // filter by period (month)
?per_page=50            // pagination (default: 50, max: 200)
```

**Response** `200 OK`:
```json
{
    "data": [
        {
            "id": 1,
            "team_id": 1,
            "task_run_id": 5,
            "task_run": {
                "id": 5,
                "task_id": 1,
                "task": {
                    "id": 1,
                    "title": "Implement user authentication"
                }
            },
            "model": "claude-sonnet-4-6",
            "input_tokens": 15234,
            "output_tokens": 8721,
            "cost_usd": "0.176445",
            "period": "2026-03",
            "recorded_at": "2026-03-25T10:12:00Z",
            "created_at": "2026-03-25T10:12:00Z"
        }
    ],
    "meta": {
        "current_page": 1,
        "last_page": 2,
        "per_page": 50,
        "total": 85,
        "summary": {
            "total_cost_usd": "12.543210",
            "total_input_tokens": 1523400,
            "total_output_tokens": 872100,
            "record_count": 85
        }
    }
}
```

**Notes**:
- The `summary` in meta provides aggregated totals for the current filter — useful for dashboard display.
- Filter by `project_id` joins through `task_run → task → project`.
- Admin and Owner roles can see all team usage. Members can see usage for their own runs.

**Errors**:
- `403` — User does not have permission (Viewer role cannot see usage)
- `422` — Invalid date format or filter values

## Acceptance Criteria

### Cost Calculation

**Given** a model `claude-sonnet-4-6` with pricing (input: $3.00, output: $15.00 per million tokens),
**When** `CostCalculationService::calculate()` is called with 15,234 input tokens and 8,721 output tokens,
**Then** the cost is calculated as `(15234 / 1_000_000 * 3.00) + (8721 / 1_000_000 * 15.00)` = `0.045702 + 0.130815` = `0.176517` (rounded to 6 decimal places).

**Given** a model not in the pricing config,
**When** `CostCalculationService::calculate()` is called,
**Then** the fallback pricing is used.

### Balance Deduction on Result Event

**Given** a team with balance $10.00 and a TaskRun that completes with a result event containing usage data,
**When** the result event is processed,
**Then** a TeamUsageRecord is created with the calculated cost, the team balance is decremented atomically, the TaskRun is updated with total_cost_usd and usage, the Task's total_cost_usd is incremented, and a `.balance.updated` event is broadcast on the team channel.

**Given** a team with balance $0.05 and a run that costs $0.18,
**When** the result event is processed,
**Then** the balance becomes negative ($-0.13) — soft limit, deduction still happens. The next run dispatch will be blocked due to insufficient balance.

### Missing Result Event Handling

**Given** a TaskRun that fails or times out without emitting a result event,
**When** the failure handler runs,
**Then** an estimated cost (50% of max_budget_usd) is recorded, a TeamUsageRecord is created with null tokens, and the team balance is decremented.

**Given** a TaskRun that already has a TeamUsageRecord,
**When** the failure handler runs,
**Then** no duplicate usage record is created (idempotency check).

### Atomic Balance Deduction

**Given** two concurrent result events for the same team,
**When** both attempt to deduct from the balance simultaneously,
**Then** the `lockForUpdate()` ensures both deductions are applied correctly (no race condition).

### Usage API

**Given** a team with 10 usage records across 2 months,
**When** GET `/api/teams/{team}/usage?period=2026-03`,
**Then** only records with period `2026-03` are returned, with a summary showing total cost and token counts for that period.

**Given** a team with usage records across 3 projects,
**When** GET `/api/teams/{team}/usage?project_id=1`,
**Then** only records for project 1 are returned (joined through task_run → task → project).

**Given** a team member (not admin/owner),
**When** GET `/api/teams/{team}/usage`,
**Then** only usage records for their own runs are returned (scoped by created runs).

### Model Pricing Config

**Given** the application is bootstrapped,
**When** `config('model-pricing.models.claude-sonnet-4-6')` is accessed,
**Then** it returns `['input' => 3.00, 'output' => 15.00]`.

## Implementation Notes

- Balance deduction uses `DB::transaction()` with `lockForUpdate()` for atomicity. This prevents race conditions when multiple runs complete simultaneously for the same team.
- `team.decrement('balance', $costUsd)` uses Laravel's atomic decrement — no need to read-then-write.
- The `period` field (`YYYY-MM`) enables efficient monthly aggregation without date range queries.
- For the usage API summary, use a raw query or `DB::raw()` to calculate sums efficiently.
- The missing result event handler uses 50% of max_budget as a conservative estimate. This can be refined later (e.g., use average cost of similar runs).
- Broadcasting the balance update on the team channel allows the Flutter dashboard to show real-time balance changes.
- **Future**: Move pricing from config to DB (ModelPricing Filament resource) for admin-editable pricing without deployment.
