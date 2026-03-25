import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/view.dart';
import 'config/auth.dart';
import 'config/database.dart';
import 'config/network.dart';
import 'config/cache.dart';
import 'config/logging.dart';
import 'config/magic_starter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => viewConfig,
      () => authConfig,
      () => databaseConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
      () => magicStarterConfig,
    ],
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
