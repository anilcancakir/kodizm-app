import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/document_state.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';
import '../../widgets/organisms/markdown_viewer.dart';

/// Knowledge document detail view — displays full document content with
/// markdown rendering and document metadata.
///
/// Fetches the document via [DocumentState.instance.loadDocument] on
/// [initState]. All state is driven by [DocumentState.instance] via a
/// [ListenableBuilder].
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/knowledge/$documentId');
/// // or construct directly:
/// KnowledgeDetailView(projectId: 'proj-uuid-001', documentId: 'doc-uuid-001')
/// ```
class KnowledgeDetailView extends StatefulWidget {
  /// Creates the [KnowledgeDetailView] for the given [projectId] and
  /// [documentId].
  const KnowledgeDetailView({
    required this.projectId,
    required this.documentId,
    super.key,
  });

  /// The ID of the project this document belongs to.
  final String projectId;

  /// The ID of the knowledge document to display.
  final String documentId;

  @override
  State<KnowledgeDetailView> createState() => _KnowledgeDetailViewState();
}

class _KnowledgeDetailViewState extends State<KnowledgeDetailView> {
  // -----------------------------------------------------------------------
  // Category badge className map
  // -----------------------------------------------------------------------

  /// Returns the Tailwind className string for the given document [category].
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

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  /// Loads the document from the API via [DocumentState].
  Future<void> _loadDocument() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await DocumentState.instance.loadDocument(
      teamId,
      widget.projectId,
      widget.documentId,
    );
  }

  // -----------------------------------------------------------------------
  // Formatting helpers
  // -----------------------------------------------------------------------

  /// Formats a [DateTime] as "Mar 25, 2026".
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }

  /// Returns the display name of the document author.
  String _authorName(ProjectDocument doc) {
    if (doc.createdByUserName != null) return doc.createdByUserName!;
    if (doc.createdByAgentRoleName != null) return doc.createdByAgentRoleName!;
    return trans('common.unknown');
  }

  /// Returns the i18n label for the given document [category].
  String _categoryLabel(String? category) {
    if (category == null) return trans('knowledge.category_other');
    return trans('knowledge.category_$category');
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DocumentState.instance,
      builder: (context, _) {
        final document = DocumentState.instance.selectedDocument;

        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            // ---------------------------------------------------------------
            // Header
            // ---------------------------------------------------------------
            PageHeader(
              title: document?.title ?? trans('knowledge.detail_title'),
              leading: WAnchor(
                onTap: () =>
                    MagicRoute.to('/projects/${widget.projectId}/knowledge'),
                child: WDiv(
                  className: '''
                    flex flex-row items-center gap-1
                    px-2 py-1 rounded-lg
                    text-slate-500 dark:text-slate-400
                  ''',
                  children: [
                    WIcon(
                      Icons.arrow_back,
                      className: 'text-base text-slate-500 dark:text-slate-400',
                    ),
                  ],
                ),
              ),
              actions: [
                if (document?.category != null)
                  WDiv(
                    className:
                        'px-2.5 py-1 rounded-full text-xs font-semibold '
                        '${_categoryBadgeClassName(document!.category)}',
                    child: WText(
                      _categoryLabel(document.category),
                      className: 'text-xs font-semibold',
                    ),
                  ),
              ],
            ),

            // ---------------------------------------------------------------
            // Loading state
            // ---------------------------------------------------------------
            if (document == null)
              const WDiv(
                className: 'w-full flex items-center justify-center py-16',
                child: CircularProgressIndicator(),
              )
            else ...[
              // -------------------------------------------------------------
              // Content — main document body
              // -------------------------------------------------------------
              SectionCard(children: [MarkdownViewer(data: document.content)]),

              // -------------------------------------------------------------
              // Metadata
              // -------------------------------------------------------------
              SectionCard(
                title: trans('knowledge.metadata'),
                children: [
                  // Author
                  _MetaRow(
                    label: trans('tasks.created_by'),
                    value: _authorName(document),
                  ),

                  // Category
                  if (document.category != null)
                    _MetaRow(
                      label: trans('knowledge.category_label'),
                      value: _categoryLabel(document.category),
                    ),

                  // Created
                  _MetaRow(
                    label: trans('tasks.created_at_label'),
                    value: _formatDate(document.createdAt),
                  ),

                  // Updated
                  _MetaRow(
                    label: trans('tasks.updated_at_label'),
                    value: _formatDate(document.updatedAt),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Meta row molecule
// ---------------------------------------------------------------------------

/// A simple label + value row used inside the metadata card.
class _MetaRow extends StatelessWidget {
  /// Creates a [_MetaRow] with a [label] and [value].
  const _MetaRow({required this.label, required this.value});

  /// The field label (e.g. "Created by").
  final String label;

  /// The field value (e.g. "Alice Smith").
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-start gap-2',
      children: [
        WText(
          label,
          className:
              'text-xs font-semibold text-slate-500 dark:text-slate-400 w-24 pt-0.5',
        ),
        WDiv(
          className: 'flex-1',
          child: WText(
            value,
            className: 'text-sm text-gray-800 dark:text-gray-200',
          ),
        ),
      ],
    );
  }
}
