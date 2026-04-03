import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/state/skill_state.dart';

// ---------------------------------------------------------------------------
// SkillMarketplaceView
// ---------------------------------------------------------------------------

/// SkillsMP marketplace browser — search and import skills from the
/// marketplace.
///
/// Supports keyword search and AI-powered semantic search with a toggle
/// between the two modes. Displays quota usage and marks already-imported
/// skills.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/skills/marketplace');
/// ```
class SkillMarketplaceView extends StatefulWidget {
  /// Creates the [SkillMarketplaceView].
  const SkillMarketplaceView({super.key});

  @override
  State<SkillMarketplaceView> createState() => _SkillMarketplaceViewState();
}

class _SkillMarketplaceViewState extends State<SkillMarketplaceView> {
  final TextEditingController _searchController = TextEditingController();

  /// Whether AI search mode is active (vs keyword search).
  bool _isAiSearch = false;

  /// Set of source IDs currently being imported (for loading state).
  final Set<String> _importingIds = {};

  @override
  void initState() {
    super.initState();
    SkillState.instance.fetchQuota();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  /// Runs the search using the selected mode.
  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (_isAiSearch) {
      await SkillState.instance.aiSearchMarketplace(query);
    } else {
      await SkillState.instance.searchMarketplace(query);
    }
  }

  /// Imports a marketplace skill and refreshes state.
  Future<void> _onImport(Map<String, dynamic> item) async {
    final sourceId = item['id']?.toString() ?? '';
    if (sourceId.isEmpty) return;

    setState(() => _importingIds.add(sourceId));

    await SkillState.instance.importSkill({
      'skillsmp_id': sourceId,
      'name': item['name'] ?? '',
      'body': item['body'] ?? '',
      'description': item['description'],
      'category': item['category'],
      'slug': item['slug'],
      'skillsmp_url': item['url'] ?? item['source_url'],
    });

    setState(() => _importingIds.remove(sourceId));
  }

  /// Checks whether a marketplace item has already been imported.
  bool _isImported(Map<String, dynamic> item) {
    final sourceId = item['id']?.toString() ?? '';
    if (sourceId.isEmpty) return false;

    final skills = SkillState.instance.rxState ?? [];
    return skills.any((s) => s.sourceId == sourceId);
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkillState.instance,
      builder: (context, _) {
        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            // -------------------------------------------------------------
            // Header
            // -------------------------------------------------------------
            MagicStarterPageHeader(
              title: trans('skills.marketplace'),
              subtitle: trans('skills.marketplace_subtitle'),
            ),

            // -------------------------------------------------------------
            // Search section
            // -------------------------------------------------------------
            MagicStarterCard(
              child: WDiv(
                className: 'flex flex-col gap-4',
                children: [
                  // Search mode toggle
                  WDiv(
                    className: 'flex flex-row items-center gap-2',
                    children: [
                      _SearchModeButton(
                        label: trans('skills.keyword_search'),
                        isActive: !_isAiSearch,
                        onTap: () => setState(() => _isAiSearch = false),
                      ),
                      _SearchModeButton(
                        label: trans('skills.ai_search'),
                        isActive: _isAiSearch,
                        onTap: () => setState(() => _isAiSearch = true),
                      ),
                    ],
                  ),

                  // Search input + button
                  WDiv(
                    className: 'flex flex-row items-center gap-3',
                    children: [
                      WDiv(
                        className: 'flex-1',
                        child: WFormInput(
                          controller: _searchController,
                          label: trans('skills.search_placeholder'),
                        ),
                      ),
                      WAnchor(
                        onTap: _onSearch,
                        child: WDiv(
                          className: '''
                              flex flex-row items-center gap-2
                              px-4 py-2.5 rounded-lg
                              bg-amber-400
                            ''',
                          children: [
                            WIcon(
                              Icons.search,
                              className: 'text-base text-primary-900',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -------------------------------------------------------------
            // Results
            // -------------------------------------------------------------
            if (SkillState.instance.marketplaceLoading)
              const WDiv(
                className: 'w-full flex items-center justify-center py-16',
                child: CircularProgressIndicator(),
              )
            else if (SkillState.instance.marketplaceResults != null)
              _buildResults(SkillState.instance.marketplaceResults!),

            // -------------------------------------------------------------
            // Quota display
            // -------------------------------------------------------------
            if (SkillState.instance.quotaInfo != null) _buildQuota(),
          ],
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Results list
  // -----------------------------------------------------------------------

  /// Builds the marketplace results list, or an empty state.
  Widget _buildResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return WDiv(
        className:
            'w-full flex flex-col items-center justify-center py-12 gap-3',
        children: [
          WIcon(
            Icons.search_off,
            className: 'text-4xl text-slate-300 dark:text-slate-600',
          ),
          WText(
            trans('skills.no_results'),
            className: 'text-base font-semibold text-slate-500',
          ),
          WText(
            trans('skills.search_hint'),
            className: 'text-sm text-slate-400',
          ),
        ],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
      itemBuilder: (context, index) => _buildResultCard(results[index]),
    );
  }

  /// Builds a single marketplace result card.
  Widget _buildResultCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final sourceId = item['id']?.toString() ?? '';
    final imported = _isImported(item);
    final importing = _importingIds.contains(sourceId);

    return WDiv(
      className: '''
          rounded-xl bg-white dark:bg-gray-800
          border border-slate-200 dark:border-gray-700
          shadow-sm p-5
          flex flex-col gap-3
        ''',
      children: [
        // Header: name + import button
        WDiv(
          className: 'flex flex-row items-center justify-between',
          children: [
            WDiv(
              className: 'flex-1 flex flex-col gap-1',
              children: [
                WText(
                  name,
                  className: '''
                      text-lg font-semibold
                      text-gray-900 dark:text-white
                    ''',
                ),
                if (description.isNotEmpty)
                  WText(
                    description,
                    className: 'text-sm text-slate-500 dark:text-slate-400',
                  ),
              ],
            ),
            if (imported)
              WDiv(
                className: 'px-3 py-1.5 rounded-lg bg-emerald-500/15',
                child: WText(
                  trans('skills.imported'),
                  className: '''
                      text-sm font-medium
                      text-emerald-600 dark:text-emerald-400
                    ''',
                ),
              )
            else if (importing)
              SizedBox(
                width: 20,
                height: 20,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              WAnchor(
                onTap: () => _onImport(item),
                child: WDiv(
                  className: '''
                      px-3 py-1.5 rounded-lg
                      bg-amber-400
                    ''',
                  child: WText(
                    trans('skills.import'),
                    className: 'text-sm font-medium text-primary-900',
                  ),
                ),
              ),
          ],
        ),

        // Category badge
        if (category.isNotEmpty)
          WDiv(
            className: 'flex flex-row items-center',
            children: [
              WDiv(
                className: 'px-2.5 py-0.5 rounded-full bg-slate-500/15',
                child: WText(
                  category,
                  className: '''
                      text-xs font-medium
                      text-slate-600 dark:text-slate-400
                    ''',
                ),
              ),
            ],
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Quota display
  // -----------------------------------------------------------------------

  /// Renders the API quota info bar.
  Widget _buildQuota() {
    final quota = SkillState.instance.quotaInfo!;
    final remaining = quota['remaining']?.toString() ?? '0';
    final limit = quota['limit']?.toString() ?? '0';

    return WDiv(
      className: '''
          flex flex-row items-center justify-center
          w-full py-3
        ''',
      child: WText(
        trans('skills.quota_remaining', {
          'remaining': remaining,
          'limit': limit,
        }),
        className: 'text-sm text-slate-500 dark:text-slate-400',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search mode toggle button
// ---------------------------------------------------------------------------

class _SearchModeButton extends StatelessWidget {
  const _SearchModeButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeClass = isActive
        ? 'bg-primary text-white dark:bg-primary-700'
        : '''
            bg-white text-slate-600
            dark:bg-gray-800 dark:text-slate-300
            border border-slate-200 dark:border-gray-700
          ''';

    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: 'px-3 py-1 rounded-full $activeClass',
        child: WText(
          label,
          className: isActive
              ? 'text-sm font-medium text-white'
              : 'text-sm font-medium text-slate-600 dark:text-slate-300',
        ),
      ),
    );
  }
}
