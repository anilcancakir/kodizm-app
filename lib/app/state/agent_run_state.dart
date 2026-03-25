import 'package:magic/magic.dart';

import '../events/websocket_event.dart';
import '../models/file_change.dart';
import '../models/stream_event.dart';
import '../models/task_run_detail.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [AgentRunState] uses.
///
/// In production the default [_MagicAgentRunHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class AgentRunHttpClient {
  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });

  /// Perform a POST request.
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });
}

/// Default production [AgentRunHttpClient] backed by the Magic [Http] facade.
class _MagicAgentRunHttpClient implements AgentRunHttpClient {
  const _MagicAgentRunHttpClient();

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => Http.get(url, query: query, headers: headers);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => Http.post(url, data: data, headers: headers);
}

// ---------------------------------------------------------------------------
// Event name → type mapping
// ---------------------------------------------------------------------------

/// Maps WebSocket event names to [StreamEvent.type] values.
const Map<String, String> _wsEventTypeMap = {
  '.agent.system': 'system',
  '.agent.assistant': 'assistant',
  '.agent.result': 'result',
  '.agent.question': 'question',
  '.agent.status': 'status',
};

// ---------------------------------------------------------------------------
// AgentRunState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for a single agent execution run.
///
/// Manages the run detail, streaming events, file changes, turn count, and
/// cost tracking. Designed to be used alongside the WebSocket layer — the
/// view subscribes to WebSocket events and forwards them via [addEvent].
///
/// The primary state (`rxState`) is unused; all fields are secondary state
/// managed with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// final runState = AgentRunState.instance;
///
/// // Load the run detail from API.
/// await runState.loadRunDetail('team-1', 'proj-1', 'task-1', 'run-1');
///
/// // Replay existing events (e.g. on reconnect).
/// await runState.loadExistingEvents('run-1');
///
/// // Forward a live WebSocket event.
/// runState.addEvent(wsEvent);
///
/// // Clean up when leaving the screen.
/// runState.reset();
/// ```
class AgentRunState extends MagicController with MagicStateMixin<void> {
  /// Creates an [AgentRunState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicAgentRunHttpClient].
  AgentRunState({AgentRunHttpClient? httpClient})
    : _http = httpClient ?? const _MagicAgentRunHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static AgentRunState get instance => Magic.findOrPut(AgentRunState.new);

  final AgentRunHttpClient _http;

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  TaskRunDetail? _runDetail;
  List<StreamEvent> _events = [];
  final Set<String> _seenEventIds = {};
  int _turnCount = 0;
  double _currentCost = 0.0;
  List<FileChange> _fileChanges = [];

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// The loaded run detail, or `null` if not yet fetched.
  TaskRunDetail? get runDetail => _runDetail;

  /// All streaming events received so far (replay + live), in order.
  List<StreamEvent> get events => List.unmodifiable(_events);

  /// Number of assistant turns observed during this run.
  int get turnCount => _turnCount;

  /// Current accumulated cost in USD.
  double get currentCost => _currentCost;

  /// File changes extracted from streaming events.
  List<FileChange> get fileChanges => List.unmodifiable(_fileChanges);

  // ---------------------------------------------------------------------------
  // loadRunDetail
  // ---------------------------------------------------------------------------

  /// Fetch the run detail from the API and store it as [runDetail].
  ///
  /// Calls [refreshUI] after updating [_runDetail].
  Future<void> loadRunDetail(
    String teamId,
    String projectId,
    String taskId,
    String runId,
  ) async {
    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/tasks/$taskId/runs/$runId',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _runDetail = TaskRunDetail.fromMap(data);
    } else {
      _runDetail = null;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // loadExistingEvents
  // ---------------------------------------------------------------------------

  /// Replay existing stream events from the API for the given [runId].
  ///
  /// Uses cursor-based pagination (`after_id` + `has_more`) to fetch all
  /// pages. Deduplicates events by ID via [_seenEventIds].
  ///
  /// Optionally pass [afterId] to start from a specific cursor position
  /// (e.g. to resume after the last known event).
  Future<void> loadExistingEvents(String runId, {String? afterId}) async {
    String? cursor = afterId;
    bool hasMore = true;

    while (hasMore) {
      final Map<String, dynamic> query = {'limit': 100};
      if (cursor != null) {
        query['after_id'] = cursor;
      }

      final response = await _http.get(
        '/task-runs/$runId/stream-events',
        query: query,
      );

      if (!response.successful) break;

      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      final List<dynamic> items = body['data'] as List<dynamic>;
      final Map<String, dynamic> meta = body['meta'] as Map<String, dynamic>;

      for (final item in items) {
        final event = StreamEvent.fromMap(item as Map<String, dynamic>);
        addStreamEvent(event);
      }

      hasMore = meta['has_more'] as bool;
      cursor = meta['next_cursor'] as String?;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // addEvent (WebSocket → StreamEvent)
  // ---------------------------------------------------------------------------

  /// Maps a raw [WebSocketEvent] to a [StreamEvent] and processes it.
  ///
  /// **CRITICAL**: WebSocket `broadcastWith()` payloads lack fields that
  /// [StreamEvent] requires (`id`, `task_run_id`, `occurred_at`,
  /// `content_text`). This method synthesizes the missing fields.
  ///
  /// For `.agent.status` events, only the run detail status is updated —
  /// no [StreamEvent] is created (pure status update, not rendered).
  void addEvent(WebSocketEvent wsEvent) {
    final String eventType =
        _wsEventTypeMap[wsEvent.eventName] ?? wsEvent.eventName;

    // -- .agent.status is a pure metadata update, no StreamEvent --
    if (wsEvent.eventName == '.agent.status') {
      _handleStatusEvent(wsEvent);
      refreshUI();
      return;
    }

    // -- Synthesize StreamEvent fields --
    final String syntheticId =
        'ws_${DateTime.now().microsecondsSinceEpoch}_${_events.length}';
    final String contentText = _extractContentText(wsEvent);
    final String? filePath = wsEvent.data['file_path'] as String?;

    final streamEvent = StreamEvent(
      id: syntheticId,
      taskRunId: _runDetail?.id ?? '',
      type: eventType,
      data: wsEvent.data,
      contentText: contentText.isEmpty ? null : contentText,
      filePath: filePath,
      isQuestion: wsEvent.eventName == '.agent.question',
      occurredAt: DateTime.now(),
    );

    // -- Per-event-type side effects --
    switch (wsEvent.eventName) {
      case '.agent.system':
        _handleSystemEvent(wsEvent);
      case '.agent.assistant':
        _handleAssistantEvent(wsEvent);
      case '.agent.result':
        _handleResultEvent(wsEvent);
      case '.agent.question':
        // Question events are rendered but have no extra side effects.
        break;
    }

    addStreamEvent(streamEvent);
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // addStreamEvent
  // ---------------------------------------------------------------------------

  /// Appends a [StreamEvent] to the event list with deduplication.
  ///
  /// If the event's [StreamEvent.id] has already been seen, the event is
  /// silently dropped. If the event type is `'file_change'` and a
  /// [StreamEvent.filePath] is present, a [FileChange] is extracted.
  void addStreamEvent(StreamEvent event) {
    if (_seenEventIds.contains(event.id)) return;

    _seenEventIds.add(event.id);
    _events = [..._events, event];

    // Extract file change if applicable.
    if (event.type == 'file_change' && event.filePath != null) {
      final operation = (event.data['operation'] as String?) ?? 'M';
      _fileChanges = [
        ..._fileChanges,
        FileChange(filePath: event.filePath!, operation: operation),
      ];
    }
  }

  // ---------------------------------------------------------------------------
  // cancelRun
  // ---------------------------------------------------------------------------

  /// Cancel the currently active run via the API.
  ///
  /// On success, updates [runDetail] status to `'cancelled'` via
  /// [TaskRunDetail.copyWith].
  Future<void> cancelRun(
    String teamId,
    String projectId,
    String taskId,
    String runId,
  ) async {
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/tasks/$taskId/runs/$runId/cancel',
    );

    if (response.successful && _runDetail != null) {
      _runDetail = _runDetail!.copyWith(status: 'cancelled');
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------

  /// Clear all state fields and notify listeners.
  ///
  /// Call this when leaving the agent run detail screen to free memory.
  void reset() {
    _runDetail = null;
    _events = [];
    _seenEventIds.clear();
    _turnCount = 0;
    _currentCost = 0.0;
    _fileChanges = [];
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Handle `.agent.system` — extract `session_id` and `model`, update
  /// [_runDetail] via [TaskRunDetail.copyWith].
  void _handleSystemEvent(WebSocketEvent wsEvent) {
    if (_runDetail == null) return;

    final sessionId = wsEvent.data['session_id'] as String?;
    final model = wsEvent.data['model'] as String?;

    _runDetail = _runDetail!.copyWith(sessionId: sessionId, model: model);
  }

  /// Handle `.agent.assistant` — increment [_turnCount].
  void _handleAssistantEvent(WebSocketEvent wsEvent) {
    _turnCount++;
  }

  /// Handle `.agent.result` — extract cost and duration, update
  /// [_runDetail] via [TaskRunDetail.copyWith].
  void _handleResultEvent(WebSocketEvent wsEvent) {
    final totalCostUsd = (wsEvent.data['total_cost_usd'] as num?)?.toDouble();
    final durationMs = wsEvent.data['duration_ms'] as int?;

    if (totalCostUsd != null) {
      _currentCost = totalCostUsd;
    }

    if (_runDetail != null) {
      _runDetail = _runDetail!.copyWith(
        totalCostUsd: totalCostUsd,
        durationMs: durationMs,
      );
    }
  }

  /// Handle `.agent.status` — update [_runDetail] status only.
  void _handleStatusEvent(WebSocketEvent wsEvent) {
    if (_runDetail == null) return;

    final status = wsEvent.data['status'] as String?;
    if (status != null) {
      _runDetail = _runDetail!.copyWith(status: status);
    }
  }

  /// Extract content text from a [WebSocketEvent] based on its event name.
  ///
  /// - `.agent.assistant`: joins `text` blocks from the `content` list
  /// - `.agent.question`: extracts `question_text`
  /// - `.agent.result`: extracts `result_text` or empty
  /// - `.agent.system`: extracts `content_text` or empty
  String _extractContentText(WebSocketEvent wsEvent) {
    switch (wsEvent.eventName) {
      case '.agent.assistant':
        final content = wsEvent.data['content'];
        if (content is List) {
          return content
              .where(
                (block) =>
                    block is Map<String, dynamic> && block['type'] == 'text',
              )
              .map((block) => (block as Map<String, dynamic>)['text'] as String)
              .join('');
        }
        return content?.toString() ?? '';

      case '.agent.question':
        return wsEvent.data['question_text'] as String? ?? '';

      case '.agent.result':
        return wsEvent.data['result_text'] as String? ?? '';

      case '.agent.system':
        return wsEvent.data['content_text'] as String? ?? '';

      default:
        return '';
    }
  }
}
