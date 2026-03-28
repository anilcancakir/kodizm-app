# Widgets

13 reusable widgets organized by atomic design: atoms, molecules, organisms.

All files in `lib/resources/widgets/`. See `CLAUDE.md` for Wind UI rules and coding conventions.

## Atoms (5)

Smallest reusable units -- single-purpose display components.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `StatusBadge` | `atoms/status_badge.dart` | Pill badge for task/run status with DESIGN.md color mapping | `TaskListView`, `TaskDetailView`, `AgentRunView` |
| `PriorityBadge` | `atoms/priority_badge.dart` | Pill badge for task priority (P0-P3) | `TaskListView`, `TaskDetailView` |
| `TaskTypeIcon` | `atoms/task_type_icon.dart` | Icon + label for task type (story/task/bug/spike) | `TaskListView`, `TaskDetailView` |
| `StreamingIndicator` | `atoms/streaming_indicator.dart` | Pulsing spinner + "Agent is thinking..." label | `ConversationChatView` |
| `TerminalEventTile` | `atoms/terminal_event_tile.dart` | Single stream event row: system, assistant, tool_use (collapsible), result, file_change, error, question | `TerminalEventList` |

## Molecules (3)

Combinations of atoms -- small functional units used across views.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `PageHeader` | `molecules/page_header.dart` | Page title + subtitle + actions row with border-b divider, responsive sm:flex-row | All views (layout standard) |
| `SectionCard` | `molecules/section_card.dart` | Rounded card container: rounded-2xl, p-6, gap-4, optional `noPadding` for flush content | All views (layout standard) |
| `ModelCostBreakdown` | `molecules/model_cost_breakdown.dart` | Per-model cost table: aggregates SessionUsageRecords by model, shows input/output tokens + cost | `SessionDetailView`, `AgentRunView` |

## Organisms (5)

Complex components composed of atoms and molecules.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `MarkdownViewer` | `organisms/markdown_viewer.dart` | Markdown rendering with DESIGN.md typography + syntax-highlighted code blocks | `KnowledgeDetailView`, `ChatMessageBubble`, `TaskDetailView` |
| `QuestionPanel` | `organisms/question_panel.dart` | Slide-in panel for pending AgentQuestion with text input and submit button | `AgentRunView` |
| `TerminalEventList` | `organisms/terminal_event_list.dart` | Scrollable dark terminal container rendering TerminalEventTile items, accepts ScrollController | `AgentRunView`, `SessionDetailView` |
| `ChatMessageBubble` | `organisms/chat_message_bubble.dart` | User (amber, right-aligned) or assistant (white, left-aligned with MarkdownViewer) message bubble | `ConversationChatView` |
| `ChatToolUseCard` | `organisms/chat_tool_use_card.dart` | Collapsible tool use card: tool name header, JSON input/result display | `ConversationChatView` |

## Composition Graph

```
TerminalEventList
  -> TerminalEventTile (atom)

AgentRunView
  -> TerminalEventList (organism)
  -> QuestionPanel (organism)
  -> StatusBadge (atom)
  -> ModelCostBreakdown (molecule)
  -> SectionCard (molecule)

ConversationChatView
  -> ChatMessageBubble (organism)
    -> MarkdownViewer (organism)
  -> ChatToolUseCard (organism)
  -> StreamingIndicator (atom)

All Views
  -> PageHeader (molecule)
  -> SectionCard (molecule)
```

## Related Docs

- [Design System](design-system.md) -- visual tokens and color references
- [Views and Routes](views-and-routes.md) -- where widgets are used
- See `CLAUDE.md` for widget rules (Wind UI only, no Flutter native layout)
