# Spec 05 — Task Management

> Task CRUD, state machine, sections.
> Dependencies: 02-Project Management (tasks belong to projects).

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Task CRUD & State Machine | Task model + migration + factory + policy, TaskStatus enum with state transitions, CRUD API |
| 2 | Task Sections | TaskSection model + migration + factory, section CRUD API, version increment logic |

## Dependencies on Other Specs

- **02-Project Management**: Tasks belong to projects. Project model and API must exist.
- Used by **06-Agent Execution**: TaskRuns reference tasks. Agent execution reads task data and writes sections.
- **Note**: User and Team models come from magic-starter and are extended by Kodizm.

## Data Models

### Task
```
tasks
├── id: uuid PK
├── project_id: uuid FK → projects
├── parent_task_id: uuid FK → tasks nullable  // sub-task support
├── title: string
├── description: text nullable
├── acceptance_criteria: text nullable
├── type: enum(story, task, bug, spike)
├── priority: enum(p0, p1, p2, p3) default p2
├── status: enum(draft, analysis, planning, design, in_progress, review, testing, done, failed)
├── estimated_complexity: enum(xs, s, m, l, xl) nullable
├── assigned_agent_role_id: uuid FK → agent_roles nullable
├── created_by_user_id: uuid FK → users nullable  // null = agent-created
├── source: enum(manual, pm_conversation) default 'manual'
├── source_conversation_id: uuid FK → task_runs nullable  // PM chat session that created this task
├── design_needed: boolean default false              // PM flags → triggers Designer stage
├── retry_count: integer default 0                    // tracks reject→retry cycles
├── sprint_id: uuid FK → sprints nullable      // POST-MVP: add migration when sprints table exists
├── branch_name: string nullable          // feature/task-{id}
├── total_cost_usd: decimal(10,4) default 0
├── timestamps
└── soft_deletes
```

**Post-MVP fields** (include in migration but not exposed in MVP API):
- `source` — always `manual` in MVP
- `source_conversation_id` — null in MVP (PM conversation not implemented)
- `design_needed` — always false in MVP (Designer agent not implemented)
- `sprint_id` — null in MVP (sprints not implemented)

### TaskSection
```
task_sections
├── id: uuid PK
├── task_id: uuid FK → tasks
├── type: enum(analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments)
├── title: string
├── content: text
├── created_by_agent_role_id: uuid FK → agent_roles nullable
├── created_by_user_id: uuid FK → users nullable
├── version: int default 1
├── timestamps
```

## State Machine

### TaskStatus Transitions (Full Pipeline)

```
draft → analysis
analysis → planning, failed
planning → design (if design_needed), in_progress, failed
design → in_progress, failed
in_progress → review, failed
review → in_progress (reject → retry), testing, failed
testing → in_progress (fail → retry), done, failed
done → (terminal)
failed → draft (reopen)
```

### MVP Simplified Flow

MVP only uses a subset of statuses:
```
draft → in_progress → review → done
draft → in_progress → failed
in_progress → failed
review → in_progress (reject)
review → done (approve)
failed → draft (reopen)
```

The full state machine is implemented (all transitions defined in the enum), but the pipeline stages (analysis, planning, design, testing) are only used post-MVP when pipeline orchestration is built.

## Relevant Enums

```php
enum TaskType: string
{
    case Story = 'story';
    case Task = 'task';
    case Bug = 'bug';
    case Spike = 'spike';
}

enum TaskPriority: string
{
    case P0 = 'p0';  // Critical
    case P1 = 'p1';  // High
    case P2 = 'p2';  // Medium (default)
    case P3 = 'p3';  // Low
}

enum TaskStatus: string
{
    case Draft = 'draft';
    case Analysis = 'analysis';
    case Planning = 'planning';
    case Design = 'design';
    case InProgress = 'in_progress';
    case Review = 'review';
    case Testing = 'testing';
    case Done = 'done';
    case Failed = 'failed';

    public function allowedTransitions(): array
    {
        return match ($this) {
            self::Draft => [self::Analysis],
            self::Analysis => [self::Planning, self::Failed],
            self::Planning => [self::Design, self::InProgress, self::Failed],
            self::Design => [self::InProgress, self::Failed],
            self::InProgress => [self::Review, self::Failed],
            self::Review => [self::InProgress, self::Testing, self::Failed],
            self::Testing => [self::InProgress, self::Done, self::Failed],
            self::Done => [],
            self::Failed => [self::Draft],
        };
    }

    public function canTransitionTo(self $target): bool
    {
        return in_array($target, $this->allowedTransitions(), true);
    }
}

enum TaskComplexity: string
{
    case XS = 'xs';
    case S = 's';
    case M = 'm';
    case L = 'l';
    case XL = 'xl';
}

enum TaskSource: string
{
    case Manual = 'manual';
    case PmConversation = 'pm_conversation';
}

enum TaskSectionType: string
{
    case Analysis = 'analysis';
    case Plan = 'plan';
    case DesignBrief = 'design_brief';
    case DesignAssets = 'design_assets';
    case DevReport = 'dev_report';
    case ReviewReport = 'review_report';
    case TestReport = 'test_report';
    case Notes = 'notes';
    case Comments = 'comments';
}
```

## Database Indexes

```
tasks:         (project_id, status), (parent_task_id)
task_sections: (task_id, type)
```

## Business Rules

- Tasks are scoped to projects. Project is scoped to team. Multi-tenancy enforced via project → team chain.
- Soft deletes on Task model.
- `total_cost_usd` on Task is the sum of all completed TaskRun costs for that task.
- `retry_count` increments when a review/testing rejection sends the task back to `in_progress`.
- State transitions are validated — attempting an invalid transition throws an exception.
