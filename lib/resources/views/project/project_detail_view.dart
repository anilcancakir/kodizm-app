import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/project_repository.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_repository_state.dart';
import '../../../app/state/project_state.dart';
import '../../../app/state/task_state.dart';
import '../../widgets/atoms/priority_badge.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';

/// Project detail view — displays a single project's full information.
///
/// Receives [projectId] from the route parameter and fetches the project
/// via [ProjectState.instance.fetchProject]. Uses the global "page header +
/// section cards" layout standard matching magic_starter's pattern.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId');
/// ```
class ProjectDetailView extends StatefulWidget {
  /// Creates the [ProjectDetailView].
  const ProjectDetailView({required this.projectId, super.key});

  /// The project UUID received from the route parameter.
  final String projectId;

  @override
  State<ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<ProjectDetailView> {
  // ---------------------------------------------------------------------------
  // Form controllers
  // ---------------------------------------------------------------------------

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _techStackController = TextEditingController();

  bool _saving = false;
  bool _deleting = false;
  bool _formPopulated = false;

  /// Tracks which repository's SSH key is currently expanded.
  String? _expandedSshRepoId;

  // ---------------------------------------------------------------------------
  // Add Repository form controllers
  // ---------------------------------------------------------------------------

  final _addRepoFormKey = GlobalKey<FormState>();
  final _repoNameController = TextEditingController();
  final _repoUrlController = TextEditingController();
  final _repoBranchController = TextEditingController();
  final _repoMountPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    _repoNameController.dispose();
    _repoUrlController.dispose();
    _repoBranchController.dispose();
    _repoMountPathController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  /// Fetches the project, repositories, and tasks from the API.
  Future<void> _fetchData() async {
    final teamId = _teamId;
    if (teamId == null) return;

    await Future.wait([
      ProjectState.instance.fetchProject(teamId, widget.projectId),
      ProjectRepositoryState.instance.fetchRepositories(
        teamId,
        widget.projectId,
      ),
      TaskState.instance.fetchTasks(teamId, widget.projectId),
    ]);

    _populateForm();
  }

  /// Fills form controllers from the currently selected project.
  void _populateForm() {
    final project = ProjectState.instance.selectedProject;
    if (project == null || _formPopulated) return;

    _nameController.text = project.name ?? '';
    _descriptionController.text = project.description ?? '';
    _techStackController.text = project.techStack ?? '';
    _formPopulated = true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The current team ID from the authenticated user.
  String? get _teamId => Auth.user<User>()?.currentTeam?.id;

  /// Whether the current user can manage project settings (owner or admin).
  bool get _canManageProject =>
      Auth.user<User>()?.currentTeam?.canManageMembers ?? false;

  /// Returns a Tailwind className for the status dot based on the repo status string.
  static String _statusDotClassName(String? status) => switch (status) {
    'connected' || 'cloned' => 'bg-emerald-500',
    'error' || 'failed' => 'bg-red-500',
    _ => 'bg-slate-300',
  };

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Saves the edited project settings.
  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tech_stack': _techStackController.text.trim(),
    };

    await ProjectState.instance.updateProject(teamId, widget.projectId, data);

    if (!mounted) return;
    setState(() => _saving = false);

    await ProjectState.instance.fetchProject(teamId, widget.projectId);
  }

  /// Shows a confirmation dialog and deletes the project.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trans('projects.delete_confirm_title')),
        content: Text(trans('projects.delete_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(trans('common.cancel')),
          ),
          // AlertDialog allowed exception — DESIGN.md danger-500.
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(trans('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _deleting = true);

    final success = await ProjectState.instance.deleteProject(
      teamId,
      widget.projectId,
    );

    if (!mounted) return;

    if (success) {
      MagicRoute.to('/projects');
    } else {
      setState(() => _deleting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Repository actions
  // ---------------------------------------------------------------------------

  /// Opens the "Add Repository" dialog.
  Future<void> _showAddRepositoryDialog() async {
    _repoNameController.clear();
    _repoUrlController.clear();
    _repoBranchController.text = 'main';
    _repoMountPathController.text = '/workspace';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trans('projects.add_repository')),
        content: Form(
          key: _addRepoFormKey,
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              WFormInput(
                controller: _repoNameController,
                label: trans('projects.repo_name'),
                labelClassName: '''
                  text-sm font-medium mb-2
                  text-slate-600 dark:text-slate-300
                ''',
                placeholder: trans('projects.repo_name_placeholder'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return trans('validation.required');
                  }
                  return null;
                },
                className: '''
                  p-3 border border-slate-200 dark:border-gray-600
                  rounded-lg bg-white dark:bg-gray-900
                  text-sm text-slate-800 dark:text-slate-200
                  focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  error:border-red-500 error:ring-2 error:ring-red-200
                ''',
                errorClassName: 'text-red-500 text-xs mt-1',
              ),
              WFormInput(
                controller: _repoUrlController,
                label: trans('projects.repo_url'),
                labelClassName: '''
                  text-sm font-medium mb-2
                  text-slate-600 dark:text-slate-300
                ''',
                placeholder: trans('projects.repo_url_placeholder'),
                className: '''
                  p-3 border border-slate-200 dark:border-gray-600
                  rounded-lg bg-white dark:bg-gray-900
                  text-sm text-slate-800 dark:text-slate-200
                  focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  error:border-red-500 error:ring-2 error:ring-red-200
                ''',
                errorClassName: 'text-red-500 text-xs mt-1',
              ),
              WFormInput(
                controller: _repoBranchController,
                label: trans('projects.default_branch'),
                labelClassName: '''
                  text-sm font-medium mb-2
                  text-slate-600 dark:text-slate-300
                ''',
                placeholder: trans('projects.default_branch_placeholder'),
                className: '''
                  p-3 border border-slate-200 dark:border-gray-600
                  rounded-lg bg-white dark:bg-gray-900
                  text-sm text-slate-800 dark:text-slate-200
                  focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  error:border-red-500 error:ring-2 error:ring-red-200
                ''',
                errorClassName: 'text-red-500 text-xs mt-1',
              ),
              WFormInput(
                controller: _repoMountPathController,
                label: trans('projects.mount_path'),
                labelClassName: '''
                  text-sm font-medium mb-2
                  text-slate-600 dark:text-slate-300
                ''',
                placeholder: trans('projects.mount_path_placeholder'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return trans('validation.required');
                  }
                  return null;
                },
                className: '''
                  p-3 border border-slate-200 dark:border-gray-600
                  rounded-lg bg-white dark:bg-gray-900
                  text-sm text-slate-800 dark:text-slate-200
                  focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
                  error:border-red-500 error:ring-2 error:ring-red-200
                ''',
                errorClassName: 'text-red-500 text-xs mt-1',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(trans('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              if (_addRepoFormKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(trans('common.save')),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    final data = <String, dynamic>{
      'name': _repoNameController.text.trim(),
      'repository_url': _repoUrlController.text.trim(),
      'default_branch': _repoBranchController.text.trim().isEmpty
          ? 'main'
          : _repoBranchController.text.trim(),
      'mount_path': _repoMountPathController.text.trim(),
    };

    await ProjectRepositoryState.instance.createRepository(
      teamId,
      widget.projectId,
      data,
    );

    if (!mounted) return;

    await ProjectRepositoryState.instance.fetchRepositories(
      teamId,
      widget.projectId,
    );
  }

  /// Shows a confirmation dialog and deletes the repository.
  Future<void> _confirmDeleteRepository(ProjectRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trans('projects.delete_repo_confirm_title')),
        content: Text(trans('projects.delete_repo_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(trans('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: Text(trans('common.delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    await ProjectRepositoryState.instance.deleteRepository(
      teamId,
      widget.projectId,
      repo.id,
    );

    if (!mounted) return;

    await ProjectRepositoryState.instance.fetchRepositories(
      teamId,
      widget.projectId,
    );
  }

  /// Generates an SSH key for the given repository.
  Future<void> _generateSshKey(ProjectRepository repo) async {
    final teamId = _teamId;
    if (teamId == null) return;

    await ProjectRepositoryState.instance.generateSshKey(
      teamId,
      widget.projectId,
      repo.id,
    );

    if (!mounted) return;

    await ProjectRepositoryState.instance.fetchRepositories(
      teamId,
      widget.projectId,
    );
  }

  /// Triggers a clone operation for the given repository.
  Future<void> _cloneRepository(ProjectRepository repo) async {
    final teamId = _teamId;
    if (teamId == null) return;

    await ProjectRepositoryState.instance.cloneRepository(
      teamId,
      widget.projectId,
      repo.id,
    );

    if (!mounted) return;

    await ProjectRepositoryState.instance.fetchRepositories(
      teamId,
      widget.projectId,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProjectState.instance,
      builder: (context, _) {
        final project = ProjectState.instance.selectedProject;

        if (project == null) {
          return const WDiv(
            className: 'flex items-center justify-center w-full py-16',
            child: CircularProgressIndicator(),
          );
        }

        return WDiv(
          className: 'p-4 lg:p-6 flex flex-col gap-6',
          children: [
            // Page header — outside cards.
            PageHeader(
              title: project.name ?? trans('projects.unnamed_project'),
              subtitle: project.description,
              actions: [_buildHeaderBadges(project)],
            ),

            // Section cards.
            _buildInfoSection(project),
            _buildRepositoriesSection(),
            _buildRecentTasksSection(),
            _buildKnowledgeSection(),
            _buildDebugChatSection(),
            if (_canManageProject) _buildSettingsSection(project),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header badges
  // ---------------------------------------------------------------------------

  /// Tech stack + execution mode badges shown in the page header trailing.
  Widget _buildHeaderBadges(Project project) {
    return WDiv(
      className: 'flex flex-row items-center gap-2',
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
          ),
        WDiv(
          className: '''
            px-3 py-1 rounded-full
            bg-slate-100 dark:bg-gray-700
          ''',
          child: WText(
            project.executionMode,
            className: 'text-xs font-medium text-slate-700 dark:text-slate-300',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Info Section
  // ---------------------------------------------------------------------------

  /// Builds the info section: created date.
  Widget _buildInfoSection(Project project) {
    return SectionCard(
      title: trans('projects.project_info'),
      children: [
        WDiv(
          className: 'flex flex-col gap-4',
          children: [
            // Created at.
            WDiv(
              className: 'flex flex-row items-center gap-2',
              children: [
                WIcon(
                  Icons.calendar_today,
                  className: 'text-sm text-slate-400 dark:text-slate-500',
                ),
                WText(
                  trans('projects.created_label', {
                    'date': project.createdAt ?? trans('common.unknown'),
                  }),
                  className: 'text-sm text-slate-600 dark:text-slate-400',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Repositories Section
  // ---------------------------------------------------------------------------

  /// Builds the repositories section with list of repos and inline add button.
  Widget _buildRepositoriesSection() {
    return ListenableBuilder(
      listenable: ProjectRepositoryState.instance,
      builder: (context, _) {
        final repositories = ProjectRepositoryState.instance.repositories;

        return SectionCard(
          title: trans('projects.repositories'),
          children: [
            // Header row with add button.
            WDiv(
              className: 'flex flex-row items-center justify-end',
              children: [
                WAnchor(
                  onTap: _showAddRepositoryDialog,
                  child: WDiv(
                    className: '''
                      flex flex-row items-center gap-2
                      px-3 py-1.5 rounded-lg
                      bg-amber-400 dark:bg-amber-500
                    ''',
                    children: [
                      WIcon(
                        Icons.add,
                        className: '''
                          text-sm font-bold
                          text-primary dark:text-primary-900
                        ''',
                      ),
                      WText(
                        trans('projects.add_repository'),
                        className: '''
                          text-sm font-medium
                          text-primary dark:text-primary-900
                        ''',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Repository list or empty state.
            if (repositories.isEmpty)
              WDiv(
                className: '''
                  flex flex-col items-center justify-center w-full
                  py-8 rounded-xl
                  bg-slate-50 dark:bg-gray-900
                ''',
                children: [
                  WIcon(
                    Icons.folder_outlined,
                    className: 'text-3xl text-slate-300 dark:text-slate-600',
                  ),
                  const WSpacer(className: 'h-2'),
                  WText(
                    trans('projects.no_repositories'),
                    className: 'text-sm text-slate-400 dark:text-slate-500',
                  ),
                ],
              )
            else
              ...repositories.map(_buildRepositoryCard),
          ],
        );
      },
    );
  }

  /// Builds a single repository card inside the repositories section.
  Widget _buildRepositoryCard(ProjectRepository repo) {
    final isExpanded = _expandedSshRepoId == repo.id;

    return WDiv(
      className: '''
        flex flex-col gap-3
        p-4 rounded-xl
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-slate-700
      ''',
      children: [
        // Row 1: Name + repo URL + copy + branch badge.
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            // Status dot.
            WDiv(
              className:
                  'w-2.5 h-2.5 rounded-full ${_statusDotClassName(repo.repoStatus)}',
            ),
            // Name.
            WText(
              repo.name,
              className:
                  'text-sm font-semibold text-slate-700 dark:text-slate-200',
            ),
            // Repo URL (truncated).
            if (repo.repositoryUrl != null)
              WDiv(
                className: 'flex-1 min-w-0',
                child: WText(
                  repo.repositoryUrl!,
                  className:
                      'text-xs text-slate-400 dark:text-slate-500 truncate',
                ),
              )
            else
              WDiv(
                className: 'flex-1',
                child: const WSpacer(className: 'w-1'),
              ),
            // Copy URL button.
            if (repo.repositoryUrl != null)
              WAnchor(
                onTap: () =>
                    Clipboard.setData(ClipboardData(text: repo.repositoryUrl!)),
                child: WIcon(
                  Icons.copy,
                  className: 'text-xs text-slate-400 dark:text-slate-500',
                ),
              ),
            // Branch badge.
            WDiv(
              className: '''
                px-2 py-0.5 rounded-full
                bg-slate-100 dark:bg-gray-700
              ''',
              child: WText(
                repo.defaultBranch,
                className:
                    'text-xs font-medium text-slate-600 dark:text-slate-400',
              ),
            ),
          ],
        ),

        // Row 2: Mount path + last synced.
        WDiv(
          className: 'flex flex-row items-center gap-4',
          children: [
            WDiv(
              className: 'flex flex-row items-center gap-1',
              children: [
                WIcon(
                  Icons.folder_outlined,
                  className: 'text-xs text-slate-400 dark:text-slate-500',
                ),
                WText(
                  repo.mountPath,
                  className: 'text-xs text-slate-500 dark:text-slate-400',
                ),
              ],
            ),
            if (repo.lastSyncedAt != null)
              WText(
                repo.lastSyncedAt!,
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
          ],
        ),

        // Row 3: Action buttons.
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            // SSH Key toggle.
            WAnchor(
              onTap: () {
                setState(() {
                  _expandedSshRepoId = isExpanded ? null : repo.id;
                });
              },
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-1
                  px-3 py-1.5 rounded-lg
                  bg-white dark:bg-gray-700
                  border border-slate-200 dark:border-gray-600
                ''',
                children: [
                  WIcon(
                    Icons.vpn_key_outlined,
                    className: 'text-xs text-slate-500 dark:text-slate-400',
                  ),
                  WText(
                    trans('projects.ssh_deploy_key'),
                    className:
                        'text-xs font-medium text-slate-600 dark:text-slate-300',
                  ),
                ],
              ),
            ),
            // Clone button.
            WAnchor(
              onTap: () => _cloneRepository(repo),
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-1
                  px-3 py-1.5 rounded-lg
                  bg-white dark:bg-gray-700
                  border border-slate-200 dark:border-gray-600
                ''',
                children: [
                  WIcon(
                    Icons.download_outlined,
                    className: 'text-xs text-slate-500 dark:text-slate-400',
                  ),
                  WText(
                    trans('projects.clone_repo'),
                    className:
                        'text-xs font-medium text-slate-600 dark:text-slate-300',
                  ),
                ],
              ),
            ),
            // Delete button.
            WAnchor(
              onTap: () => _confirmDeleteRepository(repo),
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-1
                  px-3 py-1.5 rounded-lg
                  bg-white dark:bg-gray-700
                  border border-red-200 dark:border-red-800
                ''',
                children: [
                  WIcon(
                    Icons.delete_outlined,
                    className: 'text-xs text-red-500 dark:text-red-400',
                  ),
                  WText(
                    trans('projects.delete_repo'),
                    className:
                        'text-xs font-medium text-red-500 dark:text-red-400',
                  ),
                ],
              ),
            ),
          ],
        ),

        // Expanded SSH key section.
        if (isExpanded)
          WDiv(
            className: '''
              rounded-xl
              bg-slate-50 dark:bg-gray-900
              border border-slate-200 dark:border-gray-700
              p-4
            ''',
            children: [
              if (repo.sshPublicKey != null &&
                  repo.sshPublicKey!.isNotEmpty) ...[
                WDiv(
                  className: 'flex flex-row items-start gap-2',
                  children: [
                    WDiv(
                      className: 'flex-1 min-w-0',
                      // SelectableText + TextStyle allowed exception (CLAUDE.md).
                      child: SelectableText(
                        repo.sshPublicKey!,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    WAnchor(
                      onTap: () => Clipboard.setData(
                        ClipboardData(text: repo.sshPublicKey!),
                      ),
                      child: WIcon(
                        Icons.copy,
                        className: 'text-sm text-slate-400 dark:text-slate-500',
                      ),
                    ),
                  ],
                ),
              ] else ...[
                WText(
                  trans('projects.no_ssh_key'),
                  className: 'text-sm text-slate-500 dark:text-slate-400',
                ),
              ],
              const WSpacer(className: 'h-3'),
              // Generate key button.
              WAnchor(
                onTap: () => _generateSshKey(repo),
                child: WDiv(
                  className: '''
                    flex flex-row items-center gap-2
                    px-4 py-2 rounded-lg
                    bg-white dark:bg-gray-700
                    border border-slate-200 dark:border-gray-600
                  ''',
                  children: [
                    WText(
                      trans('projects.generate_new_key'),
                      className: '''
                        text-sm font-medium
                        text-slate-600 dark:text-slate-300
                      ''',
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Recent Tasks Section
  // ---------------------------------------------------------------------------

  /// Builds the recent tasks section showing the latest 5 tasks.
  Widget _buildRecentTasksSection() {
    return ListenableBuilder(
      listenable: TaskState.instance,
      builder: (context, _) {
        final tasks = TaskState.instance.rxState;

        return SectionCard(
          title: trans('projects.recent_tasks'),
          children: [
            if (tasks == null || tasks.isEmpty)
              WDiv(
                className: '''
                  flex flex-col items-center justify-center w-full
                  py-8 rounded-xl
                  bg-slate-50 dark:bg-gray-900
                ''',
                children: [
                  WIcon(
                    Icons.task_alt,
                    className: 'text-3xl text-slate-300 dark:text-slate-600',
                  ),
                  const WSpacer(className: 'h-2'),
                  WText(
                    trans('projects.tasks_placeholder'),
                    className: 'text-sm text-slate-400 dark:text-slate-500',
                  ),
                ],
              )
            else ...[
              ...tasks
                  .take(5)
                  .map(
                    (task) => WAnchor(
                      onTap: () => MagicRoute.to(
                        '/projects/${widget.projectId}/tasks/${task.id}',
                      ),
                      child: WDiv(
                        className: '''
                      flex flex-row items-center gap-3
                      p-3 rounded-xl
                      bg-white dark:bg-gray-800
                      border border-slate-200 dark:border-slate-700
                    ''',
                        children: [
                          WDiv(
                            className: 'flex-1',
                            child: WText(
                              task.title ?? trans('projects.unnamed_project'),
                              className:
                                  'text-sm font-medium text-slate-700 dark:text-slate-200',
                            ),
                          ),
                          StatusBadge(status: task.status ?? 'draft'),
                          PriorityBadge(priority: task.priority ?? 'p3'),
                        ],
                      ),
                    ),
                  ),
              const WSpacer(className: 'h-2'),
              WAnchor(
                onTap: () =>
                    MagicRoute.to('/projects/${widget.projectId}/tasks'),
                child: WText(
                  trans('projects.view_all_tasks'),
                  className: 'text-sm font-medium text-amber-500',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Knowledge Section
  // ---------------------------------------------------------------------------

  /// Builds the knowledge base link section.
  Widget _buildKnowledgeSection() {
    return SectionCard(
      title: trans('knowledge.title'),
      children: [
        WAnchor(
          onTap: () => MagicRoute.to('/projects/${widget.projectId}/knowledge'),
          child: WDiv(
            className: '''
              flex flex-row items-center gap-3
              p-3 rounded-xl
              bg-white dark:bg-gray-800
              border border-slate-200 dark:border-slate-700
            ''',
            children: [
              WIcon(
                Icons.library_books_outlined,
                className: 'text-base text-slate-400 dark:text-slate-500',
              ),
              WDiv(
                className: 'flex-1',
                child: WText(
                  trans('knowledge.subtitle'),
                  className: 'text-sm text-slate-600 dark:text-slate-400',
                ),
              ),
              WIcon(Icons.chevron_right, className: 'text-base text-slate-400'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Debug Chat Section
  // ---------------------------------------------------------------------------

  /// Builds the debug chat link section for real-time conversation testing.
  Widget _buildDebugChatSection() {
    return SectionCard(
      title: trans('conversation_chat.title'),
      children: [
        WAnchor(
          onTap: () => MagicRoute.to('/projects/${widget.projectId}/chat'),
          child: WDiv(
            className: '''
              flex flex-row items-center gap-3
              p-3 rounded-xl
              bg-white dark:bg-gray-800
              border border-slate-200 dark:border-slate-700
            ''',
            children: [
              WIcon(
                Icons.chat_outlined,
                className: 'text-base text-slate-400 dark:text-slate-500',
              ),
              WDiv(
                className: 'flex-1',
                child: WText(
                  trans('conversation_chat.title'),
                  className: 'text-sm text-slate-600 dark:text-slate-400',
                ),
              ),
              WIcon(Icons.chevron_right, className: 'text-base text-slate-400'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Settings Section
  // ---------------------------------------------------------------------------

  /// Builds the settings section with edit form and delete button.
  Widget _buildSettingsSection(Project project) {
    return SectionCard(
      title: trans('projects.settings'),
      children: [
        Form(
          key: _formKey,
          child: WDiv(
            className: 'flex flex-col gap-5',
            children: [
              _buildField(
                label: trans('projects.project_name'),
                hint: trans('projects.name_placeholder'),
                controller: _nameController,
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return trans('projects.name_required');
                  }
                  return null;
                },
              ),
              _buildField(
                label: trans('projects.description'),
                hint: trans('projects.description_placeholder'),
                controller: _descriptionController,
                maxLines: 3,
              ),
              _buildField(
                label: trans('projects.tech_stack'),
                hint: trans('projects.tech_stack_placeholder'),
                controller: _techStackController,
              ),
              const WSpacer(className: 'h-1'),

              // Action buttons.
              WDiv(
                className: 'flex flex-row items-center justify-between',
                children: [
                  // Delete button.
                  WAnchor(
                    onTap: _deleting ? null : _confirmDelete,
                    child: WDiv(
                      className: '''
                        flex flex-row items-center gap-2
                        px-4 py-2 rounded-lg
                        bg-red-500 dark:bg-red-600
                      ''',
                      children: [
                        if (_deleting)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        WText(
                          trans('projects.delete_project'),
                          className: 'text-sm font-semibold text-white',
                        ),
                      ],
                    ),
                  ),

                  // Save button.
                  WAnchor(
                    onTap: _saving ? null : _saveChanges,
                    child: WDiv(
                      className: '''
                        flex flex-row items-center gap-2
                        px-5 py-2 rounded-lg
                        bg-amber-400 dark:bg-amber-500
                      ''',
                      children: [
                        if (_saving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF334E68),
                              ),
                            ),
                          ),
                        WText(
                          trans('projects.save_changes'),
                          className: '''
                            text-sm font-semibold
                            text-primary dark:text-primary-900
                          ''',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Field builder
  // ---------------------------------------------------------------------------

  /// Builds a labelled [WFormInput] field with proper label-input spacing.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return WFormInput(
      controller: controller,
      type: maxLines > 1 ? InputType.multiline : InputType.text,
      label: required ? '$label *' : label,
      labelClassName: '''
        text-sm font-medium mb-2
        text-slate-600 dark:text-slate-300
      ''',
      placeholder: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      validator: validator,
      className: '''
        p-3 border border-slate-200 dark:border-gray-600
        rounded-lg bg-white dark:bg-gray-900
        text-sm text-slate-800 dark:text-slate-200
        focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
        error:border-red-500 error:ring-2 error:ring-red-200
      ''',
      errorClassName: 'text-red-500 text-xs mt-1',
    );
  }
}
