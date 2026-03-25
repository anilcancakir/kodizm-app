# Spec 15 — Designer Agent (Post-MVP)

> Figma MCP integration for design artifact creation, atomic design methodology, design approval flow.
> Dependencies: 13-Pipeline Orchestration (design stage trigger, approval gates).
>
> **TDD**: All code developed test-first (red-green-refactor).

## Overview

The Designer agent is a specialized AI agent that creates UI/UX design artifacts via Figma's MCP integration. It follows atomic design methodology, generates multiple variants for user selection, and integrates into the pipeline's conditional design stage.

## Figma MCP Integration

### MCP Server Configuration

The Designer agent's container includes Figma MCP server access:

```json
{
    "mcp_servers": {
        "figma": {
            "command": "npx",
            "args": ["-y", "@anthropic/figma-mcp-server"],
            "env": {
                "FIGMA_ACCESS_TOKEN": "{injected_from_ai_token}"
            }
        }
    }
}
```

### Figma MCP Tools Available to Designer

| Tool | Purpose |
|------|---------|
| `create_frame` | Create a new frame/artboard in Figma |
| `create_component` | Create a reusable component |
| `add_text` | Add text layers with styling |
| `add_rectangle` | Add shapes with fill/stroke |
| `add_auto_layout` | Configure auto-layout on frames |
| `set_styles` | Apply design tokens (colors, typography) |
| `export_png` | Export frame as PNG for review |
| `get_components` | Read existing components from project file |
| `duplicate_frame` | Duplicate for variant creation |

### Token Management

- Figma access tokens stored as AiToken records with `provider: figma` (new provider enum value)
- Token injected as `FIGMA_ACCESS_TOKEN` env var in Designer container
- Scoped to team's Figma workspace

## Atomic Design Methodology

The Designer agent follows atomic design principles when creating UI artifacts:

### Design Hierarchy

```
Atoms → Molecules → Organisms → Templates → Pages

Atoms:      Buttons, inputs, labels, icons, badges
Molecules:  Search bar (input + button), form field (label + input + error)
Organisms:  Navigation bar, task card, agent run panel
Templates:  Page layouts with placeholder content
Pages:      Actual screens with real content
```

### Design Process

1. **Read `design.md`**: Check if project has a design system definition
2. **If no `design.md`**: Create one based on project tech stack and brand guidelines
3. **Create atoms**: Buttons, inputs, typography scale, color palette
4. **Compose molecules**: Combine atoms into functional groups
5. **Build organisms**: Complex UI components (cards, panels, forms)
6. **Assemble templates**: Page layouts
7. **Generate pages**: Complete screens matching the task requirements

## Project Design System (`design.md`)

Each project can have a `design.md` document (stored as ProjectDocument, category: `convention`):

```markdown
# Design System — Project Name

## Brand
- Primary: #6366F1 (Indigo)
- Secondary: #10B981 (Emerald)
- Neutral: Slate scale
- Error: #EF4444
- Warning: #F59E0B
- Success: #22C55E

## Typography
- Font: Inter
- Scale: 12/14/16/18/20/24/30/36/48
- Weights: 400 (regular), 500 (medium), 600 (semibold), 700 (bold)

## Spacing
- Base: 4px
- Scale: 4/8/12/16/20/24/32/48/64

## Border Radius
- Small: 4px
- Medium: 8px
- Large: 12px
- Full: 9999px

## Components
- Button: primary, secondary, outline, ghost, danger
- Input: default, error, disabled
- Card: elevated, outlined, flat

## Platform
- Mobile-first responsive
- Breakpoints: 375 (mobile), 768 (tablet), 1024 (desktop), 1440 (wide)
```

### Design System Creation

If no `design.md` exists when Designer agent runs:
1. Designer reads project's tech stack
2. Infers appropriate design language (Material Design for Flutter, Tailwind for web, etc.)
3. Creates default `design.md` via MCP `create-document` tool
4. Proceeds with design work using the created system

## Design Approval Flow

### Trigger

1. PM/BA flags `task.design_needed = true` during analysis
2. Pipeline reaches Design stage after Planning
3. PipelineOrchestrator dispatches Designer agent

### Design Execution

1. Designer reads task analysis + plan sections for context
2. Reads `design.md` for design system
3. Creates design artifacts in Figma
4. Exports PNG previews
5. Writes `design_brief` section: rationale, decisions, component list
6. Writes `design_assets` section: Figma links, exported image URLs
7. Marks stage as ready for review

### User Review

1. Pipeline pauses at Design stage (`approval_required: true`)
2. User receives notification: "Design ready for review"
3. Flutter shows:
   - Design brief (markdown)
   - Figma link (opens in browser/app)
   - PNG previews (inline images)
   - Approve / Reject buttons
4. **Approve**: Pipeline advances to In Progress (Developer gets design as reference)
5. **Reject**: User provides feedback → Designer re-works (up to 2 retries)

### Developer Handoff

When Developer agent runs after approved design:
- Developer's prompt includes:
  - Design brief content
  - Figma component references
  - Design system (`design.md`)
  - PNG references for visual verification
- Developer implements UI matching the approved design

## Multiple Variant Generation

### Variant Strategy

For complex design tasks, the Designer generates 2-3 variants:

1. **Conservative**: Closely follows existing design system, minimal innovation
2. **Creative**: Explores new patterns while staying on-brand
3. **Bold**: Pushes boundaries, introduces new visual concepts

### Variant Presentation

Each variant is:
- A separate Figma frame
- Exported as PNG
- Described in the `design_brief` section with pros/cons
- User selects preferred variant during approval

### When to Generate Variants
- New feature with significant UI surface
- Landing pages / marketing screens
- When PM specifically requests "explore options"
- NOT for minor UI updates, bug fixes, or iteration on existing approved designs

## Task Sections for Design

### design_brief Section
```markdown
# Design Brief — [Task Title]

## Context
[What was requested, key requirements from analysis]

## Design Decisions
- [Decision 1]: [Rationale]
- [Decision 2]: [Rationale]

## Components Used
- [Component name] — [from design system or new]

## Variants (if applicable)
### Variant A: Conservative
- [Description, approach, pros/cons]
### Variant B: Creative
- [Description, approach, pros/cons]

## Accessibility Notes
- Color contrast: [compliance level]
- Touch targets: [minimum size]
- Screen reader: [considerations]

## Figma Link
[Direct link to Figma file/frame]
```

### design_assets Section
```markdown
# Design Assets — [Task Title]

## Exports
- [Screen name]: [PNG URL or path]
- [Component name]: [PNG URL or path]

## Figma References
- File: [Figma file URL]
- Frame: [Specific frame URL]
- Components: [Component set URL]

## Design Tokens (if new)
- [New color/spacing/component added to design system]
```

## AgentRole Configuration

```php
// Default Designer agent role (seeded)
[
    'name' => 'Designer',
    'slug' => 'designer',
    'cli_backend' => 'claude_code',
    'preferred_model' => 'claude-opus-4-6',
    'system_prompt' => <<<PROMPT
    You are a UI/UX Designer for a software development team. You create design artifacts using Figma MCP tools.

    Your methodology:
    1. Read the project's design.md for design system rules
    2. Follow atomic design: atoms → molecules → organisms → templates → pages
    3. Generate 2-3 variants for significant UI work
    4. Export PNG previews for review
    5. Write clear design briefs with rationale

    Rules:
    - Mobile-first responsive design
    - WCAG 2.1 AA accessibility compliance
    - Consistent with existing design system
    - Document all new components/tokens in design.md
    PROMPT,
    'backend_config' => [
        'claude-code' => [
            'mcp_servers' => [
                'figma' => [
                    'command' => 'npx',
                    'args' => ['-y', '@anthropic/figma-mcp-server'],
                ],
            ],
        ],
    ],
    'tool_permissions' => [
        'report-progress',
        'get-task',
        'get-project-info',
        'create-task-section',
        'update-task-section',
        'search-knowledge',
        'create-document',
        'update-document',
    ],
]
```
