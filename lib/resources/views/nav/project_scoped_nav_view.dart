import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';

/// Thin redirect view for top-level sidebar nav items that need project context.
///
/// Checks the user's projects and redirects to the project-scoped route:
/// - 0 projects → empty state with link to create project
/// - 1 project → immediate redirect to `/projects/{id}/{targetPath}`
/// - N projects → project picker list
///
/// ## Usage
///
/// ```dart
/// MagicRoute.page('/tasks', () => const ProjectScopedNavView(targetPath: 'tasks'));
/// MagicRoute.page('/knowledge', () => const ProjectScopedNavView(targetPath: 'knowledge'));
/// ```
class ProjectScopedNavView extends StatefulWidget {
  /// Creates a [ProjectScopedNavView] that will redirect to the given [targetPath].
  const ProjectScopedNavView({super.key, required this.targetPath});

  /// The path segment to append after the project ID (e.g., `'tasks'`, `'knowledge'`).
  final String targetPath;

  @override
  State<ProjectScopedNavView> createState() => _ProjectScopedNavViewState();
}

class _ProjectScopedNavViewState extends State<ProjectScopedNavView> {
  @override
  void initState() {
    super.initState();
    _loadAndRedirect();
  }

  /// Loads projects and auto-redirects when exactly one project exists.
  Future<void> _loadAndRedirect() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;

    await ProjectState.instance.fetchProjects(teamId);

    if (!mounted) return;

    final projects = ProjectState.instance.rxState;
    if (projects != null && projects.length == 1) {
      MagicRoute.to('/projects/${projects.first.id}/${widget.targetPath}');
    }
    // else: stay on this view — show picker or empty state.
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProjectState.instance,
      builder: (context, _) {
        if (ProjectState.instance.isLoading) {
          return const WDiv(
            className: 'w-full flex items-center justify-center py-16',
            child: CircularProgressIndicator(),
          );
        }

        final projects = ProjectState.instance.rxState;

        if (projects == null || projects.isEmpty) {
          return _buildEmptyState();
        }

        // Multiple projects — show picker.
        return _buildProjectPicker(projects);
      },
    );
  }

  /// Builds the empty state prompting the user to create a project.
  Widget _buildEmptyState() {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        PageHeader(
          title: trans('nav.select_project'),
          subtitle: trans('nav.select_project_subtitle', {
            'target': widget.targetPath,
          }),
        ),
        SectionCard(
          children: [
            WDiv(
              className:
                  'flex flex-col items-center justify-center w-full py-8',
              children: [
                WIcon(
                  Icons.folder_outlined,
                  className: 'text-4xl text-slate-300',
                ),
                const WSpacer(className: 'h-2'),
                WText(
                  trans('projects.empty_title'),
                  className: 'text-lg font-semibold text-slate-500',
                ),
                const WSpacer(className: 'h-4'),
                WAnchor(
                  onTap: () => MagicRoute.to('/projects/create'),
                  child: WDiv(
                    className: 'px-4 py-2 rounded-lg bg-amber-400',
                    child: WText(
                      trans('projects.create_project'),
                      className: 'text-sm font-semibold text-primary',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the project picker list for multi-project teams.
  Widget _buildProjectPicker(List<Project> projects) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        PageHeader(
          title: trans('nav.select_project'),
          subtitle: trans('nav.select_project_subtitle', {
            'target': widget.targetPath,
          }),
        ),
        SectionCard(
          children: [
            for (final project in projects)
              WAnchor(
                onTap: () => MagicRoute.to(
                  '/projects/${project.id}/${widget.targetPath}',
                ),
                child: WDiv(
                  className: '''
                    flex flex-row items-center gap-3
                    p-3 rounded-xl
                    bg-white dark:bg-gray-800
                    border border-slate-200 dark:border-slate-700
                  ''',
                  children: [
                    WIcon(
                      Icons.folder_outlined,
                      className: 'text-base text-slate-400',
                    ),
                    WDiv(
                      className: 'flex-1',
                      child: WText(
                        project.name ?? trans('projects.unnamed_project'),
                        className:
                            'text-sm font-medium text-slate-700 dark:text-slate-200',
                      ),
                    ),
                    WIcon(
                      Icons.chevron_right,
                      className: 'text-base text-slate-400',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
