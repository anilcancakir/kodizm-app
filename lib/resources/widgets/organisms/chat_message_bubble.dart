import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Assistant bubbles include action buttons for toggling between rendered
/// markdown and raw source, and copying the message content to clipboard.
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
class ChatMessageBubble extends StatefulWidget {
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

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  bool _showSource = false;
  bool _copied = false;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isUser = widget.message.role == 'user';

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
                  widget.message.content,
                  className: 'text-sm text-primary-600 dark:text-slate-100',
                ),
                WDiv(
                  className: 'flex flex-row justify-end mt-1',
                  children: [
                    WText(
                      _formatTimeAgo(widget.message.createdAt),
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
                _showSource
                    ? WDiv(
                        className: 'py-1',
                        child: SelectableText(
                          widget.message.content,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      )
                    : MarkdownViewer(data: widget.message.content),
                _buildAssistantFooter(),
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
          '''
        w-7 h-7 rounded-full
        flex items-center justify-center
        ${_avatarBgClassName(widget.agentRoleSlug)}
      ''',
      child: WText(
        _agentInitials(widget.agentRoleName, widget.agentRoleSlug),
        className: 'text-[10px] font-bold text-white',
      ),
    );
  }

  Widget _buildUserAvatar() {
    final String initial =
        widget.userName != null && widget.userName!.isNotEmpty
        ? widget.userName![0].toUpperCase()
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

  /// Footer for assistant bubbles — cost/duration metadata + action buttons.
  Widget _buildAssistantFooter() {
    return WDiv(
      className: 'flex flex-row items-center gap-2 mt-2',
      children: [
        // Cost / duration metadata.
        if (widget.message.costUsd != null)
          WText(
            trans('conversation_chat.cost_format', {
              'amount': widget.message.costUsd!.toStringAsFixed(4),
            }),
            className: 'text-xs text-slate-400 font-mono',
          ),
        if (widget.message.durationMs != null)
          WText(
            '${widget.message.durationMs}ms',
            className: 'text-xs text-slate-400 font-mono',
          ),
        // Timestamp.
        WText(
          _formatTimeAgo(widget.message.createdAt),
          className: 'text-[10px] text-slate-400',
        ),
        // Spacer pushes action buttons to the right.
        WDiv(className: 'flex-1'),
        // Action buttons.
        _buildActionButton(
          icon: _showSource ? Icons.visibility : Icons.code,
          onTap: () => setState(() => _showSource = !_showSource),
        ),
        _buildActionButton(
          icon: _copied ? Icons.check : Icons.copy,
          onTap: _handleCopy,
        ),
      ],
    );
  }

  /// Copies the message content to clipboard with brief visual feedback.
  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// A small ghost-style icon action button for the footer.
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: 'p-1 rounded',
        child: WIcon(icon, className: 'text-sm text-slate-400'),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Derives avatar initials from the agent role name (e.g. "Business Analyst"
  /// → "BA", "Developer" → "D"). Falls back to first letter of slug or "AI".
  static String _agentInitials(String? name, String? slug) {
    if (name != null && name.isNotEmpty) {
      return name
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase())
          .take(2)
          .join();
    }
    if (slug != null && slug.isNotEmpty) {
      return slug[0].toUpperCase();
    }
    return 'AI';
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
