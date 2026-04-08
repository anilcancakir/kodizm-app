/// A Git provider OAuth connection configured for a team.
///
/// Represents a GitHub/GitLab/Bitbucket OAuth connection used by agents
/// to interact with repositories. Maps to `GitProviderResource` from
/// the Kodizm API.
///
/// ## Usage
/// ```dart
/// final provider = GitProvider.fromMap(json['data'][0]);
/// print('${provider.username} (${provider.provider}): active=${provider.isActive}');
/// ```
class GitProvider {
  // -------

  /// Creates a [GitProvider] with all fields.
  const GitProvider({
    required this.id,
    required this.teamId,
    required this.provider,
    required this.username,
    required this.isActive,
    required this.connectedAt,
    this.displayName,
    this.email,
    this.avatarUrl,
    this.lastUsedAt,
  });

  // -------

  /// The unique identifier of this git provider connection (UUID).
  final String id;

  /// The identifier of the team that owns this connection (UUID).
  final String teamId;

  /// Git provider identifier.
  ///
  /// Known values: `'github'`, `'gitlab'`, `'bitbucket'`.
  final String provider;

  /// The authenticated username on the git provider platform.
  final String username;

  /// Human-readable display name for the authenticated account.
  /// Null when the provider does not return a display name.
  final String? displayName;

  /// Email address associated with the git provider account.
  /// Null when the provider does not expose the email.
  final String? email;

  /// URL of the avatar image for the authenticated account.
  /// Null when no avatar is available.
  final String? avatarUrl;

  /// Whether this connection is currently active.
  final bool isActive;

  /// UTC timestamp when this OAuth connection was established.
  final DateTime connectedAt;

  /// UTC timestamp of the most recent API call using this connection.
  /// Null when the connection has never been used.
  final DateTime? lastUsedAt;

  // -------

  /// Parses a [GitProvider] from a JSON-decoded map.
  factory GitProvider.fromMap(Map<String, dynamic> map) {
    return GitProvider(
      id: map['id'] as String,
      teamId: map['team_id'] as String,
      provider: map['provider'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String?,
      email: map['email'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isActive: map['is_active'] as bool,
      connectedAt: DateTime.parse(map['connected_at'] as String),
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
    );
  }
}
