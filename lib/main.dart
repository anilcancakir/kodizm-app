import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'config/app.dart';
import 'config/auth.dart';
import 'config/broadcasting.dart';
import 'config/cache.dart';
import 'config/database.dart';
import 'config/logging.dart';
import 'config/magic_starter.dart';
import 'config/network.dart';
import 'config/routing.dart';
import 'config/sentry.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Register SentryNavigatorObserver BEFORE Magic.init() — router is built
  // during boot(), so observers must be added before that. Unconditional
  // because env() isn't loaded yet; the observer is a no-op when Sentry
  // has no DSN.
  MagicRouter.instance.addObserver(SentryNavigatorObserver());

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => authConfig,
      () => broadcastingConfig,
      () => databaseConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
      () => magicStarterConfig,
      () => routingConfig,
      () => sentryConfig,
    ],
  );

  /// Configures the global modal/dialog theme using DESIGN.md tokens.
  ///
  /// Token mapping:
  ///   container    → bg-white dark:bg-gray-800 rounded-2xl shadow-xl
  ///   header       → px-6 pt-6 pb-4
  ///   footer       → px-6 py-4 bg-primary-50 dark:bg-gray-800/50
  ///   title        → text-xl font-semibold text-primary-700 dark:text-white mb-2
  ///   description  → text-sm text-primary-400 dark:text-gray-400
  ///   primaryBtn   → px-4 py-2 rounded-lg bg-secondary-400 hover:bg-secondary-500 text-primary-800 text-sm font-semibold
  ///   secondaryBtn → px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-primary-100 dark:border-gray-700 hover:bg-primary-50 dark:hover:bg-gray-700 text-primary-500 dark:text-gray-200 text-sm font-medium
  ///   dangerBtn    → px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-semibold
  ///   warningBtn   → px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-semibold
  ///   error        → text-sm text-red-500 dark:text-red-400
  ///   input        → w-full p-3 rounded-lg bg-white dark:bg-gray-900 border border-slate-200 dark:border-gray-600 text-sm text-slate-800 dark:text-slate-200 focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
  ///   maxWidth     → 480.0
  MagicStarter.useModalTheme(
    const MagicStarterModalTheme(
      containerClassName: 'bg-white dark:bg-gray-800 rounded-2xl shadow-xl',
      headerClassName: 'px-6 pt-6 pb-4',
      footerClassName: 'px-6 py-4 bg-primary-50 dark:bg-gray-800/50',
      titleClassName:
          'text-xl font-semibold text-primary-700 dark:text-white mb-2',
      descriptionClassName: 'text-sm text-primary-400 dark:text-gray-400',
      primaryButtonClassName:
          'px-4 py-2 rounded-lg bg-secondary-400 hover:bg-secondary-500 text-primary-800 text-sm font-semibold',
      secondaryButtonClassName:
          'px-4 py-2 rounded-lg bg-white dark:bg-gray-800 border border-primary-100 dark:border-gray-700 hover:bg-primary-50 dark:hover:bg-gray-700 text-primary-500 dark:text-gray-200 text-sm font-medium',
      dangerButtonClassName:
          'px-4 py-2 rounded-lg bg-red-500 hover:bg-red-600 text-white text-sm font-semibold',
      warningButtonClassName:
          'px-4 py-2 rounded-lg bg-amber-500 hover:bg-amber-600 text-white text-sm font-semibold',
      errorClassName: 'text-sm text-red-500 dark:text-red-400',
      inputClassName:
          'w-full p-3 rounded-lg bg-white dark:bg-gray-900 border border-slate-200 dark:border-gray-600 text-sm text-slate-800 dark:text-slate-200 focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20',
      maxWidth: 480.0,
    ),
  );

  final windTheme = WindThemeData(
    colors: {
      'primary': MaterialColor(0xFF334E68, <int, Color>{
        50: Color(0xFFF0F4F8),
        100: Color(0xFFD9E2EC),
        200: Color(0xFFBCCCDC),
        300: Color(0xFF829AB1),
        400: Color(0xFF486581),
        500: Color(0xFF334E68),
        600: Color(0xFF2B3F56),
        700: Color(0xFF243346),
        800: Color(0xFF1E2A38),
        900: Color(0xFF1A2332),
      }),
      'secondary': MaterialColor(0xFFFBBF24, <int, Color>{
        50: Color(0xFFFFFBEB),
        100: Color(0xFFFEF3C7),
        200: Color(0xFFFDE68A),
        300: Color(0xFFFCD34D),
        400: Color(0xFFFBBF24),
        500: Color(0xFFD9A520),
        600: Color(0xFFB8860B),
        700: Color(0xFF92690A),
        800: Color(0xFF755506),
        900: Color(0xFF604505),
      }),
    },
  );

  // -- Sentry Initialization --
  final sentryDsn = Config.get<String>('sentry.dsn', '') ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = Config.get<String>('sentry.environment', 'local');

      // -- Error Tracking --
      options.sampleRate = Config.get<double>('sentry.sample_rate', 1.0);

      // -- Performance Tracing --
      options.tracesSampleRate = Config.get<double>(
        'sentry.traces_sample_rate',
        1.0,
      );
      options.enableAutoPerformanceTracing = true;

      // -- Profiling (iOS/macOS only) --
      options.profilesSampleRate = Config.get<double>(
        'sentry.profiles_sample_rate',
        1.0,
      );

      // -- Session Replay --
      options.replay.sessionSampleRate = Config.get<double>(
        'sentry.replay_session_sample_rate',
        0.1,
      );
      options.replay.onErrorSampleRate = Config.get<double>(
        'sentry.replay_error_sample_rate',
        1.0,
      );
      options.replay.quality = SentryReplayQuality.medium;

      // -- Screenshots & View Hierarchy --
      options.attachScreenshot = true;
      options.screenshotQuality = SentryScreenshotQuality.medium;
      options.attachViewHierarchy = true;

      // -- Native Crash Handling --
      options.enableNativeCrashHandling = true;
      options.anrEnabled = true;
      options.enableAppHangTracking = true;
      options.appHangTimeoutInterval = Duration(seconds: 2);

      // -- Frame Tracking --
      options.enableFramesTracking = true;

      // -- Breadcrumbs --
      options.enableAutoNativeBreadcrumbs = true;
      options.enableUserInteractionBreadcrumbs = true;
      options.maxBreadcrumbs = 100;

      // -- Sessions --
      options.enableAutoSessionTracking = true;

      // -- Privacy --
      options.privacy.maskAllText = true;
      options.privacy.maskAllImages = true;
      options.sendDefaultPii = false;

      // -- Distributed Tracing --
      options.tracePropagationTargets.add(
        Config.get<String>('network.drivers.api.base_url', 'localhost') ??
            'localhost',
      );

      // -- Debug (only in non-production) --
      options.debug =
          Config.get<String>('sentry.environment', 'local') != 'production';
    });
  }

  FlutterNativeSplash.remove();
  runApp(
    sentryDsn.isNotEmpty
        ? SentryWidget(
            child: MagicApplication(
              title: 'Kodizm - AI Dev Platform',
              windTheme: windTheme,
            ),
          )
        : MagicApplication(
            title: 'Kodizm - AI Dev Platform',
            windTheme: windTheme,
          ),
  );
}
