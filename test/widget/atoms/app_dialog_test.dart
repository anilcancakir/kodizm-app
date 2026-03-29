import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/resources/widgets/atoms/app_dialog.dart';

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [widget] in the standard Wind + Material test scaffold.
Widget _wrap(Widget widget) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(home: Scaffold(body: widget)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUpAll(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  // -------------------------------------------------------------------------
  // AppDialog.theme
  // -------------------------------------------------------------------------

  group('AppDialog.theme', () {
    test('returns MagicStarterModalTheme from MagicStarter.modalTheme', () {
      final theme = AppDialog.theme;
      expect(theme, isA<MagicStarterModalTheme>());
      expect(theme.containerClassName, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // AppDialog widget rendering
  // -------------------------------------------------------------------------

  group('AppDialog rendering', () {
    testWidgets('renders body content', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(body: WText('Body content')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Body content'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(
                  title: 'Dialog Title',
                  body: WText('Body content'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Title'), findsOneWidget);
    });

    testWidgets('shows description when provided', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(
                  title: 'Title',
                  description: 'A helpful description',
                  body: WText('Body content'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('A helpful description'), findsOneWidget);
    });

    testWidgets('hides header WDiv when no title or description', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(body: WText('Body only')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No title or description text should appear.
      expect(find.text('Body only'), findsOneWidget);
      // Confirm dialog renders without throwing.
      expect(find.byType(AppDialog), findsOneWidget);
    });

    testWidgets('renders footer when provided', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(
                  title: 'Title',
                  body: WText('Body content'),
                  footer: WText('Footer content'),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Footer content'), findsOneWidget);
    });

    testWidgets('uses modalTheme containerClassName on WDiv shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppDialog(body: WText('Body content')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The outer WDiv should include the modal theme containerClassName.
      final expectedClassName = AppDialog.theme.containerClassName;
      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv));
      final hasContainerClass = wDivs.any(
        (w) => w.className?.contains(expectedClassName) == true,
      );
      expect(hasContainerClass, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // AppDialog.show<T>()
  // -------------------------------------------------------------------------

  group('AppDialog.show()', () {
    testWidgets('presents AppDialog and resolves with value on pop', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? result;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AppDialog.show<String>(
                  context: context,
                  title: 'Pick',
                  body: Builder(
                    builder: (inner) => ElevatedButton(
                      onPressed: () => Navigator.of(inner).pop('selected'),
                      child: const Text('Select'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Pick'), findsOneWidget);

      // Tap the inner button to pop with a value.
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(result, equals('selected'));
    });

    testWidgets('returns null when dismissed via barrier tap', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? result = 'initial';

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AppDialog.show<String>(
                  context: context,
                  title: 'Dismissible',
                  body: WText('Content'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);

      // Tap outside the dialog to dismiss it.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(result, isNull);
    });

    testWidgets('renders with no footer when footer is omitted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AppDialog.show<void>(
                context: context,
                body: WText('No footer'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('No footer'), findsOneWidget);
    });
  });
}
