import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/events/websocket_event.dart';
import '../../../app/models/conversation.dart';
import '../../../app/models/user.dart';
import '../../../app/services/websocket_service.dart';
import '../../../app/state/conversation_chat_state.dart';
import '../../widgets/atoms/streaming_indicator.dart';
import '../../widgets/molecules/section_card.dart';
import '../../widgets/organisms/chat_message_bubble.dart';

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
}

// ---------------------------------------------------------------------------
// ConversationChatView
// ---------------------------------------------------------------------------

/// Production conversation chat page — real-time chat interface showing
/// messages with styled bubbles, a header bar with metadata, and a
/// collapsible debug panel behind [_rawEventsExpanded] toggle.
///
/// Supports both creating new conversations and loading existing ones
/// via an optional `conversationId` query parameter.
///
/// ## Usage
///
/// ```dart
/// ConversationChatView(projectId: 'proj-uuid-001')
/// ```
class ConversationChatView extends StatefulWidget {
  /// Creates a [ConversationChatView] for the given [projectId].
  const ConversationChatView({super.key, required this.projectId});

  /// The ID of the project to create conversations in.
  final String projectId;

  @override
  State<ConversationChatView> createState() => _ConversationChatViewState();
}

class _ConversationChatViewState extends State<ConversationChatView> {
  late ConversationChatState _state;
  String _teamId = '';
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _rawEventsExpanded = false;
  bool _isCreating = false;

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
    _teamId = Auth.user<User>()?.currentTeam?.id ?? '';

    _scrollController.addListener(_onScrollChanged);

    // Load existing conversation if query param present.
    _maybeLoadConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _answerController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _state.reset();
    super.dispose();
  }

  /// Checks for a `conversationId` query parameter and loads that
  /// conversation if present.
  void _maybeLoadConversation() {
    try {
      final conversationId = MagicRouter.instance.queryParameter(
        'conversationId',
      );
      if (conversationId != null && conversationId.isNotEmpty) {
        _state.loadConversation(_teamId, widget.projectId, conversationId);
      }
    } catch (_) {
      // Query params not available in tests — silently ignore.
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

    setState(() => _isCreating = true);

    await _state.createConversation(_teamId, widget.projectId);

    if (mounted) {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    await _state.sendMessage(text);

    if (mounted && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.conversation == null) {
          return _buildStartChat();
        }
        return _buildContent();
      },
    );
  }

  // -----------------------------------------------------------------------
  // Start Chat (no conversation yet)
  // -----------------------------------------------------------------------

  Widget _buildStartChat() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-4',
      children: [
        // Title bar
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            WText(
              trans('conversation_chat.title'),
              className: 'text-lg font-semibold text-slate-900 dark:text-white',
            ),
          ],
        ),

        // Centered start button or loading
        WDiv(
          className: 'w-full flex flex-col items-center justify-center py-16',
          child: _isCreating
              ? WDiv(
                  className: 'flex flex-col items-center gap-3',
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    WText(
                      trans('conversation_chat.starting'),
                      className: 'text-sm text-slate-500 dark:text-slate-400',
                    ),
                  ],
                )
              : WDiv(
                  className: 'flex flex-col items-center gap-4',
                  children: [
                    WText(
                      trans('conversation_chat.subtitle'),
                      className: 'text-sm text-slate-500 dark:text-slate-400',
                    ),
                    WAnchor(
                      onTap: _handleStartChat,
                      child: WDiv(
                        className: '''
                          px-6 py-3 bg-amber-400 rounded-lg
                        ''',
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
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Content (conversation exists)
  // -----------------------------------------------------------------------

  Widget _buildContent() {
    final conversation = _state.conversation!;

    // Trigger auto-scroll after build.
    if (_autoScroll && _state.messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return WDiv(
      className: 'flex flex-col gap-0',
      children: [
        // Header bar
        _buildHeader(conversation),

        // Message area
        _buildMessageArea(),

        // Question / permission cards
        if (_state.pendingQuestion != null) _buildQuestionCard(),
        if (_state.pendingPermission != null) _buildPermissionCard(),

        // Streaming indicator
        if (_state.isSending) const StreamingIndicator(),

        // Input area
        if (conversation.status != 'completed') _buildInputArea(),

        // Debug panel (conditionally shown)
        if (_rawEventsExpanded) _buildDebugPanel(conversation),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Header bar
  // -----------------------------------------------------------------------

  Widget _buildHeader(Conversation conversation) {
    return WDiv(
      className: '''
        px-4 py-3 border-b border-slate-200 dark:border-slate-700
        flex flex-row items-center gap-3
      ''',
      children: [
        // Agent role badge
        if (conversation.agentRoleName != null)
          WDiv(
            className:
                '''
              px-2 py-0.5 rounded-full
              ${_agentRoleClassName(conversation.agentRoleSlug)}
            ''',
            child: WText(
              conversation.agentRoleName!,
              className: 'text-xs font-semibold',
            ),
          ),

        // Conversation title
        WText(
          conversation.title ?? trans('conversation_chat.title'),
          className: 'text-sm font-semibold text-slate-900 dark:text-white',
        ),

        // Status badge
        _buildConversationStatusBadge(conversation.status),

        // Cost display
        WText(
          trans('conversation_chat.cost_format', {
            'amount': (conversation.totalCostUsd ?? 0.0).toStringAsFixed(2),
          }),
          className: 'font-mono text-sm text-slate-500 dark:text-slate-400',
        ),

        // Session phase (if available)
        if (_state.sessionPhase != null)
          WText(
            trans('conversation_chat.session_phase', {
              'phase': _state.sessionPhase!,
            }),
            className: 'text-xs text-slate-400',
          ),

        // Spacer
        WSpacer(className: 'flex-1'),

        // Complete button
        if (conversation.status == 'active')
          WAnchor(
            onTap: _handleComplete,
            child: WDiv(
              className: 'px-3 py-1.5 bg-red-500 rounded-lg',
              child: WText(
                trans('conversation_chat.complete_chat'),
                className: 'text-xs text-white font-medium',
              ),
            ),
          ),

        // Debug toggle button
        WAnchor(
          onTap: () => setState(() => _rawEventsExpanded = !_rawEventsExpanded),
          child: WDiv(
            className:
                '''
              p-1.5 rounded-lg
              ${_rawEventsExpanded ? 'bg-amber-400/15' : 'bg-slate-100 dark:bg-slate-800'}
            ''',
            child: WIcon(
              Icons.bug_report_outlined,
              className:
                  '''
                text-lg
                ${_rawEventsExpanded ? 'text-amber-600' : 'text-slate-400'}
              ''',
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Conversation status badge (uses conversation_chat i18n keys)
  // -----------------------------------------------------------------------

  Widget _buildConversationStatusBadge(String status) {
    final colorMap = {
      'active': 'bg-emerald-500/15 text-emerald-500',
      'paused': 'bg-amber-400/15 text-amber-500',
      'completed': 'bg-slate-500/15 text-slate-500',
      'failed': 'bg-red-500/15 text-red-500',
    };

    return WDiv(
      className:
          'px-1.5 py-0.5 rounded ${colorMap[status] ?? colorMap['active']!}',
      child: WText(
        trans('conversation_chat.status_$status'),
        className: 'text-[11px] font-semibold',
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Message area
  // -----------------------------------------------------------------------

  Widget _buildMessageArea() {
    final messages = _state.messages;

    if (messages.isEmpty) {
      return WDiv(
        className: 'w-full flex items-center justify-center py-16',
        child: WText(
          trans('conversation_chat.no_messages'),
          className: 'text-sm text-slate-400 dark:text-slate-500',
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          ChatMessageBubble(message: messages[index]),
    );
  }

  // -----------------------------------------------------------------------
  // Input area
  // -----------------------------------------------------------------------

  Widget _buildInputArea() {
    return WDiv(
      className: '''
        px-4 py-3 border-t border-slate-200 dark:border-slate-700
        flex flex-row gap-3 items-center
      ''',
      children: [
        WDiv(
          className: 'flex-1',
          child: WFormInput(
            controller: _inputController,
            label: trans('conversation_chat.placeholder'),
          ),
        ),
        WAnchor(
          onTap: _state.isSending ? null : _handleSendMessage,
          child: WDiv(
            className:
                '''
              px-4 py-2 rounded-lg
              ${_state.isSending ? 'bg-slate-300 dark:bg-slate-600' : 'bg-amber-400'}
            ''',
            child: WText(
              _state.isSending
                  ? trans('conversation_chat.sending')
                  : trans('conversation_chat.send'),
              className: 'text-sm font-medium text-slate-900',
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Question card
  // -----------------------------------------------------------------------

  Widget _buildQuestionCard() {
    final question = _state.pendingQuestion!;
    final questionId = question['questionId'] as String? ?? '';
    final message = question['message'] as String? ?? '';
    final header = question['header'] as String?;
    final options = question['options'] as List<Map<String, dynamic>>?;
    final isDisabled = _state.isAnswering;

    return WDiv(
      className: '''
        mx-4 p-4 rounded-xl border-2 border-amber-400
        bg-amber-50 dark:bg-amber-900/10
      ''',
      children: [
        // Header
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-3',
          children: [
            WIcon(Icons.help_outline, className: 'text-amber-600 text-lg'),
            WText(
              trans('conversation_chat.question_title'),
              className: 'text-sm font-semibold text-amber-700',
            ),
          ],
        ),

        // Optional header text
        if (header != null)
          WText(header, className: 'text-base font-medium mb-2'),

        // Question message
        WText(
          message,
          className: 'text-sm text-slate-700 dark:text-slate-300 mb-3',
        ),

        // Clickable option cards
        if (options != null)
          for (final option in options)
            WAnchor(
              onTap: isDisabled
                  ? null
                  : () => _state.answerQuestion(
                      questionId,
                      option['label'] as String? ?? '',
                    ),
              child: WDiv(
                className: '''
                  p-3 rounded-lg border border-slate-200
                  hover:border-amber-400 mb-2
                ''',
                children: [
                  WText(
                    option['label'] as String? ?? '',
                    className: 'text-sm font-medium',
                  ),
                  if (option['description'] != null)
                    WText(
                      option['description'] as String,
                      className: 'text-xs text-slate-500',
                    ),
                ],
              ),
            ),

        // Free-form fallback input
        WDiv(
          className: 'flex flex-row gap-2 mt-2',
          children: [
            WDiv(
              className: 'flex-1',
              child: WFormInput(
                controller: _answerController,
                label: trans('conversation_chat.answer_placeholder'),
              ),
            ),
            WAnchor(
              onTap: isDisabled
                  ? null
                  : () {
                      final text = _answerController.text.trim();
                      if (text.isEmpty) return;
                      _answerController.clear();
                      _state.answerQuestion(questionId, text);
                    },
              child: WDiv(
                className:
                    '''
                  px-4 py-2 rounded-lg
                  ${isDisabled ? 'bg-slate-300 dark:bg-slate-600' : 'bg-amber-400'}
                ''',
                child: WText(
                  isDisabled
                      ? trans('conversation_chat.question_submitting')
                      : trans('conversation_chat.question_submit'),
                  className: 'text-sm font-medium text-slate-900',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Permission card
  // -----------------------------------------------------------------------

  Widget _buildPermissionCard() {
    final permission = _state.pendingPermission!;
    final questionId = permission['questionId'] as String? ?? '';
    final toolName = permission['toolName'] as String? ?? '';
    final input = permission['input'];
    final isDisabled = _state.isAnswering;

    return WDiv(
      className: '''
        mx-4 p-4 rounded-xl border-2 border-blue-400
        bg-blue-50 dark:bg-blue-900/10
      ''',
      children: [
        // Header
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-3',
          children: [
            WIcon(Icons.shield_outlined, className: 'text-blue-600 text-lg'),
            WText(
              trans('conversation_chat.permission_title'),
              className: 'text-sm font-semibold text-blue-700',
            ),
          ],
        ),

        // Tool name
        WText(
          trans('conversation_chat.permission_tool', {'tool': toolName}),
          className: 'font-mono text-sm',
        ),

        // Input display
        if (input != null)
          WDiv(
            className: '''
              bg-slate-100 dark:bg-slate-800
              p-3 rounded-lg overflow-hidden mt-2
            ''',
            child: SelectableText(
              jsonEncode(input),
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),

        // Approve / Deny buttons
        WDiv(
          className: 'flex flex-row gap-3 mt-3',
          children: [
            WAnchor(
              onTap: isDisabled
                  ? null
                  : () => _state.answerQuestion(questionId, 'approve'),
              child: WDiv(
                className: 'px-4 py-2 bg-emerald-500 rounded-lg',
                child: WText(
                  trans('conversation_chat.permission_approve'),
                  className: 'text-white text-sm font-medium',
                ),
              ),
            ),
            WAnchor(
              onTap: isDisabled
                  ? null
                  : () => _state.answerQuestion(questionId, 'deny'),
              child: WDiv(
                className: 'px-4 py-2 bg-red-500 rounded-lg',
                child: WText(
                  trans('conversation_chat.permission_deny'),
                  className: 'text-white text-sm font-medium',
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
    return SectionCard(
      title: trans('conversation_chat.session_info'),
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
        _InfoRow(label: trans('agent_run.status'), value: conversation.status),

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
            label: trans('agent_run.session_id'),
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
    );
  }

  // -----------------------------------------------------------------------
  // Raw events panel
  // -----------------------------------------------------------------------

  Widget _buildRawEventsPanel() {
    final events = _state.rawEvents;

    return SectionCard(
      title: trans('conversation_chat.raw_events_count', {
        'count': events.length.toString(),
      }),
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
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Returns agent role badge className based on slug.
  String _agentRoleClassName(String? slug) {
    return switch (slug) {
      'ba' => 'bg-indigo-500/10 text-indigo-500',
      'lead' => 'bg-primary-500/10 text-primary-500',
      'dev' => 'bg-teal-500/10 text-teal-500',
      'reviewer' => 'bg-violet-500/10 text-violet-500',
      'qa' => 'bg-emerald-500/10 text-emerald-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  /// Truncates a UUID to first 8 characters with ellipsis.
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
