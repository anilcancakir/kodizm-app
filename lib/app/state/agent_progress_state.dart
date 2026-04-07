import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// AgentProgressItem data class
// ---------------------------------------------------------------------------

/// Immutable snapshot of a single agent progress event from the team channel.
///
/// Created when an `.agent.progress` broadcast arrives on the team's private
/// channel. Consumed by the toast overlay to display real-time progress.
///
/// ## Usage
///
/// ```dart
/// final item = AgentProgressItem(
///   conversationId: 'conv-1',
///   projectId: 'proj-1',
///   status: 'in_progress',
///   message: 'Analyzing codebase…',
///   occurredAt: DateTime.now(),
/// );
/// print(item.isBlocked); // false
/// ```
class AgentProgressItem {
  /// Creates an [AgentProgressItem].
  const AgentProgressItem({
    required this.conversationId,
    required this.projectId,
    this.projectName,
    this.taskId,
    this.agentRoleSlug,
    this.agentRoleName,
    required this.status,
    required this.message,
    this.percentage,
    required this.occurredAt,
  });

  /// The conversation that emitted this progress event.
  final String conversationId;

  /// The project the conversation belongs to.
  final String projectId;

  /// Human-readable project name (optional, for display).
  final String? projectName;

  /// Related task ID, if the agent is working on a specific task.
  final String? taskId;

  /// Machine-readable agent role identifier (e.g. `ba`, `dev`, `qa`).
  final String? agentRoleSlug;

  /// Human-readable agent role name (e.g. `Business Analyst`).
  final String? agentRoleName;

  /// Progress status string (e.g. `in_progress`, `blocked`, `completed`).
  final String status;

  /// Human-readable progress message describing the current activity.
  final String message;

  /// Optional percentage (0–100) for determinate progress.
  final int? percentage;

  /// When this progress event occurred on the server.
  final DateTime occurredAt;

  /// Whether the agent is in a blocked state (requires user attention).
  bool get isBlocked => status == 'blocked';

  // -----------------------------------------------------------------------
  // Factory
  // -----------------------------------------------------------------------

  /// Parse a broadcast event data map into an [AgentProgressItem].
  ///
  /// Keys match the API broadcast payload: `conversation_id`, `project_id`,
  /// `project_name`, `task_id`, `agent_role_slug`, `agent_role_name`,
  /// `status`, `message`, `percentage`, `occurred_at`.
  static AgentProgressItem fromMap(Map<String, dynamic> map) {
    return AgentProgressItem(
      conversationId: (map['conversation_id'] ?? '').toString(),
      projectId: (map['project_id'] ?? '').toString(),
      projectName: map['project_name'] as String?,
      taskId: map['task_id']?.toString(),
      agentRoleSlug: map['agent_role_slug'] as String?,
      agentRoleName: map['agent_role_name'] as String?,
      status: (map['status'] ?? 'unknown').toString(),
      message: (map['message'] ?? '').toString(),
      percentage: (map['percentage'] as num?)?.toInt(),
      occurredAt:
          DateTime.tryParse((map['occurred_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// AgentProgressState controller
// ---------------------------------------------------------------------------

/// Global state controller that listens to the team WebSocket channel for
/// agent progress events and manages a toast notification queue.
///
/// Subscribes to `private-team.{teamId}` and filters for `.agent.progress`
/// events. Maintains up to 3 active toasts — non-blocked toasts auto-dismiss
/// after 5 seconds, blocked toasts persist until manually dismissed.
///
/// The controller is a singleton managed by [Magic.findOrPut]. The overlay
/// widget reads [activeToasts] and calls [dismissToast] on user interaction.
///
/// ## Usage
///
/// ```dart
/// final progress = AgentProgressState.instance;
///
/// // Subscribe when the user selects a team.
/// progress.subscribeToTeam('team-uuid-001');
///
/// // Read active toasts in the overlay widget.
/// for (final toast in progress.activeToasts) {
///   print('${toast.agentRoleName}: ${toast.message}');
/// }
///
/// // Dismiss a toast manually.
/// progress.dismissToast('conv-uuid-001');
///
/// // Switch teams (unsubscribes old, subscribes new).
/// progress.switchTeam('team-uuid-002');
/// ```
class AgentProgressState extends MagicController with MagicStateMixin<void> {
  /// Creates an [AgentProgressState].
  AgentProgressState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static AgentProgressState get instance =>
      Magic.findOrPut(AgentProgressState.new);

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// Maximum number of toasts visible simultaneously.
  static const int _maxToasts = 3;

  /// Duration before a non-blocked toast auto-dismisses.
  static const Duration _autoDismissDuration = Duration(seconds: 10);

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  /// The currently subscribed team ID.
  String? _teamId;

  /// Active stream subscription on the team channel.
  StreamSubscription<BroadcastEvent>? _subscription;

  /// Active toast items, ordered by insertion (oldest first).
  final List<AgentProgressItem> _activeToasts = [];

  /// Auto-dismiss timers keyed by conversation ID.
  final Map<String, Timer> _timers = {};

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// The list of active toast items for the overlay to render.
  List<AgentProgressItem> get activeToasts => List.unmodifiable(_activeToasts);

  /// The currently subscribed team ID, if any.
  String? get teamId => _teamId;

  // ---------------------------------------------------------------------------
  // subscribeToTeam
  // ---------------------------------------------------------------------------

  /// Subscribe to the team's private channel for agent progress events.
  ///
  /// Stores the [teamId] and begins listening on `private-team.{teamId}`.
  /// Only `.agent.progress` events are processed; all others are ignored.
  void subscribeToTeam(String teamId) {
    if (_teamId == teamId && _subscription != null) return;

    unsubscribe();

    _teamId = teamId;
    _subscription = Echo.private('team.$teamId').events.listen(_onEvent);

    Log.debug('AgentProgressState: subscribed to team.$teamId');
  }

  // ---------------------------------------------------------------------------
  // unsubscribe
  // ---------------------------------------------------------------------------

  /// Cancel the channel subscription, clear all toasts and timers.
  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;

    if (_teamId != null) {
      Echo.leave('team.$_teamId');
      Log.debug('AgentProgressState: unsubscribed from team.$_teamId');
    }

    _cancelAllTimers();
    _activeToasts.clear();
    _teamId = null;

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // switchTeam
  // ---------------------------------------------------------------------------

  /// Switch to a different team channel.
  ///
  /// Unsubscribes from the current team (if any) and subscribes to
  /// [newTeamId].
  void switchTeam(String newTeamId) {
    unsubscribe();
    subscribeToTeam(newTeamId);
  }

  // ---------------------------------------------------------------------------
  // dismissToast
  // ---------------------------------------------------------------------------

  /// Manually dismiss a toast by its [conversationId].
  ///
  /// Removes the item from [activeToasts], cancels any pending auto-dismiss
  /// timer, and notifies listeners.
  void dismissToast(String conversationId) {
    _activeToasts.removeWhere((t) => t.conversationId == conversationId);
    _timers[conversationId]?.cancel();
    _timers.remove(conversationId);

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Test hook
  // ---------------------------------------------------------------------------

  /// Exposes [_addToast] for testing toast queue logic without WebSocket.
  @visibleForTesting
  void addToastForTesting(AgentProgressItem item) => _addToast(item);

  // ---------------------------------------------------------------------------
  // dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _cancelAllTimers();
    _subscription?.cancel();
    _subscription = null;

    if (_teamId != null) {
      Echo.leave('team.$_teamId');
    }

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private — event handling
  // ---------------------------------------------------------------------------

  /// Route incoming broadcast events to the progress handler.
  void _onEvent(BroadcastEvent event) {
    if (event.event != '.agent.progress') return;

    final item = AgentProgressItem.fromMap(event.data);
    _addToast(item);
  }

  // ---------------------------------------------------------------------------
  // Private — toast queue logic
  // ---------------------------------------------------------------------------

  /// Add or update a toast in the active queue.
  ///
  /// Rules:
  /// 1. Same `conversationId` already exists → update in-place, reset timer.
  /// 2. Queue has room (< 3) → append.
  /// 3. Queue full → evict oldest non-blocked, or oldest blocked if all blocked.
  void _addToast(AgentProgressItem item) {
    final existingIndex = _activeToasts.indexWhere(
      (t) => t.conversationId == item.conversationId,
    );

    if (existingIndex != -1) {
      // Update existing toast.
      _activeToasts[existingIndex] = item;
      _resetTimer(item);
    } else if (_activeToasts.length < _maxToasts) {
      // Room available — just add.
      _activeToasts.add(item);
      _startTimer(item);
    } else {
      // Queue full — find a slot to evict.
      final evictIndex = _findEvictIndex();
      final evicted = _activeToasts[evictIndex];
      _timers[evicted.conversationId]?.cancel();
      _timers.remove(evicted.conversationId);
      _activeToasts[evictIndex] = item;
      _startTimer(item);
    }

    refreshUI();
  }

  /// Find the index of the toast to evict when the queue is full.
  ///
  /// Prefers the oldest non-blocked toast. If all are blocked, evicts the
  /// oldest blocked toast.
  int _findEvictIndex() {
    // Try oldest non-blocked first.
    for (var i = 0; i < _activeToasts.length; i++) {
      if (!_activeToasts[i].isBlocked) return i;
    }
    // All blocked — evict oldest (index 0).
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Private — timer management
  // ---------------------------------------------------------------------------

  /// Start an auto-dismiss timer for [item] if it is not blocked.
  void _startTimer(AgentProgressItem item) {
    _timers[item.conversationId]?.cancel();

    if (item.isBlocked) return;

    _timers[item.conversationId] = Timer(_autoDismissDuration, () {
      dismissToast(item.conversationId);
    });
  }

  /// Reset the timer for an updated [item].
  ///
  /// Cancels the existing timer and starts a new one (or removes it if the
  /// item is now blocked).
  void _resetTimer(AgentProgressItem item) {
    _timers[item.conversationId]?.cancel();
    _timers.remove(item.conversationId);

    if (!item.isBlocked) {
      _timers[item.conversationId] = Timer(_autoDismissDuration, () {
        dismissToast(item.conversationId);
      });
    }
  }

  /// Cancel all active timers.
  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
