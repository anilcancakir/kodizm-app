# Spec 14 — OpenCode CLI Backend (Post-MVP)

> Adds OpenCode as a second CLI backend alongside Claude Code, enabling GPT, Gemini, and other non-Anthropic models.
> Dependencies: 03-Agent System (CLI backend strategy interface), 06-Agent Execution (AgentRunner, streaming).
>
> **TDD**: All code developed test-first (red-green-refactor).

## Overview

OpenCode is an alternative CLI agent that supports multiple AI providers (OpenAI, Google, OpenRouter). Adding OpenCode as a backend expands Kodizm's model coverage beyond Anthropic-only (Claude Code) to include GPT, Gemini, and any model available via OpenRouter.

The implementation follows the Strategy pattern established in 03-Agent System. `OpenCodeStrategy` implements the same `CliBackendStrategy` interface as `ClaudeCodeStrategy`.

## OpenCodeStrategy Implementation

### Interface (from 03-Agent System)

```php
interface CliBackendStrategy
{
    public function buildCommand(TaskRun $taskRun, AgentRole $agentRole, string $resolvedToken): string;
    public function normalizeEvent(array $rawEvent): ?CanonicalStreamEvent;
    public function getSessionResumePath(TaskRun $taskRun): string;
    public function getSessionVolumeMount(TaskRun $taskRun): string;
    public function extractSessionId(array $initEvent): ?string;
    public function extractCost(array $resultEvent): ?CostData;
    public function supportsElicitation(): bool;
}
```

### OpenCodeStrategy

```php
class OpenCodeStrategy implements CliBackendStrategy
{
    public function buildCommand(TaskRun $taskRun, AgentRole $agentRole, string $resolvedToken): string
    {
        $model = $taskRun->model ?? $agentRole->preferred_model;
        $prompt = $taskRun->prompt;
        $sessionId = $taskRun->session_id;

        $cmd = 'opencode run';
        $cmd .= ' --format json';
        $cmd .= " --model {$model}";

        if ($sessionId) {
            $cmd .= " --session {$sessionId}";
        }

        // Escape prompt for shell
        $cmd .= ' ' . escapeshellarg($prompt);

        return $cmd;
    }

    public function normalizeEvent(array $rawEvent): ?CanonicalStreamEvent
    {
        return match ($rawEvent['type'] ?? null) {
            'step_start' => $this->normalizeStepStart($rawEvent),
            'text' => $this->normalizeText($rawEvent),
            'tool_use' => $this->normalizeToolUse($rawEvent),
            'step_finish' => $this->normalizeStepFinish($rawEvent),
            'error' => $this->normalizeError($rawEvent),
            default => null, // Drop unknown events
        };
    }

    public function getSessionResumePath(TaskRun $taskRun): string
    {
        return "/home/agent/.local/share/opencode";
    }

    public function getSessionVolumeMount(TaskRun $taskRun): string
    {
        $base = config('docker.session_volume_base');
        return "{$base}/{$taskRun->id}/opencode:/home/agent/.local/share/opencode";
    }

    public function extractSessionId(array $initEvent): ?string
    {
        return $initEvent['session_id'] ?? null;
    }

    public function extractCost(array $resultEvent): ?CostData
    {
        return new CostData(
            inputTokens: $resultEvent['usage']['input_tokens'] ?? 0,
            outputTokens: $resultEvent['usage']['output_tokens'] ?? 0,
            totalCostUsd: $resultEvent['total_cost_usd'] ?? null,
            model: $resultEvent['model'] ?? null,
        );
    }

    public function supportsElicitation(): bool
    {
        return false; // OpenCode does not support interactive elicitation
    }
}
```

## OpenCode CLI Command

### Full Command Format
```bash
opencode run --format json --model {model} --session {session_id} "{prompt}"
```

### Parameters

| Flag | Description | Required |
|------|-------------|----------|
| `--format json` | Output as NDJSON stream | Yes |
| `--model {model}` | Model to use (e.g., `gpt-5.4`, `gemini-3.1-pro`) | Yes |
| `--session {session_id}` | Resume existing session | No (only for resume) |
| `"{prompt}"` | The prompt/instruction for the agent | Yes |

### Docker Execution
```bash
docker exec -i {container_name} opencode run --format json --model gpt-5.4 "Implement the login feature..."
```

## NDJSON Event Normalization

### OpenCode Raw Events → Canonical Events

| OpenCode Event | Canonical Type | Transform Details |
|---------------|---------------|-------------------|
| `step_start` | `system` | Session init. Extract `session_id`, `model`. Map to canonical system event with session metadata. |
| `text` | `assistant` | Text content from the model. Wrap in canonical assistant event with `content: [{type: "text", text: "..."}]` format. |
| `tool_use` | `assistant` | Tool call details. Map to canonical assistant event with `content: [{type: "tool_use", name: "...", input: {...}}]` format. |
| `step_finish` | `result` | Completion event. Extract `total_cost_usd`, `usage` (input_tokens, output_tokens), `duration_ms`. Map `is_error` from exit status. |
| `error` | `error` | Error event. Extract `message`, `code`. Map to canonical error event. |

### Normalization Implementation

```php
private function normalizeStepStart(array $raw): CanonicalStreamEvent
{
    return new CanonicalStreamEvent(
        type: StreamEventType::System,
        data: [
            'session_id' => $raw['session_id'] ?? null,
            'model' => $raw['model'] ?? null,
            'message' => 'Agent session started (OpenCode)',
        ],
        contentText: 'Session started',
        occurredAt: now(),
    );
}

private function normalizeText(array $raw): CanonicalStreamEvent
{
    return new CanonicalStreamEvent(
        type: StreamEventType::Assistant,
        data: [
            'role' => 'assistant',
            'content' => [
                ['type' => 'text', 'text' => $raw['text'] ?? ''],
            ],
        ],
        contentText: $raw['text'] ?? '',
        occurredAt: now(),
    );
}

private function normalizeToolUse(array $raw): CanonicalStreamEvent
{
    return new CanonicalStreamEvent(
        type: StreamEventType::Assistant,
        data: [
            'role' => 'assistant',
            'content' => [
                [
                    'type' => 'tool_use',
                    'name' => $raw['tool'] ?? $raw['name'] ?? 'unknown',
                    'input' => $raw['input'] ?? $raw['args'] ?? [],
                ],
            ],
        ],
        contentText: "Tool: " . ($raw['tool'] ?? $raw['name'] ?? 'unknown'),
        occurredAt: now(),
    );
}

private function normalizeStepFinish(array $raw): CanonicalStreamEvent
{
    return new CanonicalStreamEvent(
        type: StreamEventType::Result,
        data: [
            'is_error' => $raw['error'] ?? false,
            'total_cost_usd' => $raw['total_cost_usd'] ?? null,
            'duration_ms' => $raw['duration_ms'] ?? null,
            'usage' => [
                'input_tokens' => $raw['usage']['input_tokens'] ?? 0,
                'output_tokens' => $raw['usage']['output_tokens'] ?? 0,
            ],
            'model' => $raw['model'] ?? null,
        ],
        contentText: ($raw['error'] ?? false) ? 'Run failed' : 'Run completed',
        occurredAt: now(),
    );
}

private function normalizeError(array $raw): CanonicalStreamEvent
{
    return new CanonicalStreamEvent(
        type: StreamEventType::Error,
        data: [
            'message' => $raw['message'] ?? 'Unknown error',
            'code' => $raw['code'] ?? null,
        ],
        contentText: $raw['message'] ?? 'Unknown error',
        occurredAt: now(),
    );
}
```

## Session Resume

### Mechanism
- OpenCode uses `--session {session_id}` flag for session resume
- Session data stored at `/home/agent/.local/share/opencode/`
- Session volume persists between container restarts (same as Claude Code pattern)

### Resume Flow
1. User answers question or triggers resume
2. New container started with session volume mounted
3. Command built with `--session {previous_session_id}`
4. OpenCode loads session state from volume → continues execution

### Difference from Claude Code
- Claude Code: `--resume {session_id}` with answer injected in prompt
- OpenCode: `--session {session_id}` — session DB file handles continuity
- OpenCode does NOT support interactive elicitation — questions must be handled differently

### Question Handling (OpenCode)
Since OpenCode doesn't support interactive elicitation like Claude Code:
- Questions from OpenCode agents are detected via specific output patterns (e.g., explicit "QUESTION:" markers in agent output)
- On question detection: container is stopped, session preserved
- On answer: new container, resume with answer prepended to prompt
- This is less seamless than Claude Code's elicitation — document this limitation

## Multi-Provider Token Support

### Provider → OpenCode Auth Config Mapping

| Provider | Env Var | Token Type |
|----------|---------|------------|
| OpenAI | `OPENAI_API_KEY` | API key |
| Google | `GOOGLE_API_KEY` or `GEMINI_API_KEY` | API key |
| OpenRouter | `OPENROUTER_API_KEY` | API key |

### Auth Config Injection

```php
class OpenCodeStrategy implements CliBackendStrategy
{
    public function getEnvironmentVariables(AiToken $token): array
    {
        return match ($token->provider) {
            AiProvider::OpenAI => ['OPENAI_API_KEY' => $token->credentials],
            AiProvider::Google => ['GOOGLE_API_KEY' => $token->credentials],
            AiProvider::OpenRouter => ['OPENROUTER_API_KEY' => $token->credentials],
            default => throw new UnsupportedProviderException($token->provider),
        };
    }
}
```

These env vars are injected into the Docker container at runtime:
```php
// In ContainerManager::start()
$envVars = $strategy->getEnvironmentVariables($token);
// → docker run -e OPENAI_API_KEY=sk-... -e KODIZM_MCP_TOKEN=jwt... {image}
```

## Session Volume Paths

```
{session_volume_base}/{taskRunId}/opencode:/home/agent/.local/share/opencode
```

- Volume base: `config('docker.session_volume_base')` (e.g., `/var/kodizm/sessions`)
- OpenCode stores session DB and state files in `~/.local/share/opencode/`
- Container runs as `agent` user (UID 1001) — paths use `/home/agent/`
- Same 24h cleanup lifecycle as Claude Code session volumes

## Model Resolution

```php
// AgentRole with OpenCode backend
// preferred_model: 'gpt-5.4'
// backend_config.opencode.model_fallbacks: ['gemini-3.1-pro']

public function resolveModel(AgentRole $agentRole): string
{
    // 1. Try preferred_model
    // 2. Fall through model_fallbacks
    // 3. Default per provider
    $model = $agentRole->preferred_model;
    if ($model) return $model;

    $fallbacks = $agentRole->backend_config['opencode']['model_fallbacks'] ?? [];
    return $fallbacks[0] ?? 'gpt-5.4'; // default
}
```

## Registration

```php
// In CliBackendRegistry (from 03-Agent System)
$registry->register('opencode', new OpenCodeStrategy());

// Strategy resolution in AgentRunner
$strategy = $registry->resolve($agentRole->cli_backend);
// Returns OpenCodeStrategy for 'opencode', ClaudeCodeStrategy for 'claude_code'
```

## Limitations vs Claude Code

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| Interactive elicitation | Yes (stdin pipe) | No (prompt-based) |
| Session resume | `--resume {id}` | `--session {id}` |
| MCP server support | Yes (built-in) | Yes (config-based) |
| Output format | `--output-format stream-json` | `--format json` |
| System prompt | `--append-system-prompt` | Custom instructions via config |
| Budget limit | `--max-budget-usd` | Not supported (track externally) |
| Max turns | `--max-turns` | Not supported |
| Providers | Anthropic only | OpenAI, Google, OpenRouter |
