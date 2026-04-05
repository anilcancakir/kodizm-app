import 'package:magic/magic.dart';

import '../models/mcp_server.dart';

// ---------------------------------------------------------------------------
// McpServerState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for MCP server CRUD operations.
///
/// Manages the merged list of MCP servers for a project — including
/// project-scoped, team-scoped, and global entries — returned by the
/// project MCP servers endpoint.
///
/// The primary state (`rxState`) holds the `List<McpServer>` for the active
/// project. CRUD operations update the in-memory list and notify listeners
/// without requiring a full re-fetch.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final mcpState = McpServerState.instance;
///
/// // Fetch merged servers for a project.
/// await mcpState.fetchServers('team-uuid', 'proj-uuid');
/// final list = mcpState.rxState; // List<McpServer>?
///
/// // Create a project-scoped server.
/// final server = await mcpState.createServer('team-uuid', 'proj-uuid', data);
/// ```
class McpServerState extends MagicController
    with MagicStateMixin<List<McpServer>> {
  /// Creates an [McpServerState].
  McpServerState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static McpServerState get instance => Magic.findOrPut(McpServerState.new);

  // ---------------------------------------------------------------------------
  // Convenience accessor
  // ---------------------------------------------------------------------------

  /// The currently loaded MCP server list (empty list when not yet fetched).
  List<McpServer> get servers => rxState ?? [];

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------

  /// Fetch merged MCP servers for a project (project + team + global).
  ///
  /// Sets loading, then populates `rxState` with the parsed server list on
  /// success, or transitions to error on failure.
  Future<void> fetchServers(String teamId, String projectId) async {
    await fetchList<McpServer>(
      '/teams/$teamId/projects/$projectId/mcp-servers',
      McpServer.fromMap,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a project-scoped MCP server.
  ///
  /// POSTs to the project MCP servers endpoint. On success, the new server is
  /// appended to the in-memory list and listeners are notified.
  ///
  /// Returns the created [McpServer] on success, or `null` on failure.
  Future<McpServer?> createServer(
    String teamId,
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/mcp-servers',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> serverData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final server = McpServer.fromMap(serverData);
      final updated = [...servers, server];
      setSuccess(updated);
      return server;
    }

    return null;
  }

  /// Update an existing MCP server.
  ///
  /// PUTs to the project MCP servers endpoint. On success, the updated server
  /// replaces its counterpart in the in-memory list and listeners are notified.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> updateServer(
    String teamId,
    String projectId,
    String serverId,
    Map<String, dynamic> data,
  ) async {
    final response = await Http.put(
      '/teams/$teamId/projects/$projectId/mcp-servers/$serverId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> serverData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final updated = McpServer.fromMap(serverData);
      final list = servers.map((s) => s.id == serverId ? updated : s).toList();
      setSuccess(list);
      return true;
    }

    return false;
  }

  /// Delete an MCP server.
  ///
  /// Sends a DELETE request to the project MCP servers endpoint. On success,
  /// the server is removed from the in-memory list and listeners are notified.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteServer(
    String teamId,
    String projectId,
    String serverId,
  ) async {
    final response = await Http.delete(
      '/teams/$teamId/projects/$projectId/mcp-servers/$serverId',
    );

    if (response.successful) {
      final list = servers.where((s) => s.id != serverId).toList();
      list.isEmpty ? setEmpty() : setSuccess(list);
      return true;
    }

    return false;
  }
}
