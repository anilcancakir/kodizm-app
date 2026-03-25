# Spec 17 — Multi-Model Routing (Post-MVP)

> Category-based task decomposition, optimal model mapping, parallel wave execution, and model consensus scoring.
> Dependencies: 14-OpenCode Backend (multi-provider support required).
>
> **TDD**: All code developed test-first (red-green-refactor).

## Overview

Multi-model routing enables Kodizm to decompose tasks by category (frontend, backend, database, etc.), route each sub-task to the optimal model for that category, execute independent sub-tasks in parallel waves, and optionally use consensus scoring for critical decisions. This is the most advanced orchestration feature — it turns Kodizm into a true multi-model, multi-agent platform.

## Category-Based Task Decomposition

### Task Categories

When a task is complex enough to benefit from decomposition, the Lead Developer (planning stage) breaks it into categorized sub-tasks:

```php
enum TaskCategory: string
{
    case Frontend = 'frontend';
    case Backend = 'backend';
    case Database = 'database';
    case Api = 'api';
    case Testing = 'testing';
    case DevOps = 'devops';
    case Documentation = 'documentation';
    case Design = 'design';
    case Security = 'security';
    case Performance = 'performance';
}
```

### Decomposition Process

1. Lead Dev agent analyzes the task during Planning stage
2. Identifies distinct work categories
3. Creates sub-tasks via MCP `create-task` tool:
   - Each sub-task has `parent_task_id` set to the original task
   - Each sub-task tagged with a category (stored in `task.settings.category`)
   - Dependencies between sub-tasks specified (stored in `task.settings.depends_on: [task_ids]`)
4. Writes decomposition plan to TaskSection (type: `plan`)

### Example Decomposition

Original task: "Add Google OAuth login"

| Sub-task | Category | Dependencies |
|----------|----------|-------------|
| Create OAuth migration | database | — |
| Implement OAuthService | backend | database migration |
| Add Google OAuth endpoints | api | OAuthService |
| Build Google login button UI | frontend | — |
| Connect UI to OAuth API | frontend | API endpoints |
| Write OAuth integration tests | testing | All implementation |

## Category → Optimal Model Mapping

### Default Mapping

```php
// config/model-routing.php
return [
    'category_model_map' => [
        'frontend' => [
            'primary' => 'claude-sonnet-4-6',
            'fallback' => 'gpt-5.4',
            'rationale' => 'Strong at UI code, component patterns',
        ],
        'backend' => [
            'primary' => 'claude-sonnet-4-6',
            'fallback' => 'gemini-3.1-pro',
            'rationale' => 'Best at Laravel/PHP patterns, service design',
        ],
        'database' => [
            'primary' => 'claude-opus-4-6',
            'fallback' => 'gpt-5.4',
            'rationale' => 'Complex schema design needs deeper reasoning',
        ],
        'api' => [
            'primary' => 'claude-sonnet-4-6',
            'fallback' => 'gpt-5.4',
            'rationale' => 'API design, REST conventions',
        ],
        'testing' => [
            'primary' => 'claude-sonnet-4-6',
            'fallback' => 'gemini-3.1-pro',
            'rationale' => 'Test generation, edge case identification',
        ],
        'devops' => [
            'primary' => 'claude-sonnet-4-6',
            'fallback' => 'gpt-5.4',
            'rationale' => 'Docker, CI/CD, infrastructure',
        ],
        'documentation' => [
            'primary' => 'claude-haiku-4-5',
            'fallback' => 'gemini-3.1-flash',
            'rationale' => 'Fast, sufficient for docs, cost-effective',
        ],
        'security' => [
            'primary' => 'claude-opus-4-6',
            'fallback' => 'gpt-5.4',
            'rationale' => 'Security requires deep reasoning',
        ],
        'performance' => [
            'primary' => 'claude-opus-4-6',
            'fallback' => 'gemini-3.1-pro',
            'rationale' => 'Complex optimization analysis',
        ],
    ],
];
```

### Customizable per Project

Teams can override the default mapping in `project.settings`:
```json
{
    "model_routing": {
        "frontend": { "primary": "gpt-5.4" },
        "backend": { "primary": "gemini-3.1-pro" }
    }
}
```

### Model Resolution for Routed Tasks

```php
class ModelRouter
{
    public function resolveModel(Task $subTask, AgentRole $agentRole): string
    {
        $category = $subTask->settings['category'] ?? null;

        if (!$category) {
            // No category — use agent role's default model
            return $agentRole->preferred_model ?? config('model-routing.default_model');
        }

        // 1. Check project override
        $projectOverride = $subTask->project->settings['model_routing'][$category]['primary'] ?? null;
        if ($projectOverride) return $projectOverride;

        // 2. Check team override
        $teamOverride = $subTask->project->team->settings['model_routing'][$category]['primary'] ?? null;
        if ($teamOverride) return $teamOverride;

        // 3. Fall back to global config
        return config("model-routing.category_model_map.{$category}.primary")
            ?? $agentRole->preferred_model
            ?? config('model-routing.default_model');
    }
}
```

## Wave-Based Parallel Execution (GSD Pattern)

### Concept

Tasks are decomposed into dependency waves. Sub-tasks within the same wave have no dependencies on each other and can execute in parallel. The pattern is inspired by the "Get Shit Done" (GSD) approach to parallel AI task execution.

### Dependency DAG Construction

```
Given sub-tasks with dependencies:
  A: no deps
  B: no deps
  C: depends on A
  D: depends on A, B
  E: depends on C
  F: depends on D

Wave computation:
  Wave 1: [A, B]       ← no dependencies, run in parallel
  Wave 2: [C, D]       ← depends only on Wave 1 tasks
  Wave 3: [E, F]       ← depends on Wave 2 tasks
```

### Implementation

```php
class WaveExecutor
{
    /**
     * Build execution waves from sub-tasks and their dependencies.
     */
    public function buildWaves(Collection $subTasks): array
    {
        $waves = [];
        $completed = collect();

        while ($completed->count() < $subTasks->count()) {
            $wave = $subTasks->filter(function (Task $task) use ($completed) {
                // Not yet completed
                if ($completed->contains($task->id)) return false;

                // All dependencies satisfied
                $deps = $task->settings['depends_on'] ?? [];
                return collect($deps)->every(fn ($dep) => $completed->contains($dep));
            });

            if ($wave->isEmpty()) {
                throw new CircularDependencyException('Circular dependency detected');
            }

            $waves[] = $wave->values()->all();
            $completed = $completed->merge($wave->pluck('id'));
        }

        return $waves;
    }

    /**
     * Execute waves sequentially, tasks within each wave in parallel.
     */
    public function execute(Task $parentTask): void
    {
        $subTasks = $parentTask->children;
        $waves = $this->buildWaves($subTasks);

        foreach ($waves as $waveIndex => $waveTasks) {
            // Dispatch all tasks in this wave in parallel
            $jobs = collect($waveTasks)->map(function (Task $task) {
                $model = app(ModelRouter::class)->resolveModel($task, $task->agentRole);
                return new ExecuteAgentTask($task, $model);
            });

            // Wait for all jobs in this wave to complete
            Bus::batch($jobs->all())
                ->name("wave-{$waveIndex}-task-{$parentTask->id}")
                ->allowFailures()
                ->dispatch();

            // Block until wave completes (or use event-driven approach)
            $this->awaitWaveCompletion($waveIndex, $parentTask);
        }
    }
}
```

### Concurrency Limits

- Wave parallel execution respects existing concurrency limits:
  - Max concurrent runs per project: 3 (configurable)
  - Max concurrent runs per team: 10 (configurable)
- If a wave has 5 tasks but project limit is 3: execute 3, queue remaining 2
- Wave does not advance until ALL tasks in current wave are complete (or failed)

### Failure Handling

- If a sub-task in a wave fails:
  - Other tasks in the same wave continue (they're independent)
  - Dependent tasks in later waves are blocked
  - Options: retry failed task (up to max retries) or skip and mark dependent tasks as blocked
- Parent task status: `failed` if any critical sub-task fails, `done` if all complete

## Model Consensus Scoring (MCO Pattern)

### Concept

For critical decisions (architecture, security review, complex planning), run the same prompt through multiple models in parallel, then score and merge the results. The MCO (Model Consensus Orchestrator) pattern ensures higher quality through model diversity.

### When to Use Consensus

- Architecture decisions (Lead Dev planning stage)
- Security reviews (Code Reviewer stage)
- Complex analysis (BA analysis stage)
- Configurable per pipeline stage in `pipeline_config`

### Consensus Configuration

```json
{
    "consensus_config": {
        "enabled": true,
        "stages": ["planning", "review"],
        "models": ["claude-opus-4-6", "gpt-5.4", "gemini-3.1-pro"],
        "min_agreement": 0.7,
        "scoring_model": "claude-opus-4-6",
        "strategy": "weighted_vote"
    }
}
```

### Consensus Flow

```
1. Dispatch same prompt to N models in parallel
2. Collect all responses
3. Scoring model evaluates + merges:
   - Identify agreements (high confidence)
   - Identify disagreements (flag for review)
   - Weight by model strength for this category
4. Generate merged output with confidence scores
5. If agreement < min_agreement → escalate to human
```

### Implementation

```php
class ConsensusOrchestrator
{
    public function executeWithConsensus(
        Task $task,
        AgentRole $agentRole,
        array $models,
    ): ConsensusResult {
        // 1. Fan-out: run same prompt on all models in parallel
        $responses = $this->fanOut($task, $agentRole, $models);

        // 2. Score: use scoring model to evaluate responses
        $scoringResult = $this->score($responses, $task);

        // 3. Merge: combine best elements from all responses
        $mergedOutput = $this->merge($scoringResult);

        // 4. Check agreement threshold
        if ($scoringResult->agreementScore < config('consensus.min_agreement')) {
            $this->escalateToHuman($task, $scoringResult);
        }

        return new ConsensusResult(
            mergedOutput: $mergedOutput,
            individualResponses: $responses,
            agreementScore: $scoringResult->agreementScore,
            modelScores: $scoringResult->modelScores,
        );
    }

    private function fanOut(Task $task, AgentRole $agentRole, array $models): array
    {
        $jobs = collect($models)->map(fn ($model) =>
            new ExecuteAgentTask($task, $agentRole, $model)
        );

        // Execute all in parallel, collect results
        return Bus::batch($jobs->all())->dispatch();
    }

    private function score(array $responses, Task $task): ScoringResult
    {
        // Use the scoring model to evaluate all responses
        // Prompt: "Given these N responses to the same task, evaluate each..."
        // Returns: per-response scores, agreement areas, disagreement areas
    }
}
```

### ConsensusResult Model

```php
class ConsensusResult
{
    public function __construct(
        public readonly string $mergedOutput,
        public readonly array $individualResponses,
        public readonly float $agreementScore,
        public readonly array $modelScores,
    ) {}
}
```

### Cost Implications

- Consensus multiplies cost by number of models (typically 3x)
- Only enable for high-value decisions where quality justifies cost
- Budget check: `estimated_cost * num_models <= remaining_budget`
- Display to user: "Consensus mode: 3 models, estimated cost: $X.XX"

## Model-Specific Prompt Variants per Agent Role

### Why Variants?

Different models respond better to different prompting styles:
- Claude: responds well to XML-structured prompts, detailed system prompts
- GPT: prefers structured instructions, JSON formatting
- Gemini: works well with examples, shorter prompts

### Prompt Variant Schema

Stored in `agent_roles.backend_config`:

```json
{
    "prompt_variants": {
        "claude-opus-4-6": {
            "system_prompt_template": "claude_detailed",
            "output_format": "markdown_structured",
            "style_notes": "Use XML tags for structure, detailed instructions"
        },
        "gpt-5.4": {
            "system_prompt_template": "gpt_concise",
            "output_format": "json_structured",
            "style_notes": "Concise instructions, JSON output preference"
        },
        "gemini-3.1-pro": {
            "system_prompt_template": "gemini_example_driven",
            "output_format": "markdown_with_examples",
            "style_notes": "Include examples, shorter prompts"
        }
    }
}
```

### Prompt Template Resolution

```php
class PromptBuilder
{
    public function buildPrompt(AgentRole $agentRole, Task $task, string $model): string
    {
        $variant = $agentRole->backend_config['prompt_variants'][$model] ?? null;
        $basePrompt = $agentRole->system_prompt;

        if (!$variant) {
            // No variant — use base prompt as-is
            return $this->interpolate($basePrompt, $task);
        }

        $template = $this->loadTemplate($variant['system_prompt_template']);
        return $this->interpolate($template, $task, $variant);
    }
}
```

### Default Templates

```
templates/
├── claude_detailed.md      — Verbose, XML-structured, guardrails
├── gpt_concise.md          — Structured, JSON-friendly, direct
├── gemini_example_driven.md — Example-heavy, shorter context
└── universal_default.md    — Works reasonably with any model
```

## Dependency DAG for Parallel Sub-Task Execution

### DAG Schema (stored in parent task)

```json
{
    "decomposition": {
        "sub_tasks": [
            { "id": 101, "category": "database", "depends_on": [] },
            { "id": 102, "category": "backend", "depends_on": [101] },
            { "id": 103, "category": "frontend", "depends_on": [] },
            { "id": 104, "category": "api", "depends_on": [101, 102] },
            { "id": 105, "category": "frontend", "depends_on": [104] },
            { "id": 106, "category": "testing", "depends_on": [102, 103, 105] }
        ],
        "waves": [
            [101, 103],
            [102],
            [104],
            [105],
            [106]
        ],
        "estimated_total_cost_usd": 12.50,
        "estimated_duration_min": 25
    }
}
```

### DAG Visualization

Flutter UI renders the DAG as a visual graph:
- Nodes: sub-tasks with category color + model badge
- Edges: dependency arrows
- Wave grouping: horizontal lanes
- Live status: node color updates as tasks complete (grey → blue → green/red)

### API Endpoints

```
GET    /api/.../tasks/{task}/decomposition     → Get DAG + wave structure
POST   /api/.../tasks/{task}/decompose         → Trigger Lead Dev decomposition
POST   /api/.../tasks/{task}/execute-waves     → Start parallel wave execution
GET    /api/.../tasks/{task}/wave-status        → Current wave progress
POST   /api/.../tasks/{task}/cancel-waves       → Cancel remaining waves
```

## Services Summary

| Service | Responsibility |
|---------|---------------|
| `ModelRouter` | Resolve optimal model for category + project + team config |
| `WaveExecutor` | Build dependency DAG, execute waves in parallel |
| `ConsensusOrchestrator` | Fan-out to multiple models, score, merge results |
| `PromptBuilder` | Build model-specific prompts from variants + templates |
| `TaskDecomposer` | Assist Lead Dev in categorizing + splitting tasks |
