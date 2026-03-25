/// An AI provider token configured for a team.
///
/// Represents a credential used by agents to call an AI provider's API.
/// Maps to `AiTokenResource` from the Kodizm API.
///
/// ## Usage
/// ```dart
/// final token = AiToken.fromMap(json['data'][0]);
/// print('${token.label} (${token.provider}): ${token.status}');
/// ```
class AiToken {
  // -------

  /// Creates an [AiToken] with all fields.
  const AiToken({
    required this.id,
    required this.teamId,
    required this.provider,
    required this.authType,
    required this.label,
    required this.status,
    required this.usageCount,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
    this.rotationAlgorithm,
    this.lastUsedAt,
    this.cooldownUntil,
    this.healthCheckedAt,
  });

  // -------

  /// The unique identifier of this token (UUID).
  final String id;

  /// The identifier of the team that owns this token (UUID).
  final String teamId;

  /// AI provider identifier.
  ///
  /// Known values: `'anthropic'`, `'openai'`, `'google'`, `'openrouter'`.
  final String provider;

  /// Authentication mechanism used for this token.
  ///
  /// Known values: `'api_key'`, `'subscription'`.
  final String authType;

  /// Human-readable label for identifying this token in the UI.
  final String label;

  /// Current operational status of the token.
  ///
  /// Known values: `'active'`, `'inactive'`, `'rate_limited'`, `'expired'`.
  final String status;

  /// Optional algorithm used for automatic key rotation.
  /// Null when rotation is not configured.
  final String? rotationAlgorithm;

  /// UTC timestamp of the most recent API call using this token.
  /// Null when the token has never been used.
  final DateTime? lastUsedAt;

  /// Total number of API calls made with this token.
  final int usageCount;

  /// UTC timestamp until which this token is in a cooldown / rate-limit window.
  /// Null when the token is not currently throttled.
  final DateTime? cooldownUntil;

  /// UTC timestamp of the last health check performed on this token.
  /// Null when no health check has been run.
  final DateTime? healthCheckedAt;

  /// Provider-specific configuration for this token.
  final Map<String, dynamic> settings;

  /// UTC timestamp when this token was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this token.
  final DateTime updatedAt;

  // -------

  /// Parses an [AiToken] from a JSON-decoded map.
  factory AiToken.fromMap(Map<String, dynamic> map) {
    return AiToken(
      id: map['id'] as String,
      teamId: map['team_id'] as String,
      provider: map['provider'] as String,
      authType: map['auth_type'] as String,
      label: map['label'] as String,
      status: map['status'] as String,
      rotationAlgorithm: map['rotation_algorithm'] as String?,
      lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      usageCount: map['usage_count'] as int,
      cooldownUntil: map['cooldown_until'] != null
          ? DateTime.parse(map['cooldown_until'] as String)
          : null,
      healthCheckedAt: map['health_checked_at'] != null
          ? DateTime.parse(map['health_checked_at'] as String)
          : null,
      settings: map['settings'] as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
