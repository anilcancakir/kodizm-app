# Spec 13 — Pipeline Orchestration (Post-MVP)

> Multi-agent pipeline with stage flow, execution modes, approval gates, retry loops, and PM decision-making.
> Dependencies: 06-Agent Execution, 05-Task Management.
>
> **TDD**: All code developed test-first (red-green-refactor).

## Overview

Pipeline orchestration enables automated multi-stage task execution across the full SDLC. Instead of manually running each agent, the pipeline automatically advances tasks through stages — analysis, planning, design (conditional), development, review, and testing — with configurable automation levels.

## Pipeline Stage Flow

```
┌─────────┐    ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌──────────┐    ┌──────────┐    ┌──────┐
│  DRAFT  │───→│ ANALYSIS │───→│ PLANNING │───→│  DESIGN   │───→│ IN_PROG  │───→│  REVIEW  │───→│ TEST │───→ DONE
│ (user)  │    │  (PM/BA) │    │(Lead Dev)│    │(Designer) │    │  (Dev)   │    │(Reviewer)│    │ (QA) │
└─────────┘    └──────────┘    └──────────┘    │ OPTIONAL  │    └──────────┘    └──────────┘    └──────┘
                                                └───────────┘         ↑              │          │
                                                                      │    REJECT     │          │
                                                                      └──────────────┘          │
                                                                      │         REJECT           │
                                                                      └─────────────────────────┘
                                                                      (max 2 retries → escalation)
```

### Stage Responsibilities

| Stage | Agent Role | Actions | Output |
|-------|-----------|---------|--------|
| Analysis | PM/BA | Clarify requirements, write story spec, identify design needs | TaskSection: `analysis` |
| Planning | Lead Developer | Technical analysis, architecture decisions, dev plan, subtask decomposition | TaskSection: `plan` |
| Design | Designer | UI/UX design via Figma MCP, mockups, approval from user | TaskSection: `design_brief` + `design_assets` |
| In Progress | Developer | Implementation, coding, unit tests | TaskSection: `dev_report`, code changes |
| Review | Code Reviewer | Code quality, security, best practices, approve/reject | TaskSection: `review_report` |
| Testing | QA Engineer | Test execution, verification against AC, approve/reject | TaskSection: `test_report` |

### Design Stage Conditional Trigger

The Designer stage is CONDITIONAL — it only runs if the PM/BA flags `design_needed: true` in the analysis section.

- PM analyzes the task and sets `task.design_needed = true` via MCP `update-task` tool
- Pipeline checks `task.design_needed` after Planning stage completes
- If `true`: route to Design stage
- If `false`: skip directly to In Progress

## Three Execution Modes

### Manual Mode (MVP Default)

```
Every stage transition requires user action.
User manually: assigns agent, triggers run, reviews output, approves/rejects, moves to next stage.
Pipeline is just a state machine — no automation.
```

- This is MVP behavior — no changes needed
- Pipeline orchestrator is not involved
- User controls everything via Flutter UI

### Semi-Auto Mode

```
Pipeline runs automatically stage by stage.
Each stage auto-dispatches the configured agent.

PAUSES and waits for user when:
  - Agent asks a question (any stage)
  - Code Reviewer or QA rejects (user decides: retry or fix)
  - Design approval needed (user reviews mockups)
  - Pipeline stage marked as "approval_required" in config
```

#### Semi-Auto Flow
1. Task moves to next stage (e.g., `analysis`)
2. Pipeline orchestrator auto-dispatches configured agent role for that stage
3. Agent executes → output persisted to TaskSection
4. On completion:
   - If stage has `approval_required: true` → PipelineStageRun status: `awaiting_approval`
   - If no approval needed → auto-advance to next stage
5. On agent question → pause, notify user via WebSocket
6. On rejection (review/testing) → notify user, wait for decision

### Full-Auto Mode

```
Pipeline runs without user intervention.
PM agent handles all decisions autonomously.
```

#### PM Agent as Decision-Maker
- PM agent is the "brain" of full-auto mode
- Handles:
  - **Agent questions**: PM evaluates question context → auto-answers if confident
  - **Reviewer rejection**: PM reads rejection reason → instructs Developer on fixes
  - **QA rejection**: PM reads test failure → instructs Developer on fixes
  - **Design approval**: PM reviews against requirements → approves if aligned

#### PM Auto-Answer Config
```json
{
    "auto_answer_config": {
        "enabled": true,
        "answerer_agent": "ba",
        "confidence_threshold": 0.8
    }
}
```

- PM evaluates whether it can confidently answer
- If confidence < threshold → escalate to human
- Auto-answered questions are logged with `StreamEventType::auto_answer`

#### Escalation to Human (Full-Auto)
PM escalates ONLY when:
- PM is not confident (ambiguous requirement)
- Max retries exceeded (2 retries per rejection source)
- Budget threshold reached
- PM explicitly flags for human review

## Approval Gates

Configurable per pipeline stage in `pipeline_config`:

```json
{
    "approval_gates": ["design", "review", "testing"]
}
```

- Stages listed in `approval_gates` pause for user approval after agent completes
- User actions: Approve (advance to next stage) or Reject (send back)
- In full-auto mode: PM agent handles approval decisions

## Retry Loops

### Rejection Flow
- **Code Reviewer rejects** → task returns to In Progress (Developer re-works)
- **QA rejects** → task returns to In Progress (Developer fixes)

### Retry Limits
- Max 2 retries per rejection source
- `task.retry_count` tracks total reject→retry cycles
- 3rd failure → pipeline stops, human escalation notification

### Rejection Content
- Rejection includes: reason, specific issues, suggested fixes
- Stored in TaskSection (`review_report` or `test_report`)
- Developer agent receives rejection context in next run's prompt

## PipelineStageRun Model

```
pipeline_stage_runs
├── id: uuid PK
├── task_id: uuid FK → tasks
├── task_run_id: uuid FK → task_runs nullable
├── stage: string                      // TaskStatus value (analysis, planning, design, in_progress, review, testing)
├── status: enum(pending, running, awaiting_approval, completed, failed, cancelled)
├── context_data: json nullable        // previous stage summary, diff, cost
├── approved_by_user_id: uuid FK → users nullable
├── approved_at: timestamp nullable
├── error: text nullable
├── started_at: timestamp nullable
├── completed_at: timestamp nullable
├── timestamps
```

### PipelineExecutionStatus Enum
```php
enum PipelineExecutionStatus: string
{
    case Pending = 'pending';
    case Running = 'running';
    case AwaitingApproval = 'awaiting_approval';
    case Completed = 'completed';
    case Failed = 'failed';
    case Cancelled = 'cancelled';
}
```

### context_data Schema
```json
{
    "previous_stage": "planning",
    "previous_output_summary": "Architecture: monolith with Laravel, 3 services identified...",
    "task_sections": [
        {"type": "analysis", "version": 2},
        {"type": "plan", "version": 1}
    ],
    "accumulated_cost_usd": 2.45,
    "rejection_reason": null,
    "rejection_count": 0
}
```

## Pipeline Configuration (per project)

Stored in `projects.pipeline_config` JSON column:

```json
{
    "execution_mode": "semi_auto",
    "stage_agents": {
        "analysis": { "agent_role_slug": "ba", "auto_dispatch": true },
        "planning": { "agent_role_slug": "lead-dev", "auto_dispatch": true },
        "design": { "agent_role_slug": "designer", "auto_dispatch": true, "approval_required": true },
        "in_progress": { "agent_role_slug": "developer", "auto_dispatch": true },
        "review": { "agent_role_slug": "code-reviewer", "auto_dispatch": true },
        "testing": { "agent_role_slug": "qa", "auto_dispatch": true }
    },
    "approval_gates": ["design", "review", "testing"],
    "max_retries_per_stage": 2,
    "auto_answer_config": {
        "enabled": true,
        "answerer_agent": "ba",
        "confidence_threshold": 0.8
    },
    "design_trigger": "pm_flag",
    "escalation_notify": ["owner", "admin"]
}
```

## Task Creation Methods

### Method 1: Manual

User creates task directly in Flutter UI:
- Fills: title, description, acceptance_criteria, type, priority, estimation
- Task starts in: `draft`
- `source: manual`

### Method 2: PM Conversation

User writes anything — customer requests, bullet points, meeting notes, raw ideas, bug reports:
```
"login sayfasinda google ile giris de olsun"
"- search broken on mobile\n- need dark mode\n- add export to CSV"
```

PM agent picks up → analyzes, groups, clarifies:
- **Single item**: Socratic clarification loop, then creates structured task
- **Multiple items**: Groups related items, prioritizes, creates multiple story spec tasks

Clarification example:
```
PM: "Is this for web only, or web + mobile?"
User: "Both"
PM: "Should Google login be alongside email login, or a separate page?"
User: "Alongside, as a button"
...continues until clear
```

PM creates structured task(s) in story spec format (see below):
- `source: pm_conversation`
- `source_conversation_id: {task_run_id}` — links to the BA chat session
- Task starts in: `analysis` (already analyzed by PM)

## PM Story Spec Format

PM agent creates tasks in a structured story spec format — not raw user request but a refined specification:

```
Title: [Clear, actionable title]
Description: [Refined problem statement + context]
Acceptance Criteria:
  - Given [context], when [action], then [result]
  - Given [context], when [action], then [result]
User Impact: [Who benefits, how]
Technical Hints: [If PM identifies relevant tech considerations]
Design Needs: [yes/no + brief if yes — triggers Designer involvement]
Dependencies: [Other task IDs if any]
```

## Services

### PipelineOrchestrator

```php
class PipelineOrchestrator
{
    public function advanceTask(Task $task): void;
    public function dispatchStage(Task $task, string $stage): PipelineStageRun;
    public function handleStageCompletion(PipelineStageRun $stageRun): void;
    public function handleRejection(PipelineStageRun $stageRun, string $reason): void;
    public function handleApproval(PipelineStageRun $stageRun, User $approver): void;
    public function canAutoAdvance(Task $task, string $currentStage): bool;
    public function shouldSkipDesign(Task $task): bool;
    public function getNextStage(string $currentStage, Task $task): ?string;
    public function escalateToHuman(Task $task, string $reason): void;
}
```

### PipelineStageDispatcher (Queue Job)

```php
class PipelineStageDispatcher implements ShouldQueue
{
    public function handle(
        PipelineOrchestrator $orchestrator,
        AgentRunner $runner,
    ): void {
        // 1. Resolve agent role for stage from pipeline_config
        // 2. Build prompt with context from previous stages
        // 3. Dispatch agent run
        // 4. On completion → orchestrator.handleStageCompletion()
    }
}
```

## WebSocket Events (Pipeline-Specific)

### Events on team.{id}

| Event | Payload | When |
|-------|---------|------|
| `.pipeline.stage_started` | `{task_id, stage, agent_role}` | Pipeline stage begins |
| `.pipeline.stage_completed` | `{task_id, stage, cost_usd}` | Stage completes |
| `.pipeline.awaiting_approval` | `{task_id, stage, stage_run_id}` | Stage needs approval |
| `.pipeline.rejected` | `{task_id, stage, reason}` | Stage rejected |
| `.pipeline.escalation` | `{task_id, reason}` | Human intervention needed |

## API Endpoints

```
POST   /api/.../tasks/{task}/pipeline/start          → Start pipeline from current stage
POST   /api/.../tasks/{task}/pipeline/approve/{run}   → Approve pipeline stage
POST   /api/.../tasks/{task}/pipeline/reject/{run}    → Reject pipeline stage with reason
GET    /api/.../tasks/{task}/pipeline/status           → Pipeline status + stage history
POST   /api/.../tasks/{task}/pipeline/cancel           → Cancel entire pipeline
```
