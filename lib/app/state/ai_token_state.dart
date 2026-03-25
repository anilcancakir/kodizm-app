import 'package:magic/magic.dart';

import '../models/ai_token.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin read-only interface over the HTTP GET verb [AiTokenState] uses.
///
/// In production the default [_MagicHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class AiTokenHttpClient {
  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });
}

/// Default production [AiTokenHttpClient] backed by the Magic [Http] facade.
class _MagicHttpClient implements AiTokenHttpClient {
  const _MagicHttpClient();

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => Http.get(url, query: query, headers: headers);
}

// ---------------------------------------------------------------------------
// AiTokenState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for the team's AI provider tokens.
///
/// Fetches the list of AI tokens configured for a team from
/// `GET /teams/{teamId}/ai-tokens` and exposes it via [MagicStateMixin].
///
/// The controller is a singleton managed by [Magic.findOrPut] — access it
/// through [instance] rather than constructing directly (except in tests).
///
/// ## Usage
///
/// ```dart
/// // Access the singleton.
/// final tokens = AiTokenState.instance;
///
/// // Trigger a fetch — typically called from onInit or a view lifecycle.
/// await tokens.loadTokens('team-uuid-001');
///
/// // React to state in a widget.
/// tokens.renderState(
///   (list) => TokenListView(tokens: list),
///   onLoading: const LoadingSpinner(),
///   onError: (msg) => ErrorBanner(message: msg),
/// );
/// ```
class AiTokenState extends MagicController with MagicStateMixin<List<AiToken>> {
  /// Creates an [AiTokenState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicHttpClient].
  AiTokenState({AiTokenHttpClient? httpClient})
    : _http = httpClient ?? const _MagicHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static AiTokenState get instance => Magic.findOrPut(AiTokenState.new);

  final AiTokenHttpClient _http;

  // ---------------------------------------------------------------------------
  // Token fetch
  // ---------------------------------------------------------------------------

  /// Fetch the AI token list for the given [teamId].
  ///
  /// Sets loading state, calls `GET /teams/{teamId}/ai-tokens`, then
  /// transitions to success with the parsed [List<AiToken>] or to error
  /// with the API message on failure.
  Future<void> loadTokens(String teamId) async {
    setLoading();

    final response = await _http.get('/teams/$teamId/ai-tokens');

    if (response.successful) {
      final raw = response.data as Map<String, dynamic>;
      final list = (raw['data'] as List<dynamic>)
          .map((item) => AiToken.fromMap(item as Map<String, dynamic>))
          .toList();
      list.isEmpty ? setEmpty() : setSuccess(list);
    } else {
      setError(response.errorMessage ?? 'Failed to load AI tokens');
    }
  }

  // ---------------------------------------------------------------------------
  // Static helpers — className variant maps
  // ---------------------------------------------------------------------------

  /// Returns the Tailwind className string for a provider badge.
  ///
  /// Used by views to render colored badges per AI provider without
  /// holding [Color] objects in state.
  static String providerBadgeClassName(String provider) {
    return switch (provider) {
      'anthropic' => 'bg-violet-500/10 text-violet-500',
      'openai' => 'bg-emerald-500/10 text-emerald-500',
      'google' => 'bg-blue-500/10 text-blue-500',
      'openrouter' => 'bg-amber-500/10 text-amber-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  /// Returns the Tailwind className string for a status indicator dot.
  ///
  /// Used by views to render colored status dots per token status without
  /// holding [Color] objects in state.
  static String statusDotClassName(String status) {
    return switch (status) {
      'active' => 'bg-emerald-400',
      'inactive' => 'bg-slate-400',
      'rate_limited' => 'bg-amber-400',
      'expired' => 'bg-red-400',
      _ => 'bg-slate-400',
    };
  }
}
