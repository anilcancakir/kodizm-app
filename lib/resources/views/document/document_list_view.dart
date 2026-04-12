import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/document_state.dart';

// ---------------------------------------------------------------------------
// DocumentListView
// ---------------------------------------------------------------------------

/// Document list view — displays all knowledge-base documents for a project.
///
/// Fetches documents via [DocumentState.instance] on init and renders loading,
/// empty, error, and content states. Provides category filter chips and
/// navigation to individual document detail pages.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/documents/$projectId');
/// ```
class DocumentListView extends StatefulWidget {
  /// Creates the [DocumentListView] for the given [projectId].
  const DocumentListView({required this.projectId, super.key});

  /// The ID of the project whose documents are shown.
  final String projectId;

  @override
  State<DocumentListView> createState() => _DocumentListViewState();
}

class _DocumentListViewState extends State<DocumentListView> {
  /// Currently active category filter. Null means "all".
  String? _activeCategory;

  // -----------------------------------------------------------------------
  // Category definitions
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

  /// Maps a category key to its trans() i18n key.
  static String _categoryTransKey(String category) {
    return 'documents.category_$category';
  }

  // -----------------------------------------------------------------------
  // Category badge className map
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

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  /// Fetches documents for the current project, optionally filtered.
  Future<void> _fetchDocuments() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await DocumentState.instance.loadDocuments(
      teamId,
      widget.projectId,
      category: _activeCategory,
    );
  }

  /// Sets the active category filter and re-fetches.
  void _setCategory(String? category) {
    setState(() => _activeCategory = category);
    _fetchDocuments();
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
          title: trans('documents.title'),
          subtitle: trans('documents.subtitle'),
          actions: [
            WAnchor(
              onTap: () {
                // Create document — future phase, no-op for now.
              },
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-amber-400
                  ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('documents.create_title'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // Category filter chips
        // -----------------------------------------------------------------
        WDiv(
          className: 'flex overflow-x-auto gap-2',
          children: [
            _CategoryChip(
              label: trans('documents.category_all'),
              isActive: _activeCategory == null,
              onTap: () => _setCategory(null),
            ),
            for (final category in _categories)
              _CategoryChip(
                label: trans(_categoryTransKey(category)),
                isActive: _activeCategory == category,
                onTap: () => _setCategory(category),
              ),
          ],
        ),

        // -----------------------------------------------------------------
        // State-driven content
        // -----------------------------------------------------------------
        DocumentState.instance.renderState(
          (documents) => _DocumentList(
            documents: documents,
            projectId: widget.projectId,
            onRefresh: _fetchDocuments,
            categoryBadgeClassName: _categoryBadgeClassName,
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
// Category filter chip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
                bg-primary-500 dark:bg-primary-600
              '''
            : '''
                px-3 py-1.5 rounded-full
                bg-white dark:bg-gray-800
                border border-slate-200 dark:border-gray-700
              ''',
        child: WText(
          label,
          className: isActive
              ? 'text-xs font-medium text-white'
              : 'text-xs font-medium text-slate-600 dark:text-slate-400',
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
            Icons.description_outlined,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          trans('documents.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('documents.empty_subtitle'),
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
              MagicRoute.to('/documents/$projectId/${documents[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document card
// ---------------------------------------------------------------------------

/// Surface card representing a single document.
///
/// Displays: title, category badge, creator name, and updated_at.
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
          // -----------------------------------------------------------------
          // Title row
          // -----------------------------------------------------------------
          WText(
            document.title,
            className: '''
                text-base font-semibold
                text-gray-900 dark:text-white
              ''',
          ),

          // -----------------------------------------------------------------
          // Footer: category badge + creator + updated_at
          // -----------------------------------------------------------------
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
