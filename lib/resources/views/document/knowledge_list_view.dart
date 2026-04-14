import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/knowledge_state.dart';

// ---------------------------------------------------------------------------
// KnowledgeListView
// ---------------------------------------------------------------------------

/// Unified knowledge list view — displays documents and memories in a single
/// tabbed interface with sub-filters per tab.
///
/// The "Documents" tab shows document entries with category sub-filters.
/// The "Memories" tab shows memory entries with memory_type sub-filters.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/knowledge/$projectId');
/// ```
class KnowledgeListView extends StatefulWidget {
  /// Creates the [KnowledgeListView] for the given [projectId].
  const KnowledgeListView({required this.projectId, super.key});

  /// The project UUID whose knowledge entries to display.
  final String projectId;

  @override
  State<KnowledgeListView> createState() => _KnowledgeListViewState();
}

class _KnowledgeListViewState extends State<KnowledgeListView> {
  /// Active tab: 0 = Documents, 1 = Memories.
  int _activeTab = 0;

  /// Active sub-filter for the current tab.
  String? _activeSubFilter;

  // -----------------------------------------------------------------------
  // Category definitions (documents tab)
  // -----------------------------------------------------------------------

  static const List<String> _categories = [
    'architecture',
    'api',
    'guide',
    'convention',
    'runbook',
    'agent_output',
    'other',
  ];

  // -----------------------------------------------------------------------
  // Memory type definitions (memories tab)
  // -----------------------------------------------------------------------

  static const List<String> _memoryTypes = [
    'feedback',
    'user',
    'project',
    'reference',
  ];

  // -----------------------------------------------------------------------
  // Badge className maps
  // -----------------------------------------------------------------------

  /// Returns Tailwind className for a category badge pill.
  static String _categoryBadgeClassName(String? category) {
    return switch (category) {
      'architecture' => 'bg-indigo-500/15 text-indigo-600 dark:text-indigo-400',
      'api' => 'bg-blue-500/15 text-blue-600 dark:text-blue-400',
      'guide' => 'bg-teal-500/15 text-teal-600 dark:text-teal-400',
      'convention' => 'bg-violet-500/15 text-violet-600 dark:text-violet-400',
      'runbook' => 'bg-amber-500/15 text-amber-600 dark:text-amber-400',
      'agent_output' =>
        'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400',
      _ => 'bg-slate-500/15 text-slate-600 dark:text-slate-400',
    };
  }

  static const _memoryTypeClassNames = {
    'feedback': 'bg-amber-500/10 text-amber-600',
    'user': 'bg-blue-500/10 text-blue-600',
    'project': 'bg-emerald-500/10 text-emerald-600',
    'reference': 'bg-violet-500/10 text-violet-600',
  };

  /// Returns the badge className for a memory type.
  static String _memoryTypeBadgeClassName(String type) {
    return _memoryTypeClassNames[type] ??
        'bg-slate-500/10 text-slate-600 dark:text-slate-400';
  }

  /// Returns the translated label for a memory type.
  static String _memoryTypeLabel(String type) {
    return switch (type) {
      'feedback' => trans('memories.type_feedback'),
      'user' => trans('memories.type_user'),
      'project' => trans('memories.type_project'),
      'reference' => trans('memories.type_reference'),
      _ => type,
    };
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fetches knowledge entries for the current tab and filter.
  Future<void> _fetchData() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    final state = KnowledgeState.instance;

    if (_activeTab == 0) {
      // Documents tab
      await state.loadDocuments(
        teamId,
        widget.projectId,
        type: 'document',
        category: _activeSubFilter,
      );
    } else {
      // Memories tab
      await state.loadMemories(
        teamId,
        widget.projectId,
        memoryType: _activeSubFilter,
      );
    }
  }

  /// Switches the active tab and resets sub-filter.
  void _onTabTap(int tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _activeSubFilter = null;
    });
    _fetchData();
  }

  /// Sets the active sub-filter. Toggles off if already active.
  void _onSubFilterTap(String filter) {
    setState(() {
      _activeSubFilter = _activeSubFilter == filter ? null : filter;
    });
    _fetchData();
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
          title: trans('knowledge.title'),
          actions: [
            if (_activeTab == 1)
              WAnchor(
                onTap: () =>
                    MagicRoute.to('/knowledge/${widget.projectId}/new'),
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
        // Tab chips: Documents | Memories
        // -----------------------------------------------------------------
        WDiv(
          className: 'flex overflow-x-auto gap-2',
          children: [
            _TabChip(
              label: trans('knowledge.documents_tab'),
              isActive: _activeTab == 0,
              onTap: () => _onTabTap(0),
            ),
            _TabChip(
              label: trans('knowledge.memories_tab'),
              isActive: _activeTab == 1,
              onTap: () => _onTabTap(1),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // Sub-filter chips
        // -----------------------------------------------------------------
        if (_activeTab == 0)
          WDiv(
            className: 'flex overflow-x-auto gap-2',
            children: [
              _FilterChip(
                label: trans('documents.category_all'),
                isActive: _activeSubFilter == null,
                onTap: () {
                  setState(() => _activeSubFilter = null);
                  _fetchData();
                },
              ),
              for (final category in _categories)
                _FilterChip(
                  label: trans('documents.category_$category'),
                  isActive: _activeSubFilter == category,
                  onTap: () => _onSubFilterTap(category),
                ),
            ],
          ),
        if (_activeTab == 1)
          WDiv(
            className: 'flex overflow-x-auto gap-2',
            children: [
              for (final memType in _memoryTypes)
                _FilterChip(
                  label: _memoryTypeLabel(memType),
                  isActive: _activeSubFilter == memType,
                  onTap: () => _onSubFilterTap(memType),
                ),
            ],
          ),

        // -----------------------------------------------------------------
        // State-driven content
        // -----------------------------------------------------------------
        KnowledgeState.instance.renderState(
          (items) => _activeTab == 0
              ? _DocumentList(
                  documents: items,
                  projectId: widget.projectId,
                  onRefresh: _fetchData,
                  categoryBadgeClassName: _categoryBadgeClassName,
                )
              : _MemoryList(
                  memories: items,
                  projectId: widget.projectId,
                  onRefresh: _fetchData,
                  typeBadgeClassName: _memoryTypeBadgeClassName,
                  typeLabel: _memoryTypeLabel,
                ),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: _EmptyView(isMemoryTab: _activeTab == 1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab chip (Documents / Memories toggle)
// ---------------------------------------------------------------------------

class _TabChip extends StatelessWidget {
  const _TabChip({
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
                px-4 py-2 rounded-full
                bg-primary-500 dark:bg-primary-600
              '''
            : '''
                px-4 py-2 rounded-full
                bg-white dark:bg-gray-800
                border border-slate-200 dark:border-gray-700
              ''',
        child: WText(
          label,
          className: isActive
              ? 'text-sm font-semibold text-white'
              : 'text-sm font-medium text-slate-600 dark:text-slate-400',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-filter chip
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
          trans('common.error_occurred'),
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
  const _EmptyView({this.isMemoryTab = false});

  final bool isMemoryTab;

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
            isMemoryTab ? Icons.lightbulb_outline : Icons.description_outlined,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          trans('knowledge.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('knowledge.empty_description'),
          className: '''
              text-sm text-slate-500 dark:text-slate-400
              text-center
            ''',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Document list
// ---------------------------------------------------------------------------

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.projectId,
    required this.onRefresh,
    required this.categoryBadgeClassName,
  });

  final List<ProjectDocument> documents;
  final String projectId;
  final Future<void> Function() onRefresh;
  final String Function(String?) categoryBadgeClassName;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: documents.length,
        separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
        itemBuilder: (context, index) => _DocumentCard(
          document: documents[index],
          categoryBadgeClassName: categoryBadgeClassName,
          onTap: () =>
              MagicRoute.to('/knowledge/$projectId/${documents[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document card
// ---------------------------------------------------------------------------

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.categoryBadgeClassName,
    required this.onTap,
  });

  final ProjectDocument document;
  final String Function(String?) categoryBadgeClassName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final creatorName =
        document.createdByUserName ??
        document.createdByAgentRoleName ??
        trans('common.unknown');

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
          WText(
            document.title,
            className: '''
                text-base font-semibold
                text-gray-900 dark:text-white
              ''',
          ),
          WDiv(
            className: 'flex flex-row items-center gap-3',
            children: [
              if (document.category != null)
                WDiv(
                  className:
                      'px-2.5 py-0.5 rounded-full ${categoryBadgeClassName(document.category)}',
                  child: WText(
                    trans('documents.category_${document.category}'),
                    className: 'text-xs font-medium',
                  ),
                ),
              WText(
                trans('documents.created_by', {'name': creatorName}),
                className: 'text-xs text-slate-500 dark:text-slate-400',
              ),
              WText(
                trans('documents.updated_at', {
                  'date': _formatDate(document.updatedAt),
                }),
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats a [DateTime] as a short date string.
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
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

  final List<ProjectDocument> memories;
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
              MagicRoute.to('/knowledge/$projectId/${memories[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Memory card
// ---------------------------------------------------------------------------

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.typeBadgeClassName,
    required this.typeLabel,
    required this.onTap,
  });

  final ProjectDocument memory;
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
          // Header: title + type badge
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              WText(
                memory.title,
                className: '''
                    text-base font-semibold
                    text-gray-900 dark:text-white
                  ''',
              ),
              if (memory.memoryType != null)
                WDiv(
                  className:
                      'px-2.5 py-0.5 rounded-full ${typeBadgeClassName(memory.memoryType!)}',
                  child: WText(
                    typeLabel(memory.memoryType!),
                    className: 'text-xs font-medium',
                  ),
                ),
            ],
          ),

          // Footer: creator
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
        ],
      ),
    );
  }
}
