import 'dart:async';

import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/session.dart';
import '../models/session_usage_record.dart';
import '../models/stream_event.dart';

// ---------------------------------------------------------------------------
// Broadcast abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over broadcast subscribe/unsubscribe for testability.
///
/// In production the default [_EchoSessionBroadcast] delegates to the [Echo]
/// facade. Tests inject a fake.
abstract class SessionWebSocket {
  /// Subscribe to a private [channel] with an event callback.
  ///
  /// [channel] is the bare channel name without the `private-` prefix
  /// (e.g. `session.abc`).
  void subscribe(String channel, void Function(BroadcastEvent) onEvent);

  /// Unsubscribe from [channel] (bare name, no `private-` prefix).
  void unsubscribe(String channel);

  /// Stream that emits after a successful WebSocket reconnection.
  Stream<void> get onReconnect;
}

/// Default production [SessionWebSocket] backed by the [Echo] facade.
class _EchoSessionBroadcast implements SessionWebSocket {
  /// Active stream subscriptions keyed by channel name.
  final Map<String, StreamSubscription<BroadcastEvent>> _subscriptions = {};

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {
    _subscriptions[channel]?.cancel();
    _subscriptions[channel] = Echo.private(channel).events.listen(onEvent);
  }

  @override
  void unsubscribe(String channel) {
    _subscriptions[channel]?.cancel();
    _subscriptions.remove(channel);
    Echo.leave(channel);
  }

  @override
  Stream<void> get onReconnect => Echo.onReconnect;
}

// ---------------------------------------------------------------------------
// SessionState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for session management.
///
/// Manages the list of sessions, the currently active session detail,
/// streaming events, and real-time WebSocket subscriptions for a single
/// `session.{sessionId}` broadcast channel.
///
/// The primary state (`rxState`) is unused — all fields are secondary state
/// managed with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// final sessionState = SessionState.instance;
///
/// // Load sessions list, optionally filtered.
/// await sessionState.loadSessions(projectId: 'proj-uuid', type: 'autonomous');
///
/// // Load a single session detail with relations.
/// await sessionState.loadSession('session-uuid');
///
/// // Subscribe to live WebSocket updates.
/// sessionState.subscribeToSession('session-uuid');
///
/// // Clean up when leaving the screen.
/// sessionState.unsubscribeFromSession();
/// sessionState.reset();
/// ```
class SessionState extends MagicController
    with MagicStateMixin<void>, SentryStateMixin<void> {
  /// Creates a [SessionState] with optional injectable dependencies for testing.
  ///
  /// When [webSocket] is `null`, [_EchoSessionBroadcast] delegates to the
  /// [Echo] facade.
  SessionState({SessionWebSocket? webSocket})
    : _ws = webSocket ?? _EchoSessionBroadcast();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static SessionState get instance => Magic.findOrPut(SessionState.new);

  final SessionWebSocket _ws;

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  List<Session> _sessions = [];
  Session? _currentSession;
  List<StreamEvent> _events = [];
  bool _isLoading = false;
  String? _error;

  // -- Filter fields --
  String? _projectFilter;
  String? _typeFilter;
  String? _phaseFilter;

  // -- WebSocket state --
  String? _activeChannel;
  Map<String, dynamic>? _pendingQuestion;
  StreamSubscription<void>? _reconnectSubscription;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// All loaded sessions, unmodifiable.
  List<Session> get sessions => List.unmodifiable(_sessions);

  /// The currently loaded session detail, or `null` if not yet fetched.
  Session? get currentSession => _currentSession;

  /// All streaming events for the current session, unmodifiable.
  List<StreamEvent> get events => List.unmodifiable(_events);

  /// Whether a network request is currently in progress.
  @override
  bool get isLoading => _isLoading;

  /// The last error message, or `null` when no error occurred.
  String? get error => _error;

  /// The currently active WebSocket channel name, or `null` when not subscribed.
  String? get activeChannel => _activeChannel;

  /// The active project filter, or `null` when unfiltered.
  String? get projectFilter => _projectFilter;

  /// The active type filter, or `null` when unfiltered.
  String? get typeFilter => _typeFilter;

  /// The active phase filter, or `null` when unfiltered.
  String? get phaseFilter => _phaseFilter;

  /// The latest pending question payload from a `.session.question` event,
  /// or `null` when no question is pending.
  Map<String, dynamic>? get pendingQuestion => _pendingQuestion;

  // ---------------------------------------------------------------------------
  // loadSessions
  // ---------------------------------------------------------------------------

  /// Fetch the sessions list from the API, optionally filtered.
  ///
  /// Maps to `GET /v1/sessions?project_id=&type=&phase=`. Null filter
  /// arguments are omitted from the query. Stores active filters for
  /// subsequent refreshes.
  ///
  /// Calls [refreshUI] after updating [_sessions].
  Future<void> loadSessions({
    String? projectId,
    String? type,
    String? phase,
  }) async {
    _projectFilter = projectId;
    _typeFilter = type;
    _phaseFilter = phase;

    final Map<String, dynamic> query = {};
    if (projectId != null) query['project_id'] = projectId;
    if (type != null) query['type'] = type;
    if (phase != null) query['phase'] = phase;

    _isLoading = true;
    _error = null;
    refreshUI();

    final response = await Http.get(
      '/v1/sessions',
      query: query.isNotEmpty ? query : null,
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _sessions = items
          .map((item) => Session.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      _sessions = [];
    }

    _isLoading = false;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // loadSession
  // ---------------------------------------------------------------------------

  /// Fetch a single session by ID, including usage records and shares.
  ///
  /// Maps to `GET /v1/sessions/{id}`. Stores the result as [currentSession].
  /// On failure, sets [currentSession] to `null`.
  ///
  /// Calls [refreshUI] after updating [_currentSession].
  Future<void> loadSession(String sessionId) async {
    _isLoading = true;
    _error = null;
    refreshUI();

    final response = await Http.get('/v1/sessions/$sessionId');

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _currentSession = Session.fromMap(data);
    } else {
      _currentSession = null;
    }

    _isLoading = false;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // loadEvents
  // ---------------------------------------------------------------------------

  /// Fetch stream events for a session from the API, optionally filtered by type.
  ///
  /// Maps to `GET /v1/sessions/{id}/events?type=`. Replaces the current
  /// [events] list entirely. On failure, clears [events].
  ///
  /// Calls [refreshUI] after updating [_events].
  Future<void> loadEvents(String sessionId, {String? type}) async {
    final Map<String, dynamic> query = {};
    if (type != null) query['type'] = type;

    final response = await Http.get(
      '/v1/sessions/$sessionId/events',
      query: query.isNotEmpty ? query : null,
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _events = items
          .map((item) => StreamEvent.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      _events = [];
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // share
  // ---------------------------------------------------------------------------

  /// Create a share grant for a session via the API.
  ///
  /// Maps to `POST /v1/sessions/{id}/share` with a payload containing
  /// [shareableType], [shareableId], and [permission].
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> share(
    String sessionId,
    String shareableType,
    String shareableId,
    String permission,
  ) async {
    final response = await Http.post(
      '/v1/sessions/$sessionId/share',
      data: {
        'shareable_type': shareableType,
        'shareable_id': shareableId,
        'permission': permission,
      },
    );

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // unshare
  // ---------------------------------------------------------------------------

  /// Remove a share grant for a session via the API.
  ///
  /// Maps to `DELETE /v1/sessions/{id}/shares/{shareId}`.
  ///
  /// Returns `true` on success, `false` otherwise.
  Future<bool> unshare(String sessionId, String shareId) async {
    final response = await Http.delete(
      '/v1/sessions/$sessionId/shares/$shareId',
    );

    return response.successful;
  }

  // ---------------------------------------------------------------------------
  // subscribeToSession
  // ---------------------------------------------------------------------------

  /// Subscribe to the `session.{sessionId}` broadcast channel.
  ///
  /// Registers [handleWebSocketEvent] as the listener on the channel.
  /// Stores the channel name in [activeChannel] for later cleanup.
  void subscribeToSession(String sessionId) {
    final channel = 'session.$sessionId';
    _activeChannel = channel;

    _ws.subscribe(channel, handleWebSocketEvent);

    _reconnectSubscription?.cancel();
    _reconnectSubscription = _ws.onReconnect.listen((_) {
      _catchUpAfterReconnect();
    });

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // _catchUpAfterReconnect
  // ---------------------------------------------------------------------------

  /// Re-fetches the current session after a WebSocket reconnection.
  ///
  /// Ensures the UI reflects the latest session state (phase, cost, events)
  /// that may have been missed during the disconnect window.
  Future<void> _catchUpAfterReconnect() async {
    if (_currentSession == null) return;

    Log.debug('SessionState: catching up after reconnect');
    await loadSession(_currentSession!.id);
  }

  // ---------------------------------------------------------------------------
  // unsubscribeFromSession
  // ---------------------------------------------------------------------------

  /// Unsubscribe from the currently active session channel.
  ///
  /// Leaves the broadcast channel and clears [activeChannel].
  /// No-op when [activeChannel] is `null`.
  void unsubscribeFromSession() {
    if (_activeChannel == null) return;

    _ws.unsubscribe(_activeChannel!);

    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;

    _activeChannel = null;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // handleWebSocketEvent
  // ---------------------------------------------------------------------------

  /// Process a live [BroadcastEvent] from the active session channel.
  ///
  /// Dispatches to the appropriate handler based on [BroadcastEvent.event]:
  /// - `.session.status` → update [currentSession] phase via copyWith
  /// - `.session.cost` → update cost fields + append usage record
  /// - `.session.stream` → append [StreamEvent] to [events]
  /// - `.session.question` → store pending question in [pendingQuestion]
  ///
  /// Unknown event names are silently ignored.
  void handleWebSocketEvent(BroadcastEvent wsEvent) {
    switch (wsEvent.event) {
      case '.session.status':
        _handleStatusEvent(wsEvent);
      case '.session.cost':
        _handleCostEvent(wsEvent);
      case '.session.stream':
        _handleStreamEvent(wsEvent);
      case '.session.question':
        _handleQuestionEvent(wsEvent);
      default:
        // Silently ignore unknown event names.
        return;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------

  /// Clear all state fields and notify listeners.
  ///
  /// Call this when leaving the session screens to free memory.
  /// Also unsubscribes any active WebSocket channel.
  void reset() {
    if (_activeChannel != null) {
      unsubscribeFromSession();
    }

    _sessions = [];
    _currentSession = null;
    _events = [];
    _isLoading = false;
    _error = null;
    _projectFilter = null;
    _typeFilter = null;
    _phaseFilter = null;
    _activeChannel = null;
    _pendingQuestion = null;

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Private event handlers
  // ---------------------------------------------------------------------------

  /// Handle `.session.status` — update [_currentSession] phase via copyWith.
  void _handleStatusEvent(BroadcastEvent wsEvent) {
    if (_currentSession == null) return;

    final phase = wsEvent.data['phase'] as String?;
    if (phase != null) {
      _currentSession = _currentSession!.copyWith(phase: phase);
    }
  }

  /// Handle `.session.cost` — update cost totals and append usage record
  /// if present in the payload.
  void _handleCostEvent(BroadcastEvent wsEvent) {
    if (_currentSession == null) return;

    final totalCostUsdRaw = wsEvent.data['total_cost_usd'] as String?;
    final totalInputTokens = wsEvent.data['total_input_tokens'] as int?;
    final totalOutputTokens = wsEvent.data['total_output_tokens'] as int?;
    final totalCacheReadTokens =
        wsEvent.data['total_cache_read_tokens'] as int?;
    final totalCacheCreationTokens =
        wsEvent.data['total_cache_creation_tokens'] as int?;
    final rawUsageRecord =
        wsEvent.data['usage_record'] as Map<String, dynamic>?;

    List<SessionUsageRecord>? updatedUsageRecords;
    if (rawUsageRecord != null) {
      updatedUsageRecords = [
        ..._currentSession!.usageRecords,
        SessionUsageRecord.fromMap(rawUsageRecord),
      ];
    }

    _currentSession = _currentSession!.copyWith(
      totalCostUsd: totalCostUsdRaw != null
          ? double.parse(totalCostUsdRaw)
          : null,
      totalInputTokens: totalInputTokens,
      totalOutputTokens: totalOutputTokens,
      totalCacheReadTokens: totalCacheReadTokens,
      totalCacheCreationTokens: totalCacheCreationTokens,
      usageRecords: updatedUsageRecords,
    );
  }

  /// Handle `.session.stream` — parse full [StreamEvent] from payload and
  /// append to [_events].
  void _handleStreamEvent(BroadcastEvent wsEvent) {
    final event = StreamEvent.fromMap(wsEvent.data);
    _events = [..._events, event];
  }

  /// Handle `.session.question` — store the raw data payload as
  /// [_pendingQuestion] so the view can prompt the user.
  void _handleQuestionEvent(BroadcastEvent wsEvent) {
    _pendingQuestion = Map<String, dynamic>.from(wsEvent.data);
  }
}
