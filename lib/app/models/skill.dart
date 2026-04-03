import 'dart:convert';

import 'package:magic/magic.dart';

/// Skill model.
///
/// Represents a reusable Claude Code skill, either installed from the
/// SkillsMP marketplace or defined locally. Extends the Magic ORM [Model]
/// with [HasTimestamps] and [InteractsWithPersistence] mixins.
///
/// ## Usage
///
/// ```dart
/// // Hydrate from API response
/// final skill = Skill.fromMap(responseData);
/// Log.debug(skill.name);
///
/// // Find a skill by ID
/// final skill = await Skill.find('skill-uuid-001');
/// Log.debug(skill?.slug);
/// ```
class Skill extends Model with HasTimestamps, InteractsWithPersistence {
  /// The table associated with the model.
  @override
  String get table => 'skills';

  /// The API resource for remote operations.
  @override
  String get resource => 'skills';

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
    'description',
    'when_to_use',
    'category',
    'body',
    'scope',
    'source',
    'source_id',
    'source_url',
    'is_active',
    'sort_order',
  ];

  /// The attributes that should be cast.
  @override
  Map<String, String> get casts => {};

  // ---------------------------------------------------------------------------
  // Typed Accessors
  // ---------------------------------------------------------------------------

  /// Get the skill's ID.
  @override
  String get id => getAttribute('id')?.toString() ?? '';

  /// Get the skill name (e.g. `'my-coding'`).
  String? get name => getAttribute('name') as String?;

  /// Set the skill name.
  set name(String? value) => setAttribute('name', value);

  /// Get the URL-friendly slug for this skill.
  String? get slug => getAttribute('slug') as String?;

  /// Set the skill slug.
  set slug(String? value) => setAttribute('slug', value);

  /// Get the optional skill description.
  String? get description => getAttribute('description') as String?;

  /// Set the skill description.
  set description(String? value) => setAttribute('description', value);

  /// Get the guidance text describing when to use this skill.
  String? get whenToUse => getAttribute('when_to_use') as String?;

  /// Set the when-to-use guidance text.
  set whenToUse(String? value) => setAttribute('when_to_use', value);

  /// Get the category this skill belongs to (e.g. `'coding'`, `'devops'`).
  String? get category => getAttribute('category') as String?;

  /// Set the skill category.
  set category(String? value) => setAttribute('category', value);

  /// Get the full skill body / prompt content.
  String? get body => getAttribute('body') as String?;

  /// Set the skill body content.
  set body(String? value) => setAttribute('body', value);

  /// Get the scope of this skill (`'global'` or `'project'`).
  String? get scope => getAttribute('scope') as String?;

  /// Set the skill scope.
  set scope(String? value) => setAttribute('scope', value);

  /// Get the source of this skill (e.g. `'marketplace'`, `'local'`).
  String? get source => getAttribute('source') as String?;

  /// Set the skill source.
  set source(String? value) => setAttribute('source', value);

  /// Get the upstream source identifier on the marketplace.
  String? get sourceId => getAttribute('source_id') as String?;

  /// Set the source ID.
  set sourceId(String? value) => setAttribute('source_id', value);

  /// Get the canonical URL of this skill on the marketplace.
  String? get sourceUrl => getAttribute('source_url') as String?;

  /// Set the source URL.
  set sourceUrl(String? value) => setAttribute('source_url', value);

  /// Whether this skill is active and available for use.
  ///
  /// Defaults to `false` when not set on the model.
  bool get isActive => getAttribute('is_active') as bool? ?? false;

  /// Set the active flag.
  set isActive(bool value) => setAttribute('is_active', value);

  /// Get the display sort order for this skill.
  ///
  /// Returns `null` when not set on the model.
  int? get sortOrder => getAttribute('sort_order') as int?;

  /// Set the sort order.
  set sortOrder(int? value) => setAttribute('sort_order', value);

  // ---------------------------------------------------------------------------
  // Static Helpers
  // ---------------------------------------------------------------------------

  /// Find a skill by ID.
  ///
  /// Returns `null` if no skill with the given [id] exists.
  ///
  /// ```dart
  /// final skill = await Skill.find('skill-uuid-001');
  /// ```
  static Future<Skill?> find(dynamic id) =>
      InteractsWithPersistence.findById<Skill>(id, Skill.new);

  /// Get all skills.
  ///
  /// ```dart
  /// final skills = await Skill.all();
  /// ```
  static Future<List<Skill>> all() =>
      InteractsWithPersistence.allModels<Skill>(Skill.new);

  // ---------------------------------------------------------------------------
  // Factory Methods
  // ---------------------------------------------------------------------------

  /// Create a [Skill] from a [Map].
  ///
  /// Uses [setRawAttributes] to hydrate the model directly from raw API data,
  /// bypassing mass-assignment protection. The [exists] flag is set based on
  /// whether the map contains an `id` key.
  ///
  /// ```dart
  /// final skill = Skill.fromMap({'id': 'skill-uuid-001', 'name': 'my-coding', ...});
  /// ```
  static Skill fromMap(Map<String, dynamic> map) {
    return Skill()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }

  /// Create a [Skill] from a JSON string.
  ///
  /// Decodes [json] and delegates to [fromMap].
  ///
  /// ```dart
  /// final skill = Skill.fromJson('{"id":"skill-uuid-001","name":"my-coding"}');
  /// ```
  static Skill fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return Skill.fromMap(map);
  }
}
