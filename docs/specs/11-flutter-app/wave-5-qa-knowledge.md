# Wave 5 — Agent Q&A & Knowledge

> Spec: 11-Flutter App
> Dependencies: Wave 4 complete (reuses streaming infrastructure, WebSocket service, AgentRunState)

## Deliverables

- [ ] Q&A flow: detect question -> show prompt -> submit answer -> agent resumes
- [ ] Question panel UI on AgentRunScreen (integrated with Wave 4 terminal)
- [ ] KnowledgeListScreen (project documents browser)
- [ ] KnowledgeDetailScreen (document viewer)
- [ ] DocumentState (ChangeNotifier + MagicStateMixin)
- [ ] Freezed models: AgentQuestion, ProjectDocument with UUID `String` ids

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## Agent Q&A Flow

### How It Works

During an agent run, the agent may ask clarifying questions. These arrive as `.agent.question` WebSocket events on the `private-task-run.{id}` channel. The user must answer for the agent to resume execution.

### Question Panel UI (on AgentRunScreen)

Added to the Agent Run Screen from Wave 4 — fixed at bottom, below terminal output:

```
+--------------------------------------------------------------+
|  Terminal Output (from Wave 4)                                |
|  ...                                                          |
+--------------------------------------------------------------+
|  Question Panel (visible when question is pending)            |
|  +----------------------------------------------------------+|
|  | ? Agent asks: "Should I use Provider or Riverpod?"        ||
|  | [Answer input field                            ] [Send]   ||
|  +----------------------------------------------------------+|
|                                              [Cancel Run]     |
+--------------------------------------------------------------+
```

**Mobile**: Question panel fixed at bottom with keyboard avoidance (input stays above keyboard).

### Question Flow

1. WebSocket receives `.agent.question` event with `{question_id, question_text}`
2. AgentRunState adds question to pending questions list
3. Question panel slides in at bottom with pulse animation
4. Terminal also shows the question event (amber/yellow background)
5. User types answer in text input field
6. User taps "Send"
7. POST `/api/task-runs/{run}/answer` via `Http` with `{ question_id, answer_text }`
8. Optimistic update: mark question as answered locally
9. Question panel hides (or shows next unanswered question if multiple)
10. Agent resumes streaming via WebSocket

### Multiple Questions
- If agent asks multiple questions (unlikely but possible), show them in a list
- Answered questions: dimmed with checkmark
- Current unanswered question: highlighted at top

### Question Event in Terminal
- Question events rendered with amber/yellow background and pulse animation
- After answering, the answer text appears below the question in the terminal (green text)

## Knowledge Screens

### Knowledge List Screen (`/projects/{projectId}/knowledge`)

- Lists all project documents (knowledge base)
- Each document card shows:
  - Title
  - Type badge (guidelines, architecture, api_reference, code_patterns, etc.)
  - Last updated (relative time)
  - Size/length indicator
- Sort: by title (default), by last updated
- Pull-to-refresh
- Tap document -> navigate to detail
- Empty state: "No knowledge documents yet. Documents are created by agents during task execution."

### Knowledge Detail Screen (`/projects/{projectId}/knowledge/{documentId}`)

- **Header**: Document title, type badge, last updated
- **Content**: Rendered markdown (full document)
  - Use `flutter_markdown` (same as task section viewer from Wave 3)
  - Support: headings, code blocks, lists, links, tables
- **Metadata**:
  - Created by (agent role or user)
  - Version number
  - Created at / Updated at
- Back navigation to knowledge list

## State Management

### QuestionState (extends AgentRunState from Wave 4)

Q&A state is integrated into `AgentRunState` — not a separate state class:

```dart
// Added to AgentRunState from Wave 4
class AgentRunState extends ChangeNotifier with MagicStateMixin {
  // ... existing properties from Wave 4 ...

  List<AgentQuestion> _questions = [];
  List<AgentQuestion> get questions => _questions;
  List<AgentQuestion> get pendingQuestions =>
      _questions.where((q) => q.answeredAt == null).toList();

  Future<void> loadQuestions(String runId) async {
    await run(() async {
      final response = await Http.get('/task-runs/$runId/questions');
      _questions = (response.data['data'] as List)
          .map((json) => AgentQuestion.fromJson(json))
          .toList();
      notifyListeners();
    });
  }

  void onQuestionEvent(Map<String, dynamic> data) {
    final question = AgentQuestion.fromJson(data);
    _questions = [..._questions, question];
    notifyListeners();
  }

  Future<void> answerQuestion(String runId, String questionId, String answerText) async {
    await run(() async {
      await Http.post('/task-runs/$runId/answer', data: {
        'question_id': questionId,
        'answer_text': answerText,
      });
      // Optimistic update
      _questions = _questions.map((q) =>
        q.id == questionId
            ? q.copyWith(answerText: answerText, answeredAt: DateTime.now())
            : q
      ).toList();
      notifyListeners();
    });
  }
}
```

### DocumentState (ChangeNotifier + MagicStateMixin)

```dart
class DocumentState extends ChangeNotifier with MagicStateMixin {
  List<ProjectDocument> _documents = [];
  ProjectDocument? _selectedDocument;

  List<ProjectDocument> get documents => _documents;
  ProjectDocument? get selectedDocument => _selectedDocument;

  Future<void> loadDocuments(String teamId, String projectId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects/$projectId/documents');
      _documents = (response.data['data'] as List)
          .map((json) => ProjectDocument.fromJson(json))
          .toList();
      notifyListeners();
    });
  }

  Future<void> loadDocument(String teamId, String projectId, String documentId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/projects/$projectId/documents/$documentId');
      _selectedDocument = ProjectDocument.fromJson(response.data['data']);
      notifyListeners();
    });
  }
}
```

## Freezed Models

### AgentQuestion

```dart
@freezed
class AgentQuestion with _$AgentQuestion {
  const factory AgentQuestion({
    required String id,              // UUID
    required String taskRunId,       // UUID
    String? streamEventId,           // UUID
    required String questionText,
    String? answerText,
    String? answeredByUserId,        // UUID
    DateTime? answeredAt,
    required DateTime createdAt,
  }) = _AgentQuestion;

  factory AgentQuestion.fromJson(Map<String, dynamic> json) => _$AgentQuestionFromJson(json);
}
```

### ProjectDocument

```dart
@freezed
class ProjectDocument with _$ProjectDocument {
  const factory ProjectDocument({
    required String id,              // UUID
    required String projectId,       // UUID
    required String title,
    required String type,            // guidelines, architecture, api_reference, code_patterns, etc.
    required String content,
    String? createdByAgentRoleId,    // UUID
    String? createdByAgentRoleName,
    String? createdByUserId,         // UUID
    String? createdByUserName,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProjectDocument;

  factory ProjectDocument.fromJson(Map<String, dynamic> json) => _$ProjectDocumentFromJson(json);
}
```

## Acceptance Criteria

### Question Detection

**Given** a running agent that asks a question,
**When** the `.agent.question` WebSocket event arrives,
**Then** the question panel slides in at the bottom with the question text and an input field.

**Given** a running agent with no pending questions,
**When** the user views the Agent Run Screen,
**Then** the question panel is hidden.

### Answer Submission

**Given** the question panel is visible with a pending question,
**When** the user types an answer and taps "Send",
**Then** `Http.post('/task-runs/{run}/answer')` is called with the question_id and answer_text, the question is marked as answered, and the agent resumes streaming.

**Given** the question panel is visible,
**When** the user tries to send an empty answer,
**Then** the send button is disabled.

### Question in Terminal

**Given** a question event in the terminal,
**When** it is rendered,
**Then** it appears with an amber/yellow background and pulse animation.

**Given** a question that has been answered,
**When** the terminal renders the answer,
**Then** the answer text appears below the question in green text.

### Q&A End-to-End

**Given** an agent run in progress,
**When** the agent asks a question, the user answers, and the agent resumes,
**Then** the full Q&A cycle works without page refresh — question appears, answer is submitted, streaming resumes.

### Knowledge List

**Given** a project with 5 knowledge documents,
**When** the user navigates to `/projects/{projectId}/knowledge`,
**Then** all 5 documents are listed with title, type badge, and last updated time.

**Given** a project with no knowledge documents,
**When** the user navigates to the knowledge list,
**Then** an empty state with "No knowledge documents yet" is displayed.

### Knowledge Detail

**Given** a knowledge document with markdown content,
**When** the user taps the document in the list,
**Then** they are navigated to the detail screen showing the full rendered markdown content with metadata.

**Given** a knowledge document with code blocks,
**When** the content is rendered,
**Then** code blocks are displayed with syntax highlighting and monospace font.

### Knowledge Browsing

**Given** the knowledge detail screen,
**When** the user taps back,
**Then** they return to the knowledge list with scroll position preserved.

## Implementation Notes

- Use `Http` facade for ALL API calls — never instantiate Dio directly.
- All model IDs are `String` (UUID) — no `int` IDs.
- State classes: `extends ChangeNotifier with MagicStateMixin`.
- Q&A state is integrated into `AgentRunState` from Wave 4 — do NOT create a separate state class for questions.
- The question panel should have keyboard avoidance on mobile (input field stays above keyboard).
- Knowledge screens reuse the markdown rendering infrastructure from Wave 3 (task section viewer).
- Knowledge documents are read-only in the Flutter app — agents create them during task execution.
- Consider adding a search/filter for knowledge documents if the list grows large.
