import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'config/app.dart';
import 'config/auth.dart';
import 'config/database.dart';
import 'config/network.dart';
import 'config/cache.dart';
import 'config/logging.dart';
import 'config/magic_starter.dart';
import 'config/websocket.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => authConfig,
      () => databaseConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
      () => magicStarterConfig,
      () => websocketConfig,
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

  runApp(MagicApplication(title: 'App', windTheme: windTheme));
}
