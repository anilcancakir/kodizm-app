/// Channel kind discriminant: one value per broadcast channel family.
enum ChannelKind { conversation, session, project, task, team }

/// Typed, immutable identifier for a single broadcast channel.
///
/// Holds both the raw string [key] (e.g. `'conversation.abc'`) used when
/// subscribing via Echo, and the semantic [kind] enum for switch-based
/// dispatch.
///
/// Factory constructors mirror every `PrivateChannel(...)` defined in the
/// API's `broadcastOn()` methods. The `private-` prefix is intentionally
/// absent; Echo adds it automatically during subscription.
///
/// ## Usage
///
/// ```dart
/// final ch = ChannelName.conversation(conversation.id);
/// print(ch.key);  // 'conversation.some-uuid'
/// print(ch.kind); // ChannelKind.conversation
///
/// ch == ChannelName.conversation(conversation.id); // true
/// ```
abstract final class ChannelName {
  // -----------------------------------------------------------------------
  // Construction
  // -----------------------------------------------------------------------

  const ChannelName._();

  /// Creates a channel identifier for the `conversation.{id}` private channel.
  factory ChannelName.conversation(String id) =>
      _ChannelName('conversation.$id', ChannelKind.conversation);

  /// Creates a channel identifier for the `session.{id}` private channel.
  factory ChannelName.session(String id) =>
      _ChannelName('session.$id', ChannelKind.session);

  /// Creates a channel identifier for the `project.{id}` private channel.
  factory ChannelName.project(String id) =>
      _ChannelName('project.$id', ChannelKind.project);

  /// Creates a channel identifier for the `task.{id}` private channel.
  factory ChannelName.task(String id) =>
      _ChannelName('task.$id', ChannelKind.task);

  /// Creates a channel identifier for the `team.{id}` private channel.
  factory ChannelName.team(String id) =>
      _ChannelName('team.$id', ChannelKind.team);

  // -----------------------------------------------------------------------
  // Accessors
  // -----------------------------------------------------------------------

  /// The raw channel name string passed to Echo's `private()` or `channel()`.
  ///
  /// Format: `'{kind}.{id}'`, e.g. `'project.abc-123'`.
  String get key;

  /// Semantic kind, use in `switch` to dispatch per channel family.
  ChannelKind get kind;
}

// ---------------------------------------------------------------------------
// Private implementation
// ---------------------------------------------------------------------------

final class _ChannelName extends ChannelName {
  const _ChannelName(this.key, this.kind) : super._();

  @override
  final String key;

  @override
  final ChannelKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _ChannelName && other.key == key);

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'ChannelName($key)';
}
