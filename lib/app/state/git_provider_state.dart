import 'package:magic/magic.dart';

import '../models/git_provider.dart';

// ---------------------------------------------------------------------------
// GitProviderState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the team's Git provider OAuth connections.
///
/// Fetches the list of connected Git providers for a team from
/// `GET /teams/{teamId}/git-providers` and exposes it via [MagicStateMixin].
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final providers = GitProviderState.instance;
///
/// // Trigger a fetch — typically called from onInit or a view lifecycle.
/// await providers.loadProviders('team-uuid-001');
///
/// // React to state in a widget.
/// providers.renderState(
///   (list) => ProviderListView(providers: list),
///   onLoading: const LoadingSpinner(),
///   onError: (msg) => ErrorBanner(message: msg),
/// );
/// ```
class GitProviderState extends MagicController
    with MagicStateMixin<List<GitProvider>> {
  /// Creates a [GitProviderState].
  GitProviderState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static GitProviderState get instance => Magic.findOrPut(GitProviderState.new);

  // ---------------------------------------------------------------------------
  // Provider fetch
  // ---------------------------------------------------------------------------

  /// Fetch the Git provider list for the given [teamId].
  ///
  /// Sets loading state, calls `GET /teams/{teamId}/git-providers`, then
  /// transitions to success with the parsed [List<GitProvider>] or to error
  /// with the API message on failure.
  Future<void> loadProviders(String teamId) async {
    await fetchList<GitProvider>(
      '/teams/$teamId/git-providers',
      GitProvider.fromMap,
    );
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  /// Disconnect the Git provider identified by [providerId] for [teamId].
  ///
  /// Calls `DELETE /teams/{teamId}/git-providers/{providerId}`, then removes
  /// the entry from the current in-memory list optimistically.
  Future<void> disconnect(String teamId, String providerId) async {
    await Http.delete('/teams/$teamId/git-providers/$providerId');
    final current = rxState ?? [];
    setSuccess(current.where((p) => p.id != providerId).toList());
  }

  // ---------------------------------------------------------------------------
  // OAuth redirect
  // ---------------------------------------------------------------------------

  /// Fetch the OAuth redirect URL for initiating a new Git provider connection.
  ///
  /// Calls `GET /teams/{teamId}/git-providers/redirect` and returns the
  /// `redirect_url` string from the response payload.
  Future<String> getRedirectUrl(String teamId) async {
    final response = await Http.get('/teams/$teamId/git-providers/redirect');
    return response.data['url'] as String;
  }

  // ---------------------------------------------------------------------------
  // Static helpers — className variant maps
  // ---------------------------------------------------------------------------

  /// Returns the Tailwind className string for a provider badge.
  ///
  /// Used by views to render colored badges per Git provider without
  /// holding [Color] objects in state.
  static String providerBadgeClassName(String provider) {
    return switch (provider) {
      'github' =>
        'bg-slate-900/10 text-slate-900 dark:bg-white/10 dark:text-white',
      'gitlab' => 'bg-orange-500/10 text-orange-500',
      'bitbucket' => 'bg-blue-500/10 text-blue-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }
}
