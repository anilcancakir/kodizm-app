import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project_memory.dart';
import '../../../app/models/user.dart';
import '../../../app/state/memory_state.dart';

// ---------------------------------------------------------------------------
// MemoryDetailView
// ---------------------------------------------------------------------------

/// Memory detail screen — displays, edits, creates, and deletes a single
/// memory entry.
///
/// When [isCreateMode] is `true`, the view starts with empty form fields and
/// persists via [MemoryState.createMemory]. Otherwise it loads an existing
/// entry identified by [memoryId] and supports inline editing and deletion.
///
/// ## Usage
///
/// ```dart
/// // View / edit existing memory:
/// MagicRoute.to('/projects/$projectId/memories/$memoryId');
///
/// // Create new memory:
/// MemoryDetailView(projectId: 'proj-uuid', isCreateMode: true)
/// ```
class MemoryDetailView extends StatefulWidget {
  /// Creates a [MemoryDetailView].
  const MemoryDetailView({
    required this.projectId,
    this.memoryId,
    this.isCreateMode = false,
    super.key,
  });

  /// The project UUID this memory belongs to.
  final String projectId;

  /// The memory UUID to display. Null when [isCreateMode] is `true`.
  final String? memoryId;

  /// When `true`, the view starts in create mode with empty form fields.
  final bool isCreateMode;

  @override
  State<MemoryDetailView> createState() => _MemoryDetailViewState();
}

class _MemoryDetailViewState extends State<MemoryDetailView> {
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  ProjectMemory? _memory;

  // -----------------------------------------------------------------------
  // Form controllers
  // -----------------------------------------------------------------------

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'feedback';

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
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (widget.isCreateMode) {
      _loading = false;
      _editing = true;
    } else {
      _loadMemory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _fileNameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Data loading
  // -----------------------------------------------------------------------

  /// Resolves the current team ID from the authenticated user.
  String? get _teamId => Auth.user<User>()?.currentTeam?.id;

  /// Loads the memory entry by ID from the in-memory state list.
  Future<void> _loadMemory() async {
    setState(() => _loading = true);

    final teamId = _teamId;
    if (teamId == null || widget.memoryId == null) {
      setState(() => _loading = false);
      return;
    }

    // Ensure the list is loaded, then pick the entry.
    final state = MemoryState.instance;
    if (state.memories.isEmpty) {
      await state.loadMemories(teamId, widget.projectId);
    }

    final memory = state.memories
        .where((m) => m.id == widget.memoryId)
        .firstOrNull;

    setState(() {
      _memory = memory;
      _loading = false;
      if (memory != null) {
        _populateForm(memory);
      }
    });
  }

  /// Populates form controllers from a [ProjectMemory].
  void _populateForm(ProjectMemory memory) {
    _nameController.text = memory.name;
    _descriptionController.text = memory.description;
    _fileNameController.text = memory.fileName;
    _contentController.text = memory.content;
    _selectedType = memory.type;
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  /// Toggles inline edit mode.
  void _toggleEdit() {
    setState(() {
      _editing = !_editing;
      if (_editing && _memory != null) {
        _populateForm(_memory!);
      }
    });
  }

  /// Saves the memory — creates or updates depending on mode.
  Future<void> _save() async {
    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _saving = true);

    final state = MemoryState.instance;

    if (widget.isCreateMode) {
      final created = await state.createMemory(
        teamId,
        widget.projectId,
        _fileNameController.text.trim(),
        _nameController.text.trim(),
        _descriptionController.text.trim(),
        _selectedType,
        _contentController.text.trim(),
      );

      setState(() => _saving = false);

      if (created != null) {
        MagicRoute.to('/projects/${widget.projectId}/memories/${created.id}');
      }
    } else {
      final updated = await state.updateMemory(
        teamId,
        widget.projectId,
        widget.memoryId!,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        content: _contentController.text.trim(),
      );

      setState(() {
        _saving = false;
        if (updated != null) {
          _memory = updated;
          _editing = false;
        }
      });
    }
  }

  /// Shows a delete confirmation dialog and deletes the memory.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: WText(
          trans('common.delete'),
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        content: WText(
          trans('memories.delete_confirm'),
          className: 'text-sm text-slate-500 dark:text-slate-400',
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
    if (teamId == null || widget.memoryId == null) return;

    final deleted = await MemoryState.instance.deleteMemory(
      teamId,
      widget.projectId,
      widget.memoryId!,
    );

    if (deleted) {
      MagicRoute.to('/projects/${widget.projectId}/memories');
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

    if (!widget.isCreateMode && _memory == null) {
      return _buildNotFound();
    }

    return _editing ? _buildEditMode() : _buildReadMode();
  }

  // -----------------------------------------------------------------------
  // Read mode
  // -----------------------------------------------------------------------

  /// Builds the read-only detail layout.
  Widget _buildReadMode() {
    final memory = _memory!;
    final creator =
        memory.createdByUserName ?? memory.createdByAgentRoleName ?? '';

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: memory.name,
          actions: [
            WAnchor(
              onTap: _toggleEdit,
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
                    trans('memories.edit_title'),
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
                    border border-red-200 dark:border-red-700
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

        // -----------------------------------------------------------------
        // Metadata card
        // -----------------------------------------------------------------
        MagicStarterCard(
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              // Type badge
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  WDiv(
                    className:
                        'px-2.5 py-0.5 rounded-full ${_typeBadgeClassName(memory.type)}',
                    child: WText(
                      _typeLabel(memory.type),
                      className: 'text-xs font-medium',
                    ),
                  ),
                ],
              ),

              // Description
              if (memory.description.isNotEmpty)
                WDiv(
                  className: 'flex flex-col gap-1',
                  children: [
                    WText(
                      trans('memories.form_description'),
                      className: '''
                          text-sm font-semibold
                          text-slate-700 dark:text-slate-300
                        ''',
                    ),
                    WText(
                      memory.description,
                      className: 'text-sm text-slate-500 dark:text-slate-400',
                    ),
                  ],
                ),

              // File name
              WDiv(
                className: 'flex flex-col gap-1',
                children: [
                  WText(
                    trans('memories.form_file_name'),
                    className: '''
                        text-sm font-semibold
                        text-slate-700 dark:text-slate-300
                      ''',
                  ),
                  WText(
                    memory.fileName,
                    className: 'text-sm text-slate-500 dark:text-slate-400',
                  ),
                ],
              ),

              // Creator + last synced
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
                          className:
                              'text-xs text-slate-400 dark:text-slate-500',
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
                          className:
                              'text-xs text-slate-400 dark:text-slate-500',
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),

        // -----------------------------------------------------------------
        // Content card
        // -----------------------------------------------------------------
        if (memory.content.isNotEmpty)
          MagicStarterCard(
            child: WDiv(
              className: 'flex flex-col gap-3',
              children: [
                WText(
                  trans('memories.form_content'),
                  className: '''
                      text-base font-semibold
                      text-gray-900 dark:text-white
                    ''',
                ),
                WDiv(
                  className: '''
                      p-4 rounded-lg
                      bg-slate-50 dark:bg-gray-900
                    ''',
                  child: SelectableText(
                    memory.content,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Edit / create mode
  // -----------------------------------------------------------------------

  /// Builds the inline edit or create form layout.
  Widget _buildEditMode() {
    final isCreate = widget.isCreateMode;

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: isCreate
              ? trans('memories.create_title')
              : trans('memories.edit_title'),
        ),

        // -----------------------------------------------------------------
        // Form card
        // -----------------------------------------------------------------
        MagicStarterCard(
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              // Name
              WFormInput(
                controller: _nameController,
                label: trans('memories.form_name'),
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

              // Description
              WFormInput(
                controller: _descriptionController,
                label: trans('memories.form_description'),
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

              // File name (create only)
              if (isCreate)
                WFormInput(
                  controller: _fileNameController,
                  label: trans('memories.form_file_name'),
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

              // Type dropdown
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
                    value: _selectedType,
                    isExpanded: false,
                    items: ['feedback', 'user', 'project', 'reference']
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: WText(
                              _typeLabel(t),
                              className:
                                  'text-sm text-gray-900 dark:text-white',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                ],
              ),

              // Content
              WFormInput(
                controller: _contentController,
                label: trans('memories.form_content'),
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

              // Action buttons — right-aligned
              WDiv(
                className:
                    'w-full flex flex-row items-center justify-end gap-3',
                children: [
                  if (!isCreate)
                    WAnchor(
                      onTap: _toggleEdit,
                      child: WDiv(
                        className: '''
                            px-4 py-2 rounded-lg
                            bg-white dark:bg-gray-800
                            border border-slate-200 dark:border-gray-700
                          ''',
                        child: WText(
                          trans('common.cancel'),
                          className:
                              'text-sm font-medium text-slate-500 dark:text-slate-400',
                        ),
                      ),
                    ),
                  WAnchor(
                    onTap: _saving ? null : _save,
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

  /// Displays a not-found message when the memory cannot be loaded.
  Widget _buildNotFound() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('memories.title')),
        WDiv(
          className:
              'w-full flex flex-col items-center justify-center py-16 gap-4',
          children: [
            WIcon(
              Icons.search_off,
              className: 'text-4xl text-slate-300 dark:text-slate-600',
            ),
            WText(
              trans('memories.empty_title'),
              className:
                  'text-lg font-semibold text-slate-500 dark:text-slate-400',
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
