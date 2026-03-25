# Spec 09 — Billing & Credits

> Team balance tracking, cost recording, usage API, and pre-dispatch enforcement.
> Dependencies: 01 (Platform Core — teams), 06 (Agent Execution — cost recording after runs).

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Balance & Usage | TeamUsageRecord model + migration + factory, cost calculation service, balance field on Team |
| 2 | Enforcement & API | Pre-dispatch balance check, usage API endpoints, dashboard stats, usage flush command |

## Dependencies on Other Specs

| Spec | Why |
|------|-----|
| 01 — Platform Core | Teams must exist; balance field is on the teams table |
| 06 — Agent Execution | AgentRunner calls cost recording after run completion (wave 2 depends on 06-wave-4) |

**Note**: User and Team models come from magic-starter and are extended by Kodizm.

## Data Models

### TeamUsageRecord
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

### Balance Field on Team
```
teams
├── balance: decimal(12,4) default 0  // already in schema, ensure migration exists
```

### Indexes
```
team_usage_records: (team_id, recorded_at), (team_id, period)
```

## Business Rules

### Balance Rules
- Team balance starts at 0
- Admin adds credits manually (MVP) — Stripe integration is post-MVP
- Before dispatching agent run: `team.balance >= config('billing.min_balance', 0.10)`
- After run completes: `team.balance -= actual_cost`, create TeamUsageRecord
- If balance < 0 after deduction: allowed (soft limit). Next dispatch blocked.
- `--max-budget-usd` passed to CLI agent as hard stop per run

### Cost Calculation
```
cost_usd = (input_tokens / 1_000_000 * input_price) + (output_tokens / 1_000_000 * output_price)
```

### Model Pricing
```php
// config/model-pricing.php
'claude-opus-4-6'    => ['input' => 5.00,  'output' => 25.00],  // per million tokens
'claude-sonnet-4-6'  => ['input' => 3.00,  'output' => 15.00],
'claude-haiku-4-5'   => ['input' => 0.80,  'output' => 4.00],
'gpt-5.4'            => ['input' => 6.00,  'output' => 18.00],   // full scope
'gemini-3.1-pro'     => ['input' => 3.00,  'output' => 12.00],   // full scope
```

Note: Prices are placeholders. Post-MVP: move to DB (Filament-editable).

## Key Design Decisions

- **Soft limit on balance** — Balance can go negative after a run (we can't predict exact cost upfront). The pre-dispatch check prevents starting new runs when balance is insufficient.
- **Usage records per run** — Each completed run creates one TeamUsageRecord. Not per-event, per-run.
- **Period field** — `YYYY-MM` format for fast monthly aggregation queries without date range scans.
- **Decimal precision** — `cost_usd` uses `decimal(10,6)` for per-record precision; `balance` uses `decimal(12,4)` for running total.
