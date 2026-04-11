import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/conversation.dart';
import '../../../app/models/conversation_message.dart';
import '../../../app/models/user.dart';
import '../../../app/state/conversation_detail_state.dart';

/// Conversation chat view — displays messages and allows sending new ones.
///
/// Full-height chat layout: compact header, scrollable message list, and a
/// sticky input bar at the bottom (hidden when conversation is not active).
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/conversations/$projectId/$conversationId');
/// ```
class ConversationDetailView extends StatefulWidget {
  /// Creates the [ConversationDetailView].
  const ConversationDetailView({
    required this.projectId,
    required this.conversationId,
    super.key,
  });

  /// The ID of the parent project.
  final String projectId;

  /// The ID of the conversation to display.
  final String conversationId;

  @override
  State<ConversationDetailView> createState() => _ConversationDetailViewState();
}

class _ConversationDetailViewState extends State<ConversationDetailView> {
  final _state = ConversationDetailState();
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _state.reset();
    super.dispose();
  }

  /// Loads the conversation and its messages.
  Future<void> _load() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await _state.load(teamId, widget.projectId, widget.conversationId);
    _scrollToBottom();
  }

  /// Scrolls the message list to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Sends the current input as a user message.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _state.isSending) return;

    _messageController.clear();
    final success = await _state.sendMessage(text);
    _scrollToBottom();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trans('conversations.send_failed'))),
      );
    }

    if (mounted) _focusNode.requestFocus();
  }

  // -----------------------------------------------------------------------
  // Status badge helpers
  // -----------------------------------------------------------------------

  /// Returns a className string for the given conversation [status].
  static String _statusBadgeClassName(String status) {
    return switch (status) {
      'active' => 'bg-emerald-500/15 text-emerald-500',
      'paused' => 'bg-amber-500/15 text-amber-500',
      'completed' => 'bg-slate-500/15 text-slate-500',
      'failed' => 'bg-red-500/15 text-red-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  /// Returns the i18n label for a conversation [status].
  static String _statusLabel(String status) {
    return switch (status) {
      'active' => trans('conversations.status_active'),
      'paused' => trans('conversations.status_paused'),
      'completed' => trans('conversations.status_completed'),
      'failed' => trans('conversations.status_failed'),
      _ => status,
    };
  }

  // -----------------------------------------------------------------------
  // Role color helpers
  // -----------------------------------------------------------------------

  /// Returns a className string for message role badge.
  static String _roleBadgeClassName(String role) {
    return switch (role) {
      'user' => 'bg-blue-500/15 text-blue-600',
      'assistant' => 'bg-emerald-500/15 text-emerald-600',
      'system' => 'bg-slate-500/15 text-slate-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  // -----------------------------------------------------------------------
  // Cost / time helpers
  // -----------------------------------------------------------------------

  /// Formats [cost] as `$X.XX` or `--` when absent.
  static String _formatCost(double? cost) {
    if (cost == null) return '--';
    return '\$${cost.toStringAsFixed(2)}';
  }

  /// Returns a relative time string from [dateTime].
  static String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return trans('time.just_now');
    if (diff.inHours < 1) {
      return trans('time.minutes_ago', {'minutes': diff.inMinutes.toString()});
    }
    if (diff.inDays < 1) {
      return trans('time.hours_ago', {'hours': diff.inHours.toString()});
    }
    return trans('time.days_ago', {'days': diff.inDays.toString()});
  }

  // -----------------------------------------------------------------------
  // Whether input should be shown
  // -----------------------------------------------------------------------

  /// Returns true when the conversation accepts new messages.
  bool _isInputEnabled(Conversation conversation) {
    return conversation.status == 'active' || conversation.status == 'paused';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.isLoading) return _buildLoading();
        if (_state.isError) return _buildError();
        if (_state.isSuccess) return _buildChat(_state.rxState!);
        return const WDiv(className: '', children: []);
      },
    );
  }

  // -----------------------------------------------------------------------
  // Loading
  // -----------------------------------------------------------------------

  Widget _buildLoading() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('conversations.detail_title')),
        const WDiv(
          className: 'w-full flex items-center justify-center py-16',
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Error
  // -----------------------------------------------------------------------

  Widget _buildError() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('conversations.detail_title')),
        MagicStarterCard(
          child: WDiv(
            className:
                'w-full flex flex-col items-center justify-center py-16 gap-4',
            children: [
              WIcon(Icons.error_outline, className: 'text-4xl text-red-400'),
              WText(
                _state.rxStatus.message ?? trans('common.error'),
                className: 'text-sm text-red-500',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Chat layout
  // -----------------------------------------------------------------------

  Widget _buildChat(Conversation conversation) {
    final messages = _state.messages;
    final displayTitle = conversation.title ?? conversation.agentRoleName ?? '';
    final showInput = _isInputEnabled(conversation);

    // The layout shell wraps us in an overflow-y-auto (SingleChildScrollView)
    // which gives ∞ height. We need to fill the scroll viewport exactly so
    // Column + Expanded can work. Grab the viewport height from the ancestor
    // ScrollPosition and constrain ourselves to it.
    final scrollable = Scrollable.maybeOf(context);
    final viewportHeight = scrollable?.position.viewportDimension;
    final effectiveHeight = (viewportHeight != null && viewportHeight.isFinite)
        ? viewportHeight
        : MediaQuery.sizeOf(context).height;

    return SizedBox(
      height: effectiveHeight,
      child: WDiv(
        className: 'flex flex-col',
        children: [
          // -- Header --
          _buildHeader(displayTitle, conversation),

          // -- Messages --
          WDiv(
            className: 'flex-1 overflow-hidden',
            child: _buildMessageList(messages),
          ),

          // -- Input bar --
          if (showInput) _buildInputBar(),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Header
  // -----------------------------------------------------------------------

  Widget _buildHeader(String title, Conversation conversation) {
    return WDiv(
      className: '''
        px-4 py-3 border-b border-gray-200 dark:border-gray-700
      ''',
      child: WDiv(
        className: 'flex flex-row items-center',
        children: [
          // Back button
          WAnchor(
            onTap: () => MagicRoute.to('/conversations/${widget.projectId}'),
            child: WIcon(Icons.arrow_back, className: 'text-lg text-slate-400'),
          ),
          const WSpacer(className: 'w-3'),

          // Title + info
          WDiv(
            className: 'flex-1',
            child: WDiv(
              className: 'flex flex-col gap-0.5',
              children: [
                WText(
                  title,
                  className:
                      'text-base font-semibold text-gray-900 dark:text-white truncate',
                ),
                WDiv(
                  className: 'flex flex-row items-center gap-2',
                  children: [
                    WDiv(
                      className:
                          'px-1.5 py-0.5 rounded-full ${_statusBadgeClassName(conversation.status)}',
                      child: WText(
                        _statusLabel(conversation.status),
                        className: 'text-[10px] font-medium',
                      ),
                    ),
                    if (conversation.model != null)
                      WText(
                        conversation.model!,
                        className: 'text-[10px] text-slate-400',
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Cost badge
          if (conversation.totalCostUsd != null)
            WDiv(
              className: 'px-2 py-1 rounded-lg bg-slate-100 dark:bg-gray-700',
              child: WText(
                _formatCost(conversation.totalCostUsd),
                className: 'text-xs font-mono text-slate-500',
              ),
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Message list
  // -----------------------------------------------------------------------

  Widget _buildMessageList(List<ConversationMessage> messages) {
    if (messages.isEmpty) {
      return WDiv(
        className:
            'w-full flex flex-col items-center justify-center py-16 gap-3',
        children: [
          WIcon(
            Icons.chat_bubble_outline,
            className: 'text-3xl text-slate-300',
          ),
          WText(
            trans('conversations.detail_no_messages'),
            className: 'text-sm text-slate-400',
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
    );
  }

  // -----------------------------------------------------------------------
  // Message bubble
  // -----------------------------------------------------------------------

  Widget _buildMessageBubble(ConversationMessage message) {
    final isUser = message.role == 'user';
    final isOptimistic = message.id.startsWith('optimistic-');

    return WDiv(
      className: 'flex flex-col ${isUser ? 'items-end' : 'items-start'} mb-3',
      children: [
        // Role + timestamp
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-1',
          children: [
            WDiv(
              className:
                  'px-2 py-0.5 rounded-full ${_roleBadgeClassName(message.role)}',
              child: WText(
                isUser
                    ? trans('conversations.detail_role_user')
                    : message.role == 'assistant'
                    ? trans('conversations.detail_role_assistant')
                    : message.role,
                className: 'text-[10px] font-semibold uppercase',
              ),
            ),
            WText(
              _relativeTime(message.createdAt),
              className: 'text-[10px] text-slate-400',
            ),
            if (!isUser && message.costUsd != null)
              WText(
                _formatCost(message.costUsd),
                className: 'text-[10px] font-mono text-slate-400',
              ),
          ],
        ),

        // Bubble
        WDiv(
          className:
              '''
            px-4 py-3 rounded-2xl max-w-[85%]
            ${isUser ? 'bg-blue-500/10 dark:bg-blue-500/20' : 'bg-slate-100 dark:bg-gray-800'}
            ${isOptimistic ? 'opacity-60' : ''}
          ''',
          child: SelectableText(
            message.content ?? '',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Input bar
  // -----------------------------------------------------------------------

  Widget _buildInputBar() {
    return WDiv(
      className: '''
        px-4 py-3 border-t border-gray-200 dark:border-gray-700
        bg-white dark:bg-gray-900
      ''',
      child: WDiv(
        className: 'flex flex-row items-center',
        children: [
          WDiv(
            className: 'flex-1',
            child: WFormInput(
              controller: _messageController,
              focusNode: _focusNode,
              label: trans('conversations.type_message'),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const WSpacer(className: 'w-2'),
          WAnchor(
            onTap: _state.isSending ? null : _sendMessage,
            child: WDiv(
              className:
                  '''
                p-2.5 rounded-xl
                ${_state.isSending ? 'bg-amber-400/50' : 'bg-amber-400'}
              ''',
              child: _state.isSending
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : WIcon(Icons.send, className: 'text-lg text-gray-900'),
            ),
          ),
        ],
      ),
    );
  }
}
