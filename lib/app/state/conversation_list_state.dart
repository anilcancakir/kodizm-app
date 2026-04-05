import 'package:magic/magic.dart';

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
    with MagicStateMixin<List<Conversation>> {
  /// Creates a [ConversationListState].
  ConversationListState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ConversationListState get instance =>
      Magic.findOrPut(ConversationListState.new);

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
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets state to initial (idle/empty) without triggering a network call.
  void reset() {
    setEmpty();
  }
}
