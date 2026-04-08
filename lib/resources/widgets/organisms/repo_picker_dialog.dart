import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/git_repo.dart';
import '../../../app/state/repo_picker_state.dart';

// ---------------------------------------------------------------------------
// RepoPickerDialog
// ---------------------------------------------------------------------------

/// Dialog organism for selecting a GitHub repository from a connected provider.
///
/// Fetches the user's repositories via [RepoPickerState], displays them in a
/// searchable list, and creates a `ProjectRepository` via `POST` when the user
/// selects one. Provides an "Add manually" escape hatch for users who prefer
/// to enter the repository URL directly.
///
/// Returns `true` when a repository was successfully added, `false` when the
/// user chose "Add manually", or `null` when the dialog was dismissed.
///
/// ## Usage
///
/// ```dart
/// final result = await RepoPickerDialog.show(
///   context,
///   teamId: 'team-uuid',
///   projectId: 'project-uuid',
///   providerId: 'provider-uuid',
/// );
/// if (result == true) { /* repo added */ }
/// if (result == false) { /* show manual form */ }
/// ```
class RepoPickerDialog extends StatefulWidget {
  /// Creates a [RepoPickerDialog].
  const RepoPickerDialog._({
    required this.teamId,
    required this.projectId,
    required this.providerId,
  });

  /// The team owning the project.
  final String teamId;

  /// The project to attach the repository to.
  final String projectId;

  /// The Git provider whose repos to fetch.
  final String providerId;

  // -------------------------------------------------------------------------
  // Static entry point
  // -------------------------------------------------------------------------

  /// Opens the repo picker dialog and returns the result.
  ///
  /// Returns `true` when a repository was created, `false` when the user chose
  /// "Add manually", or `null` on dismiss.
  static Future<bool?> show(
    BuildContext context, {
    required String teamId,
    required String projectId,
    required String providerId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => RepoPickerDialog._(
        teamId: teamId,
        projectId: projectId,
        providerId: providerId,
      ),
    );
  }

  @override
  State<RepoPickerDialog> createState() => _RepoPickerDialogState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _RepoPickerDialogState extends State<RepoPickerDialog> {
  // -------

  final TextEditingController _searchController = TextEditingController();

  /// Filter query applied to the repo list.
  String _filter = '';

  /// Whether an API call to create the repository is in flight.
  bool _isCreating = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    RepoPickerState.instance.loadRepos(widget.teamId, widget.providerId);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Handlers
  // -------------------------------------------------------------------------

  /// Syncs the filter string with the search input.
  void _onSearchChanged() {
    setState(() => _filter = _searchController.text.toLowerCase());
  }

  /// Filters [repos] by the current [_filter] string.
  List<GitRepo> _filtered(List<GitRepo> repos) {
    if (_filter.isEmpty) return repos;
    return repos
        .where((r) => r.fullName.toLowerCase().contains(_filter))
        .toList();
  }

  /// Creates a `ProjectRepository` from the selected [repo] and closes the
  /// dialog on success.
  Future<void> _selectRepo(GitRepo repo) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    try {
      final nameParts = repo.fullName.split('/');
      final name = nameParts.length > 1 ? nameParts.last : repo.fullName;

      await Http.post(
        '/teams/${widget.teamId}/projects/${widget.projectId}/repositories',
        data: {
          'name': name,
          'repository_url': repo.sshUrl,
          'default_branch': repo.defaultBranch,
          'git_provider_id': widget.providerId,
          'is_main': false,
        },
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  /// Returns `false` to signal the caller should show the manual form.
  void _onAddManually() => Navigator.of(context).pop(false);

  /// Closes without a selection.
  void _onCancel() => Navigator.of(context).pop();

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;

    return MagicStarterDialogShell(
      title: trans('repos.picker_title'),
      body: ListenableBuilder(
        listenable: RepoPickerState.instance,
        builder: (context, _) {
          return RepoPickerState.instance.renderState(
            (repos) => _buildContent(repos),
            onLoading: _buildLoading(),
            onError: (msg) => _buildError(msg),
            onEmpty: _buildEmpty(),
          );
        },
      ),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-between items-center',
        children: [
          // "Add manually" link on the left
          WAnchor(
            onTap: _onAddManually,
            child: WText(
              trans('repos.add_manually'),
              className: 'text-sm text-slate-500 dark:text-slate-400 underline',
            ),
          ),

          // Cancel button on the right
          WAnchor(
            onTap: _onCancel,
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sub-builders
  // -------------------------------------------------------------------------

  /// Full content: search field + filtered repo list.
  Widget _buildContent(List<GitRepo> repos) {
    final visible = _filtered(repos);

    return WDiv(
      className: 'w-full flex flex-col gap-3',
      children: [
        // Search field
        WFormInput(
          controller: _searchController,
          label: trans('repos.search_placeholder'),
          prefix: WIcon(Icons.search, className: 'text-sm text-slate-400'),
        ),

        // Creating overlay
        if (_isCreating)
          WDiv(
            className:
                'w-full flex flex-row items-center justify-center gap-2 py-4',
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              WText(
                trans('repos.adding'),
                className: 'text-sm text-slate-500 dark:text-slate-400',
              ),
            ],
          ),

        // Repo list or empty search result
        if (!_isCreating && visible.isEmpty)
          _buildEmpty()
        else if (!_isCreating)
          WDiv(
            className: 'w-full flex flex-col gap-1 max-h-80 overflow-y-auto',
            children: [for (final repo in visible) _buildRepoRow(repo)],
          ),
      ],
    );
  }

  /// Single repo row: name, description, private badge, select action.
  Widget _buildRepoRow(GitRepo repo) {
    return WAnchor(
      onTap: () => _selectRepo(repo),
      child: WDiv(
        className: '''
          p-3 rounded-xl
          bg-slate-50 dark:bg-gray-800
          flex flex-row items-center gap-3
          hover:bg-slate-100 dark:hover:bg-gray-700
        ''',
        children: [
          // Repo icon
          WIcon(
            Icons.folder_outlined,
            className: 'text-lg text-slate-400 dark:text-slate-500',
          ),

          // Name + description
          WDiv(
            className: 'flex-1 min-w-0 flex flex-col gap-0.5',
            children: [
              WText(
                repo.fullName,
                className:
                    'text-sm font-medium text-slate-800 dark:text-white truncate',
              ),
              if (repo.description != null && repo.description!.isNotEmpty)
                WText(
                  repo.description!,
                  className:
                      'text-xs text-slate-400 dark:text-slate-500 truncate',
                ),
            ],
          ),

          // Private badge
          if (repo.isPrivate)
            WDiv(
              className:
                  'px-2 py-0.5 rounded-md bg-slate-200/60 dark:bg-slate-700',
              child: WText(
                trans('repos.private_badge'),
                className:
                    'text-xs font-medium text-slate-500 dark:text-slate-400',
              ),
            ),

          // Select indicator
          WIcon(
            Icons.chevron_right,
            className: 'text-lg text-slate-300 dark:text-slate-600',
          ),
        ],
      ),
    );
  }

  /// Loading spinner.
  Widget _buildLoading() {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-12',
      child: CircularProgressIndicator(),
    );
  }

  /// Error state.
  Widget _buildError(String message) {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-8 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          message,
          className: 'text-sm text-slate-500 dark:text-slate-400 text-center',
        ),
      ],
    );
  }

  /// Empty state — no repos found.
  Widget _buildEmpty() {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-8 gap-3',
      children: [
        WIcon(
          Icons.inbox_outlined,
          className: 'text-4xl text-slate-300 dark:text-slate-600',
        ),
        WText(
          trans('repos.no_repos'),
          className: 'text-sm text-slate-500 dark:text-slate-400 text-center',
        ),
      ],
    );
  }
}
