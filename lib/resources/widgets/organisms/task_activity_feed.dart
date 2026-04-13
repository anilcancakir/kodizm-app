import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation.dart';
import '../../../app/models/task_section.dart';
import '../atoms/status_badge.dart';
import 'markdown_viewer.dart';

// ---------------------------------------------------------------------------
// Private: unified activity item
// ---------------------------------------------------------------------------

class _ActivityItem {
  const _ActivityItem({required this.date, required this.widget});

  final DateTime date;
  final Widget widget;
}

// ---------------------------------------------------------------------------
// TaskActivityFeed
// ---------------------------------------------------------------------------

/// Tabbed activity feed showing sections and runs for a task.
///
/// Renders a two-tab interface — "All" interleaves [sections] and
/// [conversations] sorted newest-first; "Runs" shows only [conversations].
///
/// ## Usage
///
/// ```dart
/// TaskActivityFeed(
///   sections: task.sections,
///   conversations: task.conversations,
///   projectId: task.projectId,
/// )
/// ```
class TaskActivityFeed extends StatefulWidget {
  /// Creates a [TaskActivityFeed].
  const TaskActivityFeed({
    super.key,
    required this.sections,
    required this.conversations,
    required this.projectId,
  });

  /// The task sections to display in the feed.
  final List<TaskSection> sections;

  /// The conversations (runs) to display in the feed.
  final List<Conversation> conversations;

  /// The project ID used for building conversation route URLs.
  final String projectId;

  @override
  State<TaskActivityFeed> createState() => _TaskActivityFeedState();
}

class _TaskActivityFeedState extends State<TaskActivityFeed> {
  // -------
  int _activeTab = 0;

  // -------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [_buildTabBar(), _buildContent()],
    );
  }

  // -----------------------------------------------------------------------
  // Tab bar
  // -----------------------------------------------------------------------

  Widget _buildTabBar() {
    return WDiv(
      className:
          'flex flex-row border-b border-slate-200 dark:border-slate-700',
      children: [
        _buildTab(0, trans('tasks.detail_tab_all')),
        _buildTab(1, trans('tasks.detail_tab_runs')),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final bool isActive = _activeTab == index;

    return WDiv(
      className: isActive
          ? 'flex-1 border-b-2 border-secondary-400'
          : 'flex-1 border-b-2 border-transparent',
      child: WAnchor(
        onTap: () => setState(() => _activeTab = index),
        child: WDiv(
          className: 'text-center py-2.5',
          child: WText(
            label,
            className: isActive
                ? 'text-sm font-semibold text-primary-700 dark:text-white'
                : 'text-sm font-medium text-slate-400 dark:text-slate-500',
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Content
  // -----------------------------------------------------------------------

  Widget _buildContent() {
    final bool isEmpty =
        widget.sections.isEmpty && widget.conversations.isEmpty;

    if (isEmpty) {
      return _buildEmptyState();
    }

    if (_activeTab == 1) {
      return _buildRunsList();
    }

    return _buildAllList();
  }

  Widget _buildEmptyState() {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-8 gap-3',
      children: [
        WIcon(
          Icons.history,
          className: 'text-4xl text-slate-300 dark:text-slate-600',
        ),
        WText(
          trans('tasks.detail_no_activity'),
          className: 'text-sm text-slate-500 dark:text-slate-400 text-center',
        ),
      ],
    );
  }

  Widget _buildAllList() {
    final List<_ActivityItem> items = [
      for (final section in widget.sections)
        _ActivityItem(
          date: section.createdAt,
          widget: _buildSectionCard(section),
        ),
      for (final conv in widget.conversations)
        _ActivityItem(
          date: conv.startedAt ?? conv.createdAt,
          widget: _buildConversationRow(conv),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return WDiv(
      className: 'flex flex-col gap-4',
      children: items.map((item) => item.widget).toList(),
    );
  }

  Widget _buildRunsList() {
    final List<_ActivityItem> items = [
      for (final conv in widget.conversations)
        _ActivityItem(
          date: conv.startedAt ?? conv.createdAt,
          widget: _buildConversationRow(conv),
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return WDiv(
      className: 'flex flex-col gap-3',
      children: items.map((item) => item.widget).toList(),
    );
  }

  // -----------------------------------------------------------------------
  // Section card
  // -----------------------------------------------------------------------

  Widget _buildSectionCard(TaskSection section) {
    final String typeLabel = trans(
      'tasks.section_type_${section.type.replaceAll('-', '_')}',
    );

    return WDiv(
      className:
          '''flex flex-col gap-3 p-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800''',
      children: [
        // Header row: type badge + title + version badge
        WDiv(
          className: 'flex flex-row gap-2 items-center',
          children: [
            WDiv(
              className: 'px-1.5 py-0.5 rounded bg-indigo-500/10',
              child: WText(
                typeLabel,
                className: 'text-[11px] font-semibold text-indigo-500',
              ),
            ),
            WDiv(
              className: 'flex-1',
              child: WText(
                section.title,
                className:
                    'text-sm font-semibold text-primary-700 dark:text-white',
              ),
            ),
            WDiv(
              className: 'px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700',
              child: WText(
                'v${section.version}',
                className: 'text-[11px] text-slate-500 dark:text-slate-400',
              ),
            ),
          ],
        ),
        // Date
        WText(
          _formatDate(section.createdAt),
          className: 'text-xs text-slate-400 dark:text-slate-500',
        ),
        // Markdown content
        MarkdownViewer(data: section.content, selectable: false),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Conversation row
  // -----------------------------------------------------------------------

  Widget _buildConversationRow(Conversation conv) {
    final String cost = conv.totalCostUsd != null
        ? '\$${conv.totalCostUsd!.toStringAsFixed(2)}'
        : '--';

    final DateTime date = conv.startedAt ?? conv.createdAt;

    return WAnchor(
      onTap: () =>
          MagicRoute.to('/conversations/${widget.projectId}/chats/${conv.id}'),
      child: WDiv(
        className:
            '''flex flex-row gap-3 items-center p-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800''',
        children: [
          // Agent role name + optional prompt subtitle
          WDiv(
            className: 'flex-1 flex flex-col',
            children: [
              WText(
                conv.agentRoleName ?? '--',
                className:
                    'text-sm font-medium text-primary-700 dark:text-white',
              ),
              if (conv.prompt != null && conv.prompt!.isNotEmpty)
                WText(
                  conv.prompt!,
                  className:
                      'text-xs text-slate-500 dark:text-slate-400 truncate',
                ),
            ],
          ),
          // Status badge
          StatusBadge(status: conv.status),
          // Cost
          WText(cost, className: 'text-xs text-slate-500 dark:text-slate-400'),
          // Date
          WText(
            _formatDate(date),
            className: 'text-xs text-slate-400 dark:text-slate-500',
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Date formatting
  // -----------------------------------------------------------------------

  String _formatDate(DateTime date) {
    final String month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }
}
