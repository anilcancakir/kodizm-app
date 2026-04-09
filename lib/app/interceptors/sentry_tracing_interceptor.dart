import 'package:magic/magic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Sentry distributed tracing interceptor for Magic Http.
///
/// Injects `sentry-trace` and `baggage` headers into outgoing requests
/// for distributed tracing between Flutter and Laravel. Records HTTP
/// breadcrumbs on responses and errors for debugging context.
///
/// Note: Child span tracking is intentionally omitted because
/// [MagicResponse] does not carry a request reference, making it
/// impossible to correlate responses to their originating request
/// in concurrent scenarios. Header injection (the critical path for
/// distributed tracing) works without spans.
///
/// ## Usage
/// ```dart
/// Magic.make<NetworkDriver>('network')
///     .addInterceptor(SentryTracingInterceptor());
/// ```
class SentryTracingInterceptor extends MagicNetworkInterceptor {
  /// Stores the last request so onResponse can include URL/method in
  /// breadcrumbs (MagicResponse does not carry a request reference).
  MagicRequest? _lastRequest;

  @override
  dynamic onRequest(MagicRequest request) {
    _lastRequest = request;

    final span = Sentry.getSpan();
    if (span == null) return request;

    // Inject distributed tracing headers from the current transaction.
    final traceHeader = span.toSentryTrace();
    final baggageHeader = span.toBaggageHeader();

    request.headers['sentry-trace'] = traceHeader.value;
    if (baggageHeader != null) {
      request.headers['baggage'] = baggageHeader.value;
    }

    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) {
    final method = _lastRequest?.method ?? 'UNKNOWN';
    final url = _lastRequest?.url ?? '';

    Sentry.addBreadcrumb(
      Breadcrumb(
        type: 'http',
        category: 'http',
        data: {
          'method': method,
          'url': url,
          'status_code': response.statusCode,
          'reason': response.message ?? '',
        },
        level: response.statusCode >= 400
            ? SentryLevel.warning
            : SentryLevel.info,
      ),
    );

    return response;
  }

  @override
  dynamic onError(MagicError error) {
    final method = error.request?.method ?? 'UNKNOWN';
    final url = error.request?.url ?? '';

    Sentry.addBreadcrumb(
      Breadcrumb(
        type: 'http',
        category: 'http',
        data: {
          'method': method,
          'url': url,
          'status_code': error.statusCode,
          'reason': error.message ?? '',
        },
        level: SentryLevel.error,
      ),
    );

    return error;
  }
}
