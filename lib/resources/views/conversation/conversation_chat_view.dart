import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/events/websocket_event.dart';
import '../../../app/models/agent_role.dart';
import '../../../app/models/chat_item.dart';
import '../../../app/models/conversation.dart';
import '../../../app/models/user.dart';
import '../../../app/services/websocket_service.dart';
import '../../../app/state/conversation_chat_state.dart';
import '../../widgets/organisms/agent_role_picker_modal.dart';
import '../../widgets/organisms/chat_header.dart';
import '../../widgets/organisms/chat_input_bar.dart';
import '../../widgets/organisms/chat_question_card.dart';
import '../../widgets/organisms/chat_permission_card.dart';
import '../../widgets/organisms/chat_stream_event_renderer.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// WebSocket adapter — bridges WebSocketService to ConversationChatWebSocket
// ---------------------------------------------------------------------------

/// Adapts the real [WebSocketService] to the [ConversationChatWebSocket]
/// interface expected by [ConversationChatState].
class _WebSocketAdapter implements ConversationChatWebSocket {
  _WebSocketAdapter(this._service);

  final WebSocketService _service;

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    _service.subscribe(channel, onEvent);
  }

  @override
  void unsubscribe(String channel) {
    _service.unsubscribe(channel);
  }

  @override
  Stream<void> get onReconnect => _service.onReconnect;
}

// ---------------------------------------------------------------------------
// ConversationChatView
// ---------------------------------------------------------------------------

/// Production conversation chat page — real-time chat interface showing
/// messages with styled bubbles, a header bar with metadata, and a
/// collapsible debug panel behind [_rawEventsExpanded] toggle.
///
/// ## Usage
///
/// ```dart
/// ConversationChatView(projectId: 'proj-uuid-001')
/// ```
class ConversationChatView extends StatefulWidget {
  const ConversationChatView({
    super.key,
    required this.projectId,
    this.conversationId,
  });

  final String projectId;
  final String? conversationId;

  @override
  State<ConversationChatView> createState() => _ConversationChatViewState();
}

class _ConversationChatViewState extends State<ConversationChatView> {
  late ConversationChatState _state;
  String _teamId = '';
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _autoScroll = true;
  bool _rawEventsExpanded = false;
  bool _isCreating = false;
  bool _isLoadingExisting = false;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    ConversationChatWebSocket? wsAdapter;
    try {
      final wsService = Magic.make<WebSocketService>('websocket');
      wsAdapter = _WebSocketAdapter(wsService);
    } catch (_) {
      // WS may not be connected in tests.
    }

    _state = Magic.findOrPut<ConversationChatState>(
      () => ConversationChatState(webSocket: wsAdapter),
    );
    _state.attachView();
    _teamId = Auth.user<User>()?.currentTeam?.id ?? '';

    _scrollController.addListener(_onScrollChanged);
    _maybeLoadConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _answerController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _inputFocusNode.dispose();
    // Mark view detached. A post-frame callback checks if a new
    // ConversationChatView re-attached — if not, the user navigated away
    // from conversations entirely and stale WS subscriptions are cleaned up.
    _state.detachView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_state.hasActiveView) {
        _state.unsubscribeChannels();
      }
    });
    super.dispose();
  }

  void _maybeLoadConversation() {
    // Path-param conversation ID takes priority (e.g. /chats/:conversationId).
    final conversationId = widget.conversationId;
    if (conversationId != null && conversationId.isNotEmpty) {
      // Same conversation (e.g. browser refresh) — skip refetch, just
      // re-subscribe WS channels that dispose() cleared.
      if (_state.conversation?.id == conversationId) {
        _isLoadingExisting = true;
        _state.resubscribe();
        return;
      }

      // Different conversation — full reset before loading.
      _state.reset();
      _isLoadingExisting = true;
      _state.loadConversation(_teamId, widget.projectId, conversationId);
      return;
    }

    try {
      final agentRoleId = MagicRouter.instance.queryParameter('agentRoleId');
      if (agentRoleId != null && agentRoleId.isNotEmpty) {
        _autoCreateWithAgentRole(agentRoleId);
      }
    } catch (_) {
      // Query params not available in tests.
    }
  }

  /// Auto-creates a conversation with the given [agentRoleId] — used when
  /// navigating from a task's "Chat with BA" button or conversation list.
  Future<void> _autoCreateWithAgentRole(String agentRoleId) async {
    if (_teamId.isEmpty) return;

    setState(() => _isCreating = true);
    await _state.createConversation(
      _teamId,
      widget.projectId,
      agentRoleId: agentRoleId,
    );
    _updateUrlWithConversationId();
    if (mounted) setState(() => _isCreating = false);
  }

  /// Replace the current URL with conversationId so browser refresh survives.
  void _updateUrlWithConversationId() {
    final id = _state.conversation?.id;
    if (id == null) return;

    try {
      MagicRoute.replace('/projects/${widget.projectId}/chats/$id');
    } catch (_) {
      // Router may not be available in tests.
    }
  }

  // -----------------------------------------------------------------------
  // Scroll
  // -----------------------------------------------------------------------

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;

    final atBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20;

    if (atBottom != _autoScroll) {
      setState(() => _autoScroll = atBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  Future<void> _handleStartChat() async {
    if (_teamId.isEmpty) return;

    // Fetch agent roles first, then show picker modal.
    setState(() => _isCreating = true);
    final roles = await _state.fetchAgentRoles(_teamId);
    if (!mounted) return;
    setState(() => _isCreating = false);

    final AgentRole? selected = await AgentRolePickerModal.show(context, roles);
    if (selected == null || !mounted) return;

    setState(() => _isCreating = true);
    await _state.createConversation(
      _teamId,
      widget.projectId,
      agentRoleId: selected.id,
      title: selected.name,
    );
    _updateUrlWithConversationId();
    if (mounted) setState(() => _isCreating = false);
  }

  /// Returns a truncated preview of the first user message — used as title
  /// fallback when [Conversation.title] is null.
  String? _firstUserMessagePreview() {
    for (final item in _state.chatItems) {
      if (item is ChatMessageItem && item.message.role == 'user') {
        final content = item.message.content?.trim() ?? '';
        if (content.isEmpty) continue;
        return content.length > 60 ? '${content.substring(0, 60)}...' : content;
      }
    }
    return null;
  }

  Future<void> _handleSendMessage() async {
    final text = _inputController.text.trim();
    final hasAttachments = _state.pendingAttachments.isNotEmpty;

    if (text.isEmpty && !hasAttachments) return;

    _inputController.clear();
    await _state.sendMessage(text);

    if (mounted) {
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _handleComplete() async {
    await _state.completeConversation();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // The chat view runs inside _FullscreenLayout (bare Scaffold + SafeArea)
    // so we have bounded height — Column + Expanded works naturally.
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.conversation == null) {
          if (_isLoadingExisting) {
            return WDiv(
              className: 'flex flex-col items-center justify-center w-full',
              child: const CircularProgressIndicator(),
            );
          }
          return _buildWelcome();
        }
        return _buildChat();
      },
    );
  }

  // -----------------------------------------------------------------------
  // Welcome state (no conversation yet)
  // -----------------------------------------------------------------------

  Widget _buildWelcome() {
    return WDiv(
      className: 'flex flex-col items-center justify-center w-full',
      child: WDiv(
        className: 'w-full flex flex-col items-center gap-4',
        children: [
          // Agent monogram circle
          WDiv(
            className:
                'w-12 h-12 rounded-full bg-amber-400 flex items-center justify-center',
            child: WText('A', className: 'text-lg font-bold text-white'),
          ),

          WText(
            trans('conversation_chat.welcome_title'),
            className: 'text-lg font-semibold text-slate-800',
          ),

          WText(
            trans('conversation_chat.welcome_subtitle'),
            className: 'text-sm text-slate-500',
          ),

          if (_isCreating)
            WDiv(
              className: 'flex flex-col items-center gap-3',
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                WText(
                  trans('conversation_chat.starting'),
                  className: 'text-sm text-slate-500',
                ),
              ],
            )
          else
            WAnchor(
              onTap: _handleStartChat,
              child: WDiv(
                className: 'px-6 py-3 bg-amber-400 rounded-lg',
                child: WText(
                  trans('conversation_chat.start_chat'),
                  className: 'text-sm font-semibold text-slate-900',
                ),
              ),
            ),

          if (_state.error != null)
            WText(_state.error!, className: 'text-sm text-red-500'),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Chat content (conversation exists)
  // -----------------------------------------------------------------------

  Widget _buildChat() {
    final conversation = _state.conversation!;

    if (_autoScroll && _state.chatItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return WDiv(
      className: 'flex flex-col',
      children: [
        // Header — fixed at top
        ChatHeader(
          conversation: conversation,
          sessionPhase: _state.sessionPhase,
          runningCostUsd: _state.runningCostUsd,
          firstMessagePreview: _firstUserMessagePreview(),
          debugExpanded: _rawEventsExpanded,
          onComplete: _handleComplete,
          onToggleDebug: () =>
              setState(() => _rawEventsExpanded = !_rawEventsExpanded),
        ),

        // Message area — expands to fill available space
        WDiv(className: 'flex-1', child: _buildMessageArea()),

        // Bottom sticky area — question/permission cards, input
        if (_state.pendingQuestion != null)
          ChatQuestionCard(
            question: _state.pendingQuestion!,
            isDisabled: _state.isAnswering,
            answerController: _answerController,
            onAnswer: _state.answerQuestion,
          ),

        if (_state.pendingPermission != null)
          ChatPermissionCard(
            permission: _state.pendingPermission!,
            isDisabled: _state.isAnswering,
            onAnswer: _state.answerQuestion,
          ),

        if (conversation.status != 'completed')
          ChatInputBar(
            controller: _inputController,
            focusNode: _inputFocusNode,
            isSending: _state.isSending,
            disabled:
                _state.pendingQuestion != null ||
                _state.pendingPermission != null,
            awaitingResponse: _state.isAgentRunning || _state.awaitingResponse,
            queuedCount: _state.queuedCount,
            onSend: _handleSendMessage,
            onStop: _state.stopMessage,
            onAttachmentsChanged: _state.setPendingAttachments,
          ),

        // Debug panel — scrollable within remaining space
        if (_rawEventsExpanded)
          WDiv(
            className: 'flex-1',
            child: SingleChildScrollView(child: _buildDebugPanel(conversation)),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Message area
  // -----------------------------------------------------------------------

  Widget _buildMessageArea() {
    final chatItems = _state.chatItems;
    final conversation = _state.conversation!;
    final showTyping = _state.isSending || _state.awaitingResponse;
    final totalItems = chatItems.length + (showTyping ? 1 : 0);

    if (chatItems.isEmpty && !showTyping) {
      return WDiv(
        className: 'flex flex-col items-center justify-center w-full',
        child: WDiv(
          className: 'flex flex-col items-center gap-3',
          children: [
            WDiv(
              className:
                  'w-10 h-10 rounded-full flex items-center justify-center ${_avatarBgClassName(conversation.agentRoleSlug)}',
              child: WText(
                _agentInitials(conversation.agentRoleName),
                className: 'text-sm font-semibold text-white',
              ),
            ),
            WText(
              trans('conversation_chat.no_messages'),
              className: 'text-sm text-slate-400',
            ),
          ],
        ),
      );
    }

    return WDiv(
      className: 'relative',
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            // Typing indicator at the end of the list
            if (index >= chatItems.length) {
              return _buildTypingBubble(conversation);
            }
            return ChatStreamEventRenderer(
              item: chatItems[index],
              agentRoleSlug: conversation.agentRoleSlug,
              agentRoleName: conversation.agentRoleName,
              userName: Auth.user<User>()?.name,
              onCancelMessage: _state.cancelQueuedMessage,
            );
          },
        ),

        // Scroll-to-bottom FAB
        if (!_autoScroll)
          WDiv(
            className: 'absolute bottom-4 right-4',
            child: WAnchor(
              onTap: () {
                _scrollToBottom();
                setState(() => _autoScroll = true);
              },
              child: WDiv(
                className: 'p-2 rounded-full bg-amber-400 shadow-md',
                child: WIcon(
                  Icons.keyboard_arrow_down,
                  className: 'text-lg text-slate-900',
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Typing bubble — agent "working" indicator
  // -----------------------------------------------------------------------

  Widget _buildTypingBubble(Conversation conversation) {
    return WDiv(
      className: 'flex flex-row items-start gap-2 mb-3',
      children: [
        // Agent avatar
        WDiv(
          className:
              'w-8 h-8 rounded-full flex items-center justify-center ${_avatarBgClassName(conversation.agentRoleSlug)}',
          child: WText(
            _agentInitials(conversation.agentRoleName),
            className: 'text-xs font-semibold text-white',
          ),
        ),

        // Bubble with phase-aware status text
        WDiv(
          className: '''
            px-4 py-3 rounded-2xl rounded-tl-sm
            bg-slate-100 dark:bg-slate-800
            flex flex-row items-center gap-2
          ''',
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            WText(
              _typingStatusLabel(),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
          ],
        ),
      ],
    );
  }

  /// Returns a user-friendly label based on the current session phase.
  String _typingStatusLabel() {
    final phase = _state.sessionPhase;
    return switch (phase) {
      'provisioning' => trans('conversation_chat.status_starting'),
      'executing' => trans('conversation_chat.status_working'),
      'warm' => trans('conversation_chat.status_thinking'),
      _ =>
        _state.isSending
            ? trans('conversation_chat.status_sending')
            : trans('conversation_chat.status_connecting'),
    };
  }

  /// Derives avatar initials from agent role name (e.g. "Developer" → "D",
  /// "Business Analyst" → "BA").
  String _agentInitials(String? name) {
    if (name == null || name.isEmpty) return 'A';
    return name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
  }

  // -----------------------------------------------------------------------
  // Debug panel — metadata + raw events (behind _rawEventsExpanded toggle)
  // -----------------------------------------------------------------------

  Widget _buildDebugPanel(Conversation conversation) {
    return WDiv(
      className: '''
        border-t border-slate-200 dark:border-slate-700
        bg-slate-50 dark:bg-slate-900
        p-4 flex flex-col gap-4
      ''',
      children: [
        // Debug panel header
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(
              Icons.bug_report_outlined,
              className: 'text-sm text-slate-400',
            ),
            WText(
              trans('conversation_chat.debug_panel'),
              className:
                  'text-sm font-semibold text-slate-600 dark:text-slate-300',
            ),
          ],
        ),

        // Metadata card
        _buildMetadataCard(conversation),

        // Raw events panel
        _buildRawEventsPanel(),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Metadata card
  // -----------------------------------------------------------------------

  Widget _buildMetadataCard(Conversation conversation) {
    return MagicStarterCard(
      title: trans('conversation_chat.session_info'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Conversation ID
          WDiv(
            className: 'flex flex-col gap-0.5',
            children: [
              WText(
                trans('conversation_chat.conversation_id'),
                className:
                    'text-xs font-semibold text-slate-500 dark:text-slate-400',
              ),
              WAnchor(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: conversation.id));
                },
                child: WText(
                  _truncateId(conversation.id),
                  className: '''
                  text-sm text-gray-800 dark:text-gray-200
                  underline decoration-dotted
                ''',
                ),
              ),
            ],
          ),

          // Status
          _InfoRow(
            label: trans('conversation_chat.status_label'),
            value: conversation.status,
          ),

          // Paused badge
          if (conversation.status == 'paused')
            WDiv(
              className: 'px-2 py-1 rounded-lg bg-amber-400/15',
              child: WText(
                trans('conversation_chat.status_paused'),
                className: 'text-xs font-semibold text-amber-500',
              ),
            ),

          // Agent role
          if (conversation.agentRoleName != null)
            _InfoRow(
              label: trans('conversation_chat.agent_role'),
              value: conversation.agentRoleName!,
            ),

          // Model
          if (conversation.model != null)
            _InfoRow(
              label: trans('conversation_chat.model_label'),
              value: conversation.model!,
            ),

          // Cost
          _InfoRow(
            label: trans('conversation_chat.cost_label'),
            value: trans('conversation_chat.cost_format', {
              'amount': (conversation.totalCostUsd ?? 0.0).toStringAsFixed(2),
            }),
          ),

          // Input tokens
          _InfoRow(
            label: trans('conversation_chat.input_tokens'),
            value: (conversation.totalInputTokens ?? 0).toString(),
          ),

          // Output tokens
          _InfoRow(
            label: trans('conversation_chat.output_tokens'),
            value: (conversation.totalOutputTokens ?? 0).toString(),
          ),

          // Session ID
          if (_state.sessionId != null)
            _InfoRow(
              label: trans('conversation_chat.session_id'),
              value: _truncateId(_state.sessionId!),
            ),

          // Running cost
          if (_state.runningCostUsd != null)
            _InfoRow(
              label: trans('conversation_chat.cost_label'),
              value: '\$${_state.runningCostUsd}',
            ),

          // Warm Until
          if (_state.warmUntil != null)
            _InfoRow(
              label: trans('conversation_chat.warm_until'),
              value: _state.warmUntil!,
            ),

          // Messages count
          WText(
            trans('conversation_chat.messages_count', {
              'count': _state.messages.length.toString(),
            }),
            className: 'text-xs text-slate-500 dark:text-slate-400',
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Raw events panel
  // -----------------------------------------------------------------------

  Widget _buildRawEventsPanel() {
    final events = _state.rawEvents;

    return MagicStarterCard(
      title: trans('conversation_chat.raw_events_count', {
        'count': events.length.toString(),
      }),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Toggle to expand/collapse events list
          WAnchor(
            onTap: () {},
            child: WDiv(
              className: 'flex flex-row items-center gap-2',
              children: [
                WIcon(Icons.expand_more, className: 'text-sm text-slate-400'),
                WText(
                  trans('conversation_chat.raw_events'),
                  className:
                      'text-xs font-medium text-slate-500 dark:text-slate-400',
                ),
              ],
            ),
          ),

          // Event list
          for (final event in events)
            WDiv(
              className: '''
                p-3 rounded-lg
                bg-slate-900 dark:bg-slate-950
              ''',
              children: [
                WDiv(
                  className: 'flex flex-row items-center gap-2 mb-1',
                  children: [
                    WDiv(
                      className: 'px-1.5 py-0.5 rounded bg-slate-700',
                      child: WText(
                        event.eventName,
                        className: 'text-[10px] font-mono text-slate-300',
                      ),
                    ),
                    WText(
                      event.channel,
                      className: 'text-[10px] font-mono text-slate-500',
                    ),
                  ],
                ),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(event.data),
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrains Mono',
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  String _avatarBgClassName(String? slug) {
    return switch (slug) {
      'ba' => 'bg-indigo-500',
      'lead' => 'bg-primary-500',
      'dev' => 'bg-teal-500',
      'reviewer' => 'bg-violet-500',
      'qa' => 'bg-emerald-500',
      _ => 'bg-slate-500',
    };
  }

  String _truncateId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...';
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

/// Simple label + value pair for the metadata sidebar.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-0.5',
      children: [
        WText(
          label,
          className: 'text-xs font-semibold text-slate-500 dark:text-slate-400',
        ),
        WText(value, className: 'text-sm text-gray-800 dark:text-gray-200'),
      ],
    );
  }
}
