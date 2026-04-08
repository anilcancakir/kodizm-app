import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/git_provider.dart';
import '../../../app/models/user.dart';
import '../../../app/state/git_provider_state.dart';

/// Settings view for managing Git provider OAuth integrations.
///
/// Displays connected GitHub (and other provider) accounts with avatar,
/// username, provider badge, and a disconnect action. Provides a
/// "Connect GitHub" button that fetches the OAuth redirect URL and
/// opens it via [Launch.url].
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/settings/integrations');
/// ```
class IntegrationsView extends StatefulWidget {
  /// Creates the [IntegrationsView].
  const IntegrationsView({super.key});

  @override
  State<IntegrationsView> createState() => _IntegrationsViewState();
}

class _IntegrationsViewState extends State<IntegrationsView> {
  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await GitProviderState.instance.loadProviders(teamId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GitProviderState.instance,
      builder: (context, _) {
        return GitProviderState.instance.renderState(
          (providers) => _ProviderContent(providers: providers),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: const _EmptyView(),
        );
      },
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
        WText(message, className: 'text-sm text-slate-500 dark:text-slate-400'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty view
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('integrations.title'),
          subtitle: trans('integrations.subtitle'),
        ),
        WDiv(
          className:
              'w-full flex flex-col items-center justify-center py-16 gap-4',
          children: [
            WIcon(
              Icons.link_off,
              className: 'text-4xl text-slate-400 dark:text-slate-500',
            ),
            WText(
              trans('integrations.no_providers_title'),
              className:
                  'text-base font-semibold text-gray-900 dark:text-white',
            ),
            WText(
              trans('integrations.no_providers_subtitle'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
            WSpacer(className: 'h-2'),
            _ConnectGitHubButton(),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Provider content (connected state)
// ---------------------------------------------------------------------------

class _ProviderContent extends StatelessWidget {
  const _ProviderContent({required this.providers});

  final List<GitProvider> providers;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('integrations.title'),
          subtitle: trans('integrations.subtitle'),
          actions: [_ConnectGitHubButton()],
        ),
        ...providers.map((provider) => _ProviderCard(provider: provider)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Provider card
// ---------------------------------------------------------------------------

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});

  final GitProvider provider;

  /// Shows a disconnect confirmation dialog and calls [GitProviderState.disconnect].
  void _confirmDisconnect(BuildContext context) {
    final teamId = provider.teamId;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans('integrations.disconnect')),
        content: Text(trans('integrations.disconnect_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(trans('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              GitProviderState.instance.disconnect(teamId, provider.id);
            },
            child: Text(trans('integrations.disconnect')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MagicStarterCard(
      child: WDiv(
        className: 'flex flex-row items-center gap-4',
        children: [
          // Avatar or placeholder icon
          WDiv(
            className:
                'w-10 h-10 rounded-full overflow-hidden flex items-center justify-center bg-slate-100 dark:bg-slate-800',
            child: provider.avatarUrl != null
                ? Image.network(
                    provider.avatarUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  )
                : WIcon(
                    Icons.person,
                    className: 'text-xl text-slate-400 dark:text-slate-500',
                  ),
          ),

          // Username, email, connected date
          WDiv(
            className: 'flex-1 min-w-0 flex flex-col gap-0.5',
            children: [
              WText(
                provider.displayName ?? provider.username,
                className:
                    'text-sm font-medium text-slate-800 dark:text-white truncate',
              ),
              if (provider.email != null)
                WText(
                  provider.email!,
                  className:
                      'text-xs text-slate-400 dark:text-slate-500 truncate',
                ),
              WText(
                trans('integrations.connected_at', {
                  'date': _formatDate(provider.connectedAt),
                }),
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
            ],
          ),

          // Provider badge
          WDiv(
            className:
                'px-2.5 py-1 rounded-md ${GitProviderState.providerBadgeClassName(provider.provider)}',
            child: WText(
              _providerLabel(provider.provider),
              className: 'text-xs font-semibold',
            ),
          ),

          // Disconnect button
          WAnchor(
            onTap: () => _confirmDisconnect(context),
            child: WDiv(
              className:
                  'px-3 py-1.5 rounded-lg border border-red-200 dark:border-red-800',
              child: WText(
                trans('integrations.disconnect'),
                className: 'text-xs font-medium text-red-600 dark:text-red-400',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connect GitHub button
// ---------------------------------------------------------------------------

class _ConnectGitHubButton extends StatelessWidget {
  const _ConnectGitHubButton();

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () async {
        final teamId = Auth.user<User>()?.currentTeam?.id;
        if (teamId == null) return;
        final url = await GitProviderState.instance.getRedirectUrl(teamId);
        Launch.url(url);
      },
      child: WDiv(
        className: 'px-4 py-2 rounded-lg bg-slate-900 dark:bg-white',
        child: WText(
          trans('integrations.connect_github'),
          className: 'text-sm font-medium text-white dark:text-slate-900',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Maps a provider slug to its display label.
String _providerLabel(String provider) {
  return switch (provider) {
    'github' => trans('integrations.provider_github'),
    _ => provider,
  };
}

/// Formats a [DateTime] as `YYYY-MM-DD`.
String _formatDate(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
