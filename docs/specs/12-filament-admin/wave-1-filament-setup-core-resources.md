# Wave 1 — Filament v5 Setup & Core Resources

> Spec: 12-Filament Admin
> Dependencies: 01-Platform Core complete (User, Team, Fortify auth), 09-Billing & Credits complete (balance, usage records)

**TDD**: All code developed test-first. Feature tests for Filament pages/resources.

## Deliverables

- [ ] Install Filament v5 as Laravel package
- [ ] Configure admin panel (route: `/admin`, guard: `web`, super-admin gate)
- [ ] TeamResource: list, view, edit teams
- [ ] UserResource: list, view users
- [ ] Dashboard page with key platform stats
- [ ] UUID route resolution for all resources
- [ ] Feature tests for each resource CRUD and access control

## Filament v5 Installation

```bash
composer require filament/filament:"^5.0"
php artisan filament:install --panels
```

### Panel Provider

```php
// app/Providers/Filament/AdminPanelProvider.php
class AdminPanelProvider extends PanelProvider
{
    public function panel(Panel $panel): Panel
    {
        return $panel
            ->id('admin')
            ->path('admin')
            ->login()
            // NO tenant() — global admin panel for super-admins
            ->resources([
                TeamResource::class,
                UserResource::class,
            ])
            ->pages([
                DashboardPage::class,
            ]);
    }
}
```

### Super-Admin Gate

```php
// User model — implements FilamentUser (NOT HasTenants)
class User extends Authenticatable implements FilamentUser
{
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_super_admin === true;
    }
}
```

### UUID Route Resolution

All models use UUID primary keys. Ensure route model binding works:

```php
// On each Filament Resource
protected static ?string $recordRouteKeyName = 'id';

// Models already have:
// - $keyType = 'string'
// - $incrementing = false
// - UUID generation in boot/creating
```

## TeamResource

### Table Columns

| Column | Type | Notes |
|--------|------|-------|
| Name | TextColumn | Searchable |
| Slug | TextColumn | Badge |
| Owner | TextColumn | Owner user name (relationship) |
| Balance | TextColumn | Formatted `$XX.XX`, color coded: green (>$10), yellow ($1-$10), red (<$1) |
| Members | TextColumn | Count via `withCount('members')` |
| Created At | TextColumn | Date |

### Table Filters

- **Balance Range**: Select filter — healthy (>$10), low ($1-$10), critical (<$1)
- **Created**: Date range filter

### Table Actions

- View
- Edit (balance, limits)

### View Page (Infolist)

#### Info Section
- Name, slug, owner, created at
- Balance: large display with color coding

#### Members Section
- Table of team members:
  | Column | Type |
  |--------|------|
  | Name | TextColumn |
  | Email | TextColumn |
  | Role | BadgeColumn — owner (purple), admin (blue), member (green), viewer (grey) |
  | Joined | TextColumn — relative time |

#### Usage Summary Section
- Current month total cost
- Total runs this month
- Top models by cost (table)
- Top agent roles by usage count

### Edit Form

```php
Form::schema([
    Section::make('Team Info')->schema([
        TextInput::make('name')
            ->required()
            ->maxLength(255),
        Placeholder::make('slug')
            ->content(fn ($record) => $record->slug),
        Placeholder::make('owner')
            ->content(fn ($record) => $record->owner->name),
    ]),

    Section::make('Balance & Limits')->schema([
        TextInput::make('balance')
            ->numeric()
            ->prefix('$')
            ->helperText('Current credit balance. Use Add Credits action for audited adjustments.'),
        TextInput::make('max_concurrent_runs')
            ->numeric()
            ->nullable()
            ->helperText('Override global default. Null = use system default.'),
    ]),
]);
```

### Add Credits Action

```php
Action::make('addCredits')
    ->label('Add Credits')
    ->icon('heroicon-o-plus-circle')
    ->color('success')
    ->form([
        TextInput::make('amount')
            ->label('Amount (USD)')
            ->numeric()
            ->required()
            ->minValue(0.01)
            ->maxValue(10000)
            ->prefix('$'),
        Textarea::make('reason')
            ->label('Reason')
            ->required()
            ->placeholder('e.g., Initial credit, monthly top-up, support credit'),
    ])
    ->action(function (Team $record, array $data) {
        DB::transaction(function () use ($record, $data) {
            $record->increment('balance', $data['amount']);

            TeamUsageRecord::create([
                'id' => Str::uuid(),
                'team_id' => $record->id,
                'cost_usd' => -$data['amount'], // Negative = credit added
                'period' => now()->format('Y-m'),
                'recorded_at' => now(),
                'model' => null,
                'task_run_id' => null,
            ]);
        });

        Notification::make()
            ->title("Added \${$data['amount']} to {$record->name}")
            ->success()
            ->send();
    })
    ->requiresConfirmation()
    ->modalDescription('This will add credits to the team\'s balance.');
```

## UserResource

### Table Columns

| Column | Type | Notes |
|--------|------|-------|
| Name | TextColumn | Searchable |
| Email | TextColumn | Searchable |
| Teams | TextColumn | Count via `withCount('teams')` |
| Super Admin | IconColumn | Boolean — `is_super_admin` |
| Last Login | TextColumn | Relative time, sortable |
| Created At | TextColumn | Date, sortable |

### Table Filters

- **Super Admin**: Ternary filter — super admins / regular / all
- **Has Teams**: Boolean filter — users with at least one team

### Table Actions

- View

### View Page (Infolist)

#### Info Section
- Name, email, super admin badge, created at, last login

#### Team Memberships Section
- Table of user's teams:
  | Column | Type |
  |--------|------|
  | Team Name | TextColumn — link to TeamResource |
  | Role | BadgeColumn |
  | Joined | TextColumn — relative time |

## Dashboard Page

### Stats Overview (4 cards)

```php
StatsOverviewWidget::make([
    Stat::make('Total Teams', Team::count())
        ->description('Platform-wide')
        ->icon('heroicon-o-user-group')
        ->color('info'),
    Stat::make('Active Runs', TaskRun::where('status', 'running')->count())
        ->description('Running right now')
        ->icon('heroicon-o-play')
        ->color('success'),
    Stat::make('Total Spend Today', '$' . number_format($costToday, 2))
        ->description('All teams combined')
        ->icon('heroicon-o-currency-dollar')
        ->color('warning'),
    Stat::make('Total Users', User::count())
        ->description('Platform-wide')
        ->icon('heroicon-o-users')
        ->color('info'),
]);
```

### Recent Runs Table

```php
Table::make([
    TextColumn::make('id')->label('ID')->limit(8),
    TextColumn::make('task.title')->label('Task')->limit(30),
    TextColumn::make('task.team.name')->label('Team'),
    TextColumn::make('agentRole.name')->label('Agent'),
    TextColumn::make('model'),
    TextColumn::make('status')->badge()
        ->color(fn ($state) => match($state) {
            'running' => 'success',
            'completed' => 'success',
            'failed' => 'danger',
            'cancelled' => 'gray',
            'waiting_for_input' => 'warning',
            default => 'info',
        }),
    TextColumn::make('total_cost_usd')->label('Cost')->money('usd'),
    TextColumn::make('started_at')->label('Started')->since(),
])
->query(TaskRun::query()->with(['task.team', 'agentRole'])->latest('started_at')->limit(20))
```

## Acceptance Criteria

### Filament Panel Access

**Given** a user with `is_super_admin = true`,
**When** they navigate to `/admin`,
**Then** they can log in and see the global admin panel with all platform data.

**Given** a regular user (not super admin),
**When** they try to access `/admin`,
**Then** they are denied access (403 or redirect to login).

**Given** a super admin in the admin panel,
**When** they view any resource,
**Then** they see ALL records across ALL teams (no tenant scoping).

### TeamResource

**Given** a super admin in the Filament panel,
**When** they navigate to the Teams resource,
**Then** all platform teams are listed with name, slug, owner, balance (color-coded), and member count.

**Given** a super admin viewing a team's detail page,
**When** they see the members section,
**Then** all team members are listed with name, email, role badge, and join date.

**Given** a super admin on a team's view page,
**When** they click "Add Credits" and enter $50.00 with reason "Monthly top-up",
**Then** the team's balance increases by $50.00, a TeamUsageRecord (with UUID) is created with negative cost, and a success notification appears.

**Given** a team with balance $3.00,
**When** the super admin views the team in the table,
**Then** the balance is displayed in yellow (between $1 and $10).

### UserResource

**Given** a super admin in the Filament panel,
**When** they navigate to the Users resource,
**Then** all platform users are listed with name, email, team count, super admin flag, and last login.

**Given** a super admin viewing a user's detail page,
**When** they see the team memberships section,
**Then** all teams the user belongs to are listed with team name (linked), role, and join date.

### Dashboard

**Given** the admin dashboard page,
**When** it loads,
**Then** four stat cards are displayed: total teams, active runs, total spend today, and total users.

**Given** 5 runs completed today with a total cost of $12.50,
**When** the super admin views the dashboard,
**Then** "Active Runs" shows the current count and "Total Spend Today" shows the correct amount.

## Done-When

- `/admin` accessible by super admins only — regular users get 403
- TeamResource lists all teams, view page shows members + usage + balance history
- UserResource lists all users, view page shows team memberships
- Dashboard shows platform-wide stats and recent runs
- All IDs are UUID — routes resolve correctly
- Feature tests pass for access control, TeamResource CRUD, UserResource read, dashboard rendering

## Implementation Notes

- Filament v5 uses Livewire 3 — all interactions are server-rendered.
- NO `TenantScope`, NO `HasTenants` — queries are unscoped (global).
- All `id` columns are UUID (`char(36)` / `uuid` type). Filament's `$recordRouteKeyName = 'id'` handles this.
- TeamResource is primarily view + action (teams are created via Flutter). Edit is limited to balance/limits.
- UserResource is read-only — users are managed via Flutter.
- Add Credits action must use a DB transaction for atomicity. The TeamUsageRecord UUID is generated explicitly.
- System-scope roles (from 03-Agent System seeder) are visible but managed in Wave 2.
