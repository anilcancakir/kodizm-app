import 'dart:convert';

import 'package:magic/magic.dart';

/// MCP Server model.
///
/// Represents a remote Model Context Protocol server configured for a project,
/// team, or globally. Extends the Magic ORM [Model] with [HasTimestamps] and
/// [InteractsWithPersistence] mixins to provide full persistence and timestamp
/// tracking.
///
/// The auth token is write-only — it is never returned by the API. Use
/// [hasAuthToken] to check whether a token has been set.
///
/// ## Usage
///
/// ```dart
/// // Hydrate from API response
/// final server = McpServer.fromMap(responseData);
/// Log.debug(server.name);
///
/// // Check if a token is configured
/// if (server.hasAuthToken) {
///   Log.debug('Token is set for ${server.name}');
/// }
/// ```
class McpServer extends Model with HasTimestamps, InteractsWithPersistence {
  /// The table associated with the model.
  @override
  String get table => 'mcp_servers';

  /// The API resource for remote operations.
  @override
  String get resource => 'mcp-servers';

  /// Whether the primary key is auto-incrementing.
  ///
  /// Set to false because this app uses string UUIDs as primary keys.
  @override
  bool get incrementing => false;

  /// The attributes that are mass assignable.
  @override
  List<String> get fillable => [
    'name',
    'slug',
    'type',
    'url',
    'description',
    'scope',
    'is_active',
    'sort_order',
    'has_auth_token',
    'headers',
  ];

  /// The attributes that should be cast.
  @override
  Map<String, String> get casts => {};

  // ---------------------------------------------------------------------------
  // Typed Accessors
  // ---------------------------------------------------------------------------

  /// Get the server's ID.
  @override
  String get id => getAttribute('id')?.toString() ?? '';

  /// Get the display name for this MCP server.
  String get name => getAttribute('name') as String? ?? '';

  /// Set the display name.
  set name(String value) => setAttribute('name', value);

  /// Get the URL-friendly slug for this server.
  String get slug => getAttribute('slug') as String? ?? '';

  /// Set the slug.
  set slug(String value) => setAttribute('slug', value);

  /// Get the transport type (`'http'` or `'sse'`).
  String get type => getAttribute('type') as String? ?? '';

  /// Set the transport type.
  set type(String value) => setAttribute('type', value);

  /// Get the server URL.
  String get url => getAttribute('url') as String? ?? '';

  /// Set the server URL.
  set url(String value) => setAttribute('url', value);

  /// Get the optional human-readable description.
  String? get description => getAttribute('description') as String?;

  /// Set the description.
  set description(String? value) => setAttribute('description', value);

  /// Get the scope of this server (`'system'`, `'team'`, or `'project'`).
  ///
  /// Falls back to `'system'` when not set on the model.
  String get scope => getAttribute('scope') as String? ?? 'system';

  /// Set the scope.
  set scope(String value) => setAttribute('scope', value);

  /// Get the human-readable scope label (e.g. `'Global'`, `'Team'`, `'Project'`).
  ///
  /// Populated by the API as a computed field.
  String get scopeLabel => getAttribute('scope_label') as String? ?? '';

  /// Whether this server is active and will be injected into agent sessions.
  ///
  /// Falls back to `true` when not set on the model.
  bool get isActive => getAttribute('is_active') as bool? ?? true;

  /// Set the active flag.
  set isActive(bool value) => setAttribute('is_active', value);

  /// Get the display sort order for this server within its scope.
  int get sortOrder => (getAttribute('sort_order') as num?)?.toInt() ?? 0;

  /// Set the sort order.
  set sortOrder(int value) => setAttribute('sort_order', value);

  /// Whether a bearer auth token has been stored for this server.
  ///
  /// The actual token is never returned by the API — this flag indicates
  /// whether one has been configured.
  bool get hasAuthToken => getAttribute('has_auth_token') as bool? ?? false;

  /// Get the optional custom HTTP headers map.
  ///
  /// Returns `null` when no custom headers are configured.
  Map<String, dynamic>? get headers {
    final data = getAttribute('headers');
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Set the custom headers map.
  set headers(Map<String, dynamic>? value) => setAttribute('headers', value);

  // ---------------------------------------------------------------------------
  // Static Helpers
  // ---------------------------------------------------------------------------

  /// Find an MCP server by ID.
  ///
  /// Returns `null` if no server with the given [id] exists.
  ///
  /// ```dart
  /// final server = await McpServer.find('mcp-uuid-001');
  /// ```
  static Future<McpServer?> find(dynamic id) =>
      InteractsWithPersistence.findById<McpServer>(id, McpServer.new);

  /// Get all MCP servers.
  ///
  /// ```dart
  /// final servers = await McpServer.all();
  /// ```
  static Future<List<McpServer>> all() =>
      InteractsWithPersistence.allModels<McpServer>(McpServer.new);

  // ---------------------------------------------------------------------------
  // Factory Methods
  // ---------------------------------------------------------------------------

  /// Create an [McpServer] from a [Map].
  ///
  /// Uses [setRawAttributes] to hydrate the model directly from raw API data,
  /// bypassing mass-assignment protection. The [exists] flag is set based on
  /// whether the map contains an `id` key.
  ///
  /// ```dart
  /// final server = McpServer.fromMap({'id': 'mcp-uuid-001', 'name': 'My MCP', ...});
  /// ```
  static McpServer fromMap(Map<String, dynamic> map) {
    return McpServer()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }

  /// Create an [McpServer] from a JSON string.
  ///
  /// Decodes [json] and delegates to [fromMap].
  ///
  /// ```dart
  /// final server = McpServer.fromJson('{"id":"mcp-uuid-001","name":"My MCP"}');
  /// ```
  static McpServer fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return McpServer.fromMap(map);
  }
}
