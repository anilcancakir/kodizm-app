import 'dart:async';

import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/agent_role.dart';
import '../models/conversation.dart';

// ---------------------------------------------------------------------------
// ConversationListState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the conversation list within a project.
///
/// Manages [List<Conversation>] for a given project, supporting load, delete,
/// and reset operations.
///
/// ## Usage
///
/// ```dart
/// // Access via singleton accessor.
/// final state = ConversationListState.instance;
///
/// // Fetch all conversations for a project.
/// await state.loadConversations('team-uuid', 'proj-uuid');
/// final list = state.rxState; // List<Conversation>?
///
/// // Delete a conversation.
/// await state.deleteConversation('team-uuid', 'proj-uuid', 'conv-uuid');
/// ```
class ConversationListState extends MagicController
    with
        MagicStateMixin<List<Conversation>>,
        SentryStateMixin<List<Conversation>> {
  /// Creates a [ConversationListState].
  ConversationListState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ConversationListState get instance =>
      Magic.findOrPut(ConversationListState.new);

  // ---------------------------------------------------------------------------
  // Subscription state
  // ---------------------------------------------------------------------------

  StreamSubscription<BroadcastEvent>? _projectSubscription;
  StreamSubscription<void>? _reconnectSubscription;
  String? _teamId;
  String? _projectId;

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Fetch all conversations for the given [teamId] and [projectId].
  ///
  /// Sets loading, then populates `rxState` with the parsed list on success,
  /// or transitions to error on failure. An empty list triggers [setEmpty].
  Future<void> loadConversations(String teamId, String projectId) async {
    await fetchList<Conversation>(
      '/teams/$teamId/projects/$projectId/conversations',
      Conversation.fromMap,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Delete a conversation by [conversationId] and reload the list.
  ///
  /// Calls the DELETE endpoint, then re-fetches the conversation list on
  /// success. On failure, transitions to error state.
  Future<void> deleteConversation(
    String teamId,
    String projectId,
    String conversationId,
  ) async {
    final response = await Http.delete(
      '/teams/$teamId/projects/$projectId/conversations/$conversationId',
    );

    if (response.successful) {
      await loadConversations(teamId, projectId);
    } else {
      setError(response.errorMessage ?? 'Failed to delete conversation');
    }
  }

  // ---------------------------------------------------------------------------
  // Agent roles
  // ---------------------------------------------------------------------------

  /// Fetch the available agent roles for the given [teamId].
  ///
  /// Returns the list of [AgentRole] or an empty list on failure.
  Future<List<AgentRole>> fetchAgentRoles(String teamId) async {
    final response = await Http.get('/teams/$teamId/agent-roles');
    if (!response.successful) return [];

    final List<dynamic> items =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return items
        .map((item) => AgentRole.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Create a new conversation for the given [agentRoleId].
  ///
  /// Returns the created [Conversation] or `null` on failure.
  Future<Conversation?> createConversation(
    String teamId,
    String projectId,
    String agentRoleId,
  ) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/conversations',
      data: {'agent_role_id': agentRoleId},
    );

    if (!response.successful) return null;

    final Map<String, dynamic> data =
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return Conversation.fromMap(data);
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  /// Subscribe to real-time project-level broadcast events.
  ///
  /// Listens on `private-project.[projectId]` for `.conversation.status` and
  /// `.conversation.title` events, reloading the list on each. Also reloads
  /// when the WebSocket reconnects.
  ///
  /// Cancels any existing subscription before starting a new one, so it is
  /// safe to call multiple times as the active project changes.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// state.subscribeToProjectEvents(teamId, projectId);
  /// // ...
  /// state.unsubscribeFromProjectEvents();
  /// ```
  void subscribeToProjectEvents(String teamId, String projectId) {
    unsubscribeFromProjectEvents();

    _teamId = teamId;
    _projectId = projectId;

    _projectSubscription = Echo.private('project.$projectId').events.listen((
      BroadcastEvent event,
    ) {
      if (event.event == '.conversation.status' ||
          event.event == '.conversation.title') {
        loadConversations(teamId, projectId);
      }
    });

    _reconnectSubscription = Echo.onReconnect.listen((_) {
      loadConversations(_teamId!, _projectId!);
    });
  }

  /// Cancel the active project-level broadcast subscription.
  ///
  /// Leaves the Echo channel and cancels all stream listeners. Safe to call
  /// even if no subscription is currently active.
  void unsubscribeFromProjectEvents() {
    _projectSubscription?.cancel();
    _reconnectSubscription?.cancel();

    if (_projectId != null) {
      Echo.leave('project.$_projectId');
    }

    _projectSubscription = null;
    _reconnectSubscription = null;
    _teamId = null;
    _projectId = null;
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets state to initial (idle/empty) without triggering a network call.
  void reset() {
    setEmpty();
  }
}
