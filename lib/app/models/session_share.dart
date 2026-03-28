/// A share grant that exposes a session to a polymorphic resource.
///
/// Maps directly to `SessionShareResource` from the Kodizm API.
/// A share links a session to any shareable entity (e.g. a Project or Team)
/// via a polymorphic `shareable_type` / `shareable_id` pair.
///
/// ## Usage
/// ```dart
/// final share = SessionShare.fromMap(json['shares'][0]);
/// print('${share.permission} access for ${share.shareableType}:${share.shareableId}');
/// ```
class SessionShare {
  // -------

  /// Creates a [SessionShare] with all fields.
  const SessionShare({
    required this.id,
    required this.sessionId,
    required this.shareableType,
    required this.shareableId,
    required this.permission,
    required this.sharedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // -------

  /// The unique identifier of this share record (UUID).
  final String id;

  /// The identifier of the shared session (UUID).
  final String sessionId;

  /// The fully-qualified class name of the polymorphic target
  /// (e.g. `'App\\Models\\Project'`).
  final String shareableType;

  /// The identifier of the polymorphic target (UUID).
  final String shareableId;

  /// The access level granted — either `'read'` or `'write'`.
  final String permission;

  /// The identifier of the user who created this share (UUID).
  final String sharedBy;

  /// UTC timestamp when this share was created.
  final DateTime createdAt;

  /// UTC timestamp of the last update to this share record.
  final DateTime updatedAt;

  // -------

  /// Parses a [SessionShare] from a JSON-decoded map.
  factory SessionShare.fromMap(Map<String, dynamic> map) {
    return SessionShare(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      shareableType: map['shareable_type'] as String,
      shareableId: map['shareable_id'] as String,
      permission: map['permission'] as String,
      sharedBy: map['shared_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
