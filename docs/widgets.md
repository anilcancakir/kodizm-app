# Widgets

25 reusable widgets organized by atomic design: atoms, molecules, organisms.

All files in `lib/resources/widgets/`. See `CLAUDE.md` for Wind UI rules and coding conventions.

## Atoms (9)

Smallest reusable units -- single-purpose display components.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `StatusBadge` | `atoms/status_badge.dart` | Pill badge for task/conversation status with DESIGN.md color mapping | `TaskListView`, `TaskDetailView`, `DashboardView` |
| `PriorityBadge` | `atoms/priority_badge.dart` | Pill badge for task priority (P0-P3) | `TaskListView`, `TaskDetailView` |
| `TaskTypeIcon` | `atoms/task_type_icon.dart` | Icon + label for task type (story/task/bug/spike) | `TaskListView`, `TaskDetailView` |
| `StreamingIndicator` | `atoms/streaming_indicator.dart` | Pulsing spinner + "Agent is thinking..." label | `ConversationChatView` |
| `TerminalEventTile` | `atoms/terminal_event_tile.dart` | Single stream event row: system, assistant, tool_use (collapsible), result, file_change, error, question | `TerminalEventList` |
| `ChatFileChangeRow` | `atoms/chat_file_change_row.dart` | File change row with operation badge (M/A/D) | `ConversationChatView` |
| `ChatErrorBlock` | `atoms/chat_error_block.dart` | Error message display block | `ChatStreamEventRenderer` |
| `ChatResultBlock` | `atoms/chat_result_block.dart` | Tool result display block | `ChatStreamEventRenderer` |
| `ChatThinkingBlock` | `atoms/chat_thinking_block.dart` | Thinking/reasoning display block | `ChatStreamEventRenderer` |

## Molecules (2)

Combinations of atoms -- small functional units used across views.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `ModelCostBreakdown` | `molecules/model_cost_breakdown.dart` | Per-model cost table: aggregates SessionUsageRecords by model, shows input/output tokens + cost | `SessionDetailView` |
| `ChatSubagentBlock` | `molecules/chat_subagent_block.dart` | Subagent execution block with agent name and status | `ConversationChatView` |

## Organisms (14)

Complex components composed of atoms and molecules.

| Widget | File | Purpose | Used By |
|--------|------|---------|---------|
| `MarkdownViewer` | `organisms/markdown_viewer.dart` | Markdown rendering with DESIGN.md typography + syntax-highlighted code blocks | `KnowledgeDetailView`, `ChatMessageBubble`, `TaskDetailView` |
| `QuestionPanel` | `organisms/question_panel.dart` | Slide-in panel for pending AgentQuestion with text input and submit button | `SessionDetailView` |
| `TerminalEventList` | `organisms/terminal_event_list.dart` | Scrollable dark terminal container rendering TerminalEventTile items, accepts ScrollController | `SessionDetailView` |
| `ChatMessageBubble` | `organisms/chat_message_bubble.dart` | User (amber, right-aligned) or assistant (white, left-aligned with MarkdownViewer) message bubble | `ConversationChatView` |
| `ChatToolUseCard` | `organisms/chat_tool_use_card.dart` | Collapsible tool use card: tool name header, JSON input/result display | `ConversationChatView` |
| `ChatQuestionCard` | `organisms/chat_question_card.dart` | Question card with AskUserQuestion options | `ConversationChatView` |
| `ChatPermissionCard` | `organisms/chat_permission_card.dart` | Tool permission approval card | `ConversationChatView` |
| `ChatInputBar` | `organisms/chat_input_bar.dart` | Message input bar with send button and typing indicator | `ConversationChatView` |
| `ChatStreamEventRenderer` | `organisms/chat_stream_event_renderer.dart` | Routes stream events to appropriate chat widgets | `ConversationChatView` |
| `EnvironmentConfigSection` | `organisms/environment_config_section.dart` | Runtime version dropdowns and service toggles | `ProjectDetailView` |
| `ProjectCreateModal` | `organisms/project_create_modal.dart` | Create project modal dialog | `ProjectListView` |
| `TaskCreationMethodModal` | `organisms/task_creation_method_modal.dart` | Task creation method selector modal | `TaskListView` |
| `AgentRolePickerModal` | `organisms/agent_role_picker_modal.dart` | Agent role selection modal | `TaskDetailView` |

## Composition Graph

```
ConversationChatView
  -> ChatMessageBubble (organism)
    -> MarkdownViewer (organism)
  -> ChatToolUseCard (organism)
  -> ChatQuestionCard (organism)
  -> ChatPermissionCard (organism)
  -> ChatInputBar (organism)
  -> ChatStreamEventRenderer (organism)
    -> ChatThinkingBlock (atom)
    -> ChatResultBlock (atom)
    -> ChatErrorBlock (atom)
    -> ChatFileChangeRow (atom)
  -> ChatSubagentBlock (molecule)
  -> StreamingIndicator (atom)

SessionDetailView
  -> TerminalEventList (organism)
    -> TerminalEventTile (atom)
  -> QuestionPanel (organism)
  -> ModelCostBreakdown (molecule)

All Views
  -> PageHeader (molecule, from magic_starter)
  -> SectionCard (molecule, from magic_starter)
```

## Related Docs

- [Design System](design-system.md) -- visual tokens and color references
- [Views and Routes](views-and-routes.md) -- where widgets are used
- See `CLAUDE.md` for widget rules (Wind UI only, no Flutter native layout)
