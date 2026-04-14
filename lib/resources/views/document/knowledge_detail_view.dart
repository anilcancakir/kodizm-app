import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_document.dart';
import '../../../app/models/user.dart';
import '../../../app/state/knowledge_state.dart';

// ---------------------------------------------------------------------------
// KnowledgeDetailView
// ---------------------------------------------------------------------------

/// Unified knowledge detail screen for both documents and memories.
///
/// Displays full content for a single knowledge entry, supports inline
/// editing, deletion, and handles both document and memory types with
/// conditional form fields.
///
/// When [isCreateMode] is `true`, the view starts with empty form fields
/// for creating a new memory entry.
///
/// ## Usage
///
/// ```dart
/// // View existing entry:
/// MagicRoute.to('/knowledge/$projectId/$entryId');
///
/// // Create new memory:
/// KnowledgeDetailView(projectId: 'proj-uuid', isCreateMode: true)
/// ```
class KnowledgeDetailView extends StatefulWidget {
  /// Creates a [KnowledgeDetailView].
  const KnowledgeDetailView({
    required this.projectId,
    this.entryId,
    this.isCreateMode = false,
    super.key,
  });

  /// The project UUID this entry belongs to.
  final String projectId;

  /// The entry UUID to display. Null when [isCreateMode] is `true`.
  final String? entryId;

  /// When `true`, the view starts in create mode with empty form fields.
  final bool isCreateMode;

  @override
  State<KnowledgeDetailView> createState() => _KnowledgeDetailViewState();
}

class _KnowledgeDetailViewState extends State<KnowledgeDetailView> {
  bool _loading = true;
  bool _saving = false;

  // -----------------------------------------------------------------------
  // Form controllers
  // -----------------------------------------------------------------------

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedMemoryType = 'feedback';

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
    if (widget.isCreateMode) {
      _loading = false;
    } else {
      _loadEntry();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Data loading
  // -----------------------------------------------------------------------

  /// Resolves the current team ID from the authenticated user.
  String? get _teamId => Auth.user<User>()?.currentTeam?.id;

  /// Loads the knowledge entry by ID.
  Future<void> _loadEntry() async {
    final teamId = _teamId;
    if (teamId == null || widget.entryId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    await KnowledgeState.instance.loadDocument(
      teamId,
      widget.projectId,
      widget.entryId!,
    );

    setState(() => _loading = false);
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  /// Enters edit mode with current values pre-filled.
  void _startEditing() {
    final doc = KnowledgeState.instance.selectedDocument;
    if (doc == null) return;

    _titleController.text = doc.title;
    _contentController.text = doc.content;
    if (doc.memoryType != null) {
      _selectedMemoryType = doc.memoryType!;
    }
    KnowledgeState.instance.setEditing(value: true);
  }

  /// Cancels editing.
  void _cancelEditing() {
    KnowledgeState.instance.setEditing(value: false);
  }

  /// Saves edits.
  Future<void> _saveEdits() async {
    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _saving = true);

    await KnowledgeState.instance.updateDocument(
      teamId,
      widget.projectId,
      widget.entryId!,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
    );

    setState(() => _saving = false);
    KnowledgeState.instance.setEditing(value: false);
    await _loadEntry();
  }

  /// Saves a new memory entry.
  Future<void> _createMemory() async {
    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _saving = true);

    final created = await KnowledgeState.instance.createMemory(
      teamId,
      widget.projectId,
      _titleController.text.trim(),
      _contentController.text.trim(),
      _selectedMemoryType,
    );

    setState(() => _saving = false);

    if (created != null) {
      MagicRoute.to('/knowledge/${widget.projectId}/${created.id}');
    }
  }

  /// Shows a delete confirmation dialog and deletes the entry.
  Future<void> _confirmDelete() async {
    final doc = KnowledgeState.instance.selectedDocument;
    final confirmMessage = doc?.isMemory == true
        ? trans('memories.delete_confirm')
        : trans('documents.delete_confirm');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: WText(
          trans('common.delete'),
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        content: WText(
          confirmMessage,
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

    final teamId = _teamId;
    if (teamId == null || widget.entryId == null) return;

    final deleted = await KnowledgeState.instance.deleteDocument(
      teamId,
      widget.projectId,
      widget.entryId!,
    );

    if (deleted && mounted) {
      MagicRoute.to('/knowledge/${widget.projectId}');
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

    if (widget.isCreateMode) {
      return _buildCreateMode();
    }

    return ListenableBuilder(
      listenable: KnowledgeState.instance,
      builder: (context, _) {
        final doc = KnowledgeState.instance.selectedDocument;

        if (doc == null) {
          return _buildNotFound();
        }

        final isEditing = KnowledgeState.instance.isEditing;

        return MagicTitle(
          title: doc.title,
          child: isEditing ? _buildEditMode(doc) : _buildReadMode(doc),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Read mode
  // -----------------------------------------------------------------------

  Widget _buildReadMode(ProjectDocument doc) {
    final creatorName =
        doc.createdByUserName ??
        doc.createdByAgentRoleName ??
        trans('common.unknown');

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // Header
        MagicStarterPageHeader(
          title: doc.title,
          actions: [
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
        ),

        // Metadata row
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            // Category badge (documents)
            if (!doc.isMemory && doc.category != null)
              WDiv(
                className:
                    'px-2.5 py-0.5 rounded-full ${_categoryBadgeClassName(doc.category)}',
                child: WText(
                  trans('documents.category_${doc.category}'),
                  className: 'text-xs font-medium',
                ),
              ),
            // Memory type badge
            if (doc.isMemory && doc.memoryType != null)
              WDiv(
                className:
                    'px-2.5 py-0.5 rounded-full ${_memoryTypeBadgeClassName(doc.memoryType!)}',
                child: WText(
                  _memoryTypeLabel(doc.memoryType!),
                  className: 'text-xs font-medium',
                ),
              ),
            // Auto-inject badge
            if (doc.isMemory && doc.autoInject == true)
              WDiv(
                className:
                    'px-2.5 py-0.5 rounded-full bg-green-500/15 text-green-600 dark:text-green-400',
                child: WText(
                  trans('knowledge.auto_inject'),
                  className: 'text-xs font-medium',
                ),
              ),
            WText(
              trans('documents.created_by', {'name': creatorName}),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            WText(
              trans('documents.updated_at', {
                'date': _formatDate(doc.updatedAt),
              }),
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
          ],
        ),

        // Content card
        if (doc.content.isNotEmpty)
          MagicStarterCard(
            child: SelectableText(
              doc.content,
              style: TextStyle(
                fontFamily: 'AlbertSans',
                fontSize: 14,
                height: 1.6,
                color: WindTheme.dataOf(context).getColor('slate', 600),
              ),
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Edit mode
  // -----------------------------------------------------------------------

  Widget _buildEditMode(ProjectDocument doc) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: doc.isMemory
              ? trans('memories.edit_title')
              : trans('documents.edit_title'),
        ),
        MagicStarterCard(
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              WFormInput(
                controller: _titleController,
                label: trans('documents.form_title'),
              ),
              WFormInput(
                controller: _contentController,
                label: trans('documents.form_content'),
                maxLines: 12,
              ),
              // Action buttons
              WDiv(
                className:
                    'w-full flex flex-row items-center justify-end gap-3',
                children: [
                  WAnchor(
                    onTap: _cancelEditing,
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
                    onTap: _saving ? null : _saveEdits,
                    child: WDiv(
                      className:
                          '''
                          flex flex-row items-center gap-2
                          px-4 py-2 rounded-lg
                          bg-amber-400
                          ${_saving ? 'opacity-50' : ''}
                        ''',
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        WText(
                          trans('common.save'),
                          className: 'text-sm font-semibold text-primary-900',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Create mode (memory)
  // -----------------------------------------------------------------------

  Widget _buildCreateMode() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('memories.create_title')),
        MagicStarterCard(
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              // Title
              WFormInput(
                controller: _titleController,
                label: trans('documents.form_title'),
                labelClassName: '''
                    text-sm font-medium mb-2
                    text-slate-600 dark:text-slate-300
                  ''',
                className: '''
                    text-sm bg-white dark:bg-gray-900
                    border border-slate-200 dark:border-gray-700
                    rounded-lg px-3 py-2.5
                    text-gray-900 dark:text-white
                    focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  ''',
              ),

              // Memory type dropdown
              WDiv(
                className: 'flex flex-col gap-2',
                children: [
                  WText(
                    trans('memories.form_type'),
                    className: '''
                        text-sm font-medium
                        text-slate-600 dark:text-slate-300
                      ''',
                  ),
                  DropdownButton<String>(
                    value: _selectedMemoryType,
                    isExpanded: false,
                    items: ['feedback', 'user', 'project', 'reference']
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: WText(
                              _memoryTypeLabel(t),
                              className:
                                  'text-sm text-gray-900 dark:text-white',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMemoryType = value);
                      }
                    },
                  ),
                ],
              ),

              // Content
              WFormInput(
                controller: _contentController,
                label: trans('documents.form_content'),
                labelClassName: '''
                    text-sm font-medium mb-2
                    text-slate-600 dark:text-slate-300
                  ''',
                className: '''
                    text-sm bg-white dark:bg-gray-900
                    border border-slate-200 dark:border-gray-700
                    rounded-lg px-3 py-2.5
                    text-gray-900 dark:text-white
                    focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  ''',
                maxLines: 8,
              ),

              // Action buttons
              WDiv(
                className:
                    'w-full flex flex-row items-center justify-end gap-3',
                children: [
                  WAnchor(
                    onTap: _saving ? null : _createMemory,
                    child: WDiv(
                      className:
                          '''
                          flex flex-row items-center gap-2
                          px-4 py-2 rounded-lg
                          bg-amber-400
                          ${_saving ? 'opacity-50' : ''}
                        ''',
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        WText(
                          trans('memories.save'),
                          className: 'text-sm font-semibold text-primary-900',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Not found state
  // -----------------------------------------------------------------------

  Widget _buildNotFound() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('knowledge.title')),
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

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Formats a [DateTime] as a short date string.
  String _formatDate(DateTime date) {
    final month = trans('common.month_${date.month}');
    return '$month ${date.day}, ${date.year}';
  }
}
