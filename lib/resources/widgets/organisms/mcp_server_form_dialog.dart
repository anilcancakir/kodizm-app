import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/mcp_server.dart';
import '../../../app/state/mcp_server_state.dart';

/// Form dialog for creating or editing an MCP server.
///
/// When [server] is `null` the dialog operates in create mode. When a server
/// is provided the fields are pre-filled for editing.
///
/// Calls [onSaved] after a successful create/update so the parent can refresh.
///
/// ## Usage
///
/// ```dart
/// McpServerFormDialog.show(
///   context,
///   teamId: teamId,
///   projectId: projectId,
///   onSaved: () => mcpState.fetchServers(teamId, projectId),
/// );
/// ```
class McpServerFormDialog extends StatefulWidget {
  /// Creates an [McpServerFormDialog].
  const McpServerFormDialog({
    required this.teamId,
    required this.projectId,
    this.server,
    required this.onSaved,
    super.key,
  });

  /// The team UUID.
  final String teamId;

  /// The project UUID.
  final String projectId;

  /// The server to edit; `null` for create mode.
  final McpServer? server;

  /// Callback invoked after a successful save.
  final VoidCallback onSaved;

  /// Convenience static method to show the dialog.
  static Future<void> show(
    BuildContext context, {
    required String teamId,
    required String projectId,
    McpServer? server,
    required VoidCallback onSaved,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => McpServerFormDialog(
        teamId: teamId,
        projectId: projectId,
        server: server,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<McpServerFormDialog> createState() => _McpServerFormDialogState();
}

class _McpServerFormDialogState extends State<McpServerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedType = 'http';
  bool _saving = false;

  /// Whether we are editing an existing server.
  bool get _isEditing => widget.server != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.server!;
      _nameController.text = s.name;
      _urlController.text = s.url;
      _descController.text = s.description ?? '';
      _selectedType = s.type.isNotEmpty ? s.type : 'http';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Validates and persists the server via [McpServerState].
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _selectedType,
      'url': _urlController.text.trim(),
      'description': _descController.text.trim(),
    };

    final token = _tokenController.text.trim();
    if (token.isNotEmpty) {
      data['auth_token'] = token;
    }

    bool success;
    if (_isEditing) {
      success = await McpServerState.instance.updateServer(
        widget.teamId,
        widget.projectId,
        widget.server!.id,
        data,
      );
    } else {
      final created = await McpServerState.instance.createServer(
        widget.teamId,
        widget.projectId,
        data,
      );
      success = created != null;
    }

    if (!mounted) return;

    if (success) {
      widget.onSaved();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: WText(trans('mcp_servers.save_success')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: WindTheme.dataOf(context).getColor('emerald', 500),
        ),
      );
    } else {
      setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = _isEditing
        ? trans('mcp_servers.edit')
        : trans('mcp_servers.add');

    return MagicStarterDialogShell(
      title: title,
      body: Form(
        key: _formKey,
        child: WDiv(
          className: 'flex flex-col gap-4',
          children: [
            // Name
            WFormInput(
              controller: _nameController,
              label: '${trans('mcp_servers.name')} *',
              labelClassName: '''
                text-sm font-medium mb-2
                text-slate-600 dark:text-slate-300
              ''',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return trans('validation.required');
                }
                return null;
              },
              className: _inputClassName,
              errorClassName: 'text-red-500 text-xs mt-1',
            ),

            // Type selector
            WDiv(
              className: 'flex flex-col gap-2',
              children: [
                WText(
                  trans('mcp_servers.type'),
                  className: '''
                    text-sm font-medium
                    text-slate-600 dark:text-slate-300
                  ''',
                ),
                WDiv(
                  className: 'flex flex-row gap-2',
                  children: [
                    _buildTypeChip('http', trans('mcp_servers.type_http')),
                    _buildTypeChip('sse', trans('mcp_servers.type_sse')),
                  ],
                ),
              ],
            ),

            // URL
            WFormInput(
              controller: _urlController,
              label: '${trans('mcp_servers.url')} *',
              labelClassName: '''
                text-sm font-medium mb-2
                text-slate-600 dark:text-slate-300
              ''',
              placeholder: 'https://mcp.example.com/sse',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return trans('validation.required');
                }
                return null;
              },
              className: _inputClassName,
              errorClassName: 'text-red-500 text-xs mt-1',
            ),

            // Auth Token
            WFormInput(
              controller: _tokenController,
              label: trans('mcp_servers.auth_token'),
              labelClassName: '''
                text-sm font-medium mb-2
                text-slate-600 dark:text-slate-300
              ''',
              placeholder: _isEditing && widget.server!.hasAuthToken
                  ? trans('mcp_servers.auth_token_set')
                  : trans('mcp_servers.auth_token_hint'),
              type: InputType.password,
              className: _inputClassName,
              errorClassName: 'text-red-500 text-xs mt-1',
            ),

            // Description
            WFormInput(
              controller: _descController,
              label: trans('mcp_servers.description'),
              labelClassName: '''
                text-sm font-medium mb-2
                text-slate-600 dark:text-slate-300
              ''',
              type: InputType.multiline,
              maxLines: 3,
              minLines: 3,
              className: _inputClassName,
              errorClassName: 'text-red-500 text-xs mt-1',
            ),
          ],
        ),
      ),
      footerBuilder: (dialogContext) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: WDiv(
              className: MagicStarter.modalTheme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          if (_saving)
            WDiv(
              className: MagicStarter.modalTheme.primaryButtonClassName,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            WAnchor(
              onTap: _save,
              child: WDiv(
                className: MagicStarter.modalTheme.primaryButtonClassName,
                child: WText(trans('common.save'), className: 'text-inherit'),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Shared input className for all form fields.
  static const _inputClassName = '''
    p-3 border border-slate-200 dark:border-gray-600
    rounded-lg bg-white dark:bg-gray-900
    text-sm text-slate-800 dark:text-slate-200
    focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
    error:border-red-500 error:ring-2 error:ring-red-200
  ''';

  /// Builds a selectable type chip (HTTP or SSE).
  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;

    return WAnchor(
      onTap: () => setState(() => _selectedType = type),
      child: WDiv(
        className:
            '''
          px-4 py-2 rounded-lg text-sm font-medium
          border
          ${isSelected ? 'bg-amber-400/15 border-amber-400 text-amber-700 dark:text-amber-400' : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-500'}
        ''',
        child: WText(label, className: 'text-inherit'),
      ),
    );
  }
}
