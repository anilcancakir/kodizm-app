import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/document_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kDocument1 = {
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

const Map<String, dynamic> kDocument2 = {
  'id': 'doc-uuid-002',
  'project_id': 'proj-uuid-001',
  'title': 'API Reference',
  'content': '# API\n\nEndpoints documented here.',
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

/// Injectable HTTP client for testing [DocumentState] without hitting the
/// network. Records calls and returns pre-configured [MagicResponse] values.
class _FakeDocumentHttpClient implements DocumentHttpClient {
  final List<_HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Set a responder that maps URL to [MagicResponse].
  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  /// Shortcut: always return the same response regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('GET', url, query: query));
    return _responder(url);
  }
}

class _HttpCall {
  _HttpCall(this.method, this.url, {this.data, this.query});

  final String method;
  final String url;
  final dynamic data;
  final Map<String, dynamic>? query;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DocumentState', () {
    late _FakeDocumentHttpClient http;
    late DocumentState state;

    setUp(() {
      http = _FakeDocumentHttpClient();
      state = DocumentState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. loadDocuments — success
    // -----------------------------------------------------------------------

    test('loadDocuments success populates list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kDocument1, kDocument2],
          },
          statusCode: 200,
        ),
      );

      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

      expect(state.rxState, isNotNull);
      expect(state.rxState!.length, equals(2));
      expect(state.rxState![0].id, equals('doc-uuid-001'));
      expect(state.rxState![1].id, equals('doc-uuid-002'));
      expect(state.isSuccess, isTrue);

      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(
        http.calls.first.url,
        equals('/teams/team-uuid-001/projects/proj-uuid-001/documents'),
      );
    });

    // -----------------------------------------------------------------------
    // 2. loadDocuments — empty
    // -----------------------------------------------------------------------

    test('loadDocuments empty sets empty state', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
        ),
      );

      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

      expect(state.isEmpty, isTrue);
    });

    // -----------------------------------------------------------------------
    // 3. loadDocuments — error
    // -----------------------------------------------------------------------

    test('loadDocuments error sets error state', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {'message': 'Internal Server Error'},
          statusCode: 500,
        ),
      );

      await state.loadDocuments('team-uuid-001', 'proj-uuid-001');

      expect(state.isError, isTrue);
    });

    // -----------------------------------------------------------------------
    // 4. loadDocument — success
    // -----------------------------------------------------------------------

    test('loadDocument success stores selectedDocument', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kDocument1}, statusCode: 200),
      );

      await state.loadDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'doc-uuid-001',
      );

      expect(state.selectedDocument, isNotNull);
      expect(state.selectedDocument!.id, equals('doc-uuid-001'));
      expect(state.selectedDocument!.title, equals('Architecture Overview'));
      expect(state.selectedDocument!.category, equals('architecture'));
    });

    // -----------------------------------------------------------------------
    // 5. loadDocument — failure
    // -----------------------------------------------------------------------

    test('loadDocument failure sets selectedDocument to null', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not found'}, statusCode: 404),
      );

      await state.loadDocument(
        'team-uuid-001',
        'proj-uuid-001',
        'doc-uuid-999',
      );

      expect(state.selectedDocument, isNull);
    });

    // -----------------------------------------------------------------------
    // 6. constructor
    // -----------------------------------------------------------------------

    test('constructor produces a valid DocumentState instance', () {
      final instance = DocumentState(httpClient: http);
      expect(instance, isA<DocumentState>());
      expect(instance.selectedDocument, isNull);
      instance.dispose();
    });
  });
}
