import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/skill.dart';
import '../../../app/state/skill_state.dart';

// ---------------------------------------------------------------------------
// SkillDetailView
// ---------------------------------------------------------------------------

/// Skill detail screen — displays full information for a single skill.
///
/// Shows name, description, category, scope, source, body content,
/// and active/inactive status. Fetches via [SkillState.instance.fetchSkill].
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/skills/$skillId');
/// // or construct directly:
/// SkillDetailView(skillId: 'skill-uuid-001')
/// ```
class SkillDetailView extends StatefulWidget {
  /// Creates a [SkillDetailView] for the given [skillId].
  const SkillDetailView({super.key, required this.skillId});

  /// The skill UUID to display.
  final String skillId;

  @override
  State<SkillDetailView> createState() => _SkillDetailViewState();
}

class _SkillDetailViewState extends State<SkillDetailView> {
  bool _loading = true;
  Skill? _skill;

  @override
  void initState() {
    super.initState();
    _loadSkill();
  }

  /// Fetches the skill by ID and updates local state.
  Future<void> _loadSkill() async {
    setState(() => _loading = true);
    final skill = await SkillState.instance.fetchSkill(widget.skillId);
    setState(() {
      _skill = skill;
      _loading = false;
    });
  }

  // -----------------------------------------------------------------------
  // Badge helpers
  // -----------------------------------------------------------------------

  /// Returns Tailwind className for the scope badge.
  static String _scopeBadgeClassName(String? scope) {
    return switch (scope) {
      'global' => 'bg-blue-500/15 text-blue-600 dark:text-blue-400',
      'project' => 'bg-teal-500/15 text-teal-600 dark:text-teal-400',
      _ => 'bg-slate-500/15 text-slate-600 dark:text-slate-400',
    };
  }

  /// Returns Tailwind className for the source badge.
  static String _sourceBadgeClassName(String? source) {
    return switch (source) {
      'marketplace' => 'bg-indigo-500/15 text-indigo-600 dark:text-indigo-400',
      _ => 'bg-slate-500/15 text-slate-600 dark:text-slate-400',
    };
  }

  /// Returns Tailwind className for the category badge.
  static String _categoryBadgeClassName(String? category) {
    return switch (category) {
      'coding' => 'bg-teal-500/15 text-teal-600 dark:text-teal-400',
      'devops' => 'bg-blue-500/15 text-blue-600 dark:text-blue-400',
      'testing' => 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400',
      'design' => 'bg-violet-500/15 text-violet-600 dark:text-violet-400',
      'writing' => 'bg-amber-500/15 text-amber-600 dark:text-amber-400',
      _ => 'bg-slate-500/15 text-slate-600 dark:text-slate-400',
    };
  }

  /// Returns the translated scope label.
  static String _scopeLabel(String? scope) {
    return switch (scope) {
      'global' => trans('skills.scope_global'),
      'project' => trans('skills.scope_project'),
      _ => scope ?? '',
    };
  }

  /// Returns the translated source label.
  static String _sourceLabel(String? source) {
    return switch (source) {
      'marketplace' => trans('skills.source_marketplace'),
      _ => trans('skills.source_local'),
    };
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const WDiv(
        className: 'w-full flex items-center justify-center py-16',
        child: CircularProgressIndicator(),
      );
    }

    if (_skill == null) {
      return _buildNotFound();
    }

    final skill = _skill!;

    return MagicTitle(
      title: skill.name ?? '',
      child: WDiv(
        className: 'p-4 lg:p-6 flex flex-col gap-6',
        children: [
          // -----------------------------------------------------------------
          // Header
          // -----------------------------------------------------------------
          MagicStarterPageHeader(
            title: skill.name ?? trans('skills.detail_title'),
            subtitle: skill.description ?? '',
            actions: [
              WDiv(
                className: skill.isActive
                    ? 'px-3 py-1 rounded-full bg-emerald-500/15'
                    : 'px-3 py-1 rounded-full bg-slate-500/15',
                child: WText(
                  skill.isActive
                      ? trans('skills.active')
                      : trans('skills.inactive'),
                  className: skill.isActive
                      ? 'text-sm font-medium text-emerald-600 dark:text-emerald-400'
                      : 'text-sm font-medium text-slate-500 dark:text-slate-400',
                ),
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // Metadata card
          // -----------------------------------------------------------------
          MagicStarterCard(
            child: WDiv(
              className: 'flex flex-col gap-4',
              children: [
                // Category + scope + source badges row
                WDiv(
                  className: 'flex flex-row items-center gap-2',
                  children: [
                    if (skill.category?.isNotEmpty ?? false)
                      WDiv(
                        className:
                            'px-2.5 py-0.5 rounded-full ${_categoryBadgeClassName(skill.category)}',
                        child: WText(
                          skill.category!,
                          className: 'text-xs font-medium',
                        ),
                      ),
                    WDiv(
                      className:
                          'px-2.5 py-0.5 rounded-full ${_scopeBadgeClassName(skill.scope)}',
                      child: WText(
                        _scopeLabel(skill.scope),
                        className: 'text-xs font-medium',
                      ),
                    ),
                    WDiv(
                      className:
                          'px-2.5 py-0.5 rounded-full ${_sourceBadgeClassName(skill.source)}',
                      child: WText(
                        _sourceLabel(skill.source),
                        className: 'text-xs font-medium',
                      ),
                    ),
                  ],
                ),

                // When to use
                if (skill.whenToUse?.isNotEmpty ?? false) ...[
                  WText(
                    trans('skills.when_to_use'),
                    className: '''
                      text-sm font-semibold
                      text-slate-700 dark:text-slate-300
                    ''',
                  ),
                  WText(
                    skill.whenToUse!,
                    className: 'text-sm text-slate-500 dark:text-slate-400',
                  ),
                ],

                // Source URL
                if (skill.sourceUrl?.isNotEmpty ?? false)
                  WDiv(
                    className: 'flex flex-row items-center gap-2',
                    children: [
                      WIcon(Icons.link, className: 'text-sm text-slate-400'),
                      WText(
                        skill.sourceUrl!,
                        className: 'text-sm text-blue-500 dark:text-blue-400',
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // -----------------------------------------------------------------
          // Skill body card
          // -----------------------------------------------------------------
          if (skill.body?.isNotEmpty ?? false)
            MagicStarterCard(
              child: WDiv(
                className: 'flex flex-col gap-3',
                children: [
                  WText(
                    trans('skills.skill_body'),
                    className: '''
                      text-base font-semibold
                      text-gray-900 dark:text-white
                    ''',
                  ),
                  WDiv(
                    className: '''
                      p-4 rounded-lg
                      bg-slate-50 dark:bg-gray-900
                    ''',
                    child: WText(
                      skill.body!,
                      className: '''
                        text-sm font-mono
                        text-slate-700 dark:text-slate-300
                      ''',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Not found state
  // -----------------------------------------------------------------------

  /// Displays a not-found message when the skill cannot be loaded.
  Widget _buildNotFound() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(title: trans('skills.detail_title')),
        WDiv(
          className:
              'w-full flex flex-col items-center justify-center py-16 gap-4',
          children: [
            WIcon(
              Icons.search_off,
              className: 'text-4xl text-slate-300 dark:text-slate-600',
            ),
            WText(
              trans('skills.not_found'),
              className:
                  'text-lg font-semibold text-slate-500 dark:text-slate-400',
            ),
            WText(
              trans('skills.not_found_subtitle'),
              className: '''
                  text-sm text-slate-400 dark:text-slate-500
                  max-w-xs text-center
                ''',
            ),
          ],
        ),
      ],
    );
  }
}
