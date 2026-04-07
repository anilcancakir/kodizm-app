import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/mcp_server.dart';
import '../../../app/state/mcp_server_state.dart';
import 'mcp_server_form_dialog.dart';

/// Organism widget that displays the MCP Servers section in the project detail.
///
/// Shows a list of all MCP servers (project, team, and global scoped) for the
/// current project. Project-scoped servers can be added, edited, and deleted;
/// team and global servers are shown read-only.
///
/// ## Usage
///
/// ```dart
/// McpServerSection(
///   teamId: 'team-uuid',
///   projectId: 'project-uuid',
/// )
/// ```
class McpServerSection extends StatefulWidget {
  /// Creates an [McpServerSection].
  const McpServerSection({
    required this.teamId,
    required this.projectId,
    super.key,
  });

  /// The team UUID.
  final String teamId;

  /// The project UUID.
  final String projectId;

  @override
  State<McpServerSection> createState() => _McpServerSectionState();
}

class _McpServerSectionState extends State<McpServerSection> {
  late final McpServerState _state;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _state = McpServerState.instance;
    _state.fetchServers(widget.teamId, widget.projectId);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Opens the create/edit dialog.
  void _showFormDialog({McpServer? server}) {
    McpServerFormDialog.show(
      context,
      teamId: widget.teamId,
      projectId: widget.projectId,
      server: server,
      onSaved: () => _state.fetchServers(widget.teamId, widget.projectId),
    );
  }

  /// Confirms and deletes a server.
  Future<void> _confirmDelete(McpServer server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: WText(trans('mcp_servers.delete')),
        content: WText(trans('mcp_servers.delete_confirm')),
        actions: [
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(false),
            child: WText(trans('common.cancel')),
          ),
          WAnchor(
            onTap: () => Navigator.of(dialogContext).pop(true),
            child: WText(trans('common.delete'), className: 'text-red-500'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await _state.deleteServer(
      widget.teamId,
      widget.projectId,
      server.id,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: WText(trans('mcp_servers.delete_success')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: WindTheme.dataOf(context).getColor('emerald', 500),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Badge classNames
  // ---------------------------------------------------------------------------

  /// Returns the className for a scope badge.
  static String _scopeBadgeClass(String scope) => switch (scope) {
    'system' => 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400',
    'team' => 'bg-blue-100 text-blue-600 dark:bg-blue-900 dark:text-blue-400',
    'project' =>
      'bg-green-100 text-green-600 dark:bg-green-900 dark:text-green-400',
    _ => 'bg-gray-100 text-gray-600',
  };

  /// Returns the className for a type badge.
  static String _typeBadgeClass(String type) => switch (type) {
    'http' =>
      'bg-amber-100 text-amber-700 dark:bg-amber-900 dark:text-amber-400',
    'sse' =>
      'bg-purple-100 text-purple-700 dark:bg-purple-900 dark:text-purple-400',
    _ => 'bg-gray-100 text-gray-600',
  };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return MagicStarterCard(
          title: trans('mcp_servers.title'),
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              // Header row with add button.
              WDiv(
                className: 'flex flex-row items-center justify-between',
                children: [
                  WText(
                    trans('mcp_servers.subtitle'),
                    className: 'text-sm text-slate-400',
                  ),
                  WAnchor(
                    onTap: () => _showFormDialog(),
                    child: WDiv(
                      className: '''
                        flex flex-row items-center gap-2
                        px-3 py-1.5 rounded-lg
                        bg-amber-400 dark:bg-amber-500
                      ''',
                      children: [
                        WIcon(
                          Icons.add,
                          className: '''
                            text-sm font-bold
                            text-primary dark:text-primary-900
                          ''',
                        ),
                        WText(
                          trans('mcp_servers.add'),
                          className: '''
                            text-sm font-medium
                            text-primary dark:text-primary-900
                          ''',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Content: loading / empty / list.
              if (_state.isLoading)
                WDiv(
                  className: 'flex items-center justify-center w-full py-8',
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_state.servers.isEmpty)
                _buildEmptyState()
              else
                ..._state.servers.map(_buildServerRow),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  /// Builds the empty state placeholder.
  Widget _buildEmptyState() {
    return WDiv(
      className: '''
        flex flex-col items-center justify-center w-full
        py-8 rounded-xl
        bg-slate-50 dark:bg-gray-900
      ''',
      children: [
        WIcon(
          Icons.dns_outlined,
          className: 'text-3xl text-slate-300 dark:text-slate-600',
        ),
        const WSpacer(className: 'h-2'),
        WText(
          trans('mcp_servers.empty_title'),
          className: 'text-base font-semibold text-slate-500',
        ),
        const WSpacer(className: 'h-1'),
        WText(
          trans('mcp_servers.empty_description'),
          className: 'text-sm text-slate-400',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Server row
  // ---------------------------------------------------------------------------

  /// Builds a single server row with type badge, info, scope badge, and actions.
  Widget _buildServerRow(McpServer server) {
    final isProjectScoped = server.scope == 'project';

    return WDiv(
      className: '''
        flex flex-row items-center gap-3
        p-3 rounded-lg
        border border-gray-200 dark:border-gray-700
      ''',
      children: [
        // Type badge (HTTP / SSE).
        WDiv(
          className:
              '''
            px-2 py-0.5 rounded text-xs font-semibold uppercase
            ${_typeBadgeClass(server.type)}
          ''',
          child: WText(server.type.toUpperCase(), className: 'text-inherit'),
        ),

        // Server info (name + url).
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col gap-0.5',
          children: [
            WText(
              server.name,
              className: '''
                text-sm font-medium
                text-slate-800 dark:text-slate-200
              ''',
            ),
            WText(server.url, className: 'text-xs text-slate-400 truncate'),
          ],
        ),

        // Scope badge.
        WDiv(
          className:
              '''
            px-2 py-0.5 rounded-full text-xs font-medium
            ${_scopeBadgeClass(server.scope)}
          ''',
          child: WText(
            server.scopeLabel.isNotEmpty ? server.scopeLabel : server.scope,
            className: 'text-inherit',
          ),
        ),

        // Actions (edit + delete) — only for project-scoped servers.
        if (isProjectScoped)
          WDiv(
            className: 'flex flex-row items-center gap-1',
            children: [
              WAnchor(
                onTap: () => _showFormDialog(server: server),
                child: WDiv(
                  className: '''
                    p-1.5 rounded-md
                    hover:bg-slate-100 dark:hover:bg-slate-800
                  ''',
                  child: WIcon(
                    Icons.edit_outlined,
                    className: 'text-sm text-slate-400',
                  ),
                ),
              ),
              WAnchor(
                onTap: () => _confirmDelete(server),
                child: WDiv(
                  className: '''
                    p-1.5 rounded-md
                    hover:bg-red-50 dark:hover:bg-red-900/20
                  ''',
                  child: WIcon(
                    Icons.delete_outlined,
                    className: 'text-sm text-red-400',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
