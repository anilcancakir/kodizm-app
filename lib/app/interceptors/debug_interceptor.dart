import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

/// HTTP debug interceptor that logs every request and response in dev mode.
///
/// Activated only when [kDebugMode] is `true` — zero overhead in release builds.
/// Logs via the [Log] facade so output respects the configured logging driver.
///
/// ## Usage
/// ```dart
/// Magic.make<NetworkDriver>('network')
///     .addInterceptor(DebugInterceptor());
/// ```
class DebugInterceptor extends MagicNetworkInterceptor {
  @override
  dynamic onRequest(MagicRequest request) {
    if (!kDebugMode) return request;

    final buffer = StringBuffer()
      ..writeln('→ ${request.method} ${request.url}');

    if (request.queryParameters != null &&
        request.queryParameters!.isNotEmpty) {
      buffer.writeln('  Query: ${_encode(request.queryParameters)}');
    }

    if (request.data != null) {
      buffer.writeln('  Data: ${_encode(request.data)}');
    }

    Log.debug(buffer.toString().trimRight());
    return request;
  }

  @override
  dynamic onResponse(MagicResponse response) {
    if (!kDebugMode) return response;

    Log.debug(
      '← ${response.statusCode} ${response.message ?? ''}\n'
      '  Body: ${_encode(response.data)}',
    );
    return response;
  }

  @override
  dynamic onError(MagicError error) {
    Log.error(
      '✕ ${error.statusCode} ${error.request?.method ?? ''} '
      '${error.request?.url ?? ''}\n'
      '  ${error.message ?? ''}\n'
      '  Body: ${_encode(error.response?.data)}',
    );
    return error;
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Compact JSON encode — truncates large payloads to keep logs readable.
  static String _encode(dynamic value) {
    if (value == null) return 'null';
    try {
      final json = const JsonEncoder.withIndent('  ').convert(value);
      if (json.length > 2000) return '${json.substring(0, 2000)}… (truncated)';
      return json;
    } catch (_) {
      final str = value.toString();
      if (str.length > 2000) return '${str.substring(0, 2000)}… (truncated)';
      return str;
    }
  }
}
