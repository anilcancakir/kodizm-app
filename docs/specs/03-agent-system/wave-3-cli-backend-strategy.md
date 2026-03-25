# Wave 3 — CLI Backend Strategy

> Spec: 03-Agent System
> Dependencies: Wave 1 (Agent Roles) must be complete

## Deliverables

- [ ] CliBackend enum (if not already created in wave-1)
- [ ] CliBackendStrategy interface
- [ ] ClaudeCodeStrategy implementation
- [ ] OpenCodeStrategy stub (throws NotImplementedException)
- [ ] Config: `config/cli-backends.php`
- [ ] Config: `config/model-pricing.php`
- [ ] Unit tests for ClaudeCodeStrategy command building
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## CliBackend Enum

```php
enum CliBackend: string
{
    case ClaudeCode = 'claude_code';
    case OpenCode = 'opencode';

    public function strategy(): CliBackendStrategy
    {
        return match ($this) {
            self::ClaudeCode => app(ClaudeCodeStrategy::class),
            self::OpenCode => app(OpenCodeStrategy::class),
        };
    }
}
```

## CliBackendStrategy Interface

```php
interface CliBackendStrategy
{
    /**
     * The CLI binary name/path.
     */
    public function binary(): string;

    /**
     * Which AI provider this backend requires.
     */
    public function requiredProvider(): AiProvider;

    /**
     * Environment variable name for the API key.
     */
    public function envKey(): string;

    /**
     * Default model if none specified on the agent role.
     */
    public function defaultModel(): string;

    /**
     * Build the full CLI command string for execution.
     *
     * @param CliCommandContext $context  DTO with all execution parameters
     * @return array<string>  Command as array of arguments (for Process)
     */
    public function buildCommand(CliCommandContext $context): array;

    /**
     * Normalize a raw NDJSON event from the CLI into canonical format.
     *
     * @param array $rawEvent  Parsed JSON line from CLI stdout
     * @return CanonicalEvent|null  Null = skip this event (e.g., user events)
     */
    public function normalizeEvent(array $rawEvent): ?CanonicalEvent;
}
```

## CliCommandContext DTO

```php
final readonly class CliCommandContext
{
    public function __construct(
        public string $prompt,
        public string $model,
        public ?string $systemPrompt = null,
        public ?string $promptAppend = null,
        public int $maxTurns = 50,
        public float $maxBudgetUsd = 5.00,
        public ?string $sessionId = null,
        public ?string $claudeMdContent = null,
        public array $mcpServers = [],
        public array $allowedTools = [],
    ) {}
}
```

## CanonicalEvent DTO

```php
final readonly class CanonicalEvent
{
    public function __construct(
        public StreamEventType $type,
        public array $data,
        public ?string $contentText = null,
        public ?string $filePath = null,
        public bool $isQuestion = false,
        public ?string $sessionId = null,
    ) {}
}
```

## ClaudeCodeStrategy Implementation

```php
class ClaudeCodeStrategy implements CliBackendStrategy
{
    public function binary(): string
    {
        return config('cli-backends.claude_code.binary', 'claude');
    }

    public function requiredProvider(): AiProvider
    {
        return AiProvider::Anthropic;
    }

    public function envKey(): string
    {
        return 'ANTHROPIC_API_KEY';
    }

    public function defaultModel(): string
    {
        return config('cli-backends.claude_code.default_model', 'claude-sonnet-4-6');
    }

    public function buildCommand(CliCommandContext $context): array;
    public function normalizeEvent(array $rawEvent): ?CanonicalEvent;
}
```

### buildCommand Output

The command should produce an array equivalent to:

```bash
claude \
  -p "{prompt}" \
  --output-format stream-json \
  --model {model} \
  --max-turns {maxTurns} \
  --max-budget-usd {maxBudgetUsd} \
  --append-system-prompt "{systemPrompt + promptAppend}" \
  --dangerously-skip-permissions \
  --resume {sessionId}   # only if sessionId is not null
```

**Implementation**:

```php
public function buildCommand(CliCommandContext $context): array
{
    $command = [
        $this->binary(),
        '-p', $context->prompt,
        '--output-format', 'stream-json',
        '--model', $context->model,
        '--max-turns', (string) $context->maxTurns,
        '--max-budget-usd', (string) $context->maxBudgetUsd,
        '--dangerously-skip-permissions',
    ];

    // Append system prompt (base + team/project append)
    $systemPrompt = trim(implode("\n---\n", array_filter([
        $context->systemPrompt,
        $context->promptAppend,
    ])));

    if ($systemPrompt !== '') {
        $command[] = '--append-system-prompt';
        $command[] = $systemPrompt;
    }

    // Resume existing session
    if ($context->sessionId !== null) {
        $command[] = '--resume';
        $command[] = $context->sessionId;
    }

    return $command;
}
```

### normalizeEvent — Claude Code Event Mapping

| Claude Code Event Type | Canonical Type | Transform |
|----------------------|---------------|-----------|
| `system` (subtype: `init`) | `StreamEventType::System` | Extract `session_id`, `model` from data |
| `assistant` | `StreamEventType::Assistant` | Pass `content` array, extract text, detect tool_use |
| `user` | (drop — return null) | Tool results, not broadcast |
| `result` | `StreamEventType::Result` | Map `is_error`, `total_cost_usd`, `usage`, `duration_ms`, `num_turns` |

**Question detection** (from `assistant` events):
- Claude Code uses "elicitation" events when the agent asks a question.
- Raw event type: when event contains `content` with a block of type `tool_use` and the tool name indicates elicitation, or when the event type itself is an elicitation type.
- Map to `StreamEventType::Question` with `isQuestion: true`.
- Extract question text from the content.

**File change detection** (from `assistant` events):
- When `content` contains tool_use blocks with tools like `Write`, `Edit` — extract `file_path`.
- Map to `StreamEventType::FileChange` with `filePath` set.

```php
public function normalizeEvent(array $rawEvent): ?CanonicalEvent
{
    $type = $rawEvent['type'] ?? null;

    return match ($type) {
        'system' => $this->normalizeSystem($rawEvent),
        'assistant' => $this->normalizeAssistant($rawEvent),
        'result' => $this->normalizeResult($rawEvent),
        'user' => null, // drop user events (tool results)
        default => null,
    };
}
```

## OpenCodeStrategy Stub

```php
class OpenCodeStrategy implements CliBackendStrategy
{
    public function binary(): string
    {
        return 'opencode';
    }

    public function requiredProvider(): AiProvider
    {
        throw new \RuntimeException('OpenCode backend is not yet implemented (post-MVP).');
    }

    public function envKey(): string
    {
        throw new \RuntimeException('OpenCode backend is not yet implemented (post-MVP).');
    }

    public function defaultModel(): string
    {
        throw new \RuntimeException('OpenCode backend is not yet implemented (post-MVP).');
    }

    public function buildCommand(CliCommandContext $context): array
    {
        throw new \RuntimeException('OpenCode backend is not yet implemented (post-MVP).');
    }

    public function normalizeEvent(array $rawEvent): ?CanonicalEvent
    {
        throw new \RuntimeException('OpenCode backend is not yet implemented (post-MVP).');
    }
}
```

## Config Files

### config/cli-backends.php

```php
return [
    'claude_code' => [
        'binary' => env('CLAUDE_CODE_BINARY', 'claude'),
        'default_model' => env('CLAUDE_CODE_DEFAULT_MODEL', 'claude-sonnet-4-6'),
        'max_turns' => env('CLAUDE_CODE_MAX_TURNS', 50),
        'max_budget_usd' => env('CLAUDE_CODE_MAX_BUDGET_USD', 5.00),
    ],

    'opencode' => [
        'binary' => env('OPENCODE_BINARY', 'opencode'),
        'default_model' => env('OPENCODE_DEFAULT_MODEL', 'gpt-5.4'),
        'max_turns' => env('OPENCODE_MAX_TURNS', 50),
    ],
];
```

### config/model-pricing.php

```php
return [
    // Prices per million tokens (USD)
    // NOTE: These are placeholders. Move to DB (Filament-editable) for production.

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

    // Post-MVP models
    'gpt-5.4' => [
        'input' => 6.00,
        'output' => 18.00,
    ],
    'gemini-3.1-pro' => [
        'input' => 3.00,
        'output' => 12.00,
    ],
];
```

**Cost calculation helper**:
```php
function calculateCost(string $model, int $inputTokens, int $outputTokens): float
{
    $pricing = config("model-pricing.{$model}");

    if ($pricing === null) {
        throw new \RuntimeException("Unknown model pricing: {$model}");
    }

    return ($inputTokens / 1_000_000 * $pricing['input'])
         + ($outputTokens / 1_000_000 * $pricing['output']);
}
```

## Acceptance Criteria

### CliBackend Enum

**Given** the `CliBackend::ClaudeCode` enum value,
**When** `strategy()` is called,
**Then** an instance of `ClaudeCodeStrategy` is returned.

**Given** the `CliBackend::OpenCode` enum value,
**When** `strategy()` is called and any method is invoked,
**Then** a `RuntimeException` is thrown with a post-MVP message.

### ClaudeCodeStrategy — buildCommand

**Given** a CliCommandContext with prompt "Fix the login bug", model "claude-sonnet-4-6", maxTurns 50, maxBudgetUsd 5.00,
**When** `buildCommand` is called,
**Then** the returned array contains `['claude', '-p', 'Fix the login bug', '--output-format', 'stream-json', '--model', 'claude-sonnet-4-6', '--max-turns', '50', '--max-budget-usd', '5', '--dangerously-skip-permissions']`.

**Given** a context with a systemPrompt set,
**When** `buildCommand` is called,
**Then** `--append-system-prompt` and the prompt text are included in the command.

**Given** a context with both systemPrompt and promptAppend set,
**When** `buildCommand` is called,
**Then** the appended system prompt is `systemPrompt + "\n---\n" + promptAppend`.

**Given** a context with a sessionId set,
**When** `buildCommand` is called,
**Then** `--resume` and the session ID are included in the command.

**Given** a context with sessionId = null,
**When** `buildCommand` is called,
**Then** `--resume` is NOT in the command.

### ClaudeCodeStrategy — normalizeEvent

**Given** a raw event with `type: "system"`,
**When** `normalizeEvent` is called,
**Then** a CanonicalEvent with `type: StreamEventType::System` is returned, containing the session_id.

**Given** a raw event with `type: "assistant"`,
**When** `normalizeEvent` is called,
**Then** a CanonicalEvent with `type: StreamEventType::Assistant` is returned with content text extracted.

**Given** a raw event with `type: "user"`,
**When** `normalizeEvent` is called,
**Then** `null` is returned (event dropped).

**Given** a raw event with `type: "result"`,
**When** `normalizeEvent` is called,
**Then** a CanonicalEvent with `type: StreamEventType::Result` is returned with cost and usage data.

### Config Files

**Given** the application boots,
**When** `config('cli-backends.claude_code.binary')` is accessed,
**Then** it returns `'claude'` (or the env override).

**Given** the model "claude-sonnet-4-6",
**When** `config('model-pricing.claude-sonnet-4-6')` is accessed,
**Then** it returns `['input' => 3.00, 'output' => 15.00]`.

## Implementation Notes

- Place strategy classes in `App\Services\CliBackends\` namespace.
- Place DTOs in `App\DTOs\` namespace.
- Register strategies in a service provider if needed, but the enum `strategy()` method using `app()` is sufficient.
- The `normalizeEvent` method will be heavily used during streaming (Spec 06). Keep it fast — no DB calls, no heavy processing.
- The `buildCommand` returns an array suitable for Laravel's `Process::command($array)` or Symfony Process.
- CLAUDE.md content injection: if `claudeMdContent` is set in context, it should be written to a temp file and placed in the container's project directory before execution. This is handled by the container manager (Spec 04), not by the strategy itself.
