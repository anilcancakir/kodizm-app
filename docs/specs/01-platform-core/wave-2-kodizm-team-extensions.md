# Wave 2 — Kodizm Team Extensions

> Spec: 01-Platform Core
> Dependencies: Wave 1 (Magic Starter Configuration) must be complete

## Goal

Extend magic-starter's Team model with Kodizm-specific fields (balance, max_concurrent_runs), implement viewer role permission gate, and build the team balance service + API.

## Deliverables

- [ ] Migration: add `balance` and `max_concurrent_runs` columns to teams table
- [ ] Extend Team model with new fields + casts
- [ ] Viewer role permission gate (read-only policy for tasks, docs, knowledge)
- [ ] TeamBalanceService (check balance, deduct credits, add credits)
- [ ] API: `GET /api/teams/{team}/balance`
- [ ] Feature tests for all new functionality

## Schema Extension

```sql
-- Migration: add Kodizm fields to magic-starter's teams table
ALTER TABLE teams
    ADD COLUMN balance DECIMAL(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN max_concurrent_runs INT NOT NULL DEFAULT 10;
```

```php
// In migration file
Schema::table('teams', function (Blueprint $table) {
    $table->decimal('balance', 12, 2)->default(0);
    $table->integer('max_concurrent_runs')->default(10);
});
```

## Team Model Extension

Extend or override magic-starter's Team model to include the new fields:

```php
// Add to Team model (extend magic-starter's model)
protected $casts = [
    // ...existing magic-starter casts
    'balance' => 'decimal:2',
    'max_concurrent_runs' => 'integer',
];

protected $fillable = [
    // ...existing magic-starter fillable
    'max_concurrent_runs',
    // Note: balance is NOT fillable — managed only through TeamBalanceService
];
```

## Viewer Role Permission Gate

The `viewer` role has read-only access. Implement a policy/gate layer that enforces this across all team-scoped resources.

### Permissions Matrix (viewer column)

| Resource | Viewer Can |
|----------|-----------|
| Tasks | Read only |
| Docs | Read only |
| Knowledge | Read only |
| Agents | No access (cannot run) |
| Team settings | No access |
| Balance | No access |
| Members list | Read only |

### Implementation Approach

```php
// Gate/Policy pattern — check viewer restrictions
// In a base TeamPolicy or via middleware

public function viewAny(User $user, Team $team): bool
{
    // All roles including viewer can list resources
    return $team->hasMember($user);
}

public function create(User $user, Team $team): bool
{
    // Viewer cannot create anything
    $role = $team->roleOf($user);
    return $role !== TeamRole::Viewer;
}

public function update(User $user, Team $team, $resource): bool
{
    $role = $team->roleOf($user);
    return $role !== TeamRole::Viewer;
}

public function delete(User $user, Team $team, $resource): bool
{
    $role = $team->roleOf($user);
    return $role !== TeamRole::Viewer;
}
```

Use magic-starter's existing authorization contracts/hooks where possible. The viewer gate should integrate with whatever policy pattern magic-starter uses, not bypass it.

## TeamBalanceService

```php
interface TeamBalanceServiceContract
{
    public function getBalance(Team $team): string;
    public function hasBalance(Team $team, string $amount): bool;
    public function deduct(Team $team, string $amount, string $reason): void;
    public function addCredits(Team $team, string $amount, string $reason): void;
}
```

### Business Rules

- `balance` uses `decimal(12,2)` — all operations use string-based decimal math (BCMath) to avoid float precision issues.
- `deduct()` throws `InsufficientBalanceException` if balance would go negative.
- `deduct()` and `addCredits()` are wrapped in DB transactions with row-level locking (`lockForUpdate()`).
- `reason` parameter is for future audit trail (logged but not persisted to a ledger table in this wave).
- Balance is **not** directly settable — only through `deduct()` and `addCredits()`.

### Implementation

```php
class TeamBalanceService implements TeamBalanceServiceContract
{
    public function getBalance(Team $team): string
    {
        return $team->balance;
    }

    public function hasBalance(Team $team, string $amount): bool
    {
        return bccomp($team->balance, $amount, 2) >= 0;
    }

    public function deduct(Team $team, string $amount, string $reason): void
    {
        DB::transaction(function () use ($team, $amount, $reason) {
            $team = Team::lockForUpdate()->find($team->id);

            if (bccomp($team->balance, $amount, 2) < 0) {
                throw new InsufficientBalanceException($team, $amount);
            }

            $team->balance = bcsub($team->balance, $amount, 2);
            $team->save();

            Log::info('Team balance deducted', [
                'team_id' => $team->id,
                'amount' => $amount,
                'reason' => $reason,
                'new_balance' => $team->balance,
            ]);
        });
    }

    public function addCredits(Team $team, string $amount, string $reason): void
    {
        DB::transaction(function () use ($team, $amount, $reason) {
            $team = Team::lockForUpdate()->find($team->id);

            $team->balance = bcadd($team->balance, $amount, 2);
            $team->save();

            Log::info('Team credits added', [
                'team_id' => $team->id,
                'amount' => $amount,
                'reason' => $reason,
                'new_balance' => $team->balance,
            ]);
        });
    }
}
```

## API Endpoint

### GET /api/teams/{team}/balance

Get team balance. Requires owner, admin, or member role (viewer excluded).

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": {
        "balance": "95.50",
        "currency": "USD",
        "max_concurrent_runs": 10
    }
}
```

**Errors**:
- `401` — Unauthenticated
- `403` — Viewer role or non-member
- `404` — Team not found

**Notes**:
- `total_spent` and `this_month_spent` are deferred to the usage tracking spec — not included in this wave.
- Balance precision is 2 decimal places (USD cents).

## Acceptance Criteria

### Migration

**Given** a teams table from magic-starter,
**When** the Kodizm extension migration runs,
**Then** `balance` (decimal 12,2, default 0) and `max_concurrent_runs` (int, default 10) columns are added.

### Team Model

**Given** a team with `balance: "50.00"` and `max_concurrent_runs: 5`,
**When** the team is retrieved,
**Then** `balance` is cast to a 2-decimal string and `max_concurrent_runs` is cast to integer.

### Viewer Role — Read Only

**Given** a team member with role `viewer`,
**When** they attempt to create a task,
**Then** a 403 response is returned.

**Given** a team member with role `viewer`,
**When** they attempt to list tasks,
**Then** the tasks are returned (read access allowed).

**Given** a team member with role `viewer`,
**When** they GET `/api/teams/{team}/balance`,
**Then** a 403 response is returned.

### Balance Service

**Given** a team with balance "100.00",
**When** `deduct($team, "25.50", "agent run")` is called,
**Then** the team balance is "74.50".

**Given** a team with balance "10.00",
**When** `deduct($team, "20.00", "agent run")` is called,
**Then** `InsufficientBalanceException` is thrown and balance remains "10.00".

**Given** a team with balance "50.00",
**When** `addCredits($team, "100.00", "top-up")` is called,
**Then** the team balance is "150.00".

**Given** two concurrent deductions of "60.00" on a team with balance "100.00",
**When** both execute simultaneously,
**Then** one succeeds (balance "40.00") and the other throws `InsufficientBalanceException` (row-level lock prevents race condition).

### Balance API

**Given** a team member with role `member`,
**When** they GET `/api/teams/{team}/balance`,
**Then** balance and max_concurrent_runs are returned (status 200).

**Given** a team member with role `viewer`,
**When** they GET `/api/teams/{team}/balance`,
**Then** a 403 response is returned.

**Given** a team owner,
**When** they GET `/api/teams/{team}/balance`,
**Then** the response includes `balance`, `currency`, and `max_concurrent_runs`.

## Implementation Notes

- Use BCMath for all balance arithmetic — never use float operations.
- `InsufficientBalanceException` should be a custom exception class with team and requested amount context.
- Register `TeamBalanceServiceContract` → `TeamBalanceService` in a service provider.
- The balance endpoint controller should be thin — delegate to `TeamBalanceService`.
- Row-level locking (`lockForUpdate()`) is critical for concurrent deductions. Test with parallel requests.
- Future specs (usage tracking, billing) will add a ledger table. For now, balance is the source of truth.
- `max_concurrent_runs` is read by the agent orchestration spec (future) to throttle runs.

## Done-When

Team has `balance` and `max_concurrent_runs` fields. Viewer role is enforced as read-only across all team-scoped resources. `GET /api/teams/{team}/balance` returns balance data. `TeamBalanceService` handles credit operations with transaction safety. All tests pass.
