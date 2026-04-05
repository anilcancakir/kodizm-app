import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/message_attachment.dart';
import 'package:app/resources/widgets/atoms/attachment_thumbnail.dart';

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
// Fixtures
// ---------------------------------------------------------------------------

MessageAttachment _makeImageAttachment() {
  return const MessageAttachment(
    id: 'att-001',
    messageId: 'msg-001',
    filename: 'photo.png',
    mimeType: 'image/png',
    size: 204800, // 200 KB
    url: 'https://example.com/attachments/photo.png',
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget widget) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
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

  group('AttachmentThumbnail', () {
    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    testWidgets('renders a WAnchor wrapping the thumbnail container', (
      tester,
    ) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(AttachmentThumbnail(attachment: _makeImageAttachment())),
      );
      await tester.pump();

      expect(find.byType(WAnchor), findsOneWidget);
    });

    testWidgets('renders rounded overflow-hidden container', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(AttachmentThumbnail(attachment: _makeImageAttachment())),
      );
      await tester.pump();

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final roundedContainers = wDivs.where(
        (d) =>
            d.className?.contains('rounded-lg') == true &&
            d.className?.contains('overflow-hidden') == true,
      );
      expect(roundedContainers, isNotEmpty);
    });

    testWidgets('renders fixed size constraint via w-48 h-48 className', (
      tester,
    ) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(AttachmentThumbnail(attachment: _makeImageAttachment())),
      );
      await tester.pump();

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final constrained = wDivs.where(
        (d) =>
            d.className?.contains('w-48') == true &&
            d.className?.contains('h-48') == true,
      );
      expect(constrained, isNotEmpty);
    });

    testWidgets('renders WDiv and WAnchor widgets', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(AttachmentThumbnail(attachment: _makeImageAttachment())),
      );
      await tester.pump();

      expect(find.byType(WDiv), findsWidgets);
      expect(find.byType(WAnchor), findsOneWidget);
    });

    // -----------------------------------------------------------------------
    // Tap interaction — opens dialog
    // -----------------------------------------------------------------------

    testWidgets('tap opens fullscreen dialog with InteractiveViewer', (
      tester,
    ) async {
      _setViewport(tester);

      // Suppress image-loading exceptions — network calls fail in unit tests
      // but the errorBuilder handles it gracefully in production.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is NetworkImageLoadException) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        _wrap(AttachmentThumbnail(attachment: _makeImageAttachment())),
      );
      await tester.pump();

      await tester.tap(find.byType(WAnchor));
      await tester.pump();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });
}
