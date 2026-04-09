import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/skill.dart';

// ---------------------------------------------------------------------------
// SkillState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for skill management and SkillsMP marketplace
/// operations.
///
/// Manages the team skill list, marketplace search results, AI search,
/// skill import, and API quota tracking.
///
/// The primary state (`rxState`) holds the `List<Skill>` for the team.
/// Secondary state fields ([selectedSkill], [marketplaceResults],
/// [marketplaceLoading], [quotaInfo]) are managed independently with manual
/// [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final skills = SkillState.instance;
///
/// // Fetch all skills.
/// await skills.fetchSkills();
/// final list = skills.rxState; // List<Skill>?
///
/// // Search the marketplace.
/// final results = await skills.searchMarketplace('coding');
///
/// // Import a skill.
/// final imported = await skills.importSkill({'source_id': 'mp-skill-001'});
/// ```
class SkillState extends MagicController
    with MagicStateMixin<List<Skill>>, SentryStateMixin<List<Skill>> {
  /// Creates a [SkillState].
  SkillState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static SkillState get instance => Magic.findOrPut(SkillState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  Skill? _selectedSkill;

  /// The currently selected skill (set by [fetchSkill]).
  Skill? get selectedSkill => _selectedSkill;

  List<Map<String, dynamic>>? _marketplaceResults;

  /// The most recent marketplace search results.
  ///
  /// Returns `null` until the first successful [searchMarketplace] or
  /// [aiSearchMarketplace] call.
  List<Map<String, dynamic>>? get marketplaceResults => _marketplaceResults;

  bool _marketplaceLoading = false;

  /// Whether a marketplace search is currently in progress.
  bool get marketplaceLoading => _marketplaceLoading;

  Map<String, dynamic>? _quotaInfo;

  /// Cached quota response from [fetchQuota].
  ///
  /// Returns `null` until the first successful [fetchQuota] call.
  Map<String, dynamic>? get quotaInfo => _quotaInfo;

  // ---------------------------------------------------------------------------
  // Skill list operations
  // ---------------------------------------------------------------------------

  /// Fetch all skills for the team.
  ///
  /// Sets loading, then populates `rxState` with the parsed skill list on
  /// success, or transitions to error on failure.
  Future<void> fetchSkills() async {
    await fetchList<Skill>('/skills', Skill.fromMap);
  }

  /// Find a skill by [id], returning from the in-memory list when possible.
  ///
  /// Falls back to a `GET /skills/{id}` request when the skill is not already
  /// loaded. Returns `null` on failure.
  Future<Skill?> fetchSkill(String id) async {
    final cached = rxState?.firstWhere(
      (s) => s.id == id,
      orElse: () => Skill(),
    );

    if (cached != null && cached.id.isNotEmpty) {
      _selectedSkill = cached;
      refreshUI();
      return cached;
    }

    final response = await Http.get('/skills/$id');

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedSkill = Skill.fromMap(data);
      refreshUI();
      return _selectedSkill;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Marketplace operations
  // ---------------------------------------------------------------------------

  /// Search the SkillsMP marketplace by keyword [query].
  ///
  /// Sets [marketplaceLoading] during the request. Stores results in
  /// [marketplaceResults] on success. Returns the results list, or `null`
  /// on failure.
  Future<List<Map<String, dynamic>>?> searchMarketplace(
    String query, {
    int page = 1,
  }) async {
    _marketplaceLoading = true;
    refreshUI();

    final response = await Http.get(
      '/skillsmp/search',
      query: {'q': query, 'page': page},
    );

    _marketplaceLoading = false;

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _marketplaceResults = items
          .map((item) => item as Map<String, dynamic>)
          .toList();
      refreshUI();
      return _marketplaceResults;
    }

    refreshUI();
    return null;
  }

  /// Search the SkillsMP marketplace using AI-powered semantic search.
  ///
  /// Sets [marketplaceLoading] during the request. Stores results in
  /// [marketplaceResults] on success. Returns the results list, or `null`
  /// on failure.
  Future<List<Map<String, dynamic>>?> aiSearchMarketplace(String query) async {
    _marketplaceLoading = true;
    refreshUI();

    final response = await Http.get('/skillsmp/ai-search', query: {'q': query});

    _marketplaceLoading = false;

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      _marketplaceResults = items
          .map((item) => item as Map<String, dynamic>)
          .toList();
      refreshUI();
      return _marketplaceResults;
    }

    refreshUI();
    return null;
  }

  /// Import a skill from SkillsMP via `POST /skillsmp/import`.
  ///
  /// On success, refreshes the skills list via [fetchSkills] and returns the
  /// newly imported [Skill]. Returns `null` on failure.
  Future<Skill?> importSkill(Map<String, dynamic> data) async {
    final response = await Http.post('/skillsmp/import', data: data);

    if (response.successful) {
      final Map<String, dynamic> skillData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final skill = Skill.fromMap(skillData);
      await fetchSkills();
      return skill;
    }

    return null;
  }

  /// Fetch the current SkillsMP API quota for the team.
  ///
  /// Stores the result in [quotaInfo] on success. Returns the quota map, or
  /// `null` on failure.
  Future<Map<String, dynamic>?> fetchQuota() async {
    final response = await Http.get('/skillsmp/quota');

    if (response.successful) {
      _quotaInfo = response.data as Map<String, dynamic>?;
      refreshUI();
      return _quotaInfo;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new skill via `POST /skills`.
  ///
  /// Returns the created [Skill] on success, or `null` on failure.
  Future<Skill?> createSkill(Map<String, dynamic> data) async {
    final response = await Http.post('/skills', data: data);

    if (response.successful) {
      final Map<String, dynamic> skillData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      return Skill.fromMap(skillData);
    }

    return null;
  }
}
