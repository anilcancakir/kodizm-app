import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/skill.dart';
import '../../../app/state/skill_state.dart';

// ---------------------------------------------------------------------------
// SkillListView
// ---------------------------------------------------------------------------

/// Skill list view — displays all locally available skills for the team.
///
/// Fetches skills via [SkillState.instance] on init and renders loading,
/// empty, error, and content states. Provides navigation to the marketplace
/// and individual skill detail pages.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/skills');
/// ```
class SkillListView extends StatefulWidget {
  /// Creates the [SkillListView].
  const SkillListView({super.key});

  @override
  State<SkillListView> createState() => _SkillListViewState();
}

class _SkillListViewState extends State<SkillListView> {
  @override
  void initState() {
    super.initState();
    _fetchSkills();
  }

  /// Fetches all skills for the current team.
  Future<void> _fetchSkills() async {
    await SkillState.instance.fetchSkills();
  }

  // -----------------------------------------------------------------------
  // Category badge className map
  // -----------------------------------------------------------------------

  /// Returns Tailwind className for a category badge pill.
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

  /// Returns Tailwind className for a source badge pill.
  static String _sourceBadgeClassName(String? source) {
    return switch (source) {
      'marketplace' => 'bg-indigo-500/15 text-indigo-600 dark:text-indigo-400',
      _ => 'bg-slate-500/15 text-slate-600 dark:text-slate-400',
    };
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header: title + marketplace / create actions
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: trans('skills.title'),
          subtitle: trans('skills.subtitle'),
          actions: [
            WAnchor(
              onTap: () => MagicRoute.to('/skills/marketplace'),
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-white dark:bg-gray-800
                    border border-slate-200 dark:border-gray-700
                  ''',
                children: [
                  WIcon(
                    Icons.store_outlined,
                    className: 'text-base text-primary-500',
                  ),
                  WText(
                    trans('skills.marketplace'),
                    className: 'text-sm font-semibold text-primary-500',
                  ),
                ],
              ),
            ),
            WAnchor(
              onTap: () {
                // Create skill — future phase, no-op for now.
              },
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-amber-400
                  ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('skills.create_skill'),
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // -----------------------------------------------------------------
        // State-driven content
        // -----------------------------------------------------------------
        SkillState.instance.renderState(
          (skills) => _SkillGrid(
            skills: skills,
            onRefresh: _fetchSkills,
            categoryBadgeClassName: _categoryBadgeClassName,
            sourceBadgeClassName: _sourceBadgeClassName,
          ),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: _EmptyView(
            onMarketplaceTap: () => MagicRoute.to('/skills/marketplace'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          trans('common.error'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        WText(message, className: 'text-sm text-slate-500 dark:text-slate-400'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state view
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onMarketplaceTap});

  final VoidCallback onMarketplaceTap;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-5',
      children: [
        WDiv(
          className: '''
              w-16 h-16 rounded-2xl flex items-center justify-center
              bg-slate-100 dark:bg-gray-800
            ''',
          child: WIcon(
            Icons.auto_awesome_outlined,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          trans('skills.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('skills.empty_subtitle'),
          className: '''
              text-sm text-slate-500 dark:text-slate-400
              max-w-xs text-center
            ''',
        ),
        WAnchor(
          onTap: onMarketplaceTap,
          child: WDiv(
            className: '''
                flex flex-row items-center gap-2
                px-4 py-2.5 rounded-lg
                bg-amber-400 shadow-xs
              ''',
            children: [
              WIcon(
                Icons.store_outlined,
                className: 'text-sm text-primary-900',
              ),
              WText(
                trans('skills.marketplace'),
                className: 'text-sm font-medium text-primary-900',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Skill grid
// ---------------------------------------------------------------------------

class _SkillGrid extends StatelessWidget {
  const _SkillGrid({
    required this.skills,
    required this.onRefresh,
    required this.categoryBadgeClassName,
    required this.sourceBadgeClassName,
  });

  final List<Skill> skills;
  final Future<void> Function() onRefresh;
  final String Function(String?) categoryBadgeClassName;
  final String Function(String?) sourceBadgeClassName;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: skills.length,
        separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
        itemBuilder: (context, index) => _SkillCard(
          skill: skills[index],
          categoryBadgeClassName: categoryBadgeClassName,
          sourceBadgeClassName: sourceBadgeClassName,
          onTap: () => MagicRoute.to('/skills/${skills[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skill card
// ---------------------------------------------------------------------------

/// Surface card representing a single skill.
///
/// Displays: name, description, category badge, source badge,
/// and active/inactive status.
class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.categoryBadgeClassName,
    required this.sourceBadgeClassName,
    required this.onTap,
  });

  final Skill skill;
  final String Function(String?) categoryBadgeClassName;
  final String Function(String?) sourceBadgeClassName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: '''
            rounded-xl bg-white dark:bg-gray-800
            border border-slate-200 dark:border-gray-700
            shadow-sm p-5
            flex flex-col gap-3
          ''',
        children: [
          // -----------------------------------------------------------------
          // Header: name + active badge
          // -----------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              WText(
                skill.name ?? '',
                className: '''
                    text-lg font-semibold
                    text-gray-900 dark:text-white
                  ''',
              ),
              WDiv(
                className: skill.isActive
                    ? 'px-2.5 py-0.5 rounded-full bg-emerald-500/15'
                    : 'px-2.5 py-0.5 rounded-full bg-slate-500/15',
                child: WText(
                  skill.isActive
                      ? trans('skills.active')
                      : trans('skills.inactive'),
                  className: skill.isActive
                      ? 'text-xs font-medium text-emerald-600 dark:text-emerald-400'
                      : 'text-xs font-medium text-slate-500 dark:text-slate-400',
                ),
              ),
            ],
          ),

          // -----------------------------------------------------------------
          // Description
          // -----------------------------------------------------------------
          if (skill.description != null && skill.description!.isNotEmpty)
            WText(
              skill.description!,
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),

          // -----------------------------------------------------------------
          // Footer: category + source badges
          // -----------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              if (skill.category != null && skill.category!.isNotEmpty)
                WDiv(
                  className:
                      'px-2.5 py-0.5 rounded-full ${categoryBadgeClassName(skill.category)}',
                  child: WText(
                    skill.category!,
                    className: 'text-xs font-medium',
                  ),
                ),
              if (skill.source != null && skill.source!.isNotEmpty)
                WDiv(
                  className:
                      'px-2.5 py-0.5 rounded-full ${sourceBadgeClassName(skill.source)}',
                  child: WText(
                    skill.source == 'marketplace'
                        ? trans('skills.marketplace')
                        : trans('skills.local'),
                    className: 'text-xs font-medium',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
