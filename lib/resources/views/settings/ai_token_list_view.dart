import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/ai_token.dart';
import '../../../app/models/user.dart';
import '../../../app/state/ai_token_state.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';

/// Read-only list of AI provider tokens configured for the team.
///
/// Displays each token with its provider badge, label, status indicator,
/// authentication type, usage count, and last-used timestamp.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/settings/ai-tokens');
/// ```
class AiTokenListView extends StatefulWidget {
  /// Creates the [AiTokenListView].
  const AiTokenListView({super.key});

  @override
  State<AiTokenListView> createState() => _AiTokenListViewState();
}

class _AiTokenListViewState extends State<AiTokenListView> {
  @override
  void initState() {
    super.initState();
    _fetchTokens();
  }

  Future<void> _fetchTokens() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await AiTokenState.instance.loadTokens(teamId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AiTokenState.instance,
      builder: (context, _) {
        return AiTokenState.instance.renderState(
          (tokens) => _TokenContent(tokens: tokens),
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
      className: 'flex flex-col items-center justify-center py-16 gap-3',
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
        PageHeader(
          title: trans('ai_tokens.title'),
          subtitle: trans('ai_tokens.subtitle'),
        ),
        WDiv(
          className: 'flex flex-col items-center justify-center py-16 gap-3',
          children: [
            WIcon(
              Icons.key_off_outlined,
              className: 'text-4xl text-slate-400 dark:text-slate-500',
            ),
            WText(
              trans('ai_tokens.empty_title'),
              className:
                  'text-base font-semibold text-gray-900 dark:text-white',
            ),
            WText(
              trans('ai_tokens.empty_subtitle'),
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Token content
// ---------------------------------------------------------------------------

class _TokenContent extends StatelessWidget {
  const _TokenContent({required this.tokens});

  final List<AiToken> tokens;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        PageHeader(
          title: trans('ai_tokens.title'),
          subtitle: trans('ai_tokens.subtitle'),
        ),
        ...tokens.map((token) => _TokenCard(token: token)),
        WText(
          trans('ai_tokens.managed_in_admin'),
          className: 'text-sm text-slate-400 dark:text-slate-500 italic',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Token card
// ---------------------------------------------------------------------------

class _TokenCard extends StatelessWidget {
  const _TokenCard({required this.token});

  final AiToken token;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      children: [
        // Header row: provider badge + label + status dot
        WDiv(
          className: 'flex flex-row items-center gap-3',
          children: [
            // Provider badge
            WDiv(
              className:
                  'px-2.5 py-1 rounded-md ${AiTokenState.providerBadgeClassName(token.provider)}',
              child: WText(
                _providerLabel(token.provider),
                className: 'text-xs font-semibold',
              ),
            ),
            // Label
            WDiv(
              className: 'flex-1 min-w-0',
              child: WText(
                token.label,
                className:
                    'text-sm font-medium text-slate-800 dark:text-white truncate',
              ),
            ),
            // Status dot + label
            WDiv(
              className: 'flex flex-row items-center gap-1.5',
              children: [
                WDiv(
                  className:
                      'w-2 h-2 rounded-full ${AiTokenState.statusDotClassName(token.status)}',
                ),
                WText(
                  _statusLabel(token.status),
                  className: 'text-xs text-slate-500 dark:text-slate-400',
                ),
              ],
            ),
          ],
        ),
        // Details row: auth type, usage count, last used, cooldown
        WDiv(
          className: 'flex flex-row items-center gap-4 mt-2',
          children: [
            WText(
              _authTypeLabel(token.authType),
              className: 'text-xs text-slate-400',
            ),
            WText(
              trans('ai_tokens.usage_count', {
                'count': token.usageCount.toString(),
              }),
              className: 'text-xs text-slate-400',
            ),
            if (token.lastUsedAt != null)
              WText(
                trans('ai_tokens.last_used', {
                  'time': _formatDate(token.lastUsedAt!),
                }),
                className: 'text-xs text-slate-400',
              ),
            if (token.cooldownUntil != null)
              WText(
                trans('ai_tokens.cooldown_until', {
                  'time': _formatDate(token.cooldownUntil!),
                }),
                className: 'text-xs text-amber-500',
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Maps a provider slug to its display label.
String _providerLabel(String provider) {
  return switch (provider) {
    'anthropic' => trans('ai_tokens.provider_anthropic'),
    'openai' => trans('ai_tokens.provider_openai'),
    'google' => trans('ai_tokens.provider_google'),
    'openrouter' => trans('ai_tokens.provider_openrouter'),
    _ => provider,
  };
}

/// Maps a token status slug to its display label.
String _statusLabel(String status) {
  return switch (status) {
    'active' => trans('ai_tokens.status_active'),
    'inactive' => trans('ai_tokens.status_inactive'),
    'rate_limited' => trans('ai_tokens.status_rate_limited'),
    'expired' => trans('ai_tokens.status_expired'),
    _ => status,
  };
}

/// Maps an auth type slug to its display label.
String _authTypeLabel(String authType) {
  return switch (authType) {
    'api_key' => trans('ai_tokens.auth_api_key'),
    'subscription' => trans('ai_tokens.auth_subscription'),
    _ => authType,
  };
}

/// Formats a [DateTime] as `YYYY-MM-DD`.
String _formatDate(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
