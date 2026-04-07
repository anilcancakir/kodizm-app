import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/document_state.dart';

// ---------------------------------------------------------------------------
// DocumentDetailView
// ---------------------------------------------------------------------------

/// Document detail screen — displays full content for a single document.
///
/// Shows title, content (via SelectableText), category badge, creator
/// attribution, and timestamps. Supports inline editing of title and content
/// via a toggle, and delete with confirmation dialog.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/documents/$documentId');
/// ```
class DocumentDetailView extends StatefulWidget {
  /// Creates a [DocumentDetailView] for the given [projectId] and [documentId].
  const DocumentDetailView({
    required this.projectId,
    required this.documentId,
    super.key,
  });

  /// The project UUID this document belongs to.
  final String projectId;

  /// The document UUID to display.
  final String documentId;

  @override
  State<DocumentDetailView> createState() => _DocumentDetailViewState();
}

class _DocumentDetailViewState extends State<DocumentDetailView> {
  bool _loading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

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
    _loadDocument();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Fetches the document and updates local state.
  Future<void> _loadDocument() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    setState(() => _loading = true);

    await DocumentState.instance.loadDocument(
      teamId,
      widget.projectId,
      widget.documentId,
    );

    setState(() => _loading = false);
  }

  // -----------------------------------------------------------------------
  // Editing
  // -----------------------------------------------------------------------

  /// Enters edit mode, pre-filling controllers with current values.
  void _startEditing() {
    final doc = DocumentState.instance.selectedDocument;
    if (doc == null) return;

    _titleController.text = doc.title;
    _contentController.text = doc.content;
    DocumentState.instance.setEditing(value: true);
  }

  /// Cancels editing and resets controllers.
  void _cancelEditing() {
    DocumentState.instance.setEditing(value: false);
  }

  /// Saves edits via the state controller.
  Future<void> _saveEdits() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await DocumentState.instance.updateDocument(
      teamId,
      widget.projectId,
      widget.documentId,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );

    DocumentState.instance.setEditing(value: false);
    await _loadDocument();
  }

  // -----------------------------------------------------------------------
  // Delete
  // -----------------------------------------------------------------------

  /// Shows a confirmation dialog and deletes the document on confirm.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: WText(
          trans('common.delete'),
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        content: WText(
          trans('documents.delete_confirm'),
          className: 'text-sm text-slate-600 dark:text-slate-400',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: WText(
              trans('common.cancel'),
              className: 'text-sm text-slate-500',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: WText(
              trans('common.delete'),
              className: 'text-sm text-red-500',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    final deleted = await DocumentState.instance.deleteDocument(
      teamId,
      widget.projectId,
      widget.documentId,
    );

    if (deleted && mounted) {
      MagicRoute.to('/projects/${widget.projectId}/documents');
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const WDiv(
        className: 'w-full flex items-center justify-center py-16',
        child: CircularProgressIndicator(),
      );
    }

    return ListenableBuilder(
      listenable: DocumentState.instance,
      builder: (context, _) {
        final doc = DocumentState.instance.selectedDocument;

        if (doc == null) {
          return _buildNotFound();
        }

        final isEditing = DocumentState.instance.isEditing;

        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            // -------------------------------------------------------------
            // Header
            // -------------------------------------------------------------
            MagicStarterPageHeader(
              title: doc.title,
              actions: [
                if (!isEditing) ...[
                  WAnchor(
                    onTap: _startEditing,
                    child: WDiv(
                      className: '''
                          flex flex-row items-center gap-2
                          px-4 py-2 rounded-lg
                          bg-white dark:bg-gray-800
                          border border-slate-200 dark:border-gray-700
                        ''',
                      children: [
                        WIcon(
                          Icons.edit_outlined,
                          className: 'text-base text-primary-500',
                        ),
                        WText(
                          trans('common.edit'),
                          className: 'text-sm font-semibold text-primary-500',
                        ),
                      ],
                    ),
                  ),
                  WAnchor(
                    onTap: _confirmDelete,
                    child: WDiv(
                      className: '''
                          flex flex-row items-center gap-2
                          px-4 py-2 rounded-lg
                          bg-white dark:bg-gray-800
                          border border-red-300 dark:border-red-700
                        ''',
                      children: [
                        WIcon(
                          Icons.delete_outline,
                          className: 'text-base text-red-500',
                        ),
                        WText(
                          trans('common.delete'),
                          className: 'text-sm font-semibold text-red-500',
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // -------------------------------------------------------------
            // Metadata: category + creator + timestamps
            // -------------------------------------------------------------
            _MetadataRow(
              document: doc,
              categoryBadgeClassName: _categoryBadgeClassName,
            ),

            // -------------------------------------------------------------
            // Content card — display or edit mode
            // -------------------------------------------------------------
            if (isEditing)
              _EditForm(
                titleController: _titleController,
                contentController: _contentController,
                onSave: _saveEdits,
                onCancel: _cancelEditing,
              )
            else
              _ContentCard(content: doc.content),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Not found state
  // -----------------------------------------------------------------------

  /// Displays a not-found message when the document cannot be loaded.
  Widget _buildNotFound() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('documents.title')),
        WDiv(
          className:
              'w-full flex flex-col items-center justify-center py-16 gap-4',
          children: [
            WIcon(
              Icons.search_off,
              className: 'text-4xl text-slate-300 dark:text-slate-600',
            ),
            WText(
              trans('documents.not_found'),
              className:
                  'text-lg font-semibold text-slate-500 dark:text-slate-400',
            ),
            WText(
              trans('documents.not_found_subtitle'),
              className: '''
                  text-sm text-slate-400 dark:text-slate-500
                  text-center
                ''',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata row
// ---------------------------------------------------------------------------

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.document,
    required this.categoryBadgeClassName,
  });

  final ProjectDocument document;
  final String Function(String?) categoryBadgeClassName;

  @override
  Widget build(BuildContext context) {
    final creatorName =
        document.createdByUserName ??
        document.createdByAgentRoleName ??
        trans('common.unknown');

    return WDiv(
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
          className: 'text-sm text-slate-500 dark:text-slate-400',
        ),
        WText(
          trans('documents.updated_at', {
            'date': _formatDate(document.updatedAt),
          }),
          className: 'text-sm text-slate-400 dark:text-slate-500',
        ),
      ],
    );
  }

  /// Formats a [DateTime] as a short date string.
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }
}

// ---------------------------------------------------------------------------
// Content card (read-only)
// ---------------------------------------------------------------------------

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return MagicStarterCard(
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'AlbertSans',
          fontSize: 14,
          height: 1.6,
          color: WindTheme.dataOf(context).getColor('slate', 600),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit form (inline)
// ---------------------------------------------------------------------------

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.titleController,
    required this.contentController,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return MagicStarterCard(
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Title input
          WFormInput(
            controller: titleController,
            label: trans('documents.form_title'),
          ),

          // Content input
          WFormInput(
            controller: contentController,
            label: trans('documents.form_content'),
            maxLines: 12,
          ),

          // Action buttons — right-aligned
          WDiv(
            className: 'w-full flex flex-row items-center justify-end gap-3',
            children: [
              WAnchor(
                onTap: onCancel,
                child: WDiv(
                  className: '''
                      px-4 py-2 rounded-lg
                      bg-white dark:bg-gray-800
                      border border-slate-200 dark:border-gray-700
                    ''',
                  child: WText(
                    trans('common.cancel'),
                    className:
                        'text-sm font-medium text-slate-600 dark:text-slate-400',
                  ),
                ),
              ),
              WAnchor(
                onTap: onSave,
                child: WDiv(
                  className: '''
                      px-4 py-2 rounded-lg
                      bg-amber-400
                    ''',
                  child: WText(
                    trans('documents.save'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
