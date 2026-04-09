import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/resources/widgets/atoms/connection_status_banner.dart';

// ---------------------------------------------------------------------------
// Test-specific driver with controllable connectionState stream
// ---------------------------------------------------------------------------

class _TestBroadcastDriver extends FakeBroadcastDriver {
  final StreamController<BroadcastConnectionState> stateController =
      StreamController<BroadcastConnectionState>.broadcast();

  @override
  Stream<BroadcastConnectionState> get connectionState =>
      stateController.stream;

  void dispose() {
    stateController.close();
  }
}

class _TestBroadcastManager extends BroadcastManager {
  _TestBroadcastManager(this._driver);

  final _TestBroadcastDriver _driver;

  @override
  BroadcastDriver connection([String? name]) => _driver;
}

// ---------------------------------------------------------------------------
// Translation loader
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
// Test helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget widget) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 1440, height: 900, child: widget)),
    ),
  );
}

/// Emits a [state] on [driver] and pumps enough frames for the widget to
/// process the stream event + post-frame callback + resulting setState rebuild.
Future<void> _emitAndSettle(
  WidgetTester tester,
  _TestBroadcastDriver driver,
  BroadcastConnectionState state,
) async {
  driver.stateController.add(state);
  await tester.pump(); // StreamBuilder rebuild + schedule postFrameCallback
  await tester.pump(); // postFrameCallback fires → setState
  await tester.pump(); // setState rebuild settles
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late _TestBroadcastDriver driver;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    driver = _TestBroadcastDriver();
    Magic.app.setInstance('broadcasting', _TestBroadcastManager(driver));
  });

  tearDown(() {
    driver.dispose();
    Magic.app.removeInstance('broadcasting');
  });

  group('ConnectionStatusBanner', () {
    testWidgets('renders only child when connected initially', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          ConnectionStatusBanner(child: WText('content', className: 'text-sm')),
        ),
      );

      await _emitAndSettle(tester, driver, BroadcastConnectionState.connected);

      expect(find.text('content'), findsOneWidget);
      expect(find.text(trans('connection.reconnecting')), findsNothing);
      expect(find.text(trans('connection.disconnected')), findsNothing);
      expect(find.text(trans('connection.connected')), findsNothing);
    });

    testWidgets('shows amber banner when reconnecting', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          ConnectionStatusBanner(child: WText('content', className: 'text-sm')),
        ),
      );

      await _emitAndSettle(tester, driver, BroadcastConnectionState.connected);
      await _emitAndSettle(
        tester,
        driver,
        BroadcastConnectionState.reconnecting,
      );

      expect(find.text(trans('connection.reconnecting')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows red banner when disconnected', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          ConnectionStatusBanner(child: WText('content', className: 'text-sm')),
        ),
      );

      await _emitAndSettle(tester, driver, BroadcastConnectionState.connected);
      await _emitAndSettle(
        tester,
        driver,
        BroadcastConnectionState.disconnected,
      );

      expect(find.text(trans('connection.disconnected')), findsOneWidget);
    });

    testWidgets('shows green "back online" then auto-hides after 2s', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          ConnectionStatusBanner(child: WText('content', className: 'text-sm')),
        ),
      );

      await _emitAndSettle(tester, driver, BroadcastConnectionState.connected);
      await _emitAndSettle(
        tester,
        driver,
        BroadcastConnectionState.reconnecting,
      );
      await _emitAndSettle(tester, driver, BroadcastConnectionState.connected);

      expect(find.text(trans('connection.connected')), findsOneWidget);

      // After 2 seconds, the banner should auto-hide.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text(trans('connection.connected')), findsNothing);
    });

    testWidgets('does not show banner during initial connecting phase', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          ConnectionStatusBanner(child: WText('content', className: 'text-sm')),
        ),
      );

      await _emitAndSettle(tester, driver, BroadcastConnectionState.connecting);

      expect(find.text(trans('connection.reconnecting')), findsNothing);
      expect(find.text(trans('connection.disconnected')), findsNothing);
      expect(find.text(trans('connection.connected')), findsNothing);
    });
  });
}
