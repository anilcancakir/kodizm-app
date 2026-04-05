import 'package:magic/magic.dart';

import '../models/conversation.dart';
import '../models/conversation_message.dart';

// ---------------------------------------------------------------------------
// ConversationDetailState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for viewing a single conversation and its
/// messages.
///
/// HTTP-based state with message sending support.
/// Uses [MagicStateMixin<Conversation>] for loading/error/success transitions.
///
/// ## Usage
///
/// ```dart
/// final state = ConversationDetailState();
/// await state.load('team-uuid', 'proj-uuid', 'conv-uuid');
/// final conversation = state.rxState;
/// final messages = state.messages;
/// ```
class ConversationDetailState extends MagicController
    with MagicStateMixin<Conversation> {
  /// Creates a [ConversationDetailState].
  ConversationDetailState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ConversationDetailState get instance =>
      Magic.findOrPut(ConversationDetailState.new);

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  List<ConversationMessage> _messages = [];

  /// Whether a message is currently being sent.
  bool _sending = false;

  /// Stored route params for refresh/send after initial load.
  String _teamId = '';
  String _projectId = '';
  String _conversationId = '';

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// All messages in the conversation, ordered by the API (ascending).
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// Whether a message send is in progress.
  bool get isSending => _sending;

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Fetch the conversation and its messages.
  ///
  /// Sets loading, then populates `rxState` with the conversation and
  /// [messages] with the parsed list on success, or transitions to error
  /// on failure.
  Future<void> load(
    String teamId,
    String projectId,
    String conversationId,
  ) async {
    _teamId = teamId;
    _projectId = projectId;
    _conversationId = conversationId;
    setLoading();

    final response = await Http.get(
      '/teams/$teamId/projects/$projectId/conversations/$conversationId',
    );

    if (!response.successful) {
      setError(response.errorMessage ?? 'Failed to load conversation');
      return;
    }

    final Map<String, dynamic> data =
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final conversation = Conversation.fromMap(data);

    // -- Load messages --
    await _loadMessages(teamId, projectId, conversationId);

    setSuccess(conversation);
  }

  /// Fetch messages for the conversation.
  Future<void> _loadMessages(
    String teamId,
    String projectId,
    String conversationId,
  ) async {
    final response = await Http.get(
      '/teams/$teamId/projects/$projectId/conversations/$conversationId/messages',
    );

    if (response.successful) {
      final Map<String, dynamic> body = response.data as Map<String, dynamic>;
      final List<dynamic> items = body['data'] as List<dynamic>;
      _messages = items
          .map(
            (item) => ConversationMessage.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    }
  }

  // ---------------------------------------------------------------------------
  // Send message
  // ---------------------------------------------------------------------------

  /// Send a user message and refresh the message list from the server.
  ///
  /// Adds an optimistic local message immediately, then POSTs to the API.
  /// On success, refreshes the full message list to pick up the server-
  /// generated ID and any assistant reply. On failure, removes the
  /// optimistic message.
  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;

    _sending = true;
    notifyListeners();

    // Optimistic local message.
    final optimistic = ConversationMessage(
      id: 'optimistic-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId,
      role: 'user',
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _messages = [..._messages, optimistic];
    notifyListeners();

    final response = await Http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/$_conversationId/messages',
      data: {'content': content.trim()},
    );

    if (!response.successful) {
      // Remove optimistic message on failure.
      _messages = _messages.where((m) => m.id != optimistic.id).toList();
      _sending = false;
      notifyListeners();
      return false;
    }

    // Refresh messages from server to get real IDs + any assistant reply.
    await _loadMessages(_teamId, _projectId, _conversationId);

    _sending = false;
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  /// Refresh messages from the server without full reload.
  Future<void> refreshMessages() async {
    await _loadMessages(_teamId, _projectId, _conversationId);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Resets state to initial without triggering a network call.
  void reset() {
    _messages = [];
    _teamId = '';
    _projectId = '';
    _conversationId = '';
    setEmpty();
  }
}
