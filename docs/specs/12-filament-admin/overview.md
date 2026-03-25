# Spec 12 — Filament Admin Panel

> Filament v5 global admin panel for platform super-admins.
> Dependencies: 01-Platform Core, 03-Agent System, 09-Billing & Credits.

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Filament v5 Setup & Core Resources | Install Filament v5, super-admin gate, TeamResource, UserResource, stats dashboard |
| 2 | Agent & Token Management | AgentRoleResource CRUD, AiTokenResource CRUD, system config page |

## Dependencies on Other Specs

- **01-Platform Core**: User/Team models (UUID PKs), Fortify session auth (Filament uses web session auth)
- **03-Agent System**: AgentRole and AiToken models, enums (CliBackend, AiProvider, AuthType, TokenStatus, RotationAlgorithm, AgentScope)
- **09-Billing & Credits**: Team balance, TeamUsageRecord model, cost tracking

## Tech Stack

- **Filament v5**: Installed as a standard Laravel package (composer require)
- **Auth**: Fortify session-based auth (NOT Sanctum tokens — Filament uses web sessions)
- **Scope**: Global admin panel — NO multi-tenancy, NO team context
- **Access**: Only users with `is_super_admin = true` flag

## Filament Panel Configuration

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
            // NO tenant() — this is a global admin panel
            ->resources([
                TeamResource::class,
                UserResource::class,
                AgentRoleResource::class,
                AiTokenResource::class,
            ])
            ->pages([
                DashboardPage::class,
                SystemConfigPage::class,
            ]);
    }
}
```

## UUID Route Resolution

All models use UUID primary keys. Filament resources must resolve routes via UUID:

```php
// On each Resource class
public static function getEloquentQuery(): Builder
{
    return parent::getEloquentQuery();
}

// Model route key
public function getRouteKeyName(): string
{
    return 'id'; // UUID column
}
```

Ensure `$casts` on models includes no integer cast on `id`. UUID columns are `char(36)` / `uuid` type.

## Super-Admin Gate

```php
// User model
class User extends Authenticatable implements FilamentUser
{
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_super_admin === true;
    }
}
```

No `HasTenants` interface needed. No tenant switcher. The admin panel shows ALL platform data.

## Relevant Enums

```php
enum AiProvider: string {
    case Anthropic = 'anthropic';
    case OpenAI = 'openai';
    case Google = 'google';
    case OpenRouter = 'openrouter';
}

enum CliBackend: string {
    case ClaudeCode = 'claude_code';
    case OpenCode = 'opencode';
}

enum AuthType: string {
    case ApiKey = 'api_key';
    case Subscription = 'subscription';
}

enum TokenStatus: string {
    case Active = 'active';
    case Inactive = 'inactive';
    case RateLimited = 'rate_limited';
    case Expired = 'expired';
}

enum RotationAlgorithm: string {
    case FillFirst = 'fill_first';
    case RoundRobin = 'round_robin';
    case Random = 'random';
}

enum AgentScope: string {
    case System = 'system';
    case Team = 'team';
    case Project = 'project';
}
```

## Business Rules

- Admin panel access: only users with `is_super_admin = true`
- NO tenant scoping — all resources show global platform data
- Sensitive fields (AI token credentials) are encrypted at rest (Laravel encrypted cast)
- Agent roles with `scope: system` are the platform defaults managed here
- Balance modification (add credits) is a super-admin action on any team
- All model IDs are UUID — routes, forms, and relations must handle UUID strings
