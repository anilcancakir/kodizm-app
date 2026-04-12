import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_memory.dart';
import '../../../app/models/user.dart';
import '../../../app/state/memory_state.dart';

// ---------------------------------------------------------------------------
// MemoryListView
// ---------------------------------------------------------------------------

/// Memory list view — displays project memory entries with type filtering.
///
/// Fetches memories via [MemoryState.instance] on init and renders loading,
/// empty, error, and content states. Provides type-based filtering and
/// navigation to individual memory detail pages.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/memories/$projectId');
/// // or construct directly:
/// MemoryListView(projectId: 'proj-uuid-001')
/// ```
class MemoryListView extends StatefulWidget {
  /// Creates the [MemoryListView] for the given [projectId].
  const MemoryListView({required this.projectId, super.key});

  /// The project UUID whose memories to display.
  final String projectId;

  @override
  State<MemoryListView> createState() => _MemoryListViewState();
}

class _MemoryListViewState extends State<MemoryListView> {
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _fetchMemories();
  }

  /// Fetches memories for the current team and project.
  Future<void> _fetchMemories({String? type}) async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await MemoryState.instance.loadMemories(
      teamId,
      widget.projectId,
      type: type,
    );
  }

  /// Applies a type filter. Toggles off if already active.
  void _onFilterTap(String type) {
    setState(() {
      _activeFilter = _activeFilter == type ? null : type;
    });
    _fetchMemories(type: _activeFilter);
  }

  // -----------------------------------------------------------------------
  // Type badge className map
  // -----------------------------------------------------------------------

  static const _typeClassNames = {
    'feedback': 'bg-amber-500/10 text-amber-600',
    'user': 'bg-blue-500/10 text-blue-600',
    'project': 'bg-emerald-500/10 text-emerald-600',
    'reference': 'bg-violet-500/10 text-violet-600',
  };

  /// Returns the badge className for a memory type.
  static String _typeBadgeClassName(String type) {
    return _typeClassNames[type] ??
        'bg-slate-500/10 text-slate-600 dark:text-slate-400';
  }

  /// Returns the translated label for a memory type.
  static String _typeLabel(String type) {
    return switch (type) {
      'feedback' => trans('memories.type_feedback'),
      'user' => trans('memories.type_user'),
      'project' => trans('memories.type_project'),
      'reference' => trans('memories.type_reference'),
      _ => type,
    };
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: trans('memories.title'),
          subtitle: trans('memories.subtitle'),
          actions: [
            WAnchor(
              onTap: () => MagicRoute.to('/memories/${widget.projectId}/new'),
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-amber-400
                  ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('memories.create_title'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // Type filter chips
        // -----------------------------------------------------------------
        WDiv(
          className: 'flex overflow-x-auto gap-2',
          children: [
            _FilterChip(
              label: trans('memories.type_feedback'),
              isActive: _activeFilter == 'feedback',
              onTap: () => _onFilterTap('feedback'),
            ),
            _FilterChip(
              label: trans('memories.type_user'),
              isActive: _activeFilter == 'user',
              onTap: () => _onFilterTap('user'),
            ),
            _FilterChip(
              label: trans('memories.type_project'),
              isActive: _activeFilter == 'project',
              onTap: () => _onFilterTap('project'),
            ),
            _FilterChip(
              label: trans('memories.type_reference'),
              isActive: _activeFilter == 'reference',
              onTap: () => _onFilterTap('reference'),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // State-driven content
        // -----------------------------------------------------------------
        MemoryState.instance.renderState(
          (memories) => _MemoryList(
            memories: memories,
            projectId: widget.projectId,
            onRefresh: () => _fetchMemories(type: _activeFilter),
            typeBadgeClassName: _typeBadgeClassName,
            typeLabel: _typeLabel,
          ),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: const _EmptyView(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: isActive
            ? '''
                px-3 py-1.5 rounded-full
                bg-amber-400 border border-amber-400
              '''
            : '''
                px-3 py-1.5 rounded-full
                bg-white dark:bg-gray-800
                border border-slate-200 dark:border-gray-700
              ''',
        child: WText(
          label,
          className: isActive
              ? 'text-xs font-semibold text-primary-900'
              : 'text-xs font-medium text-slate-500 dark:text-slate-400',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          trans('common.error'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        WText(message, className: 'text-sm text-slate-500 dark:text-slate-400'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state view
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-5',
      children: [
        WDiv(
          className: '''
              w-16 h-16 rounded-2xl flex items-center justify-center
              bg-slate-100 dark:bg-gray-800
            ''',
          child: WIcon(
            Icons.lightbulb_outline,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          trans('memories.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('memories.empty_subtitle'),
          className: '''
              text-sm text-slate-500 dark:text-slate-400
              max-w-xs text-center
            ''',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Memory list
// ---------------------------------------------------------------------------

class _MemoryList extends StatelessWidget {
  const _MemoryList({
    required this.memories,
    required this.projectId,
    required this.onRefresh,
    required this.typeBadgeClassName,
    required this.typeLabel,
  });

  final List<ProjectMemory> memories;
  final String projectId;
  final Future<void> Function() onRefresh;
  final String Function(String) typeBadgeClassName;
  final String Function(String) typeLabel;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: memories.length,
        separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
        itemBuilder: (context, index) => _MemoryCard(
          memory: memories[index],
          typeBadgeClassName: typeBadgeClassName,
          typeLabel: typeLabel,
          onTap: () =>
              MagicRoute.to('/memories/$projectId/${memories[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Memory card
// ---------------------------------------------------------------------------

/// Surface card representing a single memory entry.
///
/// Displays: name, description, type badge, last_synced_at, creator.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.typeBadgeClassName,
    required this.typeLabel,
    required this.onTap,
  });

  final ProjectMemory memory;
  final String Function(String) typeBadgeClassName;
  final String Function(String) typeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final creator =
        memory.createdByUserName ?? memory.createdByAgentRoleName ?? '';

    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: '''
            rounded-xl bg-white dark:bg-gray-800
            border border-slate-200 dark:border-gray-700
            shadow-sm p-5
            flex flex-col gap-3
          ''',
        children: [
          // -----------------------------------------------------------------
          // Header: name + type badge
          // -----------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              WText(
                memory.name,
                className: '''
                    text-base font-semibold
                    text-gray-900 dark:text-white
                  ''',
              ),
              WDiv(
                className:
                    'px-2.5 py-0.5 rounded-full ${typeBadgeClassName(memory.type)}',
                child: WText(
                  typeLabel(memory.type),
                  className: 'text-xs font-medium',
                ),
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // Description
          // -----------------------------------------------------------------
          if (memory.description.isNotEmpty)
            WText(
              memory.description,
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),

          // -----------------------------------------------------------------
          // Footer: creator + last synced
          // -----------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-3',
            children: [
              if (creator.isNotEmpty)
                WDiv(
                  className: 'flex flex-row items-center gap-1.5',
                  children: [
                    WIcon(
                      Icons.person_outline,
                      className: 'text-xs text-slate-400',
                    ),
                    WText(
                      creator,
                      className: 'text-xs text-slate-400 dark:text-slate-500',
                    ),
                  ],
                ),
              if (memory.lastSyncedAt != null)
                WDiv(
                  className: 'flex flex-row items-center gap-1.5',
                  children: [
                    WIcon(Icons.sync, className: 'text-xs text-slate-400'),
                    WText(
                      trans('memories.last_synced', {
                        'date': _formatDate(memory.lastSyncedAt!),
                      }),
                      className: 'text-xs text-slate-400 dark:text-slate-500',
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats a [DateTime] as a short date string.
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
