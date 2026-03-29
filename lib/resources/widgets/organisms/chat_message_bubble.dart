import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation_message.dart';
import 'markdown_viewer.dart';

/// A chat message bubble displaying user or assistant content.
///
/// User messages are right-aligned with secondary-400/15 background and a
/// user avatar showing the first letter of [userName].
/// Assistant messages are left-aligned with a slate background, an agent
/// avatar circle showing the role abbreviation, markdown content via
/// [MarkdownViewer], and an optional cost/duration footer.
///
/// ## Usage
///
/// ```dart
/// ChatMessageBubble(
///   message: conversationMessage,
///   agentRoleSlug: 'ba',
///   agentRoleName: 'Business Analyst',
///   userName: 'Anilcan',
/// )
/// ```
class ChatMessageBubble extends StatelessWidget {
  /// Creates a [ChatMessageBubble] for the given [message].
  const ChatMessageBubble({
    required this.message,
    this.agentRoleSlug,
    this.agentRoleName,
    this.userName,
    super.key,
  });

  // -------

  /// The conversation message to render.
  final ConversationMessage message;

  /// Agent role slug used to pick the avatar background colour
  /// (e.g. `'ba'`, `'lead'`, `'dev'`, `'reviewer'`, `'qa'`).
  final String? agentRoleSlug;

  /// Agent role display name.
  final String? agentRoleName;

  /// Display name of the logged-in user — first letter used as monogram.
  final String? userName;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == 'user';

    return isUser ? _buildUserBubble() : _buildAssistantBubble();
  }

  // -----------------------------------------------------------------------
  // User bubble
  // -----------------------------------------------------------------------

  Widget _buildUserBubble() {
    return WDiv(
      className: 'w-full flex flex-row justify-end gap-2.5 mb-3',
      children: [
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col items-end',
          children: [
            WDiv(
              className:
                  'px-3.5 py-2.5 rounded-2xl rounded-br-sm bg-secondary-400/15',
              children: [
                WText(
                  message.content,
                  className: 'text-sm text-primary-600 dark:text-slate-100',
                ),
                WDiv(
                  className: 'flex flex-row justify-end mt-1',
                  children: [
                    WText(
                      _formatTimeAgo(message.createdAt),
                      className: 'text-[10px] text-slate-400',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        _buildUserAvatar(),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Assistant bubble
  // -----------------------------------------------------------------------

  Widget _buildAssistantBubble() {
    return WDiv(
      className: 'w-full flex flex-row gap-2.5 mb-3',
      children: [
        _buildAgentAvatar(),
        WDiv(
          className: 'flex-1 min-w-0',
          children: [
            WDiv(
              className:
                  'px-3.5 py-2.5 rounded-2xl rounded-bl-sm bg-slate-100 dark:bg-slate-800',
              children: [
                MarkdownViewer(data: message.content),
                if (_hasFooterData) _buildFooter(),
                WText(
                  _formatTimeAgo(message.createdAt),
                  className: 'text-[10px] text-slate-400 mt-1',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Avatars
  // -----------------------------------------------------------------------

  Widget _buildAgentAvatar() {
    return WDiv(
      className:
          'w-7 h-7 rounded-full flex items-center justify-center ${_avatarBgClassName(agentRoleSlug)}',
      child: WText(
        _roleAbbreviation(agentRoleSlug),
        className: 'text-[10px] font-bold text-white',
      ),
    );
  }

  Widget _buildUserAvatar() {
    final String initial = userName != null && userName!.isNotEmpty
        ? userName![0].toUpperCase()
        : 'U';

    return WDiv(
      className:
          'w-7 h-7 rounded-full flex items-center justify-center bg-secondary-400',
      child: WText(
        initial,
        className: 'text-xs font-semibold text-primary-900',
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Footer
  // -----------------------------------------------------------------------

  Widget _buildFooter() {
    return WDiv(
      className: 'flex flex-row items-center gap-2 mt-2',
      children: [
        if (message.costUsd != null)
          WText(
            trans('conversation_chat.cost_format', {
              'amount': message.costUsd!.toStringAsFixed(4),
            }),
            className: 'text-xs text-slate-400 font-mono',
          ),
        if (message.durationMs != null)
          WText(
            '${message.durationMs}ms',
            className: 'text-xs text-slate-400 font-mono',
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Whether the message has cost or duration data to show in the footer.
  bool get _hasFooterData =>
      message.costUsd != null || message.durationMs != null;

  /// Maps an agent role slug to a 2-letter abbreviation for the avatar.
  static String _roleAbbreviation(String? slug) {
    return switch (slug) {
      'ba' => 'BA',
      'lead' => 'LD',
      'dev' => 'DV',
      'reviewer' => 'RV',
      'qa' => 'QA',
      _ => 'AI',
    };
  }

  /// Maps an agent role slug to a background className for the avatar circle.
  static String _avatarBgClassName(String? slug) {
    return switch (slug) {
      'ba' => 'bg-indigo-500',
      'lead' => 'bg-primary-500',
      'dev' => 'bg-teal-500',
      'reviewer' => 'bg-violet-500',
      'qa' => 'bg-emerald-500',
      _ => 'bg-slate-500',
    };
  }

  /// Formats [dateTime] as a relative-time string and wraps it in the
  /// `conversation_chat.time_ago` translation key.
  static String _formatTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);

    final String relative;
    if (diff.inMinutes < 1) {
      relative = trans('time.just_now');
    } else if (diff.inMinutes < 60) {
      relative = trans('time.minutes_ago', {
        'minutes': diff.inMinutes.toString(),
      });
    } else if (diff.inHours < 24) {
      relative = trans('time.hours_ago', {'hours': diff.inHours.toString()});
    } else {
      final DateTime d = dateTime.toLocal();
      relative =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return trans('conversation_chat.time_ago', {'time': relative});
  }
}
