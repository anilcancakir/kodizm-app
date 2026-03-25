import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';

/// Project detail view — displays a single project's full information.
///
/// Receives [projectId] from the route parameter and fetches the project
/// via [ProjectState.instance.fetchProject]. Renders header, info, SSH key,
/// git status, recent tasks placeholder, and settings sections.
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
  final _repositoryUrlController = TextEditingController();
  final _techStackController = TextEditingController();
  final _defaultBranchController = TextEditingController();

  bool _saving = false;
  bool _deleting = false;
  bool _generatingKey = false;
  bool _checkingStatus = false;
  bool _formPopulated = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _repositoryUrlController.dispose();
    _techStackController.dispose();
    _defaultBranchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  /// Fetches the project and repo status from the API.
  Future<void> _fetchData() async {
    final teamId = _teamId;
    if (teamId == null) return;

    await Future.wait([
      ProjectState.instance.fetchProject(teamId, widget.projectId),
      ProjectState.instance.fetchRepoStatus(teamId, widget.projectId),
    ]);

    _populateForm();
  }

  /// Fills form controllers from the currently selected project.
  void _populateForm() {
    final project = ProjectState.instance.selectedProject;
    if (project == null || _formPopulated) return;

    _nameController.text = project.name ?? '';
    _descriptionController.text = project.description ?? '';
    _repositoryUrlController.text = project.repositoryUrl ?? '';
    _techStackController.text = project.techStack ?? '';
    _defaultBranchController.text = project.defaultBranch;
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

  /// Returns a status dot color based on the repo status string.
  Color _statusDotColor(String? status) {
    if (status == null) return const Color(0xFFCBD5E1); // grey — not configured
    switch (status) {
      case 'connected':
      case 'cloned':
        return const Color(0xFF10B981); // green
      case 'error':
      case 'failed':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFFCBD5E1); // grey
    }
  }

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
      'repository_url': _repositoryUrlController.text.trim(),
      'tech_stack': _techStackController.text.trim(),
      'default_branch': _defaultBranchController.text.trim().isEmpty
          ? 'main'
          : _defaultBranchController.text.trim(),
    };

    await ProjectState.instance.updateProject(teamId, widget.projectId, data);

    if (!mounted) return;
    setState(() => _saving = false);

    // Refresh project data after save.
    await ProjectState.instance.fetchProject(teamId, widget.projectId);
  }

  /// Shows a confirmation dialog and deletes the project.
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: const Text(
          'This action cannot be undone. All project data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
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

  /// Generates a new SSH key after confirmation.
  Future<void> _confirmGenerateKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate New SSH Key?'),
        content: const Text(
          'This will replace the existing deploy key. You will need to update your repository settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _generatingKey = true);

    await ProjectState.instance.generateSshKey(teamId, widget.projectId);

    if (!mounted) return;

    // Refresh project to get the new key.
    await ProjectState.instance.fetchProject(teamId, widget.projectId);

    if (!mounted) return;
    setState(() => _generatingKey = false);
  }

  /// Fetches the latest repo status.
  Future<void> _checkStatus() async {
    final teamId = _teamId;
    if (teamId == null) return;

    setState(() => _checkingStatus = true);

    await ProjectState.instance.fetchRepoStatus(teamId, widget.projectId);

    if (!mounted) return;
    setState(() => _checkingStatus = false);
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
        final repoStatus = ProjectState.instance.repoStatus;

        if (project == null) {
          return const WDiv(
            className: 'flex items-center justify-center py-16',
            child: CircularProgressIndicator(),
          );
        }

        return SingleChildScrollView(
          child: WDiv(
            className: 'w-full max-w-4xl mx-auto p-4',
            child: WDiv(
              className: 'flex flex-col gap-6',
              children: [
                _buildHeader(project),
                _buildInfoSection(project),
                _buildSshKeySection(project),
                _buildGitStatusSection(repoStatus),
                _buildRecentTasksSection(),
                if (_canManageProject) _buildSettingsSection(project),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header
  // ---------------------------------------------------------------------------

  /// Builds the header section with project name, description, badges.
  Widget _buildHeader(Project project) {
    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          project.name ?? 'Unnamed Project',
          className: '''
            text-2xl font-bold
            text-gray-900 dark:text-white
          ''',
        ),
        if (project.description != null &&
            (project.description as String).isNotEmpty) ...[
          const WSpacer(className: 'h-2'),
          WText(
            project.description!,
            className: 'text-sm text-slate-500 dark:text-slate-400',
          ),
        ],
        const WSpacer(className: 'h-3'),
        WDiv(
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
                className:
                    'text-xs font-medium text-slate-700 dark:text-slate-300',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Info Section
  // ---------------------------------------------------------------------------

  /// Builds the info section: repo URL, default branch, created date.
  Widget _buildInfoSection(Project project) {
    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          'Project Info',
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        const WSpacer(className: 'h-4'),
        // Repository URL
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(
              Icons.link,
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
            Expanded(
              child: WText(
                project.repositoryUrl ?? 'No repository configured',
                className: 'text-sm text-slate-600 dark:text-slate-400',
              ),
            ),
            if (project.repositoryUrl != null)
              WAnchor(
                onTap: () => Clipboard.setData(
                  ClipboardData(text: project.repositoryUrl!),
                ),
                child: WIcon(
                  Icons.copy,
                  className: 'text-sm text-slate-400 dark:text-slate-500',
                ),
              ),
          ],
        ),
        const WSpacer(className: 'h-3'),
        // Default branch
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(
              Icons.alt_route,
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
            WText(
              'Branch: ${project.defaultBranch}',
              className: 'text-sm text-slate-600 dark:text-slate-400',
            ),
          ],
        ),
        const WSpacer(className: 'h-3'),
        // Created at
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(
              Icons.calendar_today,
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
            WText(
              'Created: ${project.createdAt ?? 'Unknown'}',
              className: 'text-sm text-slate-600 dark:text-slate-400',
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SSH Key Section
  // ---------------------------------------------------------------------------

  /// Builds the SSH deploy key section with monospace key display.
  Widget _buildSshKeySection(Project project) {
    final publicKey = project.sshPublicKey;

    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          'SSH Deploy Key',
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        const WSpacer(className: 'h-4'),

        // Inset card with key
        WDiv(
          className: '''
            rounded-xl
            bg-slate-50 dark:bg-gray-900
            border border-slate-200 dark:border-gray-700
            p-4
          ''',
          children: [
            if (publicKey != null && publicKey.isNotEmpty) ...[
              WDiv(
                className: 'flex flex-row items-start gap-2',
                children: [
                  Expanded(
                    child: SelectableText(
                      publicKey,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: Color(0xFF475569), // slate-700
                      ),
                    ),
                  ),
                  WAnchor(
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: publicKey)),
                    child: WIcon(
                      Icons.copy,
                      className: 'text-sm text-slate-400 dark:text-slate-500',
                    ),
                  ),
                ],
              ),
            ] else ...[
              WText(
                'No SSH key generated yet.',
                className: 'text-sm text-slate-500 dark:text-slate-400',
              ),
            ],
          ],
        ),
        const WSpacer(className: 'h-4'),

        // Generate button
        WAnchor(
          onTap: _generatingKey ? null : _confirmGenerateKey,
          child: WDiv(
            className: '''
              flex flex-row items-center gap-2
              px-4 py-2 rounded-lg
              bg-white dark:bg-gray-700
              border border-slate-200 dark:border-gray-600
            ''',
            children: [
              if (_generatingKey)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              WText(
                'Generate New Key',
                className:
                    'text-sm font-medium text-gray-700 dark:text-gray-300',
              ),
            ],
          ),
        ),
        const WSpacer(className: 'h-3'),

        // Instructions
        WText(
          'Add this public key as a deploy key in your repository settings to allow Kodizm agents read access.',
          className: 'text-xs text-slate-400 dark:text-slate-500',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Git Status Section
  // ---------------------------------------------------------------------------

  /// Builds the git status section with status indicator dot.
  Widget _buildGitStatusSection(String? repoStatus) {
    final dotColor = _statusDotColor(repoStatus);
    final statusLabel = repoStatus ?? 'not configured';

    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          'Git Status',
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        const WSpacer(className: 'h-4'),
        WDiv(
          className: 'flex flex-row items-center justify-between',
          children: [
            WDiv(
              className: 'flex flex-row items-center gap-3',
              children: [
                // Status dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                WText(
                  statusLabel,
                  className:
                      'text-sm font-medium text-slate-700 dark:text-slate-300',
                ),
              ],
            ),
            // Check Status button
            WAnchor(
              onTap: _checkingStatus ? null : _checkStatus,
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-white dark:bg-gray-700
                  border border-slate-200 dark:border-gray-600
                ''',
                children: [
                  if (_checkingStatus)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  WText(
                    'Check Status',
                    className:
                        'text-sm font-medium text-gray-700 dark:text-gray-300',
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
  // 5. Recent Tasks Section (placeholder)
  // ---------------------------------------------------------------------------

  /// Builds the recent tasks placeholder section.
  Widget _buildRecentTasksSection() {
    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          'Recent Tasks',
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        const WSpacer(className: 'h-4'),
        WDiv(
          className: '''
            flex flex-col items-center justify-center
            py-8
            rounded-xl
            bg-slate-50 dark:bg-gray-900
            border border-slate-200 dark:border-gray-700
          ''',
          children: [
            WIcon(
              Icons.task_alt,
              className: 'text-3xl text-slate-300 dark:text-slate-600',
            ),
            const WSpacer(className: 'h-2'),
            WText(
              'Tasks will appear here',
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Settings Section
  // ---------------------------------------------------------------------------

  /// Builds the settings section with edit form and delete button.
  Widget _buildSettingsSection(Project project) {
    return WDiv(
      className: '''
        rounded-2xl bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        p-6
      ''',
      children: [
        WText(
          'Settings',
          className: 'text-lg font-semibold text-gray-900 dark:text-white',
        ),
        const WSpacer(className: 'h-4'),
        Form(
          key: _formKey,
          child: WDiv(
            className: 'flex flex-col gap-4',
            children: [
              _buildField(
                label: 'Project Name',
                hint: 'My Awesome Project',
                controller: _nameController,
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Project name is required.';
                  }
                  return null;
                },
              ),
              _buildField(
                label: 'Description',
                hint: 'A short description of the project',
                controller: _descriptionController,
                maxLines: 3,
              ),
              _buildField(
                label: 'Repository URL',
                hint: 'https://github.com/org/repo',
                controller: _repositoryUrlController,
                keyboardType: TextInputType.url,
              ),
              _buildField(
                label: 'Tech Stack',
                hint: 'Laravel, Flutter, Docker',
                controller: _techStackController,
              ),
              _buildField(
                label: 'Default Branch',
                hint: 'main',
                controller: _defaultBranchController,
              ),
              const WSpacer(className: 'h-2'),

              // Action buttons
              WDiv(
                className: 'flex flex-row items-center justify-between',
                children: [
                  // Delete button
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
                          'Delete Project',
                          className: 'text-sm font-semibold text-white',
                        ),
                      ],
                    ),
                  ),

                  // Save button
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
                          'Save Changes',
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

  /// Builds a labelled [WFormInput] field.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return WFormInput(
      controller: controller,
      type: maxLines > 1 ? InputType.multiline : InputType.text,
      label: required ? '$label *' : label,
      labelClassName: '''
        text-sm font-medium
        text-gray-700 dark:text-gray-300
      ''',
      placeholder: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      validator: validator,
      className: '''
        p-3 border border-slate-200 dark:border-gray-600
        rounded-lg bg-white dark:bg-gray-900
        text-sm text-slate-800 dark:text-slate-200
        focus:border-primary focus:ring-2 focus:ring-primary/20
        error:border-red-500 error:ring-2 error:ring-red-200
      ''',
      errorClassName: 'text-red-500 text-xs mt-1',
    );
  }
}
