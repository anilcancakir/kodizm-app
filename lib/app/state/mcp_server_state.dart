import 'package:magic/magic.dart';

import '../models/mcp_server.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [McpServerState] uses.
///
/// In production the default [_MagicHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class McpServerHttpClient {
  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });

  /// Perform a POST request.
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a PUT request.
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  });

  /// Perform a DELETE request.
  Future<MagicResponse> delete(String url, {Map<String, String>? headers});
}

/// Default production [McpServerHttpClient] backed by the Magic [Http] facade.
class _MagicHttpClient implements McpServerHttpClient {
  const _MagicHttpClient();

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => Http.get(url, query: query, headers: headers);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => Http.post(url, data: data, headers: headers);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) => Http.put(url, data: data, headers: headers);

  @override
  Future<MagicResponse> delete(String url, {Map<String, String>? headers}) =>
      Http.delete(url, headers: headers);
}

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
  /// Creates an [McpServerState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicHttpClient].
  McpServerState({McpServerHttpClient? httpClient})
    : _http = httpClient ?? const _MagicHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static McpServerState get instance => Magic.findOrPut(McpServerState.new);

  final McpServerHttpClient _http;

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
    setLoading();

    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/mcp-servers',
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final list = items
          .map((e) => McpServer.fromMap(e as Map<String, dynamic>))
          .toList();
      list.isEmpty ? setEmpty() : setSuccess(list);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch MCP servers');
    }
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
    final response = await _http.post(
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
    final response = await _http.put(
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
    final response = await _http.delete(
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
