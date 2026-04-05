import 'package:magic/magic.dart';

/// Sentry Observability Configuration.
///
/// Controls error tracking, performance monitoring, session replay,
/// and profiling across all environments.
///
/// ## Usage
///
/// Access via Config facade:
/// ```dart
/// final dsn = Config.get('sentry.dsn', '');
/// final traceRate = Config.get('sentry.traces_sample_rate', 1.0);
/// ```
Map<String, dynamic> get sentryConfig => {
  'sentry': {
    'dsn': env('SENTRY_DSN', ''),
    'sample_rate': double.tryParse(env('SENTRY_SAMPLE_RATE', '1.0')) ?? 1.0,
    'environment': env('APP_ENV', 'local'),
    'traces_sample_rate':
        double.tryParse(env('SENTRY_TRACES_SAMPLE_RATE', '1.0')) ?? 1.0,
    'profiles_sample_rate':
        double.tryParse(env('SENTRY_PROFILES_SAMPLE_RATE', '1.0')) ?? 1.0,
    'replay_session_sample_rate':
        double.tryParse(env('SENTRY_REPLAY_SESSION_RATE', '0.1')) ?? 0.1,
    'replay_error_sample_rate':
        double.tryParse(env('SENTRY_REPLAY_ERROR_RATE', '1.0')) ?? 1.0,
  },
};
