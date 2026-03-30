import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

import '../events/websocket_event.dart';
import '../models/agent_role.dart';
import '../models/chat_item.dart';
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
/// // Fetch available agent roles for display in a selection modal.
/// final roles = await chatState.fetchAgentRoles('team-1');
///
/// // Create a new conversation with the selected agent role.
/// await chatState.createConversation(
///   'team-1',
///   'proj-1',
///   agentRoleId: roles.first.id,
///   title: roles.first.name,
/// );
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
  List<ChatItem> _chatItems = [];
  Map<String, int> _activeSubagents = {};
  List<WebSocketEvent> _rawEvents = [];
  bool _isSending = false;
  bool _awaitingResponse = false;
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

  /// All renderable items in the conversation timeline, ordered chronologically.
  List<ChatItem> get chatItems => List.unmodifiable(_chatItems);

  /// All conversation messages (backwards-compatible accessor).
  ///
  /// Filters [chatItems] to only [ChatMessageItem] instances and extracts
  /// the wrapped [ConversationMessage].
  List<ConversationMessage> get messages => _chatItems
      .whereType<ChatMessageItem>()
      .map((item) => item.message)
      .toList();

  /// All raw WebSocket events received, for debug display.
  List<WebSocketEvent> get rawEvents => List.unmodifiable(_rawEvents);

  /// Whether a message send is currently in progress.
  bool get isSending => _isSending;

  /// Whether the state is awaiting the first WS response after a send.
  ///
  /// True after [sendMessage] completes the HTTP POST and false after the
  /// first `.conversation.message` WS event arrives from the agent. Used
  /// to keep the typing bubble visible in the gap between POST and WS.
  bool get awaitingResponse => _awaitingResponse;

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
  // Test helpers
  // ---------------------------------------------------------------------------

  /// Directly set [_awaitingResponse] — for widget tests only.
  ///
  /// Allows tests to simulate the POST→WS gap without wiring up HTTP.
  @visibleForTesting
  void setAwaitingResponseForTest({required bool value}) {
    _awaitingResponse = value;
    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // createConversation
  // ---------------------------------------------------------------------------

  /// Create a new conversation for the given team and project.
  ///
  /// POSTs to the conversations endpoint with the provided [agentRoleId].
  /// An optional [title] may be supplied (defaults to the agent role name on
  /// the caller side). Stores the created conversation and subscribes to the
  /// WebSocket channel for live events.
  Future<void> createConversation(
    String teamId,
    String projectId, {
    required String agentRoleId,
    String? title,
  }) async {
    _error = null;
    _teamId = teamId;
    _projectId = projectId;

    // -- Create conversation --
    final response = await _http.post(
      '/teams/$teamId/projects/$projectId/conversations',
      data: {'agent_role_id': agentRoleId, 'title': ?title},
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
    _awaitingResponse = true;
    refreshUI();

    // Optimistic append.
    final optimisticMessage = ConversationMessage(
      id: 'optimistic_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: _conversation!.id,
      role: 'user',
      content: text,
      createdAt: DateTime.now().toUtc(),
    );
    _chatItems = [
      ..._chatItems,
      ChatMessageItem.fromConversationMessage(optimisticMessage),
    ];
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
      _chatItems = items
          .map(
            (item) => ChatMessageItem.fromConversationMessage(
              ConversationMessage.fromMap(item as Map<String, dynamic>),
            ),
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
  /// Unsubscribe from all WS channels without clearing conversation data.
  ///
  /// Used during `dispose()` so the singleton state survives widget rebuilds
  /// (e.g. browser refresh). A full [reset] is only called when navigating
  /// to a *different* conversation.
  void unsubscribeChannels() {
    if (_subscribedChannel != null) {
      _ws?.unsubscribe(_subscribedChannel!);
      _subscribedChannel = null;
    }

    if (_subscribedSessionChannel != null) {
      _ws?.unsubscribe(_subscribedSessionChannel!);
      _subscribedSessionChannel = null;
    }
  }

  /// Re-subscribe to WS channels for the current conversation.
  ///
  /// Called after a browser refresh when the singleton still holds conversation
  /// data but the old widget's `dispose()` cleared the WS subscriptions.
  void resubscribe() {
    if (_conversation == null) return;

    final channel = 'private-conversation.${_conversation!.id}';
    _subscribedChannel = channel;
    _ws?.subscribe(channel, addEvent);

    if (_sessionId != null) {
      final sessionChannel = 'private-session.$_sessionId';
      _subscribedSessionChannel = sessionChannel;
      _ws?.subscribe(sessionChannel, _handleSessionEvent);
    }
  }

  void reset() {
    unsubscribeChannels();

    _conversation = null;
    _chatItems = [];
    _activeSubagents = {};
    _rawEvents = [];
    _isSending = false;
    _awaitingResponse = false;
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
  // fetchAgentRoles
  // ---------------------------------------------------------------------------

  /// Fetch the available agent roles for the given [teamId].
  ///
  /// Returns the parsed list directly — the caller owns the list (e.g. for
  /// modal display). No internal state is stored.
  Future<List<AgentRole>> fetchAgentRoles(String teamId) async {
    final response = await _http.get('/teams/$teamId/agent-roles');

    if (!response.successful) {
      return [];
    }

    final List<dynamic> items =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;

    return items
        .map((item) => AgentRole.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Handle `.conversation.message` — route by event type.
  ///
  /// Detects `tool_use` (AskUserQuestion options), `question` (answerable),
  /// and `permission` events. All other recognized types are appended as
  /// typed [ChatItem] subclasses to [_chatItems].
  void _handleMessageEvent(WebSocketEvent wsEvent) {
    final eventType = wsEvent.data['type'] as String?;

    // Clear awaitingResponse only on terminal or visible-content events —
    // keeps the loading indicator visible while the agent is still
    // processing behind the scenes (system, tool_use, tool_result).
    const terminalTypes = {
      'result',
      'error',
      'text',
      'assistant',
      'question',
      'permission',
    };
    if (terminalTypes.contains(eventType)) {
      _awaitingResponse = false;
    }
    final content = wsEvent.data['content'] as String?;
    final metadata = wsEvent.data['metadata'] as Map<String, dynamic>?;
    final metaData = metadata?['data'] as Map<String, dynamic>?;
    final occurredAt = wsEvent.data['occurred_at'] != null
        ? DateTime.parse(wsEvent.data['occurred_at'] as String)
        : DateTime.now().toUtc();

    switch (eventType) {
      // -- AskUserQuestion tool_use: store options for later question correlation --
      case 'tool_use':
        final toolName = metaData?['toolName'] as String?;
        if (toolName == 'AskUserQuestion') {
          final input = metaData?['input'] as Map<String, dynamic>?;
          final questions = input?['questions'] as List<dynamic>?;
          if (questions != null && questions.isNotEmpty) {
            final first = questions.first as Map<String, dynamic>;
            _pendingOptions = (first['options'] as List<dynamic>?)
                ?.map((o) => Map<String, dynamic>.from(o as Map))
                .toList();
          }
          return;
        }
        // Non-AskUserQuestion tool_use → append to active subagent or top-level
        final toolItem = ChatToolUseItem(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: occurredAt,
          toolName: toolName ?? 'Unknown',
          input: metaData?['input'],
          toolUseId: metaData?['toolUseId'] as String?,
        );
        _appendItemOrNest(toolItem);

      case 'tool_result':
        final toolUseId = metaData?['toolUseId'] as String?;
        if (toolUseId != null) {
          _correlateToolResult(
            toolUseId,
            content ?? metaData?['content'] as String?,
          );
        }

      case 'thinking':
        final thinkingItem = ChatThinkingItem(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: occurredAt,
          content: content,
        );
        _appendItemOrNest(thinkingItem);

      case 'subagent_start':
        final subagentId = metaData?['agentId'] as String? ?? '';
        final index = _chatItems.length;
        _chatItems = [
          ..._chatItems,
          ChatSubagentItem(
            id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            subagentId: subagentId,
            description: metaData?['agentType'] as String?,
            isComplete: false,
          ),
        ];
        _activeSubagents[subagentId] = index;

      case 'subagent_stop':
        // Try inner data.agentId first, fallback to top-level subagent_id
        // (truncation may strip metadata.data but keeps top-level fields).
        final subagentId =
            metaData?['agentId'] as String? ??
            metadata?['subagent_id'] as String? ??
            '';
        final index = _activeSubagents.remove(subagentId);
        if (index != null && index < _chatItems.length) {
          final existing = _chatItems[index];
          if (existing is ChatSubagentItem) {
            final updated = ChatSubagentItem(
              id: existing.id,
              occurredAt: existing.occurredAt,
              subagentId: existing.subagentId,
              description: existing.description,
              isComplete: true,
              durationMs: metaData?['durationMs'] as int?,
              children: existing.children,
            );
            _chatItems = List.of(_chatItems)..[index] = updated;
          }
        }

      case 'file_change':
        final fileItem = ChatFileChangeItem(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: occurredAt,
          operation: _inferFileOperation(metaData?['toolName'] as String?),
          filePath: (metaData?['filePath'] as String?) ?? '',
        );
        _appendItemOrNest(fileItem);

      case 'error':
        _chatItems = [
          ..._chatItems,
          ChatErrorItem(
            id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            errorText: content ?? '',
          ),
        ];

      case 'result':
        // Close any still-running subagents — the session is done.
        _closeAllActiveSubagents();
        _chatItems = [
          ..._chatItems,
          ChatResultItem(
            id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            isError: metaData?['isError'] == true,
            content: content,
          ),
        ];

      case 'question':
        if (metaData != null) {
          _pendingQuestion = {
            'questionId': metaData['questionId'] as String?,
            'message': metaData['message'] as String?,
            'options': _pendingOptions,
          };
          _pendingOptions = null;
        }
        return;

      case 'permission':
        if (metaData != null) {
          _pendingPermission = {
            'questionId': metaData['questionId'] as String?,
            'toolName': metaData['toolName'] as String?,
            'input': metaData['input'],
          };
        }
        return;

      case 'text' || 'assistant':
        if (content == null) return;
        _chatItems = [
          ..._chatItems,
          ChatMessageItem.fromConversationMessage(
            ConversationMessage(
              id: 'ws_${DateTime.now().microsecondsSinceEpoch}_${_chatItems.length}',
              conversationId:
                  wsEvent.data['conversation_id'] as String? ??
                  _conversation?.id ??
                  '',
              role: 'assistant',
              content: content,
              metadata: metadata,
              createdAt: occurredAt,
            ),
          ),
        ];

      default:
        // Unknown types silently ignored (already in _rawEvents).
        break;
    }
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

  /// Mark all active subagents as complete.
  ///
  /// Called when a `result` event arrives — the session is done, so any
  /// subagent still tracked as active must have missed its `subagent_stop`.
  void _closeAllActiveSubagents() {
    if (_activeSubagents.isEmpty) return;

    final updated = List<ChatItem>.of(_chatItems);
    for (final index in _activeSubagents.values) {
      if (index < updated.length && updated[index] is ChatSubagentItem) {
        final existing = updated[index] as ChatSubagentItem;
        if (!existing.isComplete) {
          updated[index] = ChatSubagentItem(
            id: existing.id,
            occurredAt: existing.occurredAt,
            subagentId: existing.subagentId,
            description: existing.description,
            isComplete: true,
            children: existing.children,
          );
        }
      }
    }
    _activeSubagents.clear();
    _chatItems = updated;
  }

  /// Append a [ChatItem] to the most-recently-started active subagent's
  /// children, or to the top-level [_chatItems] if no subagent is running.
  void _appendItemOrNest(ChatItem item) {
    if (_activeSubagents.isEmpty) {
      _chatItems = [..._chatItems, item];
      return;
    }

    // Find the most-recently-started subagent (highest index).
    final subagentIndex = _activeSubagents.values.reduce(
      (a, b) => a > b ? a : b,
    );
    if (subagentIndex < _chatItems.length &&
        _chatItems[subagentIndex] is ChatSubagentItem) {
      final existing = _chatItems[subagentIndex] as ChatSubagentItem;
      final updated = ChatSubagentItem(
        id: existing.id,
        occurredAt: existing.occurredAt,
        subagentId: existing.subagentId,
        description: existing.description,
        isComplete: existing.isComplete,
        durationMs: existing.durationMs,
        children: [...existing.children, item],
      );
      _chatItems = List.of(_chatItems)..[subagentIndex] = updated;
    } else {
      _chatItems = [..._chatItems, item];
    }
  }

  /// Correlate a `tool_result` event with its parent `tool_use` item.
  ///
  /// Searches both top-level [_chatItems] and active subagent children
  /// for the matching [toolUseId].
  void _correlateToolResult(String toolUseId, String? resultContent) {
    // First check top-level items.
    final topIndex = _chatItems.lastIndexWhere(
      (item) => item is ChatToolUseItem && item.toolUseId == toolUseId,
    );
    if (topIndex != -1) {
      final existing = _chatItems[topIndex] as ChatToolUseItem;
      final updated = ChatToolUseItem(
        id: existing.id,
        occurredAt: existing.occurredAt,
        toolName: existing.toolName,
        input: existing.input,
        toolUseId: existing.toolUseId,
        result: resultContent,
      );
      _chatItems = List.of(_chatItems)..[topIndex] = updated;
      return;
    }

    // Check inside active subagent children.
    for (final entry in _activeSubagents.entries) {
      final subIndex = entry.value;
      if (subIndex >= _chatItems.length) continue;
      final subItem = _chatItems[subIndex];
      if (subItem is! ChatSubagentItem) continue;

      final childIndex = subItem.children.lastIndexWhere(
        (item) => item is ChatToolUseItem && item.toolUseId == toolUseId,
      );
      if (childIndex == -1) continue;

      final existing = subItem.children[childIndex] as ChatToolUseItem;
      final updatedChild = ChatToolUseItem(
        id: existing.id,
        occurredAt: existing.occurredAt,
        toolName: existing.toolName,
        input: existing.input,
        toolUseId: existing.toolUseId,
        result: resultContent,
      );
      final updatedChildren = List<ChatItem>.of(subItem.children)
        ..[childIndex] = updatedChild;
      final updatedSub = ChatSubagentItem(
        id: subItem.id,
        occurredAt: subItem.occurredAt,
        subagentId: subItem.subagentId,
        description: subItem.description,
        isComplete: subItem.isComplete,
        durationMs: subItem.durationMs,
        children: updatedChildren,
      );
      _chatItems = List.of(_chatItems)..[subIndex] = updatedSub;
      return;
    }
  }

  /// Infer file operation type from the sidecar tool name.
  ///
  /// The bridge emits `toolName` (e.g. `'Write'`, `'Edit'`) but no explicit
  /// operation code. Maps known tool names to Git-style single-letter codes.
  String _inferFileOperation(String? toolName) {
    return switch (toolName) {
      'Write' => 'A',
      'Edit' => 'M',
      'MultiEdit' => 'M',
      _ => 'M',
    };
  }
}
