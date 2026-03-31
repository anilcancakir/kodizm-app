import 'package:magic/magic.dart';

import '../models/agent_role.dart';
import '../models/conversation.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [ConversationListState] uses.
///
/// In production the default [_MagicConversationHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class ConversationListHttpClient {
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

  /// Perform a DELETE request.
  Future<MagicResponse> delete(String url, {Map<String, String>? headers});
}

/// Default production [ConversationListHttpClient] backed by the Magic [Http] facade.
class _MagicConversationHttpClient implements ConversationListHttpClient {
  const _MagicConversationHttpClient();

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

  @override
  Future<MagicResponse> delete(String url, {Map<String, String>? headers}) =>
      Http.delete(url, headers: headers);
}

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
/// // Access via Magic IoC container.
/// final state = Magic.findOrPut(ConversationListState.new);
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
  /// Creates a [ConversationListState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicConversationHttpClient].
  ConversationListState({ConversationListHttpClient? httpClient})
    : _http = httpClient ?? const _MagicConversationHttpClient();

  final ConversationListHttpClient _http;

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Fetch all conversations for the given [teamId] and [projectId].
  ///
  /// Sets loading, then populates `rxState` with the parsed list on success,
  /// or transitions to error on failure. An empty list triggers [setEmpty].
  Future<void> loadConversations(String teamId, String projectId) async {
    setLoading();

    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/conversations',
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final conversations = items
          .map((item) => Conversation.fromMap(item as Map<String, dynamic>))
          .toList();
      conversations.isEmpty ? setEmpty() : setSuccess(conversations);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch conversations');
    }
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
    final response = await _http.delete(
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
    final response = await _http.get('/teams/$teamId/agent-roles');
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
    final response = await _http.post(
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
