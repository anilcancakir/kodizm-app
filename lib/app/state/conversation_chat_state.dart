import 'dart:async';

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

  /// Stream that emits after each successful WS reconnection.
  Stream<void> get onReconnect;
}

// ---------------------------------------------------------------------------
// ConversationChatState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the conversation chat lifecycle.
///
/// Orchestrates creating a conversation, sending messages, receiving
/// WebSocket events, tracking metadata, and accumulating raw events.
/// All mutations call [refreshUI] to notify listeners.
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

  /// Tracks which subagent is currently emitting events. Updated on
  /// `subagent_start` and `subagent_progress` so that interleaved events
  /// from parallel subagents are nested under the correct parent.
  String? _currentSubagentId;

  /// Maps Agent tool_use_id → agent name (subagent_type or name) for badge
  /// display. Populated when tool_use events with toolName == 'Agent' arrive.
  final Map<String, String> _agentToolNames = {};
  List<WebSocketEvent> _rawEvents = [];
  bool _isSending = false;
  Future<void>? _activeSendFuture;
  bool _awaitingResponse = false;
  bool _isStopping = false;
  final Set<String> _queuedMessageIds = {};

  /// Stream event IDs already seen (from API pending_events or WS broadcasts).
  /// Used to deduplicate events on WS reconnect catch-up.
  final Set<String> _seenEventIds = {};
  String? _error;
  String? _warmUntil;
  String _teamId = '';
  String _projectId = '';
  String? _subscribedChannel;

  // View attachment tracking — used by deferred dispose cleanup.
  // Counter (not bool) because dispose(old) fires AFTER initState(new)
  // on route changes — both can be alive simultaneously for one frame.
  int _activeViewCount = 0;

  /// Subscription to [ConversationChatWebSocket.onReconnect].
  StreamSubscription<void>? _reconnectSubscription;

  // Session state
  String? _sessionId;
  String? _subscribedSessionChannel;
  String? _runningCostUsd;
  String? _sessionPhase;

  // Streaming text accumulator — builds up from text_delta events
  StringBuffer _streamingTextBuffer = StringBuffer();
  String? _streamingMessageId;

  // Streaming thinking accumulator — builds up from thinking_delta events
  StringBuffer _streamingThinkingBuffer = StringBuffer();
  String? _streamingThinkingId;

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

  /// Whether the agent session is actively executing — drives the stop button.
  ///
  /// Distinct from [awaitingResponse] which only tracks the gap between
  /// HTTP POST and first WS event (typing bubble). This stays true for the
  /// entire agent turn until a terminal event (`result`/`error`) arrives or
  /// the session phase leaves `executing`.
  bool get isAgentRunning =>
      _conversation?.isExecuting == true || _sessionPhase == 'executing';

  /// Whether a stop request is currently in progress.
  bool get isStopping => _isStopping;

  /// The number of messages currently queued for delivery.
  int get queuedCount => _queuedMessageIds.length;

  /// The set of message IDs currently in the queue.
  Set<String> get queuedMessageIds => Set.unmodifiable(_queuedMessageIds);

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

    // If the conversation has an actively executing session, show the stop
    // button immediately — handles page refresh / re-open while agent runs.
    if (_conversation!.isExecuting) {
      _awaitingResponse = true;
    }

    // Restore pending question from API — survives page refresh.
    final pendingQ = data['pending_question'] as Map<String, dynamic>?;
    if (pendingQ != null) {
      _pendingQuestion = {
        'questionId': pendingQ['questionId'] as String?,
        'message': pendingQ['message'] as String?,
        'options': (pendingQ['options'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>(),
      };
    }

    // -- Recover mid-turn events from pending_events --
    final pendingEvents = data['pending_events'] as List<dynamic>?;
    if (pendingEvents != null && pendingEvents.isNotEmpty) {
      final recovered = _parsePendingEvents(pendingEvents);
      if (recovered.isNotEmpty) {
        _chatItems = [..._chatItems, ...recovered];
      }
    }

    // -- Subscribe to conversation WS channel --
    final channel = 'private-conversation.${_conversation!.id}';
    _subscribedChannel = channel;
    _ws?.subscribe(channel, addEvent);

    // -- Listen for WS reconnects to catch up on missed events --
    _reconnectSubscription?.cancel();
    _reconnectSubscription = _ws?.onReconnect.listen((_) {
      _catchUpAfterReconnect();
    });

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // WS reconnect catch-up
  // ---------------------------------------------------------------------------

  /// Re-fetch conversation state after a WS reconnect to recover missed events.
  ///
  /// Uses [_seenEventIds] to deduplicate — events already in the timeline
  /// are silently skipped.
  Future<void> _catchUpAfterReconnect() async {
    if (_conversation == null) return;

    final response = await _http.get(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}',
    );

    if (!response.successful) return;

    final Map<String, dynamic> data =
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

    // Update conversation state (status, cost, etc.).
    _conversation = Conversation.fromMap(data);

    // Recover any new pending events — dedup handled by _parsePendingEvents.
    final pendingEvents = data['pending_events'] as List<dynamic>?;
    if (pendingEvents != null && pendingEvents.isNotEmpty) {
      final recovered = _parsePendingEvents(pendingEvents);
      if (recovered.isNotEmpty) {
        _chatItems = [..._chatItems, ...recovered];
      }
    }

    // Restore pending question if conversation is paused.
    final pendingQ = data['pending_question'] as Map<String, dynamic>?;
    if (pendingQ != null && _pendingQuestion == null) {
      _pendingQuestion = {
        'questionId': pendingQ['questionId'] as String?,
        'message': pendingQ['message'] as String?,
        'options': (pendingQ['options'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>(),
      };
    }

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
    if (_conversation == null) return;
    if (_pendingQuestion != null || _pendingPermission != null) return;

    // Await any in-flight POST before starting a new one.
    if (_activeSendFuture != null) {
      await _activeSendFuture;
    }

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

    _activeSendFuture = _postMessage(text, optimisticMessage);
    await _activeSendFuture;
    _activeSendFuture = null;

    _isSending = false;
    refreshUI();
  }

  /// Sends the POST request for a message and handles the response.
  Future<void> _postMessage(
    String text,
    ConversationMessage optimisticMessage,
  ) async {
    final response = await _http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/messages',
      data: {'content': text},
    );

    if (!response.successful) {
      _error = response.errorMessage ?? 'Failed to send message';
    } else {
      // Replace optimistic message with real data from response.
      final responseData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>?;
      if (responseData != null && responseData.containsKey('id')) {
        final realMessage = ConversationMessage.fromMap(responseData);
        final optimisticIndex = _chatItems.indexWhere(
          (item) => item.id == optimisticMessage.id,
        );
        if (optimisticIndex >= 0) {
          _chatItems = List.of(_chatItems)
            ..[optimisticIndex] = ChatMessageItem.fromConversationMessage(
              realMessage,
            );
        }

        // Track queued messages.
        final status = responseData['status'] as String?;
        if (status == 'queued') {
          _queuedMessageIds.add(realMessage.id);
        }
      }
    }
  }

  /// Stop the currently running message.
  ///
  /// Sends a POST to the stop endpoint, which aborts the running agent and
  /// creates a system interrupt message. The conversation remains Active.
  Future<void> stopMessage() async {
    if (_conversation == null || _isStopping) return;
    if (!isAgentRunning && !_awaitingResponse) return;

    _isStopping = true;
    refreshUI();

    try {
      await _http.post(
        '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/stop',
      );
    } finally {
      _awaitingResponse = false;
      _isStopping = false;
      refreshUI();
    }
  }

  /// Cancel a queued message by ID.
  ///
  /// Optimistically removes from [_queuedMessageIds] and updates the
  /// message status to `'cancelled'` in the timeline, then POSTs to the
  /// cancel endpoint.
  Future<void> cancelQueuedMessage(String messageId) async {
    if (_conversation == null) return;

    // Optimistic update.
    _queuedMessageIds.remove(messageId);
    _chatItems = _chatItems.map((item) {
      if (item is ChatMessageItem && item.message.id == messageId) {
        return ChatMessageItem.fromConversationMessage(
          item.message.copyWith(status: 'cancelled'),
        );
      }
      return item;
    }).toList();
    refreshUI();

    await _http.post(
      '/teams/$_teamId/projects/$_projectId/conversations/${_conversation!.id}/messages/$messageId/cancel',
    );
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
      case '.conversation.title':
        _handleTitleEvent(wsEvent);
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
      final List<ChatItem> loaded = [];

      for (final item in items) {
        final message = ConversationMessage.fromMap(
          item as Map<String, dynamic>,
        );

        // Insert stream events before the assistant message.
        // Tracks active subagents to nest child tool_use events.
        if (message.role == 'assistant' && message.streamEvents != null) {
          // subagentId → index in [loaded]; tracks running subagents.
          final activeSubagents = <String, int>{};
          // Last subagent_progress task_id — determines nesting target.
          String? currentSubagentId;

          for (final evt in message.streamEvents!) {
            final e = evt as Map<String, dynamic>;
            final evtType = e['type'] as String?;
            final evtContent = e['content'] as String?;
            final evtMeta = e['metadata'] as Map<String, dynamic>?;
            final evtOccurred = e['occurred_at'] != null
                ? DateTime.parse(e['occurred_at'] as String)
                : message.createdAt;
            final evtId = 'se_${loaded.length}_${message.id}';

            switch (evtType) {
              case 'tool_use':
                final toolUseIdVal = evtMeta?['toolUseId'] as String?;
                final toolNameVal =
                    evtMeta?['toolName'] as String? ?? 'Unknown';
                // Cache agent name for subagent badge resolution.
                if (toolNameVal == 'Agent' && toolUseIdVal != null) {
                  final inp = evtMeta?['input'] as Map<String, dynamic>?;
                  final aName =
                      inp?['subagent_type'] as String? ??
                      inp?['name'] as String?;
                  if (aName != null) {
                    _agentToolNames[toolUseIdVal] = aName;
                  }
                }
                final toolItem = ChatToolUseItem(
                  id: evtId,
                  occurredAt: evtOccurred,
                  toolName: toolNameVal,
                  input: evtMeta?['input'],
                  toolUseId: toolUseIdVal,
                );
                // Nest under active subagent (Agent calls stay top-level).
                final nestTarget =
                    (toolNameVal != 'Agent' && currentSubagentId != null)
                    ? activeSubagents[currentSubagentId]
                    : null;
                if (nestTarget != null &&
                    nestTarget < loaded.length &&
                    loaded[nestTarget] is ChatSubagentItem) {
                  final sub = loaded[nestTarget] as ChatSubagentItem;
                  loaded[nestTarget] = ChatSubagentItem(
                    id: sub.id,
                    occurredAt: sub.occurredAt,
                    subagentId: sub.subagentId,
                    agentName: sub.agentName,
                    parentToolUseId: sub.parentToolUseId,
                    description: sub.description,
                    isComplete: sub.isComplete,
                    durationMs: sub.durationMs,
                    children: [...sub.children, toolItem],
                  );
                } else {
                  loaded.add(toolItem);
                }
              case 'tool_result':
                final toolUseId = evtMeta?['toolUseId'] as String?;
                if (toolUseId != null) {
                  _correlatePersistedToolResult(
                    loaded,
                    toolUseId,
                    evtContent ?? evtMeta?['content'] as String?,
                  );
                }
              case 'thinking':
                loaded.add(
                  ChatThinkingItem(
                    id: evtId,
                    occurredAt: evtOccurred,
                    content: evtContent,
                  ),
                );
              case 'error':
                loaded.add(
                  ChatErrorItem(
                    id: evtId,
                    occurredAt: evtOccurred,
                    errorText: evtContent ?? '',
                  ),
                );
              case 'subagent_start':
                final subagentId =
                    evtMeta?['agentId'] as String? ??
                    evtMeta?['task_id'] as String? ??
                    '';
                final toolUseId = evtMeta?['tool_use_id'] as String?;
                final idx = loaded.length;
                loaded.add(
                  ChatSubagentItem(
                    id: evtId,
                    occurredAt: evtOccurred,
                    subagentId: subagentId,
                    agentName: _resolveAgentName(toolUseId),
                    parentToolUseId: toolUseId,
                    description:
                        evtContent ??
                        evtMeta?['description'] as String? ??
                        evtMeta?['agentType'] as String?,
                    isComplete: false,
                  ),
                );
                activeSubagents[subagentId] = idx;
                currentSubagentId = subagentId;
              case 'subagent_progress':
                // Track which subagent is currently active for nesting.
                currentSubagentId =
                    evtMeta?['task_id'] as String? ??
                    evtMeta?['agentId'] as String?;
              case 'subagent_stop':
                final subagentId =
                    evtMeta?['agentId'] as String? ??
                    evtMeta?['task_id'] as String? ??
                    evtMeta?['subagent_id'] as String? ??
                    '';
                final idx = activeSubagents.remove(subagentId);
                if (currentSubagentId == subagentId) {
                  // Switch to another active subagent if any.
                  currentSubagentId = activeSubagents.isNotEmpty
                      ? activeSubagents.keys.last
                      : null;
                }
                if (idx != null &&
                    idx < loaded.length &&
                    loaded[idx] is ChatSubagentItem) {
                  final existing = loaded[idx] as ChatSubagentItem;
                  loaded[idx] = ChatSubagentItem(
                    id: existing.id,
                    occurredAt: existing.occurredAt,
                    subagentId: existing.subagentId,
                    agentName: existing.agentName,
                    parentToolUseId: existing.parentToolUseId,
                    description: existing.description,
                    isComplete: true,
                    durationMs: _extractDurationMs(evtMeta),
                    children: existing.children,
                  );
                }
            }
          }
        }

        // System messages get their own visual treatment (centered pill).
        if (message.role == 'system') {
          loaded.add(
            ChatSystemItem(
              id: message.id,
              occurredAt: message.createdAt,
              content: _localizeSystemMessage(message.content),
            ),
          );
        } else {
          loaded.add(ChatMessageItem.fromConversationMessage(message));
        }
      }

      _chatItems = loaded;
    }

    refreshUI();
  }

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------

  /// Mark that a [ConversationChatView] is actively mounted.
  ///
  /// Called in `initState()`. Paired with [detachView] in `dispose()`.
  void attachView() => _activeViewCount++;

  /// Mark that a [ConversationChatView] was disposed.
  ///
  /// Called in `dispose()`. The view schedules a post-frame callback that
  /// checks [hasActiveView] — if no views remain by the next frame,
  /// the user navigated away from conversations entirely and stale WS
  /// subscriptions are cleaned up.
  void detachView() => _activeViewCount = (_activeViewCount - 1).clamp(0, 99);

  /// Whether at least one [ConversationChatView] is currently mounted.
  bool get hasActiveView => _activeViewCount > 0;

  /// Unsubscribe from all WS channels without clearing conversation data.
  ///
  /// Used during deferred dispose cleanup so the singleton state survives
  /// widget rebuilds (e.g. browser refresh). A full [reset] is only called
  /// when navigating to a *different* conversation.
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
    _reconnectSubscription?.cancel();
    _reconnectSubscription = null;

    _conversation = null;
    _chatItems = [];
    _activeSubagents = {};
    _currentSubagentId = null;
    _agentToolNames.clear();
    _rawEvents = [];
    _isSending = false;
    _activeSendFuture = null;
    _awaitingResponse = false;
    _queuedMessageIds.clear();
    _seenEventIds.clear();
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
    _streamingTextBuffer = StringBuffer();
    _streamingMessageId = null;
    _streamingThinkingBuffer = StringBuffer();
    _streamingThinkingId = null;

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
    final metadata = wsEvent.data['metadata'] as Map<String, dynamic>?;

    // Dedup: skip events already seen (from API pending_events or prior WS).
    final streamEventId = metadata?['stream_event_id'] as String?;
    if (streamEventId != null && !_seenEventIds.add(streamEventId)) {
      return;
    }

    // Clear awaitingResponse on visible-content or terminal events — hides
    // the typing bubble once the agent starts producing output.
    const terminalTypes = {
      'result',
      'error',
      'text',
      'text_delta',
      'assistant',
      'question',
      'permission',
    };
    if (terminalTypes.contains(eventType)) {
      _awaitingResponse = false;
    }
    final content = wsEvent.data['content'] as String?;
    final occurredAt = wsEvent.data['occurred_at'] != null
        ? DateTime.parse(wsEvent.data['occurred_at'] as String)
        : DateTime.now().toUtc();

    // -- message_status: update queued/delivering status on existing messages --
    if (eventType == 'message_status') {
      final messageId = metadata?['message_id'] as String?;
      final messageStatus = metadata?['message_status'] as String?;
      if (messageId != null && messageStatus != null) {
        _chatItems = _chatItems.map((item) {
          if (item is ChatMessageItem && item.message.id == messageId) {
            return ChatMessageItem.fromConversationMessage(
              item.message.copyWith(status: messageStatus),
            );
          }
          return item;
        }).toList();

        // Remove from queued tracking if no longer queued.
        if (messageStatus != 'queued') {
          _queuedMessageIds.remove(messageId);
        }

        refreshUI();
      }
      return;
    }

    switch (eventType) {
      // -- text_delta: accumulate streaming text for real-time typing --
      case 'text_delta':
        if (content != null) {
          _streamingTextBuffer.write(content);
          final bufferedText = _streamingTextBuffer.toString();
          _streamingMessageId ??=
              'streaming_${DateTime.now().microsecondsSinceEpoch}';

          final streamingMessage = ChatMessageItem.fromConversationMessage(
            ConversationMessage(
              id: _streamingMessageId!,
              conversationId:
                  wsEvent.data['conversation_id'] as String? ??
                  _conversation?.id ??
                  '',
              role: 'assistant',
              content: bufferedText,
              createdAt: occurredAt,
            ),
          );

          // Replace existing streaming item or append new one
          final existingIndex = _chatItems.indexWhere(
            (item) => item.id == _streamingMessageId,
          );
          if (existingIndex >= 0) {
            _chatItems = List.of(_chatItems)
              ..[existingIndex] = streamingMessage;
          } else {
            _chatItems = [..._chatItems, streamingMessage];
          }
        }
        return; // refreshUI called by addEvent

      // -- AskUserQuestion tool_use: store options for later question correlation --
      case 'tool_use':
        final toolName = metadata?['toolName'] as String?;
        if (toolName == 'AskUserQuestion') {
          final input = metadata?['input'] as Map<String, dynamic>?;
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
        final incomingToolUseId = metadata?['toolUseId'] as String?;
        // Cache agent name for subagent badge resolution — run BEFORE dedup
        // because streaming content_block_start has empty input, but the full
        // assistant event carries the real input with subagent_type.
        if (toolName == 'Agent' && incomingToolUseId != null) {
          final input = metadata?['input'] as Map<String, dynamic>?;
          final agentName =
              input?['subagent_type'] as String? ?? input?['name'] as String?;
          if (agentName != null &&
              !_agentToolNames.containsKey(incomingToolUseId)) {
            _agentToolNames[incomingToolUseId] = agentName;
            // Retroactively patch any ChatSubagentItem already created
            // before this full event arrived (subagent_start fires before
            // the full assistant event with real input).
            _patchSubagentName(incomingToolUseId, agentName);
          }
        }
        // Deduplicate: streaming content_block_start sends tool_use early,
        // then the full assistant event sends it again. Skip if already seen.
        if (incomingToolUseId != null) {
          final alreadyExists = _chatItems.any(
            (item) =>
                item is ChatToolUseItem && item.toolUseId == incomingToolUseId,
          );
          if (alreadyExists) return;
        }
        final toolItem = ChatToolUseItem(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: occurredAt,
          toolName: toolName ?? 'Unknown',
          input: metadata?['input'],
          toolUseId: incomingToolUseId,
        );
        // Agent tool_use is always from the orchestrator, not a subagent
        // (subagents have Agent in disallowedTools). Force top-level so
        // parallel spawns don't get incorrectly nested under a running
        // sibling subagent.
        if (toolName == 'Agent') {
          _chatItems = [..._chatItems, toolItem];
        } else {
          _appendItemOrNest(toolItem);
        }

      case 'tool_result':
        final toolUseId = metadata?['toolUseId'] as String?;
        if (toolUseId != null) {
          _correlateToolResult(
            toolUseId,
            content ?? metadata?['content'] as String?,
          );
        }

      case 'thinking':
        // Streaming content_block_start sends thinking with null content,
        // then the full assistant event sends it with complete content.
        // If there's already a streaming thinking item, replace it with the full one.
        if (content != null &&
            content.isNotEmpty &&
            _streamingThinkingId != null) {
          final idx = _chatItems.indexWhere(
            (i) => i.id == _streamingThinkingId,
          );
          if (idx >= 0) {
            _chatItems = List.of(_chatItems)
              ..[idx] = ChatThinkingItem(
                id: _streamingThinkingId!,
                occurredAt: occurredAt,
                content: content,
              );
            _streamingThinkingId = null;
            _streamingThinkingBuffer = StringBuffer();
            return;
          }
        }
        _streamingThinkingId ??=
            'thinking_${DateTime.now().microsecondsSinceEpoch}';
        final thinkingItem = ChatThinkingItem(
          id: _streamingThinkingId!,
          occurredAt: occurredAt,
          content: content,
        );
        _appendItemOrNest(thinkingItem);

      case 'thinking_delta':
        if (content != null) {
          _streamingThinkingBuffer.write(content);
          if (_streamingThinkingId != null) {
            final idx = _chatItems.indexWhere(
              (i) => i.id == _streamingThinkingId,
            );
            if (idx >= 0) {
              _chatItems = List.of(_chatItems)
                ..[idx] = ChatThinkingItem(
                  id: _streamingThinkingId!,
                  occurredAt: occurredAt,
                  content: _streamingThinkingBuffer.toString(),
                );
            }
          }
        }
        return;

      case 'subagent_start':
        final subagentId =
            metadata?['agentId'] as String? ??
            metadata?['task_id'] as String? ??
            '';
        final toolUseId = metadata?['tool_use_id'] as String?;
        final agentName = _resolveAgentName(toolUseId);
        final index = _chatItems.length;
        _chatItems = [
          ..._chatItems,
          ChatSubagentItem(
            id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            subagentId: subagentId,
            agentName: agentName,
            parentToolUseId: toolUseId,
            description:
                metadata?['description'] as String? ??
                metadata?['agentType'] as String?,
            isComplete: false,
          ),
        ];
        _activeSubagents[subagentId] = index;
        _currentSubagentId = subagentId;

      case 'subagent_progress':
        // Track which subagent is currently emitting so interleaved events
        // from parallel subagents nest under the correct parent.
        _currentSubagentId =
            metadata?['task_id'] as String? ?? metadata?['agentId'] as String?;

      case 'subagent_stop':
        // Try inner data.agentId first, fallback to task_id and subagent_id
        // (truncation may strip metadata.data but keeps top-level fields).
        final subagentId =
            metadata?['agentId'] as String? ??
            metadata?['task_id'] as String? ??
            metadata?['subagent_id'] as String? ??
            '';
        final index = _activeSubagents.remove(subagentId);
        if (_currentSubagentId == subagentId) {
          // Switch to another active subagent if any remain.
          _currentSubagentId = _activeSubagents.isNotEmpty
              ? _activeSubagents.keys.last
              : null;
        }
        if (index != null && index < _chatItems.length) {
          final existing = _chatItems[index];
          if (existing is ChatSubagentItem) {
            final updated = ChatSubagentItem(
              id: existing.id,
              occurredAt: existing.occurredAt,
              subagentId: existing.subagentId,
              agentName: existing.agentName,
              parentToolUseId: existing.parentToolUseId,
              description: existing.description,
              isComplete: true,
              durationMs: _extractDurationMs(metadata),
              children: existing.children,
            );
            _chatItems = List.of(_chatItems)..[index] = updated;
          }
        }

      case 'file_change':
        final fileItem = ChatFileChangeItem(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          occurredAt: occurredAt,
          operation: _inferFileOperation(metadata?['toolName'] as String?),
          filePath: (metadata?['filePath'] as String?) ?? '',
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
        // Clear streaming state — result is the terminal event.
        _streamingTextBuffer = StringBuffer();
        _streamingMessageId = null;
        _streamingThinkingBuffer = StringBuffer();
        _streamingThinkingId = null;
        _chatItems = [
          ..._chatItems,
          ChatResultItem(
            id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            isError: metadata?['isError'] == true,
            content: content,
          ),
        ];

      case 'question':
        if (metadata != null) {
          _pendingQuestion = {
            'questionId': metadata['questionId'] as String?,
            'message': metadata['message'] as String?,
            'options': _pendingOptions,
          };
          _pendingOptions = null;
        }
        return;

      case 'permission':
        if (metadata != null) {
          _pendingPermission = {
            'questionId': metadata['questionId'] as String?,
            'toolName': metadata['toolName'] as String?,
            'input': metadata['input'],
          };
        }
        return;

      case 'text' || 'assistant':
        if (content == null) return;
        final finalMessage = ChatMessageItem.fromConversationMessage(
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
        );

        // Replace streaming message with final, or append if no streaming
        if (_streamingMessageId != null) {
          final streamIdx = _chatItems.indexWhere(
            (item) => item.id == _streamingMessageId,
          );
          if (streamIdx >= 0) {
            _chatItems = List.of(_chatItems)..[streamIdx] = finalMessage;
          } else {
            _chatItems = [..._chatItems, finalMessage];
          }
          _streamingTextBuffer = StringBuffer();
          _streamingMessageId = null;
        } else {
          _chatItems = [..._chatItems, finalMessage];
        }

      case 'system':
        if (content == null) return;
        _chatItems = [
          ..._chatItems,
          ChatSystemItem(
            id: 'ws_sys_${DateTime.now().microsecondsSinceEpoch}',
            occurredAt: occurredAt,
            content: _localizeSystemMessage(content),
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

    // Sync session phase from conversation status events — the API includes
    // `phase` so we can derive isAgentRunning without the session channel.
    final phase = wsEvent.data['phase'] as String?;
    if (phase != null) {
      _sessionPhase = phase;

      if (_conversation != null) {
        _conversation = _conversation!.copyWith(
          isExecuting: phase == 'executing',
        );
      }
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

  /// Handle `.conversation.title` — update the conversation title in real-time
  /// when the CC CLI generates an AI title.
  void _handleTitleEvent(WebSocketEvent wsEvent) {
    final title = wsEvent.data['title'] as String?;

    if (title != null && _conversation != null) {
      _conversation = _conversation!.copyWith(title: title);
    }
  }

  /// Handle events arriving on the `private-session.{sessionId}` channel.
  ///
  /// Routes `.session.cost` to update [_runningCostUsd] and
  /// `.session.status` to update [_sessionPhase].
  void _handleSessionEvent(WebSocketEvent wsEvent) {
    switch (wsEvent.eventName) {
      case '.session.cost':
        _runningCostUsd = wsEvent.data['running_total_usd'] as String?;
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
            agentName: existing.agentName,
            parentToolUseId: existing.parentToolUseId,
            description: existing.description,
            isComplete: true,
            children: existing.children,
          );
        }
      }
    }
    _activeSubagents.clear();
    _currentSubagentId = null;
    _chatItems = updated;
  }

  /// Extract duration from subagent_stop metadata.
  ///
  /// CC CLI sends duration at `usage.duration_ms`, not top-level `durationMs`.
  static int? _extractDurationMs(Map<String, dynamic>? meta) {
    if (meta == null) return null;
    final direct = meta['durationMs'] ?? meta['duration_ms'];
    if (direct != null) return (direct as num).toInt();
    final usage = meta['usage'] as Map<String, dynamic>?;
    if (usage == null) return null;
    final nested = usage['duration_ms'];
    return nested != null ? (nested as num).toInt() : null;
  }

  /// Resolve agent type name (e.g. "Explore", "librarian") from cache.
  String? _resolveAgentName(String? toolUseId) {
    if (toolUseId == null) return null;
    return _agentToolNames[toolUseId];
  }

  /// Retroactively update any [ChatSubagentItem] whose [parentToolUseId]
  /// matches [toolUseId] with the resolved [agentName]. Called when the full
  /// assistant event arrives after subagent_start already created the item.
  void _patchSubagentName(String toolUseId, String agentName) {
    final items = _chatItems;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is ChatSubagentItem &&
          item.parentToolUseId == toolUseId &&
          item.agentName == null) {
        _chatItems = List.of(items)
          ..[i] = ChatSubagentItem(
            id: item.id,
            occurredAt: item.occurredAt,
            subagentId: item.subagentId,
            agentName: agentName,
            parentToolUseId: item.parentToolUseId,
            description: item.description,
            isComplete: item.isComplete,
            durationMs: item.durationMs,
            children: item.children,
          );
        return;
      }
    }
  }

  /// Append a [ChatItem] to the currently-emitting subagent's children,
  /// or to the top-level [_chatItems] if no subagent is running.
  ///
  /// Uses [_currentSubagentId] (updated by `subagent_start` and
  /// `subagent_progress` events) to determine which subagent owns the
  /// incoming item. This correctly handles parallel subagents whose
  /// events arrive interleaved.
  void _appendItemOrNest(ChatItem item) {
    if (_activeSubagents.isEmpty) {
      _chatItems = [..._chatItems, item];
      return;
    }

    // Use the subagent that most recently emitted a progress event.
    final subagentIndex = _currentSubagentId != null
        ? _activeSubagents[_currentSubagentId]
        : null;
    if (subagentIndex != null &&
        subagentIndex < _chatItems.length &&
        _chatItems[subagentIndex] is ChatSubagentItem) {
      final existing = _chatItems[subagentIndex] as ChatSubagentItem;
      final updated = ChatSubagentItem(
        id: existing.id,
        occurredAt: existing.occurredAt,
        subagentId: existing.subagentId,
        agentName: existing.agentName,
        parentToolUseId: existing.parentToolUseId,
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
        agentName: subItem.agentName,
        parentToolUseId: subItem.parentToolUseId,
        description: subItem.description,
        isComplete: subItem.isComplete,
        durationMs: subItem.durationMs,
        children: updatedChildren,
      );
      _chatItems = List.of(_chatItems)..[subIndex] = updatedSub;
      return;
    }
  }

  /// Parse API `pending_events` (StreamEventResource format) into [ChatItem]s.
  ///
  /// Also populates [_seenEventIds] so WS events arriving after page load
  /// are deduplicated automatically.
  List<ChatItem> _parsePendingEvents(List<dynamic> events) {
    final items = <ChatItem>[];

    for (final raw in events) {
      final e = raw as Map<String, dynamic>;
      final evtId = e['id'] as String?;
      final evtType = e['type'] as String?;
      final evtContent = e['content_text'] as String?;
      final evtMeta = (e['metadata'] as Map?)?.cast<String, dynamic>();
      final evtData = (e['data'] as Map?)?.cast<String, dynamic>();
      final evtOccurred = e['occurred_at'] != null
          ? DateTime.parse(e['occurred_at'] as String)
          : DateTime.now().toUtc();
      final id = evtId ?? 'pe_${items.length}';

      // Track seen event IDs for dedup — skip already-seen events.
      if (evtId != null && !_seenEventIds.add(evtId)) {
        continue;
      }

      switch (evtType) {
        case 'thinking':
          items.add(
            ChatThinkingItem(
              id: id,
              occurredAt: evtOccurred,
              content: evtContent,
            ),
          );
        case 'tool_use':
          final meta = evtMeta ?? evtData?['metadata'] as Map<String, dynamic>?;
          items.add(
            ChatToolUseItem(
              id: id,
              occurredAt: evtOccurred,
              toolName: meta?['toolName'] as String? ?? 'Unknown',
              input: meta?['input'],
              toolUseId: meta?['toolUseId'] as String?,
            ),
          );
        case 'tool_result':
          final meta = evtMeta ?? evtData?['metadata'] as Map<String, dynamic>?;
          final toolUseId = meta?['toolUseId'] as String?;
          if (toolUseId != null) {
            _correlatePersistedToolResult(
              items,
              toolUseId,
              evtContent ?? meta?['content'] as String?,
            );
          }
        case 'error':
          items.add(
            ChatErrorItem(
              id: id,
              occurredAt: evtOccurred,
              errorText: evtContent ?? '',
            ),
          );
        case 'question':
          // Question events are handled via pending_question — skip here
          // to avoid duplicate question cards.
          break;
        case 'permission':
          // Permission events are handled via pending_question — skip here.
          break;
        case 'subagent_start':
          final meta = evtMeta ?? evtData?['metadata'] as Map<String, dynamic>?;
          final subagentId =
              meta?['agentId'] as String? ?? meta?['task_id'] as String? ?? '';
          final toolUseId = meta?['tool_use_id'] as String?;
          items.add(
            ChatSubagentItem(
              id: id,
              occurredAt: evtOccurred,
              subagentId: subagentId,
              agentName: _resolveAgentName(toolUseId),
              parentToolUseId: toolUseId,
              description:
                  evtContent ??
                  meta?['description'] as String? ??
                  meta?['agentType'] as String?,
              isComplete: false,
            ),
          );
        case 'subagent_stop':
          final meta = evtMeta ?? evtData?['metadata'] as Map<String, dynamic>?;
          final subagentId =
              meta?['agentId'] as String? ?? meta?['task_id'] as String? ?? '';
          // Mark the subagent as complete.
          final idx = items.lastIndexWhere(
            (i) => i is ChatSubagentItem && i.subagentId == subagentId,
          );
          if (idx != -1) {
            final existing = items[idx] as ChatSubagentItem;
            items[idx] = ChatSubagentItem(
              id: existing.id,
              occurredAt: existing.occurredAt,
              subagentId: existing.subagentId,
              agentName: existing.agentName,
              parentToolUseId: existing.parentToolUseId,
              description: existing.description,
              isComplete: true,
              durationMs: _extractDurationMs(meta),
              children: existing.children,
            );
          }
        case 'text':
          // Text events are accumulated into assistant messages — skip
          // unless they represent standalone content (rare in mid-turn).
          break;
        case 'result':
          // Result events are terminal — skip in pending recovery.
          break;
      }
    }

    return items;
  }

  /// Correlate a `tool_result` with its `tool_use` in a persisted [loaded] list.
  ///
  /// Searches both top-level items and subagent children for the matching
  /// [toolUseId], then patches the [ChatToolUseItem] with [resultContent].
  static void _correlatePersistedToolResult(
    List<ChatItem> loaded,
    String toolUseId,
    String? resultContent,
  ) {
    // Top-level search.
    final topIdx = loaded.lastIndexWhere(
      (i) => i is ChatToolUseItem && i.toolUseId == toolUseId,
    );
    if (topIdx != -1) {
      final existing = loaded[topIdx] as ChatToolUseItem;
      loaded[topIdx] = ChatToolUseItem(
        id: existing.id,
        occurredAt: existing.occurredAt,
        toolName: existing.toolName,
        input: existing.input,
        toolUseId: existing.toolUseId,
        result: resultContent,
      );
      return;
    }
    // Search inside subagent children.
    for (var i = loaded.length - 1; i >= 0; i--) {
      final item = loaded[i];
      if (item is! ChatSubagentItem) continue;
      final childIdx = item.children.lastIndexWhere(
        (c) => c is ChatToolUseItem && c.toolUseId == toolUseId,
      );
      if (childIdx == -1) continue;
      final existing = item.children[childIdx] as ChatToolUseItem;
      final updatedChildren = List<ChatItem>.of(item.children)
        ..[childIdx] = ChatToolUseItem(
          id: existing.id,
          occurredAt: existing.occurredAt,
          toolName: existing.toolName,
          input: existing.input,
          toolUseId: existing.toolUseId,
          result: resultContent,
        );
      loaded[i] = ChatSubagentItem(
        id: item.id,
        occurredAt: item.occurredAt,
        subagentId: item.subagentId,
        agentName: item.agentName,
        parentToolUseId: item.parentToolUseId,
        description: item.description,
        isComplete: item.isComplete,
        durationMs: item.durationMs,
        children: updatedChildren,
      );
      return;
    }
  }

  /// Infer file operation type from the CLI tool name.
  ///
  /// The CLI emits `toolName` (e.g. `'Write'`, `'Edit'`) but no explicit
  /// operation code. Maps known tool names to Git-style single-letter codes.
  String _inferFileOperation(String? toolName) {
    return switch (toolName) {
      'Write' => 'A',
      'Edit' => 'M',
      'MultiEdit' => 'M',
      _ => 'M',
    };
  }

  /// Map known backend system messages to localized display strings.
  ///
  /// The backend stores raw English text (e.g. `[Request interrupted by user]`)
  /// in the database. This maps recognized patterns to i18n keys so the UI
  /// shows the user's locale.
  static String _localizeSystemMessage(String raw) {
    if (raw.contains('interrupted by user')) {
      return trans('conversation_chat.event_interrupted');
    }

    return raw;
  }
}
