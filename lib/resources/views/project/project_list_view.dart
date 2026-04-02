import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';
import '../../widgets/organisms/project_create_modal.dart';
import 'package:magic_starter/magic_starter.dart';

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

  /// Opens the create project modal and navigates to the new project on success.
  Future<void> _onCreateProject(BuildContext context) async {
    final project = await ProjectCreateModal.show(context);
    if (project != null) {
      MagicRoute.to('/projects/${project.id}');
    }
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
        MagicStarterPageHeader(
          title: trans('projects.title'),
          subtitle: trans('projects.manage_subtitle'),
          actions: [
            WAnchor(
              onTap: () => _onCreateProject(context),
              child: WDiv(
                className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-amber-400
                  ''',
                children: [
                  WIcon(Icons.add, className: 'text-base text-primary'),
                  WText(
                    trans('projects.create_project'),
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
              trans('projects.sort_by'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            _SortButton(
              label: trans('projects.sort_name'),
              isActive: _sortField == SortField.name,
              onTap: () => _onSortChanged(SortField.name),
            ),
            _SortButton(
              label: trans('projects.sort_last_updated'),
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
          onEmpty: // ignore: const_widgets_require_const_arguments
          _EmptyView(
            onCreateTap: () => _onCreateProject(context),
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
          trans('projects.failed_to_load'),
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
          trans('projects.empty_title'),
          className: 'text-lg font-semibold text-slate-800 dark:text-white',
        ),
        WText(
          trans('projects.empty_subtitle'),
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
                trans('projects.create_your_first'),
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
          // Card header: short_name badge + name + active run dot
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  if (project.shortName != null &&
                      project.shortName!.isNotEmpty)
                    WDiv(
                      className: '''
                        px-2 py-0.5 rounded-full
                        bg-amber-100 dark:bg-amber-900/30
                      ''',
                      child: WText(
                        project.shortName!,
                        className: '''
                          text-xs font-bold
                          text-amber-700 dark:text-amber-400
                        ''',
                      ),
                    ),
                  WText(
                    project.name ?? trans('projects.unnamed_project'),
                    className: '''
                      text-lg font-semibold
                      text-gray-900 dark:text-white
                    ''',
                  ),
                ],
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
                      trans('projects.active_count', {
                        'count': project.activeRunCount.toString(),
                      }),
                      className:
                          'text-xs font-medium text-amber-600 dark:text-amber-400',
                    ),
                  ],
                ),
            ],
          ),

          // ---------------------------------------------------------------
          // Repositories count badge
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WIcon(
                Icons.folder_copy_outlined,
                className: 'text-sm text-slate-400 dark:text-slate-500',
              ),
              WText(
                project.repositoriesCount > 0
                    ? trans('projects.repo_count', {
                        'count': project.repositoriesCount.toString(),
                      })
                    : trans('projects.no_repositories'),
                className: 'text-sm text-slate-500 dark:text-slate-400',
              ),
            ],
          ),

          // ---------------------------------------------------------------
          // Footer row: tech stack badge + task count
          // ---------------------------------------------------------------
          WDiv(
            className: 'flex flex-row items-center justify-between',
            children: [
              if (project.techStack.isNotEmpty)
                WDiv(
                  className: '''
                    px-3 py-1 rounded-full
                    bg-slate-100 dark:bg-gray-700
                  ''',
                  child: WText(
                    project.techStack.join(', '),
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
                    trans('projects.task_count', {
                      'count': (project.taskCount ?? 0).toString(),
                    }),
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
