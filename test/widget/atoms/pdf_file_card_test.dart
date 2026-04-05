import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/message_attachment.dart';
import 'package:app/resources/widgets/atoms/pdf_file_card.dart';

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

MessageAttachment _makePdfAttachment() {
  return const MessageAttachment(
    id: 'att-002',
    messageId: 'msg-001',
    filename: 'document.pdf',
    mimeType: 'application/pdf',
    size: 1258291, // ~1.2 MB
    url: 'https://example.com/attachments/document.pdf',
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

  group('PdfFileCard', () {
    // -----------------------------------------------------------------------
    // Rendering
    // -----------------------------------------------------------------------

    testWidgets('renders filename text', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      expect(find.text('document.pdf'), findsOneWidget);
    });

    testWidgets('renders formatted file size', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      // sizeFormatted for 1258291 bytes → "1.2 MB"
      expect(find.text('1.2 MB'), findsOneWidget);
    });

    testWidgets('renders picture_as_pdf icon', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('renders row container with correct bg className', (
      tester,
    ) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      final wDivs = tester.widgetList<WDiv>(find.byType(WDiv)).toList();
      final rowContainers = wDivs.where(
        (d) =>
            d.className?.contains('flex-row') == true &&
            d.className?.contains('bg-slate-100') == true,
      );
      expect(rowContainers, isNotEmpty);
    });

    testWidgets('renders WAnchor for tap interaction', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      expect(find.byType(WAnchor), findsOneWidget);
    });

    testWidgets('renders WDiv, WIcon, and WText widgets', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(PdfFileCard(attachment: _makePdfAttachment())),
      );
      await tester.pump();

      expect(find.byType(WDiv), findsWidgets);
      // Two icons: picture_as_pdf + open_in_new.
      expect(find.byType(WIcon), findsWidgets);
      expect(find.byType(WText), findsWidgets);
    });
  });
}
