# Spec 09, Wave 1 — Balance & Usage

> TeamUsageRecord model, cost calculation service, balance field on Team.
> Dependencies: 01 complete (teams exist).

## Deliverables

1. TeamUsageRecord model with relationships and casts
2. Migration for `team_usage_records` table
3. Factory for TeamUsageRecord
4. Migration to add `balance` field to `teams` table (if not already present)
5. CostCalculationService — calculate cost from token usage + model pricing
6. UsageRecordingService — create usage record + deduct balance
7. Model pricing config file
8. Tests for model, cost calculation, balance deduction
9. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. TeamUsageRecord Schema

```
team_usage_records
├── id: uuid PK
├── team_id: uuid FK → teams
├── task_run_id: uuid FK → task_runs nullable
├── model: string
├── input_tokens: bigint default 0
├── output_tokens: bigint default 0
├── cache_read_tokens: bigint default 0
├── cache_write_tokens: bigint default 0
├── cost_usd: decimal(10,6)
├── period: string          // '2026-03' for monthly aggregation
├── recorded_at: timestamp
├── timestamps
```

### Migration Notes

- `team_id`: foreign key to `teams`, cascades on delete
- `task_run_id`: nullable FK to `task_runs` — null for manual adjustments (admin credits, etc.)
- `model`: string storing the model identifier (e.g., `claude-sonnet-4-6`)
- `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`: bigint, default 0
- `cost_usd`: `decimal(10,6)` — 6 decimal places for per-record precision
- `period`: string in `YYYY-MM` format (e.g., `2026-03`), set at record creation time
- `recorded_at`: timestamp of when the cost was incurred (run completion time)
- Indexes: `(team_id, recorded_at)`, `(team_id, period)`
- No soft deletes — usage records are permanent audit trail

### Model Relationships

- `belongsTo` Team
- `belongsTo` TaskRun (nullable)

### Model Casts

- `cost_usd` → `decimal:6`
- `recorded_at` → `datetime`
- `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens` → `integer`

## 2. Balance Field on Team

Add `balance: decimal(12,4) default 0` to the `teams` table.

> Note: The master spec already includes this field in the Team schema. If spec 01 already created this column, this migration is a no-op. If not, create the migration.

### Migration

```
ALTER TABLE teams ADD COLUMN balance decimal(12,4) DEFAULT 0;
```

- `decimal(12,4)` — supports balances up to $99,999,999.9999
- Default 0 — new teams start with zero balance

## 3. CostCalculationService

Service that calculates USD cost from token usage and model pricing.

### Interface

```
CostCalculationService::calculate(
    model: string,
    inputTokens: int,
    outputTokens: int,
): float
```

### Logic

```
1. Look up model pricing from config('model-pricing.{model}')
2. If model not found in config → throw UnknownModelException
3. Calculate:
   cost = (inputTokens / 1_000_000 * pricing.input)
        + (outputTokens / 1_000_000 * pricing.output)
4. Round to 6 decimal places
5. Return cost_usd
```

### Edge Cases

- Unknown model → `UnknownModelException` (caller decides: log warning + use 0, or fail)
- Zero tokens → returns 0.000000
- Negative tokens → throw `InvalidArgumentException`

## 4. UsageRecordingService

Service that records usage and deducts from team balance. Called by AgentRunner after run completion.

### Interface

```
UsageRecordingService::record(
    taskRun: TaskRun,
    model: string,
    inputTokens: int,
    outputTokens: int,
    cacheReadTokens: int,
    cacheWriteTokens: int,
): TeamUsageRecord
```

### Logic

```
1. Calculate cost via CostCalculationService
2. Wrap in DB transaction:
   a. Create TeamUsageRecord {
        team_id: taskRun.task.project.team_id,
        task_run_id: taskRun.id,
        model: model,
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        cache_read_tokens: cacheReadTokens,
        cache_write_tokens: cacheWriteTokens,
        cost_usd: calculated_cost,
        period: now().format('Y-m'),
        recorded_at: now(),
      }
   b. Deduct from team balance:
      Team::where('id', team_id)
        ->lockForUpdate()
        ->decrement('balance', calculated_cost)
   c. Update task_run.total_cost_usd += calculated_cost
   d. Update task.total_cost_usd += calculated_cost
3. Return created TeamUsageRecord
```

### Concurrency Safety

- Use `lockForUpdate()` on the team row to prevent race conditions when multiple runs complete simultaneously
- DB transaction ensures atomicity: either all records are created and balance deducted, or none

## 5. Model Pricing Config

```php
// config/model-pricing.php

return [
    'claude-opus-4-6'    => ['input' => 5.00,  'output' => 25.00],
    'claude-sonnet-4-6'  => ['input' => 3.00,  'output' => 15.00],
    'claude-haiku-4-5'   => ['input' => 0.80,  'output' => 4.00],
    'gpt-5.4'            => ['input' => 6.00,  'output' => 18.00],
    'gemini-3.1-pro'     => ['input' => 3.00,  'output' => 12.00],
];
```

- Prices are per million tokens
- POST-MVP: migrate to database table (Filament-editable)
- Config allows quick updates via `.env` overrides or deployment config

## 6. File Structure

```
app/Models/
└── TeamUsageRecord.php

app/Services/
├── CostCalculationService.php
└── UsageRecordingService.php

app/Exceptions/
└── UnknownModelException.php

config/
└── model-pricing.php

database/migrations/
├── xxxx_xx_xx_create_team_usage_records_table.php
└── xxxx_xx_xx_add_balance_to_teams_table.php  # if not already present

database/factories/
└── TeamUsageRecordFactory.php
```

## Acceptance Criteria

### Model & Migration
- **Given** the migration is run, **when** the `team_usage_records` table is inspected, **then** it has all columns matching the schema above, including indexes `(team_id, recorded_at)` and `(team_id, period)`.
- **Given** a TeamUsageRecord instance, **when** `$record->team` is accessed, **then** it returns the parent Team.
- **Given** a TeamUsageRecord with a task_run_id, **when** `$record->taskRun` is accessed, **then** it returns the TaskRun.
- **Given** a TeamUsageRecord with `cost_usd = 0.034215`, **when** accessed, **then** the value preserves 6 decimal places.

### Factory
- **Given** the factory is used, **when** `TeamUsageRecord::factory()->create()` is called, **then** a valid record is created with all required fields.

### Balance Field
- **Given** the migration is run, **when** the `teams` table is inspected, **then** it has a `balance` column of type `decimal(12,4)` with default 0.
- **Given** a newly created team, **when** `$team->balance` is accessed, **then** it returns 0.

### Cost Calculation
- **Given** model `claude-sonnet-4-6` with 10,000 input tokens and 2,000 output tokens, **when** `CostCalculationService::calculate()` is called, **then** cost is `(10000 / 1_000_000 * 3.00) + (2000 / 1_000_000 * 15.00) = 0.030000 + 0.030000 = 0.060000`.
- **Given** model `claude-opus-4-6` with 50,000 input and 5,000 output tokens, **when** calculated, **then** cost is `(50000 / 1_000_000 * 5.00) + (5000 / 1_000_000 * 25.00) = 0.250000 + 0.125000 = 0.375000`.
- **Given** an unknown model string, **when** `calculate()` is called, **then** `UnknownModelException` is thrown.
- **Given** zero tokens for both input and output, **when** calculated, **then** cost is 0.000000.
- **Given** negative token count, **when** calculated, **then** `InvalidArgumentException` is thrown.

### Usage Recording
- **Given** a completed TaskRun and token usage data, **when** `UsageRecordingService::record()` is called, **then** a TeamUsageRecord is created with correct cost, period is set to current month, and team balance is decremented.
- **Given** a team with balance 10.0000, **when** a run costing 0.375000 is recorded, **then** team balance becomes 9.625000.
- **Given** a team with balance 0.0500, **when** a run costing 0.100000 is recorded, **then** team balance becomes -0.050000 (soft limit allows negative).
- **Given** two runs complete simultaneously for the same team, **when** both call `record()`, **then** both records are created and balance is correctly decremented for both (no race condition).
- **Given** a recording is made, **when** checked, **then** `task_run.total_cost_usd` and `task.total_cost_usd` are also updated.

### Period Format
- **Given** a recording made in March 2026, **when** the TeamUsageRecord is inspected, **then** `period` is `"2026-03"`.
