import 'package:magic/magic.dart';

import '../events/websocket_event.dart';
import '../models/conversation.dart';
import '../models/conversation_message.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [ConversationChatState] uses.
///
/// In production the default [_MagicHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class ConversationChatHttpClient {
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

/// Default production [ConversationChatHttpClient] backed by the Magic
/// [Http] facade.
class _MagicHttpClient implements ConversationChatHttpClient {
  const _MagicHttpClient();

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
// WebSocket abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over WebSocket subscribe/unsubscribe for testing.
///
/// In production callers pass the real [WebSocketService] instance (which
/// implements this interface implicitly). Tests inject a fake.
abstract class ConversationChatWebSocket {
  /// Subscribe to [channel] with an event callback.
  void subscribe(String channel, void Function(WebSocketEvent) onEvent);

  /// Unsubscribe from [channel].
  void unsubscribe(String channel);
}

// ---------------------------------------------------------------------------
// ConversationChatState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the debug conversation chat lifecycle.
///
/// Orchestrates creating a conversation, sending messages, receiving
/// WebSocket events, tracking metadata, and accumulating raw events for
/// debug display. All mutations call [refreshUI] to notify listeners.
///
/// The primary state (`rxState`) is unused; all fields are secondary state
/// managed with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// final chatState = ConversationChatState.instance;
///
/// // Create a new conversation (auto-fetches first agent role).
/// await chatState.createConversation('team-1', 'proj-1');
///
/// // Send a user message (optimistic append, API call, WS response).
/// await chatState.sendMessage('Explain the auth flow.');
///
/// // Forward a live WebSocket event.
/// chatState.addEvent(wsEvent);
///
/// // Complete the conversation.
/// await chatState.completeConversation();
///
/// // Clean up when leaving the screen.
/// chatState.reset();
/// ```
class ConversationChatState extends MagicController with MagicStateMixin<void> {
  /// Creates a [ConversationChatState] with optional injectable
  /// dependencies for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used. When [webSocket] is `null`, no WS operations are performed
  /// (the view layer must wire the real [WebSocketService]).
  ConversationChatState({
    ConversationChatHttpClient? httpClient,
    ConversationChatWebSocket? webSocket,
  }) : _http = httpClient ?? const _MagicHttpClient(),
       _ws = webSocket;

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static ConversationChatState get instance =>
      Magic.findOrPut(ConversationChatState.new);

  final ConversationChatHttpClient _http;
  final ConversationChatWebSocket? _ws;

  // ---------------------------------------------------------------------------
  // State fields
  // ---------------------------------------------------------------------------

  Conversation? _conversation;
  List<ConversationMessage> _messages = [];
  List<WebSocketEvent> _rawEvents = [];
  bool _isSending = false;
  String? _error;
  String? _warmUntil;
  String _teamId = '';
  String _projectId = '';
  String? _subscribedChannel;

  // Session state
  String? _sessionId;
  String? _subscribedSessionChannel;
  String? _runningCostUsd;
  String? _sessionPhase;

  // Question/permission state
  Map<String, dynamic>? _pendingQuestion;
  Map<String, dynamic>? _pendingPermission;
  List<Map<String, dynamic>>? _pendingOptions;
  bool _isAnswering = false;

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// The current conversation, or `null` if not yet created.
  Conversation? get conversation => _conversation;

  /// All messages in the conversation, ordered chronologically.
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// All raw WebSocket events received, for debug display.
  List<WebSocketEvent> get rawEvents => List.unmodifiable(_rawEvents);

  /// Whether a message send is currently in progress.
  bool get isSending => _isSending;

  /// The last error message, or `null` if no error.
  String? get error => _error;

  /// The `warm_until` timestamp from the latest status event.
  String? get warmUntil => _warmUntil;

  /// The session ID linked to this conversation, or `null` if not yet known.
  ///
  /// Populated from the `session_id` field of `.conversation.status` WS events.
  String? get sessionId => _sessionId;

  /// The running cost of the linked session in USD, or `null` if not yet received.
  ///
  /// Updated via `.session.cost` WS events on the session channel.
  String? get runningCostUsd => _runningCostUsd;

  /// The current execution phase of the linked session, or `null` if not yet received.
  ///
  /// Updated via `.session.status` WS events on the session channel.
  String? get sessionPhase => _sessionPhase;

  /// The pending question awaiting a user answer, or `null`.
  ///
  /// Shape: `{questionId, message, header?, options?}`.
  Map<String, dynamic>? get pendingQuestion => _pendingQuestion;

  /// The pending permission request awaiting approval, or `null`.
  ///
  /// Shape: `{questionId, toolName, input}`.
  Map<String, dynamic>? get pendingPermission => _pendingPermission;

  /// Whether an answer submission is currently in progress.
  bool get isAnswering => _isAnswering;

  // ---------------------------------------------------------------------------
  // createConversation
  // ---------------------------------------------------------------------------

  /// Create a new conversation for the given team and project.
  ///
  /// Fetches the first available agent role via [_fetchFirstAgentRoleId],
  /// then POST-creates the conversation, stores the result, and subscribes
  /// to the WebSocket channel for live events.
  Future<void> createConversation(String teamId, String projectId) async {
    _error = null;
    _teamId = teamId;
    _projectId = projectId;

    // -- Resolve agent role --
    final agentRoleId = await _fetchFirstAgentRoleId(teamId);
    if (agentRoleId == null) {
      refreshUI();
      return;
    }

    // -- Create conversation --
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/conversations',
      data: {'agent_role_id': agentRoleId},
    );

    if (!response.successful) {
      _error = response.errorMessage ?? 'Failed to create conversation';
      refreshUI();
      return;
    }

    final Map<String, dynamic> data =
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    _conversation = Conversation.fromMap(data);

    // -- Subscribe to WS channel --
    final channel = 'private-conversation.${_conversation!.id}';
    _subscribedChannel = channel;
    _ws?.subscribe(channel, addEvent);

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // loadConversation
  // ---------------------------------------------------------------------------

  /// Load an existing conversation by ID and prepare the chat session.
  ///
  /// GETs `/teams/{teamId}/projects/{projectId}/conversations/{conversationId}`,
  /// parses the result into [_conversation], fetches existing messages via
  /// [loadMessages], and subscribes to the conversation WebSocket channel.
  Future<void> loadConversation(
    String teamId,
    String projectId,
    String conversationId,
  ) async {
    _error = null;
    _teamId = teamId;
    _projectId = projectId;

    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/conversations/$conversationId',
    );

    if (!response.successful) {
      _error = response.errorMessage ?? 'Failed to load conversation';
      refreshUI();
      return;
    }

    final Map<String, dynamic> data =
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    _conversation = Conversation.fromMap(data);

    // -- Load existing messages --
    await loadMessages();

    // -- Subscribe to conversation WS channel --
    final channel = 'private-conversation.${_conversation!.id}';
    _subscribedChannel = channel;
    _ws?.subscribe(channel, addEvent);

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // sendMessage
  // ---------------------------------------------------------------------------

  /// Send a user message in the current conversation.
  ///
  /// Guards against missing conversation or concurrent sends. Appends an
  /// optimistic user message immediately, then POSTs to the API. The
  /// assistant response arrives asynchronously via WebSocket.
  Future<void> sendMessage(String text) async {
    if (_conversation == null || _isSending) return;

    _isSending = true;
    refreshUI();

    // Optimistic append.
    final optimisticMessage = ConversationMessage(
      id: 'optimistic_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _conversation!.id,
      role: 'user',
      content: text,
      createdAt: DateTime.now().toUtc(),
    );
    _messages = [..._messages, optimisticMessage];
    refreshUI();

    final response = await _http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/messages',
      data: {'content': text},
    );

    if (!response.successful) {
      _error = response.errorMessage ?? 'Failed to send message';
    }

    _isSending = false;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // addEvent
  // ---------------------------------------------------------------------------

  /// Process a raw [WebSocketEvent] from the conversation channel.
  ///
  /// Always appends to [rawEvents] for debug display. Routes known event
  /// types (`.conversation.message`, `.conversation.status`) to their
  /// respective handlers. Unknown event types are silently ignored (already
  /// captured in raw events).
  void addEvent(WebSocketEvent wsEvent) {
    _rawEvents = [..._rawEvents, wsEvent];

    switch (wsEvent.eventName) {
      case '.conversation.message':
        _handleMessageEvent(wsEvent);
      case '.conversation.status':
        _handleStatusEvent(wsEvent);
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // completeConversation
  // ---------------------------------------------------------------------------

  /// Mark the current conversation as completed via the API.
  ///
  /// Updates the local conversation status to `'completed'` on success.
  Future<void> completeConversation() async {
    if (_conversation == null) return;

    final response = await _http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/complete',
    );

    if (response.successful) {
      _conversation = _conversation!.copyWith(status: 'completed');
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // answerQuestion
  // ---------------------------------------------------------------------------

  /// Submit an answer to a pending question or permission request.
  ///
  /// POSTs to the answer endpoint and clears pending state on success.
  /// Guards against missing conversation or concurrent answer submissions.
  Future<void> answerQuestion(String questionId, String answerText) async {
    if (_conversation == null || _isAnswering) return;

    _isAnswering = true;
    refreshUI();

    final response = await _http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/answer',
      data: {'question_id': questionId, 'answer_text': answerText},
    );

    if (response.successful) {
      _pendingQuestion = null;
      _pendingPermission = null;
      _pendingOptions = null;
    } else {
      _error = response.errorMessage ?? 'Failed to submit answer';
    }

    _isAnswering = false;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // loadMessages
  // ---------------------------------------------------------------------------

  /// Fetch all messages for the current conversation from the API.
  ///
  /// Parses the cursor-paginated response and replaces [_messages].
  Future<void> loadMessages() async {
    if (_conversation == null) return;

    final response = await _http.get(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/messages',
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

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------

  /// Clear all state fields and unsubscribe from the WebSocket channels.
  ///
  /// Unsubscribes from both the conversation channel and the session channel
  /// (if any). Call this when leaving the conversation chat screen to free
  /// resources.
  void reset() {
    if (_subscribedChannel != null) {
      _ws?.unsubscribe(_subscribedChannel!);
      _subscribedChannel = null;
    }

    if (_subscribedSessionChannel != null) {
      _ws?.unsubscribe(_subscribedSessionChannel!);
      _subscribedSessionChannel = null;
    }

    _conversation = null;
    _messages = [];
    _rawEvents = [];
    _isSending = false;
    _error = null;
    _warmUntil = null;
    _teamId = '';
    _projectId = '';
    _sessionId = null;
    _runningCostUsd = null;
    _sessionPhase = null;
    _pendingQuestion = null;
    _pendingPermission = null;
    _pendingOptions = null;
    _isAnswering = false;

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetch the first agent role ID for the given team.
  ///
  /// Returns `null` and sets [_error] if no agent roles are available or
  /// the API call fails.
  Future<String?> _fetchFirstAgentRoleId(String teamId) async {
    final response = await _http.get('/teams/$teamId/agent-roles');

    if (!response.successful) {
      _error = response.errorMessage ?? 'Failed to fetch agent roles';
      return null;
    }

    final Map<String, dynamic> body = response.data as Map<String, dynamic>;
    final List<dynamic> items = body['data'] as List<dynamic>;

    if (items.isEmpty) {
      _error = 'No agent roles available';
      return null;
    }

    final first = items.first as Map<String, dynamic>;
    return first['id'] as String;
  }

  /// Handle `.conversation.message` — route by event type.
  ///
  /// Detects `tool_use` (AskUserQuestion options), `question` (answerable),
  /// and `permission` events before falling through to text message handling.
  void _handleMessageEvent(WebSocketEvent wsEvent) {
    final eventType = wsEvent.data['type'] as String?;
    final metadata = wsEvent.data['metadata'] as Map<String, dynamic>?;
    final metaData = metadata?['data'] as Map<String, dynamic>?;

    // -- AskUserQuestion tool_use: store options for later correlation --
    if (eventType == 'tool_use' && metaData != null) {
      final toolName = metaData['toolName'] as String?;
      if (toolName == 'AskUserQuestion') {
        final input = metaData['input'] as Map<String, dynamic>?;
        final questions = input?['questions'] as List<dynamic>?;
        if (questions != null && questions.isNotEmpty) {
          final first = questions.first as Map<String, dynamic>;
          _pendingOptions = (first['options'] as List<dynamic>?)
              ?.map((o) => Map<String, dynamic>.from(o as Map))
              .toList();
        }
        return;
      }
    }

    // -- Question event: store pending question with correlated options --
    if (eventType == 'question' && metaData != null) {
      _pendingQuestion = {
        'questionId': metaData['questionId'] as String?,
        'message': metaData['message'] as String?,
        'options': _pendingOptions,
      };
      _pendingOptions = null;
      return;
    }

    // -- Permission event: store pending permission --
    if (eventType == 'permission' && metaData != null) {
      _pendingPermission = {
        'questionId': metaData['questionId'] as String?,
        'toolName': metaData['toolName'] as String?,
        'input': metaData['input'],
      };
      return;
    }

    // -- Text messages: append to message list --
    final content = wsEvent.data['content'];
    if (content == null) return;

    final message = ConversationMessage(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}_${_messages.length}',
      conversationId:
          wsEvent.data['conversation_id'] as String? ?? _conversation?.id ?? '',
      role: wsEvent.data['type'] as String? ?? 'assistant',
      content: content as String,
      metadata: wsEvent.data['metadata'] as Map<String, dynamic>?,
      createdAt: wsEvent.data['occurred_at'] != null
          ? DateTime.parse(wsEvent.data['occurred_at'] as String)
          : DateTime.now().toUtc(),
    );

    _messages = [..._messages, message];
  }

  /// Handle `.conversation.status` — update conversation status,
  /// extract `warm_until`, and wire up the session WS channel when
  /// `session_id` becomes known for the first time.
  void _handleStatusEvent(WebSocketEvent wsEvent) {
    final status = wsEvent.data['status'] as String?;

    if (status != null && _conversation != null) {
      _conversation = _conversation!.copyWith(status: status);
    }

    _warmUntil = wsEvent.data['warm_until'] as String?;

    // Subscribe to session WS channel on first encounter.
    final incomingSessionId = wsEvent.data['session_id'] as String?;
    if (incomingSessionId != null && _sessionId != incomingSessionId) {
      _sessionId = incomingSessionId;
      final sessionChannel = 'private-session.$_sessionId';
      _subscribedSessionChannel = sessionChannel;
      _ws?.subscribe(sessionChannel, _handleSessionEvent);
    }
  }

  /// Handle events arriving on the `private-session.{sessionId}` channel.
  ///
  /// Routes `.session.cost` to update [_runningCostUsd] and
  /// `.session.status` to update [_sessionPhase].
  void _handleSessionEvent(WebSocketEvent wsEvent) {
    switch (wsEvent.eventName) {
      case '.session.cost':
        _runningCostUsd = wsEvent.data['running_cost_usd'] as String?;
      case '.session.status':
        _sessionPhase = wsEvent.data['phase'] as String?;
    }

    refreshUI();
  }
}
