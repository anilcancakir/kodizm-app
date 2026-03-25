import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/document_state.dart';
import 'package:app/resources/views/knowledge/knowledge_detail_view.dart';
import 'package:app/resources/widgets/molecules/page_header.dart';
import 'package:app/resources/widgets/molecules/section_card.dart';
import 'package:app/resources/widgets/organisms/markdown_viewer.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kDocumentFull = {
  'id': 'doc-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Architecture Overview',
  'content': '# Architecture\n\nThis is the overview.',
  'category': 'architecture',
  'metadata': {'version': '1.0'},
  'created_by_user_id': 'user-uuid-001',
  'created_by_user': {'id': 'user-uuid-001', 'name': 'Alice Smith'},
  'created_by_agent_role_id': null,
  'created_by_agent_role': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T09:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeDocumentHttpClient implements DocumentHttpClient {
  final List<String> calls = [];
  late MagicResponse Function(String url) _responder;

  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add('GET $url');
    return _responder(url);
  }
}

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final String content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final Map<String, dynamic> nested =
          jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = {};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
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

/// Pumps a [KnowledgeDetailView] inside the standard test scaffold.
Future<void> _pumpView(
  WidgetTester tester, {
  String projectId = 'proj-uuid-001',
  String documentId = 'doc-uuid-001',
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KnowledgeDetailView(
              projectId: projectId,
              documentId: documentId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeDocumentHttpClient http;
  late DocumentState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeDocumentHttpClient();
    state = DocumentState(httpClient: http);
    Magic.put<DocumentState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<DocumentState>();
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed with required props
  // -------------------------------------------------------------------------

  testWidgets('widget can be constructed with required props', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': kDocumentFull}, statusCode: 200),
    );

    await _pumpView(tester, projectId: 'p1', documentId: 'd1');

    expect(find.byType(KnowledgeDetailView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders loading state initially (selectedDocument is null)
  // -------------------------------------------------------------------------

  testWidgets('renders loading state when document is null', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
    );

    await _pumpView(tester);

    // Before any document is loaded, CircularProgressIndicator is shown.
    // Use pump() NOT pumpAndSettle() — animation never settles.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders PageHeader with document title when loaded
  // -------------------------------------------------------------------------

  testWidgets('renders document title in PageHeader when loaded', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': kDocumentFull}, statusCode: 200),
    );

    // Pre-load the document into state.
    await state.loadDocument('team-uuid-001', 'proj-uuid-001', 'doc-uuid-001');

    await _pumpView(tester);

    expect(find.byType(PageHeader), findsOneWidget);
    expect(find.text('Architecture Overview'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders MarkdownViewer with document content
  // -------------------------------------------------------------------------

  testWidgets('renders MarkdownViewer with document content', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': kDocumentFull}, statusCode: 200),
    );

    // Pre-load the document.
    await state.loadDocument('team-uuid-001', 'proj-uuid-001', 'doc-uuid-001');

    await _pumpView(tester);

    expect(find.byType(MarkdownViewer), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Shows metadata section with author, category, dates
  // -------------------------------------------------------------------------

  testWidgets('shows metadata section with author and category', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': kDocumentFull}, statusCode: 200),
    );

    // Pre-load the document.
    await state.loadDocument('team-uuid-001', 'proj-uuid-001', 'doc-uuid-001');

    await _pumpView(tester);

    // Metadata SectionCard title: trans('knowledge.metadata') = 'Metadata'
    expect(find.textContaining('Metadata'), findsOneWidget);

    // Author: 'Alice Smith'
    expect(find.text('Alice Smith'), findsOneWidget);

    // Category label: trans('knowledge.category_architecture') = 'Architecture'
    // Appears in both the header badge and metadata section.
    expect(find.textContaining('Architecture'), findsWidgets);

    // Two SectionCards: one for content (MarkdownViewer), one for metadata.
    expect(find.byType(SectionCard), findsNWidgets(2));
  });
}
