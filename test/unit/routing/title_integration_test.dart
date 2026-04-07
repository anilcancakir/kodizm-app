import 'package:flutter_test/flutter_test.dart';

import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// TitleManager Integration Contract Tests
//
// Validates that Magic's TitleManager API behaves as expected for the Kodizm
// routing integration: app title fallback, suffix formatting, route title
// resolution, and override priority.
// ---------------------------------------------------------------------------

void main() {
  group('TitleManager integration contract', () {
    late List<String> captured;

    setUp(() {
      captured = [];
      TitleManager.configure(onTitleChanged: (title, _) => captured.add(title));
    });

    tearDown(() {
      TitleManager.reset();
    });

    // -------------------------------------------------------------------------
    // 1. Configure with app title and suffix
    // -------------------------------------------------------------------------

    test('instance can be configured with app title and suffix', () {
      TitleManager.instance.setAppTitle('Kodizm').setSuffix('AI');

      expect(TitleManager.instance.currentTitle, equals('Kodizm'));
      expect(captured, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 2. effectiveTitle returns app title when no route/override is set
    // -------------------------------------------------------------------------

    test(
      'effectiveTitle returns app title when no route or override is set',
      () {
        TitleManager.instance.setAppTitle('Kodizm');

        expect(TitleManager.instance.effectiveTitle, equals('Kodizm'));
      },
    );

    // -------------------------------------------------------------------------
    // 3. Route title + suffix produces "Route - Suffix" format
    // -------------------------------------------------------------------------

    test(
      'route title combined with suffix produces "Route - Suffix" format',
      () {
        TitleManager.instance
            .setAppTitle('Kodizm')
            .setSuffix('Kodizm')
            .setRouteTitle('Dashboard');

        expect(
          TitleManager.instance.effectiveTitle,
          equals('Dashboard - Kodizm'),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 4. Override title takes priority over route title
    // -------------------------------------------------------------------------

    test('override title takes priority over route title', () {
      TitleManager.instance
          .setAppTitle('Kodizm')
          .setSuffix('Kodizm')
          .setRouteTitle('Dashboard')
          .setOverride('Session #42');

      expect(
        TitleManager.instance.effectiveTitle,
        equals('Session #42 - Kodizm'),
      );
      expect(TitleManager.instance.currentTitle, equals('Session #42'));
    });

    // -------------------------------------------------------------------------
    // 5. Clearing override falls back to route title
    // -------------------------------------------------------------------------

    test('clearing override falls back to route title', () {
      TitleManager.instance
          .setAppTitle('Kodizm')
          .setSuffix('Kodizm')
          .setRouteTitle('Dashboard')
          .setOverride('Session #42');

      // Sanity: override is active.
      expect(TitleManager.instance.currentTitle, equals('Session #42'));

      // Clear override — should fall back to route title.
      TitleManager.instance.setOverride(null);

      expect(TitleManager.instance.currentTitle, equals('Dashboard'));
      expect(
        TitleManager.instance.effectiveTitle,
        equals('Dashboard - Kodizm'),
      );
    });

    // -------------------------------------------------------------------------
    // 6. onTitleChanged callback is invoked on each mutation
    // -------------------------------------------------------------------------

    test('onTitleChanged callback is invoked on title mutations', () {
      TitleManager.instance
          .setAppTitle('Kodizm')
          .setSuffix('Kodizm')
          .setRouteTitle('Projects');

      // Three mutations above should each fire the callback.
      expect(captured.length, greaterThanOrEqualTo(3));
      expect(captured.last, equals('Projects - Kodizm'));
    });
  });
}
