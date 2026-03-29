import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/project_repository.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_repository_state.dart';
import '../../../app/state/project_state.dart';
import '../../../app/state/task_state.dart';
import '../../widgets/atoms/app_dialog.dart';
import '../../widgets/atoms/priority_badge.dart';
import '../../widgets/atoms/status_badge.dart';
import 'package:magic_starter/magic_starter.dart';

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
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _techStackController = TextEditingController();

  /// Whether the user has manually edited the short_name field.
  bool _shortNameManuallyEdited = false;

  bool _saving = false;
  bool _deleting = false;
  bool _formPopulated = false;

  // ---------------------------------------------------------------------------
  // Add Repository form controllers
  // ---------------------------------------------------------------------------

  final _addRepoFormKey = GlobalKey<FormState>();
  final _repoNameController = TextEditingController();
  final _repoUrlController = TextEditingController();
  final _repoBranchController = TextEditingController();
  final _repoMountDirController = TextEditingController();
  bool _mountDirManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    ProjectRepositoryState.instance.unsubscribeFromTeam();
    _nameController.removeListener(_onNameChangedForShortName);
    _nameController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    _repoNameController.dispose();
    _repoUrlController.dispose();
    _repoBranchController.dispose();
    _repoMountDirController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  /// Fetches the project, repositories, and tasks from the API.
  ///
  /// After loading, subscribes to the team channel for real-time
  /// repo clone status updates via WebSocket.
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

    // Subscribe to team channel for real-time repo status events.
    ProjectRepositoryState.instance.subscribeToTeam(teamId, widget.projectId);
  }

  /// Fills form controllers from the currently selected project.
  void _populateForm() {
    final project = ProjectState.instance.selectedProject;
    if (project == null || _formPopulated) return;

    _nameController.text = project.name ?? '';
    _shortNameController.text = project.shortName ?? '';
    _descriptionController.text = project.description ?? '';
    _techStackController.text = project.techStack ?? '';

    // If the project already has a short_name, treat it as manually set.
    _shortNameManuallyEdited = (project.shortName ?? '').isNotEmpty;
    _nameController.addListener(_onNameChangedForShortName);

    _formPopulated = true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Computes a short name suggestion from the project name.
  ///
  /// Takes the first letter of each word, uppercases, max 5 chars.
  void _onNameChangedForShortName() {
    if (_shortNameManuallyEdited) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _shortNameController.text = '';
      return;
    }

    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(5)
        .join();

    _shortNameController.text = initials;
  }

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
      'short_name': _shortNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'tech_stack': _techStackController.text.trim(),
    };

    await ProjectState.instance.updateProject(teamId, widget.projectId, data);

    if (!mounted) return;
    setState(() => _saving = false);

    await ProjectState.instance.fetchProject(teamId, widget.projectId);
  }

  /// Shows a password confirmation dialog and deletes the project.
  Future<void> _confirmDelete() async {
    final confirmed = await MagicStarterPasswordConfirmDialog.show(
      context,
      title: trans('projects.delete_confirm_title'),
      description: trans('projects.delete_confirm_body'),
      onConfirm: (password) async {
        final response = await Http.post(
          '/auth/confirm-password',
          data: {'password': password},
        );

        if (!response.successful) {
          return response.errorMessage ?? trans('errors.invalid_password');
        }

        return null;
      },
    );

    if (!confirmed || !mounted) return;

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

  /// Shows a confirmation dialog before regenerating the SSH key.
  Future<void> _confirmRegenerateSshKey() async {
    final confirmed = await MagicStarterConfirmDialog.show(
      context,
      title: trans('projects.regenerate_ssh_confirm_title'),
      description: trans('projects.regenerate_ssh_confirm_body'),
      confirmLabel: trans('projects.regenerate_ssh_confirm_action'),
      variant: ConfirmDialogVariant.danger,
    );

    if (confirmed != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    await ProjectState.instance.regenerateSshKey(teamId, widget.projectId);
  }

  // ---------------------------------------------------------------------------
  // Repository actions
  // ---------------------------------------------------------------------------

  /// Extracts the repository folder name from a git URL.
  ///
  /// Supports SSH (`git@github.com:org/repo.git`) and HTTPS
  /// (`https://github.com/org/repo.git`) formats.
  String? _extractRepoNameFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // Take the last path segment and strip .git suffix.
    final lastSegment = trimmed.split(RegExp(r'[/:]')).last;
    final name = lastSegment.endsWith('.git')
        ? lastSegment.substring(0, lastSegment.length - 4)
        : lastSegment;

    return name.isNotEmpty ? name : null;
  }

  /// Auto-populates mount directory from URL changes.
  void _onRepoUrlChanged() {
    if (_mountDirManuallyEdited) return;

    final name = _extractRepoNameFromUrl(_repoUrlController.text);
    _repoMountDirController.text = name ?? '';
  }

  /// Opens the "Add Repository" dialog.
  Future<void> _showAddRepositoryDialog() async {
    _repoNameController.clear();
    _repoUrlController.clear();
    _repoBranchController.text = 'master';
    _repoMountDirController.clear();
    _mountDirManuallyEdited = false;

    _repoUrlController.addListener(_onRepoUrlChanged);

    final result = await AppDialog.show<bool>(
      context: context,
      title: trans('projects.add_repository'),
      body: Form(
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
              controller: _repoMountDirController,
              label: trans('projects.mount_directory'),
              labelClassName: '''
                  text-sm font-medium mb-2
                  text-slate-600 dark:text-slate-300
                ''',
              placeholder: trans('projects.mount_directory_placeholder'),
              onChanged: (_) {
                _mountDirManuallyEdited = true;
              },
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
      footer: WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(context).pop(false),
            child: WDiv(
              className: AppDialog.theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          WAnchor(
            onTap: () {
              if (_addRepoFormKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: WDiv(
              className: AppDialog.theme.primaryButtonClassName,
              child: WText(trans('common.save'), className: 'text-inherit'),
            ),
          ),
        ],
      ),
    );

    _repoUrlController.removeListener(_onRepoUrlChanged);

    if (result != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    final repoUrl = _repoUrlController.text.trim();
    final mountDir = _repoMountDirController.text.trim();
    final data = <String, dynamic>{
      'name': _repoNameController.text.trim(),
      'repository_url': repoUrl,
      'default_branch': _repoBranchController.text.trim().isEmpty
          ? 'master'
          : _repoBranchController.text.trim(),
      if (mountDir.isNotEmpty) 'mount_path': '/workspace/$mountDir',
    };

    final created = await ProjectRepositoryState.instance.createRepository(
      teamId,
      widget.projectId,
      data,
    );

    if (!mounted) return;

    await ProjectRepositoryState.instance.fetchRepositories(
      teamId,
      widget.projectId,
    );

    // If the newly created repo has a URL, a clone job was dispatched
    // server-side — mark as cloning so the UI shows a spinner immediately.
    // The WebSocket subscription will handle the status update.
    if (created != null && repoUrl.isNotEmpty) {
      ProjectRepositoryState.instance.markAsCloning(created.id);
    }
  }

  /// Shows a confirmation dialog and deletes the repository.
  Future<void> _confirmDeleteRepository(ProjectRepository repo) async {
    final confirmed = await MagicStarterConfirmDialog.show(
      context,
      title: trans('projects.delete_repo_confirm_title'),
      description: trans('projects.delete_repo_confirm_body'),
      confirmLabel: trans('common.delete'),
      variant: ConfirmDialogVariant.danger,
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

  /// Triggers a clone operation for the given repository.
  Future<void> _cloneRepository(ProjectRepository repo) async {
    final teamId = _teamId;
    if (teamId == null) return;

    // Immediately show cloning state and clear any previous error.
    ProjectRepositoryState.instance.markAsCloning(repo.id);

    await ProjectRepositoryState.instance.cloneRepository(
      teamId,
      widget.projectId,
      repo.id,
    );
  }

  /// Designates [repo] as the primary repository for the project.
  Future<void> _setMainRepository(ProjectRepository repo) async {
    final teamId = _teamId;
    if (teamId == null) return;

    await ProjectRepositoryState.instance.setMainRepository(
      teamId,
      widget.projectId,
      repo.id,
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
            MagicStarterPageHeader(
              title: project.name ?? trans('projects.unnamed_project'),
              subtitle: project.description,
              actions: [_buildHeaderBadges(project)],
            ),

            // Section cards.
            _buildInfoSection(project),
            _buildSshKeySection(project),
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

  /// Short name + tech stack + execution mode badges shown in the page header trailing.
  Widget _buildHeaderBadges(Project project) {
    return WDiv(
      className: 'flex flex-row items-center gap-2',
      children: [
        if (project.shortName != null && project.shortName!.isNotEmpty)
          WDiv(
            className: '''
              px-3 py-1 rounded-full
              bg-amber-100 dark:bg-amber-900/30
            ''',
            child: WText(
              project.shortName!,
              className: 'text-xs font-bold text-amber-700 dark:text-amber-400',
            ),
          ),
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
    return MagicStarterCard(
      title: trans('projects.project_info'),
      child: WDiv(
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
    );
  }

  // ---------------------------------------------------------------------------
  // SSH Key Section
  // ---------------------------------------------------------------------------

  /// Builds the project-level SSH key section with key display and regenerate button.
  Widget _buildSshKeySection(Project project) {
    return MagicStarterCard(
      title: trans('projects.ssh_section_title'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (project.hasSshKey &&
              project.sshPublicKey != null &&
              project.sshPublicKey!.isNotEmpty) ...[
            WDiv(
              className: '''
              rounded-xl
              bg-slate-50 dark:bg-gray-900
              border border-slate-200 dark:border-gray-700
              p-4
            ''',
              children: [
                WDiv(
                  className: 'flex flex-row items-start gap-2',
                  children: [
                    WDiv(
                      className: 'flex-1 min-w-0',
                      // SelectableText + TextStyle allowed exception (CLAUDE.md).
                      child: SelectableText(
                        project.sshPublicKey!,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    WAnchor(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: project.sshPublicKey!),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(trans('projects.ssh_key_copied')),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: WIcon(
                        Icons.copy,
                        className: 'text-sm text-slate-400 dark:text-slate-500',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            WText(
              trans('projects.no_ssh_key'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
          ],
          WAnchor(
            onTap: () => _confirmRegenerateSshKey(),
            child: WDiv(
              className: '''
              flex flex-row items-center gap-2
              px-4 py-2 rounded-lg
              bg-white dark:bg-gray-700
              border border-slate-200 dark:border-gray-600
            ''',
              children: [
                WIcon(
                  Icons.vpn_key_outlined,
                  className: 'text-xs text-slate-500 dark:text-slate-400',
                ),
                WText(
                  trans('projects.regenerate_ssh_key'),
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

        return MagicStarterCard(
          title: trans('projects.repositories'),
          child: WDiv(
            className: 'flex flex-col gap-4',
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
          ),
        );
      },
    );
  }

  /// Builds a single repository card inside the repositories section.
  Widget _buildRepositoryCard(ProjectRepository repo) {
    final project = ProjectState.instance.selectedProject;
    final repoState = ProjectRepositoryState.instance;
    final status = repoState.repoStatuses[repo.id] ?? repo.repoStatus;
    final isCloning = status == 'cloning';
    final isCloned = status == 'cloned';
    final isError = status == 'error';
    final errorMessage = repoState.repoErrors[repo.id] ?? repo.repoError;

    return WDiv(
      className: '''
        flex flex-col gap-3
        p-4 rounded-xl
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-slate-700
      ''',
      children: [
        // Row 1: Name + repo URL + copy + branch badge + star toggle.
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            // Status indicator — spinner for cloning, icon for terminal states,
            // fallback dot for unknown/not_cloned.
            if (isCloning)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else if (isCloned)
              WIcon(Icons.check_circle, className: 'text-sm text-emerald-500')
            else if (isError)
              WIcon(Icons.error_outline, className: 'text-sm text-red-500')
            else
              WDiv(
                className:
                    'w-2.5 h-2.5 rounded-full ${_statusDotClassName(status)}',
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
                onTap: () {
                  Clipboard.setData(ClipboardData(text: repo.repositoryUrl!));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(trans('projects.url_copied')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
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
            // Star toggle — filled amber for main repo, outline for others.
            Tooltip(
              message: repo.isMain
                  ? trans('projects.main_repository')
                  : trans('projects.set_as_main'),
              child: WAnchor(
                onTap: repo.isMain ? null : () => _setMainRepository(repo),
                child: WIcon(
                  repo.isMain ? Icons.star : Icons.star_outline,
                  className: repo.isMain
                      ? 'text-base text-amber-400'
                      : 'text-base text-slate-400 dark:text-slate-500',
                ),
              ),
            ),
          ],
        ),

        // Row 2: Mount path + last synced + clone status label.
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
            // Clone status label for non-null terminal/active states.
            if (isCloning)
              WText(
                trans('projects.clone_in_progress'),
                className: 'text-xs text-slate-500 dark:text-slate-400',
              )
            else if (isCloned)
              WText(
                trans('projects.clone_complete'),
                className: 'text-xs text-emerald-600 dark:text-emerald-400',
              )
            else if (isError)
              WText(
                trans('projects.clone_failed'),
                className: 'text-xs text-red-500 dark:text-red-400',
              ),
          ],
        ),

        // Error detail banner.
        if (isError && errorMessage != null && errorMessage.isNotEmpty)
          WDiv(
            className: '''
              p-3 rounded-lg
              bg-red-50 dark:bg-red-900/20
              border border-red-200 dark:border-red-800
            ''',
            child: WText(
              errorMessage,
              className: 'text-xs text-red-600 dark:text-red-400',
            ),
          ),

        // Row 3: Action buttons — clone hidden when cloned or cloning.
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            // Clone button — hidden when repo is already cloned or cloning.
            if (!isCloned && !isCloning)
              WAnchor(
                onTap: (project?.hasSshKey ?? false)
                    ? () => _cloneRepository(repo)
                    : null,
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

        return MagicStarterCard(
          title: trans('projects.recent_tasks'),
          child: WDiv(
            className: 'flex flex-col gap-4',
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
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Knowledge Section
  // ---------------------------------------------------------------------------

  /// Builds the knowledge base link section.
  Widget _buildKnowledgeSection() {
    return MagicStarterCard(
      title: trans('knowledge.title'),
      child: WAnchor(
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
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Debug Chat Section
  // ---------------------------------------------------------------------------

  /// Builds the debug chat link section for real-time conversation testing.
  Widget _buildDebugChatSection() {
    return MagicStarterCard(
      title: trans('conversation_chat.title'),
      child: WAnchor(
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
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Settings Section
  // ---------------------------------------------------------------------------

  /// Builds the settings section with edit form and delete button.
  Widget _buildSettingsSection(Project project) {
    return MagicStarterCard(
      title: trans('projects.settings'),
      child: Form(
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
            _buildShortNameField(),
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
            // Action buttons — right-aligned.
            WDiv(
              className: 'w-full flex flex-row items-center justify-end gap-3',
              children: [
                // Delete button.
                WAnchor(
                  onTap: _deleting ? null : _confirmDelete,
                  child: WDiv(
                    className: '''
                      flex flex-row items-center gap-2
                      px-4 py-2 rounded-lg
                      border border-red-500 dark:border-red-600
                    ''',
                    children: [
                      if (_deleting)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      WText(
                        trans('projects.delete_project'),
                        className: '''
                          text-sm font-semibold
                          text-red-500 dark:text-red-400
                        ''',
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
    );
  }

  // ---------------------------------------------------------------------------
  // Field builder
  // ---------------------------------------------------------------------------

  /// Builds the short name [WFormInput] with uppercase enforcement and validation.
  Widget _buildShortNameField() {
    return WFormInput(
      controller: _shortNameController,
      label: '${trans('projects.short_name')} *',
      labelClassName: '''
        text-sm font-medium mb-2
        text-slate-600 dark:text-slate-300
      ''',
      placeholder: trans('projects.short_name_placeholder'),
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        _shortNameManuallyEdited = true;
      },
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return trans('projects.short_name_invalid');
        }
        if (trimmed.length < 2 ||
            trimmed.length > 5 ||
            !RegExp(r'^[A-Z]+$').hasMatch(trimmed)) {
          return trans('projects.short_name_invalid');
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
    );
  }

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
