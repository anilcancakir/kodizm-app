# Wave 2 — Agent & Token Management

> Spec: 12-Filament Admin
> Dependencies: Wave 1 complete, 03-Agent System complete (AgentRole, AiToken models)

**TDD**: All code developed test-first. Feature tests for Filament pages/resources.

## Deliverables

- [ ] AgentRoleResource: list, create, edit system-scoped agent roles
- [ ] AiTokenResource: list, create, edit platform tokens with health check
- [ ] System Config page (global platform settings)
- [ ] Feature tests for AgentRole and AiToken CRUD
- [ ] Feature tests for System Config page

## AgentRoleResource

Manages **system-scoped** agent roles — the platform-wide defaults. This is NOT team-scoped.

### Table Columns

| Column | Type | Notes |
|--------|------|-------|
| Name | TextColumn | Searchable |
| Slug | TextColumn | Badge |
| CLI Backend | TextColumn | Badge — `claude_code` (blue), `opencode` (green) |
| Preferred Model | TextColumn | Nullable |
| Scope | TextColumn | Badge — system (purple), team (blue), project (green) |
| Active | IconColumn | Boolean |
| Sort Order | TextColumn | Sortable |

### Table Filters

- **Scope**: Select filter — system, team, project
- **CLI Backend**: Select filter — claude_code, opencode
- **Active**: Ternary filter — active / inactive / all

### Table Actions

- Edit
- Delete (with confirmation)
- Toggle active/inactive

### Form Schema

```php
Form::schema([
    Section::make('Basic Info')->schema([
        TextInput::make('name')
            ->required()
            ->maxLength(255),
        TextInput::make('slug')
            ->required()
            ->unique(ignoreRecord: true),
        Textarea::make('description')
            ->nullable()
            ->rows(3),
        Select::make('scope')
            ->options(AgentScope::class)
            ->default('system')
            ->required(),
        Toggle::make('is_active')
            ->default(true),
        TextInput::make('sort_order')
            ->numeric()
            ->default(0),
    ]),

    Section::make('AI Configuration')->schema([
        Select::make('cli_backend')
            ->options(CliBackend::class)
            ->required(),
        TextInput::make('preferred_model')
            ->nullable()
            ->placeholder('claude-sonnet-4-6'),
    ]),

    Section::make('Prompts')->schema([
        Textarea::make('system_prompt')
            ->nullable()
            ->rows(10)
            ->helperText('Base persona instructions for this agent role.'),
        Textarea::make('prompt_append')
            ->nullable()
            ->rows(5)
            ->helperText('Additional instructions appended to the system prompt.'),
    ]),

    Section::make('Backend Config')->schema([
        KeyValue::make('backend_config')
            ->nullable()
            ->helperText('JSON configuration per CLI backend.'),
    ]),

    Section::make('Tool Permissions')->schema([
        CheckboxList::make('tool_permissions')
            ->options([
                'report-progress' => 'Report Progress',
                'search-knowledge' => 'Search Knowledge',
                'get-task' => 'Get Task',
                'get-project-info' => 'Get Project Info',
                'create-task-section' => 'Create Task Section',
                'update-task-section' => 'Update Task Section',
                'create-task' => 'Create Task',
                'update-task' => 'Update Task',
                'create-document' => 'Create Document',
                'update-document' => 'Update Document',
                'search-documents' => 'Search Documents',
            ])
            ->columns(2)
            ->helperText('MCP tools this agent role is allowed to use.'),
    ]),
]);
```

### Validation Rules

```php
'name' => 'required|string|max:255',
'slug' => 'required|string|max:100|unique:agent_roles,slug,' . $record?->id,
'cli_backend' => 'required|in:claude_code,opencode',
'preferred_model' => 'nullable|string|max:100',
'system_prompt' => 'nullable|string',
'prompt_append' => 'nullable|string',
'scope' => 'required|in:system,team,project',
'is_active' => 'boolean',
'sort_order' => 'integer|min:0',
'backend_config' => 'nullable|json',
'tool_permissions' => 'nullable|array',
```

### UUID Note

All AgentRole records use UUID primary keys. The `unique` validation on `slug` uses `$record?->id` (UUID string) for ignore. Filament resolves routes via UUID automatically with `$recordRouteKeyName = 'id'`.

## AiTokenResource

Manages **platform-wide** AI tokens. Super admins can see and manage ALL tokens across the platform.

### Table Columns

| Column | Type | Notes |
|--------|------|-------|
| Label | TextColumn | Searchable, nullable fallback to "Unnamed" |
| Provider | TextColumn | Badge — anthropic (orange), openai (green), google (blue), openrouter (purple) |
| Auth Type | TextColumn | Badge |
| Status | TextColumn | Badge with color: active (green), inactive (grey), rate_limited (yellow), expired (red) |
| Credentials | TextColumn | Masked: `sk-...abc123` |
| Rotation Algorithm | TextColumn | |
| Usage Count | TextColumn | Numeric, sortable |
| Last Used | TextColumn | Relative time, sortable |

### Table Filters

- **Provider**: Select filter — anthropic, openai, google, openrouter
- **Status**: Select filter — active, inactive, rate_limited, expired
- **Auth Type**: Select filter — api_key, subscription

### Table Actions

- Edit
- Delete
- Health Check (custom action)
- Toggle status (active/inactive)

### Form Schema

```php
Form::schema([
    Section::make('Token Info')->schema([
        TextInput::make('label')
            ->nullable()
            ->maxLength(255)
            ->placeholder('e.g., Claude Max Account #1'),
        Select::make('provider')
            ->options(AiProvider::class)
            ->required(),
        Select::make('auth_type')
            ->options(AuthType::class)
            ->required(),
    ]),

    Section::make('Credentials')->schema([
        Textarea::make('credentials')
            ->required()
            ->rows(2)
            ->password()
            ->helperText('API key or subscription token. Stored encrypted.'),
    ]),

    Section::make('Configuration')->schema([
        Select::make('status')
            ->options(TokenStatus::class)
            ->default('active')
            ->required(),
        Select::make('rotation_algorithm')
            ->options(RotationAlgorithm::class)
            ->default('fill_first')
            ->required(),
        KeyValue::make('settings')
            ->nullable()
            ->helperText('Provider-specific settings (JSON).'),
    ]),

    Section::make('Stats')->schema([
        Placeholder::make('usage_count')
            ->content(fn ($record) => $record?->usage_count ?? 0)
            ->label('Total Uses'),
        Placeholder::make('last_used_at')
            ->content(fn ($record) => $record?->last_used_at?->diffForHumans() ?? 'Never')
            ->label('Last Used'),
        Placeholder::make('health_checked_at')
            ->content(fn ($record) => $record?->health_checked_at?->diffForHumans() ?? 'Never')
            ->label('Last Health Check'),
    ])->visibleOn('view'),
]);
```

### Health Check Action

```php
Action::make('healthCheck')
    ->label('Test Token')
    ->icon('heroicon-o-heart')
    ->color('info')
    ->action(function (AiToken $record) {
        $result = app(TokenHealthChecker::class)->check($record);

        if ($result->healthy) {
            Notification::make()->title('Token is healthy')->success()->send();
        } else {
            Notification::make()->title('Token check failed: ' . $result->error)->danger()->send();
        }
    })
    ->requiresConfirmation()
    ->modalDescription('This will make a lightweight API call to verify the token is valid.');
```

### Credential Security

- `credentials` field uses Laravel's encrypted cast: `'credentials' => 'encrypted'`
- In table: masked display only — `substr($value, 0, 3) . '...' . substr($value, -6)`
- In edit form: `password()` input — existing value hidden, must re-enter to change
- Never expose full credentials in admin views

## System Config Page

A custom Filament Page (not a Resource) for managing global platform settings.

### Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `max_concurrent_runs` | integer | 10 | Max concurrent agent runs platform-wide |
| `default_team_balance` | decimal | 5.00 | Default credit balance for new teams |
| `container_warm_timeout` | integer | 300 | Seconds before warm container is killed |
| `container_session_max_age` | integer | 86400 | Max container session age in seconds |
| `container_max_run_duration` | integer | 3600 | Max single run duration in seconds |
| `container_memory_limit` | string | '4g' | Docker container memory limit |
| `container_cpu_limit` | integer | 2 | Docker container CPU limit |

### Implementation

```php
// app/Filament/Pages/SystemConfigPage.php
class SystemConfigPage extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';
    protected static ?string $title = 'System Configuration';
    protected static ?string $navigationGroup = 'System';

    // Settings stored in a `system_settings` table (key-value, UUID PK)
    // or via spatie/laravel-settings package

    public function form(Form $form): Form
    {
        return $form->schema([
            Section::make('Run Limits')->schema([
                TextInput::make('max_concurrent_runs')
                    ->numeric()
                    ->required()
                    ->default(10),
                TextInput::make('default_team_balance')
                    ->numeric()
                    ->prefix('$')
                    ->required()
                    ->default(5.00),
            ]),

            Section::make('Container Timeouts')->schema([
                TextInput::make('container_warm_timeout')
                    ->numeric()
                    ->suffix('seconds')
                    ->required()
                    ->default(300),
                TextInput::make('container_session_max_age')
                    ->numeric()
                    ->suffix('seconds')
                    ->required()
                    ->default(86400),
                TextInput::make('container_max_run_duration')
                    ->numeric()
                    ->suffix('seconds')
                    ->required()
                    ->default(3600),
            ]),

            Section::make('Container Resources')->schema([
                TextInput::make('container_memory_limit')
                    ->required()
                    ->default('4g')
                    ->helperText('e.g., 2g, 4g, 8g'),
                TextInput::make('container_cpu_limit')
                    ->numeric()
                    ->required()
                    ->default(2),
            ]),
        ]);
    }
}
```

## Acceptance Criteria

### AgentRoleResource

**Given** a super admin in the Filament panel,
**When** they navigate to the Agent Roles resource,
**Then** all agent roles (across all scopes) are listed with name, slug, CLI backend, model, scope, and active status.

**Given** a super admin creating a new agent role,
**When** they fill in name, slug, cli_backend, system_prompt, and submit,
**Then** the agent role is created with a UUID primary key.

**Given** a super admin editing an agent role,
**When** they update the system_prompt and tool_permissions,
**Then** the changes are saved and reflected in the table.

**Given** a super admin deleting an agent role,
**When** they confirm the deletion,
**Then** the role is removed (soft-deleted if applicable).

### AiTokenResource

**Given** a super admin in the Filament panel,
**When** they navigate to the AI Tokens resource,
**Then** all platform tokens are listed with provider, status badge, masked credentials, and usage stats.

**Given** a super admin creating a new AI token,
**When** they fill in provider (anthropic), auth_type (api_key), credentials, and submit,
**Then** the token is created with a UUID primary key, credentials encrypted at rest, and status set to active.

**Given** a super admin viewing the token table,
**When** they see the credentials column,
**Then** it shows masked format only (e.g., `sk-...abc123`), never the full key.

**Given** a super admin clicking "Test Token" on a token,
**When** the health check runs,
**Then** a success or failure notification is displayed, and `health_checked_at` is updated.

**Given** a super admin filtering tokens by status "rate_limited",
**When** the filter is applied,
**Then** only tokens with rate_limited status are shown.

### System Config Page

**Given** a super admin navigating to System Configuration,
**When** the page loads,
**Then** all current settings are displayed with their values.

**Given** a super admin changing `max_concurrent_runs` from 10 to 20,
**When** they save,
**Then** the setting is persisted and takes effect platform-wide.

**Given** a super admin changing container timeout values,
**When** they save,
**Then** the new values are stored and reflected on next page load.

## Done-When

- AgentRoleResource: full CRUD for agent roles (all scopes visible, system roles editable by super admin)
- AiTokenResource: full CRUD with masked credentials, health check action, encrypted storage
- System Config page: all global settings viewable and editable
- All IDs are UUID — routes resolve correctly
- Feature tests pass for AgentRole CRUD, AiToken CRUD, System Config save/load

## Implementation Notes

- Filament v5 uses Livewire 3 — all interactions are server-rendered.
- NO tenant scoping — all queries are global. Super admins see everything.
- `backend_config` and `tool_permissions` are JSON columns — `KeyValue` and `CheckboxList` map directly.
- For credentials: use `->password()` on input, and a mutator on save to only update if a new value is provided.
- System settings can use a simple `system_settings` table (key: string, value: text, UUID PK) or `spatie/laravel-settings`.
- Token health check: reuse the `tokens:health-check` artisan command logic via a service class.
- All UUID PKs: ensure `$casts`, `$keyType = 'string'`, `$incrementing = false` on all models.
