import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation_message.dart';
import '../../../app/models/message_attachment.dart';
import '../atoms/attachment_thumbnail.dart';
import '../atoms/pdf_file_card.dart';
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
    this.onCancelMessage,
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

  /// Called when the user taps the cancel button on a queued message.
  /// Receives the message ID to cancel.
  final void Function(String messageId)? onCancelMessage;

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
    final bool isCancelled = widget.message.status == 'cancelled';

    return WDiv(
      className:
          'w-full flex flex-row justify-end gap-2.5 mb-3${isCancelled ? ' opacity-50' : ''}',
      children: [
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col items-end',
          children: [
            WDiv(
              className:
                  'px-3.5 py-2.5 rounded-2xl rounded-br-sm bg-secondary-400/15',
              children: [
                if (widget.message.hasAttachments)
                  _buildAttachments(widget.message.attachments),
                if (widget.message.content != null &&
                    widget.message.content!.isNotEmpty)
                  WText(
                    widget.message.content!,
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
            if (widget.message.status != null)
              _buildStatusBadge(widget.message),
          ],
        ),
        _buildUserAvatar(),
      ],
    );
  }

  /// Renders image and PDF attachments before the message text.
  ///
  /// Images are shown in a horizontal scrolling row ([overflow-x-auto]).
  /// PDFs are stacked vertically below the image row.
  Widget _buildAttachments(List<MessageAttachment> attachments) {
    final List<MessageAttachment> images = attachments
        .where((a) => a.isImage)
        .toList();
    final List<MessageAttachment> pdfs = attachments
        .where((a) => a.isPdf)
        .toList();

    return WDiv(
      className: 'flex flex-col gap-1.5 mb-2',
      children: [
        if (images.isNotEmpty)
          WDiv(
            className: 'overflow-x-auto',
            child: WDiv(
              className: 'flex flex-row gap-2',
              children: [
                for (final image in images)
                  AttachmentThumbnail(attachment: image),
              ],
            ),
          ),
        for (final pdf in pdfs) PdfFileCard(attachment: pdf),
      ],
    );
  }

  /// Status badge shown below user message bubbles when [message.status] is set.
  ///
  /// Displays a coloured pill label and, for queued messages, a cancel button
  /// that invokes [onCancelMessage] when tapped.
  Widget _buildStatusBadge(ConversationMessage message) {
    final (
      String? badgeClass,
      String? labelKey,
      bool showCancel,
    ) = switch (message.status) {
      'queued' => (
        'bg-amber-500/10 text-amber-600 dark:text-amber-400',
        'conversation_chat.status_queued',
        true,
      ),
      'delivering' => (
        'bg-blue-500/10 text-blue-500',
        'conversation_chat.status_delivering',
        false,
      ),
      'cancelled' => (
        'bg-slate-500/10 text-slate-400',
        'conversation_chat.status_cancelled',
        false,
      ),
      'failed' => (
        'bg-red-500/10 text-red-500',
        'conversation_chat.status_failed_delivery',
        false,
      ),
      _ => (null, null, false),
    };

    if (badgeClass == null) return const SizedBox.shrink();

    return WDiv(
      className: 'flex flex-row items-center gap-2 mt-1',
      children: [
        WDiv(
          className: 'px-2 py-0.5 rounded-full $badgeClass',
          child: WText(trans(labelKey!), className: 'text-xs'),
        ),
        if (showCancel && widget.onCancelMessage != null)
          WAnchor(
            onTap: () => widget.onCancelMessage!(message.id),
            child: WIcon(
              Icons.close_rounded,
              className: 'text-sm text-slate-400',
            ),
          ),
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
                          widget.message.content ?? '',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      )
                    : MarkdownViewer(data: widget.message.content ?? ''),
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
    Clipboard.setData(ClipboardData(text: widget.message.content ?? ''));
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
