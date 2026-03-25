import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/document_state.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';

/// Knowledge base list view — displays project knowledge documents.
///
/// Fetches documents via [DocumentState.instance] on init and renders
/// loading, empty, and content states.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/knowledge');
/// // or construct directly:
/// KnowledgeListView(projectId: 'proj-uuid-001')
/// ```
class KnowledgeListView extends StatefulWidget {
  /// Creates the [KnowledgeListView] for the given [projectId].
  const KnowledgeListView({required this.projectId, super.key});

  /// The ID of the project whose knowledge documents are shown.
  final String projectId;

  @override
  State<KnowledgeListView> createState() => _KnowledgeListViewState();
}

class _KnowledgeListViewState extends State<KnowledgeListView> {
  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  /// Loads documents for the current team and project.
  Future<void> _loadDocuments() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await DocumentState.instance.loadDocuments(teamId, widget.projectId);
  }

  // -----------------------------------------------------------------------
  // Category badge helpers
  // -----------------------------------------------------------------------

  /// Returns a Tailwind className string for the given document [category].
  static String _categoryBadgeClassName(String? category) {
    return switch (category) {
      'architecture' => 'bg-indigo-500/10 text-indigo-500',
      'api' => 'bg-blue-500/10 text-blue-500',
      'guide' => 'bg-emerald-500/10 text-emerald-500',
      'convention' => 'bg-violet-500/10 text-violet-500',
      'runbook' => 'bg-amber-500/10 text-amber-500',
      'agent_output' => 'bg-teal-500/10 text-teal-500',
      _ => 'bg-slate-500/10 text-slate-500',
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
        // -------------------------------------------------------------------
        // Header
        // -------------------------------------------------------------------
        PageHeader(
          title: trans('knowledge.title'),
          subtitle: trans('knowledge.subtitle'),
        ),

        // -------------------------------------------------------------------
        // State-driven content
        // -------------------------------------------------------------------
        ListenableBuilder(
          listenable: DocumentState.instance,
          builder: (context, _) {
            if (DocumentState.instance.isLoading) {
              return _buildLoading();
            }
            if (DocumentState.instance.isEmpty) {
              return _buildEmpty();
            }
            if (DocumentState.instance.isSuccess) {
              return _buildContent(DocumentState.instance.rxState!);
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

  /// Centered spinner shown while documents are loading.
  Widget _buildLoading() {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }

  // -----------------------------------------------------------------------
  // Empty state
  // -----------------------------------------------------------------------

  /// Centered empty state shown when no documents exist.
  Widget _buildEmpty() {
    return SectionCard(
      children: [
        WDiv(
          className:
              'w-full flex flex-col items-center justify-center py-16 gap-4',
          children: [
            WIcon(
              Icons.library_books_outlined,
              className: 'text-4xl text-slate-300',
            ),
            WText(
              trans('knowledge.empty_title'),
              className: 'text-lg font-semibold text-slate-500',
            ),
            WText(
              trans('knowledge.empty_subtitle'),
              className: 'text-sm text-slate-400',
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Content state
  // -----------------------------------------------------------------------

  /// Document card list shown when documents are loaded.
  Widget _buildContent(List<ProjectDocument> documents) {
    return SectionCard(
      children: [for (final doc in documents) _buildDocumentCard(doc)],
    );
  }

  /// A tappable card for a single [ProjectDocument].
  Widget _buildDocumentCard(ProjectDocument doc) {
    final authorName =
        doc.createdByUserName ??
        doc.createdByAgentRoleName ??
        trans('common.unknown');

    return WAnchor(
      onTap: () =>
          MagicRoute.to('/projects/${widget.projectId}/knowledge/${doc.id}'),
      child: WDiv(
        className: '''
          rounded-xl bg-white dark:bg-gray-800
          border border-slate-200 dark:border-gray-700
          shadow-sm p-4
          flex flex-col gap-2
        ''',
        children: [
          // -----------------------------------------------------------------
          // Title row
          // -----------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WDiv(
                className: 'flex-1',
                child: WText(
                  doc.title,
                  className:
                      'text-base font-semibold text-slate-800 dark:text-white',
                ),
              ),
              if (doc.category != null)
                WDiv(
                  className:
                      '''
                    px-2.5 py-1 rounded-full text-xs font-medium
                    ${_categoryBadgeClassName(doc.category)}
                  ''',
                  child: WText(
                    trans('knowledge.category_${doc.category}'),
                    className: 'text-xs font-medium',
                  ),
                ),
            ],
          ),

          // -----------------------------------------------------------------
          // Meta row — author credit
          // -----------------------------------------------------------------
          WText(
            trans('knowledge.created_by', {'name': authorName}),
            className: 'text-xs text-slate-400 dark:text-slate-500',
          ),
        ],
      ),
    );
  }
}
