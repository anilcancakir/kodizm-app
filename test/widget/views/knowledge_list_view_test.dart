import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/document_state.dart';
import 'package:app/resources/views/knowledge/knowledge_list_view.dart';
import 'package:app/resources/widgets/molecules/page_header.dart';
import 'package:app/resources/widgets/molecules/section_card.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kDocument1 = {
  'id': 'doc-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'Architecture Overview',
  'content': '# Architecture',
  'category': 'architecture',
  'metadata': null,
  'created_by_user_id': 'user-uuid-001',
  'created_by_user': {'id': 'user-uuid-001', 'name': 'Alice Smith'},
  'created_by_agent_role_id': null,
  'created_by_agent_role': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T09:00:00.000Z',
};

const Map<String, dynamic> kDocument2 = {
  'id': 'doc-uuid-002',
  'project_id': 'proj-uuid-001',
  'title': 'API Reference',
  'content': '# API',
  'category': 'api',
  'metadata': null,
  'created_by_user_id': null,
  'created_by_user': null,
  'created_by_agent_role_id': 'role-uuid-001',
  'created_by_agent_role': {'id': 'role-uuid-001', 'name': 'Business Analyst'},
  'created_at': '2025-06-10T10:00:00.000Z',
  'updated_at': '2025-06-10T11:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeDocumentHttpClient implements DocumentHttpClient {
  final List<String> calls = [];
  late MagicResponse Function(String url) _responder;

  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

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

/// Pumps a [KnowledgeListView] inside the standard test scaffold.
Future<void> _pumpView(
  WidgetTester tester, {
  String projectId = 'proj-uuid-001',
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
            child: KnowledgeListView(projectId: projectId),
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
  // 1. Widget can be constructed with a projectId
  // -------------------------------------------------------------------------

  testWidgets('widget constructor accepts projectId', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    await _pumpView(tester, projectId: 'proj-test-001');

    expect(find.byType(KnowledgeListView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders PageHeader with knowledge.title text
  // -------------------------------------------------------------------------

  testWidgets('renders PageHeader with title', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    await _pumpView(tester);

    expect(find.byType(PageHeader), findsOneWidget);
    expect(find.textContaining('Knowledge Base'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state before documents load', (tester) async {
    // Never resolve — HTTP stays pending so isLoading remains true.
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    // Manually set loading state before pumping.
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KnowledgeListView(projectId: 'proj-uuid-001'),
            ),
          ),
        ),
      ),
    );
    // Use pump() NOT pumpAndSettle() — animation never settles.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Shows empty state when no documents exist
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no documents exist', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    // Pre-load empty state.
    await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    // trans('knowledge.empty_title') = 'No Knowledge Documents'
    expect(find.textContaining('No Knowledge Documents'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders document cards when documents are loaded
  // -------------------------------------------------------------------------

  testWidgets('renders document cards when documents are loaded', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(
        data: {
          'data': [kDocument1, kDocument2],
        },
        statusCode: 200,
      ),
    );

    // Pre-load documents.
    await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    // Document titles should be visible.
    expect(find.text('Architecture Overview'), findsOneWidget);
    expect(find.text('API Reference'), findsOneWidget);

    // SectionCard wrapping the list.
    expect(find.byType(SectionCard), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Tapping a document card navigates to detail
  // -------------------------------------------------------------------------

  testWidgets('document cards are wrapped in WAnchor for navigation', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(
        data: {
          'data': [kDocument1],
        },
        statusCode: 200,
      ),
    );

    // Pre-load documents.
    await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    // Card is rendered with the document title.
    expect(find.text('Architecture Overview'), findsOneWidget);

    // WAnchor wraps the card for tap navigation.
    expect(find.byType(WAnchor), findsWidgets);
  });
}
