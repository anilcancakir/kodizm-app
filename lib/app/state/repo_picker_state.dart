import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/git_repo.dart';

// ---------------------------------------------------------------------------
// RepoPickerState controller
// ---------------------------------------------------------------------------

/// State for the GitHub repository picker dialog.
///
/// Fetches the list of repositories available to a connected Git provider for
/// a team from `GET /teams/{teamId}/git-providers/{providerId}/repos` and
/// exposes it via [MagicStateMixin].
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final state = RepoPickerState.instance;
///
/// // Trigger a fetch — typically called when the picker dialog opens.
/// await state.loadRepos('team-uuid-001', 'provider-uuid-001');
///
/// // React to state in a widget.
/// state.renderState(
///   (repos) => RepoListView(repos: repos),
///   onLoading: const LoadingSpinner(),
///   onError: (msg) => ErrorBanner(message: msg),
/// );
/// ```
class RepoPickerState extends MagicController
    with MagicStateMixin<List<GitRepo>>, SentryStateMixin<List<GitRepo>> {
  /// Creates a [RepoPickerState].
  RepoPickerState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static RepoPickerState get instance => Magic.findOrPut(RepoPickerState.new);

  // ---------------------------------------------------------------------------
  // Repo fetch
  // ---------------------------------------------------------------------------

  /// Fetch the repository list for the given [teamId] and [providerId].
  ///
  /// Sets loading state, calls
  /// `GET /teams/{teamId}/git-providers/{providerId}/repos`, then transitions
  /// to success with the parsed [List<GitRepo>] or to error with the API
  /// message on failure.
  Future<void> loadRepos(String teamId, String providerId) async {
    await fetchList<GitRepo>(
      '/teams/$teamId/git-providers/$providerId/repos',
      GitRepo.fromMap,
    );
  }
}
