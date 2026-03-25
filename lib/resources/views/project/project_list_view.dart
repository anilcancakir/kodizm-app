import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';
import '../../widgets/molecules/page_header.dart';

/// Project list view — displays all projects for the authenticated user's team.
///
/// Fetches projects via [ProjectState.instance] on init, renders a sortable
/// list of [Surface card](DESIGN.md) project cards, an empty state CTA, and a
/// pull-to-refresh gesture.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects');
/// ```
class ProjectListView extends StatefulWidget {
  /// Creates the [ProjectListView].
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  /// The active sort field — defaults to name (A-Z).
  SortField _sortField = SortField.name;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await ProjectState.instance.fetchProjects(teamId);
  }

  void _onSortChanged(SortField? field) {
    if (field == null || field == _sortField) return;
    setState(() => _sortField = field);
    ProjectState.instance.sortProjects(field);
  }

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // ---------------------------------------------------------------
        // Header row: title + create button
        // ---------------------------------------------------------------
        PageHeader(
          title: 'Projects',
          subtitle: 'Manage your team\'s projects.',
          actions: [
            WAnchor(
              onTap: () => MagicRoute.to('/projects/create'),
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-amber-400
                  ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    'Create Project',
                    className: 'text-sm font-semibold text-primary',
                  ),
                ],
              ),
            ),
          ],
        ),

        // ---------------------------------------------------------------
        // Sort controls
        // ---------------------------------------------------------------
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WText(
              'Sort by:',
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            _SortButton(
              label: 'Name',
              isActive: _sortField == SortField.name,
              onTap: () => _onSortChanged(SortField.name),
            ),
            _SortButton(
              label: 'Last Updated',
              isActive: _sortField == SortField.lastUpdated,
              onTap: () => _onSortChanged(SortField.lastUpdated),
            ),
          ],
        ),

        // ---------------------------------------------------------------
        // State-driven content
        // ---------------------------------------------------------------
        ProjectState.instance.renderState(
          (projects) =>
              _ProjectGrid(projects: projects, onRefresh: _fetchProjects),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: _EmptyView(
            onCreateTap: () => MagicRoute.to('/projects/create'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sort button atom
// ---------------------------------------------------------------------------

class _SortButton extends StatelessWidget {
  const _SortButton({
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
        : 'bg-white text-slate-600 dark:bg-gray-800 dark:text-slate-300 border border-slate-200 dark:border-gray-700';

    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: 'px-3 py-1 rounded-full text-sm font-medium $activeClass',
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
      className: 'flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          'Failed to load projects',
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
  const _EmptyView({required this.onCreateTap});

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-5',
      children: [
        WDiv(
          className:
              'w-16 h-16 rounded-2xl flex items-center justify-center bg-slate-100 dark:bg-gray-800',
          child: WIcon(
            Icons.folder_open_outlined,
            className: 'text-3xl text-slate-400 dark:text-slate-500',
          ),
        ),
        WText(
          'No projects yet',
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          'Get started by creating your first project.',
          className:
              'text-sm text-slate-500 dark:text-slate-400 max-w-xs text-center',
        ),
        WAnchor(
          onTap: onCreateTap,
          child: WDiv(
            className:
                'flex flex-row items-center gap-2 px-4 py-2.5 rounded-lg bg-amber-400 shadow-xs',
            children: [
              WIcon(Icons.add, className: 'text-sm text-primary-900'),
              WText(
                'Create your first project',
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
// Project grid
// ---------------------------------------------------------------------------

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects, required this.onRefresh});

  final List<Project> projects;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: projects.length,
        separatorBuilder: (context, index) => const WSpacer(className: 'h-3'),
        itemBuilder: (context, index) => _ProjectCard(
          project: projects[index],
          onTap: () => MagicRoute.to('/projects/${projects[index].id}'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project card organism
// ---------------------------------------------------------------------------

/// Surface-variant card representing a single project.
///
/// Displays: name, repo URL (or placeholder), tech stack badge,
/// task count, and active run indicator.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActiveRuns = (project.activeRunCount ?? 0) > 0;

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
          // ---------------------------------------------------------------
          // Card header: name + active run dot
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              WText(
                project.name ?? 'Unnamed Project',
                className: '''
                  text-lg font-semibold
                  text-gray-900 dark:text-white
                ''',
              ),
              if (hasActiveRuns)
                WDiv(
                  className: 'flex flex-row items-center gap-1',
                  children: [
                    WDiv(
                      className: '''
                        w-2 h-2 rounded-full
                        bg-amber-400
                        animate-pulse
                      ''',
                    ),
                    WText(
                      '${project.activeRunCount} active',
                      className:
                          'text-xs font-medium text-amber-600 dark:text-amber-400',
                    ),
                  ],
                ),
            ],
          ),

          // ---------------------------------------------------------------
          // Repo URL
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WIcon(
                Icons.link,
                className: 'text-sm text-slate-400 dark:text-slate-500',
              ),
              WText(
                project.repositoryUrl ?? 'No repo connected',
                className: '''
                  text-sm text-slate-500 dark:text-slate-400
                ''',
              ),
            ],
          ),

          // ---------------------------------------------------------------
          // Footer row: tech stack badge + task count
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              if (project.techStack != null)
                WDiv(
                  className: '''
                    px-3 py-1 rounded-full
                    bg-slate-100 dark:bg-gray-700
                  ''',
                  child: WText(
                    project.techStack!,
                    className:
                        'text-xs font-medium text-slate-700 dark:text-slate-300',
                  ),
                )
              else
                WDiv(className: 'flex-1'),
              WDiv(
                className: 'flex flex-row items-center gap-1',
                children: [
                  WIcon(
                    Icons.task_alt,
                    className: 'text-sm text-slate-400 dark:text-slate-500',
                  ),
                  WText(
                    '${project.taskCount ?? 0} tasks',
                    className: 'text-sm text-slate-500 dark:text-slate-400',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
