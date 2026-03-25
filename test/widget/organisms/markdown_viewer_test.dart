import 'package:flutter/material.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/resources/widgets/organisms/markdown_viewer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [MarkdownViewer] inside the standard test scaffold.
///
/// Uses a 1440x900 viewport so Wind UI flex layouts do not overflow.
Future<void> _pumpViewer(
  WidgetTester tester,
  String data, {
  bool selectable = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownViewer(data: data, selectable: selectable),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Renders plain text / heading
  // -------------------------------------------------------------------------

  testWidgets('renders heading and paragraph text', (tester) async {
    await _pumpViewer(tester, '# Hello\n\nA paragraph below.');

    // MarkdownBody renders text — verify the content appears.
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('A paragraph below.'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders fenced code block with HighlightView
  // -------------------------------------------------------------------------

  testWidgets('renders code block with HighlightView', (tester) async {
    const String md = '''
```dart
void main() => runApp(const MyApp());
```
''';

    await _pumpViewer(tester, md);

    // _CodeBlock renders a HighlightView.
    expect(find.byType(HighlightView), findsOneWidget);

    // Copy icon button is present inside the block.
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Empty input does not crash
  // -------------------------------------------------------------------------

  testWidgets('renders empty input without throwing', (tester) async {
    await _pumpViewer(tester, '');

    // MarkdownBody is present even with empty data.
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders GFM table
  // -------------------------------------------------------------------------

  testWidgets('renders GFM table headers', (tester) async {
    const String md = '''
| Name  | Role  |
|-------|-------|
| Alice | BA    |
| Bob   | Dev   |
''';

    await _pumpViewer(tester, md);

    // Table column headers and cells should appear as text nodes.
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Role'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders inline code with RichText (styled span)
  // -------------------------------------------------------------------------

  testWidgets('renders inline code inside paragraph', (tester) async {
    await _pumpViewer(tester, 'Call `print()` to log output.');

    // The surrounding paragraph text renders.
    expect(find.textContaining('to log output.'), findsOneWidget);

    // A RichText is rendered (inline code is a styled TextSpan within it).
    expect(find.byType(RichText), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 6. selectable: false renders without SelectionArea
  // -------------------------------------------------------------------------

  testWidgets('selectable false omits SelectionArea wrapper', (tester) async {
    await _pumpViewer(tester, '# Non-selectable', selectable: false);

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.text('Non-selectable'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. selectable: true wraps content in SelectionArea
  // -------------------------------------------------------------------------

  testWidgets('selectable true wraps content in SelectionArea', (tester) async {
    await _pumpViewer(tester, '# Selectable heading');

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('Selectable heading'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Multiple code blocks render independent HighlightView instances
  // -------------------------------------------------------------------------

  testWidgets('multiple code blocks each render a HighlightView', (
    tester,
  ) async {
    const String md = '''
```python
print("hello")
```

Some text in between.

```javascript
console.log("world");
```
''';

    await _pumpViewer(tester, md);

    expect(find.byType(HighlightView), findsNWidgets(2));
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
  });
}
