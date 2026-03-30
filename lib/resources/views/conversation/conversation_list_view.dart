import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_role.dart';
import '../../../app/models/conversation.dart';
import '../../../app/models/user.dart';
import '../../../app/state/conversation_chat_state.dart';
import '../../../app/state/conversation_list_state.dart';
import '../../widgets/organisms/agent_role_picker_modal.dart';
import 'package:magic_starter/magic_starter.dart';

/// Conversation list view — displays all conversations for a given project.
///
/// Fetches conversations via [ConversationListState] on init and renders
/// loading, empty, and content states.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/conversations');
/// // or construct directly:
/// ConversationListView(projectId: 'proj-uuid-001')
/// ```
class ConversationListView extends StatefulWidget {
  /// Creates the [ConversationListView] for the given [projectId].
  const ConversationListView({required this.projectId, super.key});

  /// The ID of the project whose conversations are shown.
  final String projectId;

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  ConversationListState get _state =>
      Magic.findOrPut(ConversationListState.new);

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  /// Loads conversations for the current team and project.
  Future<void> _loadConversations() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await _state.loadConversations(teamId, widget.projectId);
  }

  /// Shows the agent role picker and navigates directly to a new chat.
  Future<void> _handleNewConversation() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    final chatState = ConversationChatState();
    final roles = await chatState.fetchAgentRoles(teamId);
    if (!mounted || roles.isEmpty) return;

    final AgentRole? selected = await AgentRolePickerModal.show(context, roles);
    if (selected == null || !mounted) return;

    MagicRoute.to(
      '/projects/${widget.projectId}/chat?agentRoleId=${selected.id}',
    );
  }

  // -----------------------------------------------------------------------
  // Status badge helpers
  // -----------------------------------------------------------------------

  /// Returns a Tailwind className string for the given conversation [status].
  static String _statusBadgeClassName(String status) {
    return switch (status) {
      'active' => 'bg-emerald-500/15 text-emerald-500',
      'paused' => 'bg-amber-500/15 text-amber-500',
      'completed' => 'bg-slate-500/15 text-slate-500',
      'failed' => 'bg-red-500/15 text-red-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  /// Returns the i18n translation key for the given conversation [status].
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
  // Time helpers
  // -----------------------------------------------------------------------

  /// Returns a relative time string (e.g. "2 h ago") from [dateTime].
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
  // Cost helpers
  // -----------------------------------------------------------------------

  /// Formats [totalCostUsd] as `$X.XX` or `--` when absent.
  static String _formatCost(double? cost) {
    if (cost == null) return '--';
    return '\$${cost.toStringAsFixed(2)}';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -------------------------------------------------------------------
        // Header
        // -------------------------------------------------------------------
        MagicStarterPageHeader(
          title: trans('conversations.title'),
          subtitle: trans('conversations.subtitle'),
          actions: [
            WAnchor(
              onTap: _handleNewConversation,
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-amber-400
                ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('conversations.new'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------------
        // State-driven content
        // -------------------------------------------------------------------
        ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            if (_state.isLoading) {
              return _buildLoading();
            }
            if (_state.isEmpty) {
              return _buildEmpty();
            }
            if (_state.isSuccess) {
              return _buildContent(_state.rxState!);
            }
            return const WDiv(className: '', children: []);
          },
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Loading state
  // -----------------------------------------------------------------------

  /// Centered spinner shown while conversations are loading.
  Widget _buildLoading() {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }

  // -----------------------------------------------------------------------
  // Empty state
  // -----------------------------------------------------------------------

  /// Centered empty state shown when no conversations exist.
  Widget _buildEmpty() {
    return MagicStarterCard(
      child: WDiv(
        className:
            'w-full flex flex-col items-center justify-center py-16 gap-4',
        children: [
          WIcon(
            Icons.chat_bubble_outline,
            className: 'text-4xl text-slate-300',
          ),
          WText(
            trans('conversations.empty_title'),
            className: 'text-lg font-semibold text-slate-500',
          ),
          WText(
            trans('conversations.empty_subtitle'),
            className: 'text-sm text-slate-400',
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Content state
  // -----------------------------------------------------------------------

  /// Scrollable, pull-to-refresh list of conversation rows.
  Widget _buildContent(List<Conversation> conversations) {
    return MagicStarterCard(
      noPadding: true,
      child: RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => WDiv(
            className: 'mx-4 border-b border-slate-100 dark:border-slate-700',
          ),
          itemBuilder: (context, index) =>
              _buildConversationRow(conversations[index]),
        ),
      ),
    );
  }

  /// Derives a short avatar label from the agent role name (e.g. "BA").
  static String _avatarLabel(Conversation conversation) {
    final name = conversation.agentRoleName ?? conversation.title ?? '';
    if (name.isEmpty) return '?';
    return name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
  }

  /// A tappable row for a single [Conversation].
  Widget _buildConversationRow(Conversation conversation) {
    final displayTitle = conversation.title ?? conversation.agentRoleName ?? '';
    final lastActive = _relativeTime(
      conversation.lastActivityAt ?? conversation.updatedAt,
    );
    final avatar = _avatarLabel(conversation);

    return WAnchor(
      onTap: () => MagicRoute.to(
        '/projects/${widget.projectId}/chats/${conversation.id}',
      ),
      child: WDiv(
        className: 'px-4 py-3 flex flex-row items-center gap-3',
        children: [
          // -------------------------------------------------------------------
          // Agent role avatar (initials)
          // -------------------------------------------------------------------
          WDiv(
            className: '''
              w-9 h-9 rounded-full
              flex items-center justify-center
              bg-amber-400
            ''',
            child: WText(avatar, className: 'text-xs font-bold text-slate-900'),
          ),

          // -------------------------------------------------------------------
          // Title + meta
          // -------------------------------------------------------------------
          WDiv(
            className: 'flex-1 flex flex-col gap-1',
            children: [
              WText(
                displayTitle,
                className:
                    'text-sm font-semibold text-slate-800 dark:text-white',
              ),
              WText(
                trans('conversations.messages_count', {
                  'count': (conversation.messagesCount ?? 0).toString(),
                }),
                className: 'text-xs text-slate-500',
              ),
              WText(
                trans('conversations.last_active', {'time': lastActive}),
                className: 'text-xs text-slate-400',
              ),
            ],
          ),

          // -------------------------------------------------------------------
          // Status badge
          // -------------------------------------------------------------------
          WDiv(
            className:
                'px-2.5 py-1 rounded-full text-xs font-medium ${_statusBadgeClassName(conversation.status)}',
            child: WText(
              _statusLabel(conversation.status),
              className: 'text-xs font-medium',
            ),
          ),

          // -------------------------------------------------------------------
          // Cost
          // -------------------------------------------------------------------
          WText(
            _formatCost(conversation.totalCostUsd),
            className: 'text-sm font-mono text-slate-600',
          ),

          // -------------------------------------------------------------------
          // Chevron
          // -------------------------------------------------------------------
          WIcon(Icons.chevron_right, className: 'text-lg text-slate-400'),
        ],
      ),
    );
  }
}
