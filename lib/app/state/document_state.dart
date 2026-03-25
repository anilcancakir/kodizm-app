import 'package:magic/magic.dart';

import '../models/project_document.dart';

// ---------------------------------------------------------------------------
// HTTP abstraction for testability
// ---------------------------------------------------------------------------

/// Thin interface over the HTTP verbs [DocumentState] uses.
///
/// In production the default [_MagicDocumentHttpClient] delegates to [Http].
/// Tests inject a fake that records calls and returns canned responses.
abstract class DocumentHttpClient {
  /// Perform a GET request.
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  });
}

/// Default production [DocumentHttpClient] backed by the Magic [Http] facade.
class _MagicDocumentHttpClient implements DocumentHttpClient {
  const _MagicDocumentHttpClient();

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => Http.get(url, query: query, headers: headers);
}

// ---------------------------------------------------------------------------
// DocumentState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for reading project knowledge-base documents.
///
/// Manages the list of [ProjectDocument] items for a project, and a single
/// selected document loaded by [loadDocument].
///
/// The primary state (`rxState`) holds the `List<ProjectDocument>` for the
/// active project. The secondary field [selectedDocument] is managed
/// independently with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final docs = DocumentState.instance;
///
/// // Fetch all documents for a project.
/// await docs.loadDocuments('team-uuid-001', 'proj-uuid-001');
/// final list = docs.rxState; // List<ProjectDocument>?
///
/// // Fetch a single document.
/// await docs.loadDocument('team-uuid-001', 'proj-uuid-001', 'doc-uuid-001');
/// final selected = docs.selectedDocument;
/// ```
class DocumentState extends MagicController
    with MagicStateMixin<List<ProjectDocument>> {
  /// Creates a [DocumentState] with an optional [httpClient] for testing.
  ///
  /// When [httpClient] is `null` (production), the Magic [Http] facade is
  /// used via [_MagicDocumentHttpClient].
  DocumentState({DocumentHttpClient? httpClient})
    : _http = httpClient ?? const _MagicDocumentHttpClient();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static DocumentState get instance => Magic.findOrPut(DocumentState.new);

  final DocumentHttpClient _http;

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  ProjectDocument? _selectedDocument;

  /// The currently selected document (set by [loadDocument]).
  ProjectDocument? get selectedDocument => _selectedDocument;

  // ---------------------------------------------------------------------------
  // Document list operations
  // ---------------------------------------------------------------------------

  /// Fetch all documents for the given [teamId] and [projectId].
  ///
  /// Sets loading, then populates `rxState` with the parsed document list on
  /// success, or transitions to error on failure. An empty list triggers
  /// [setEmpty] instead of [setSuccess].
  Future<void> loadDocuments(String teamId, String projectId) async {
    setLoading();

    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/documents',
    );

    if (response.successful) {
      final List<dynamic> items =
          (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
      final docs = items
          .map((item) => ProjectDocument.fromMap(item as Map<String, dynamic>))
          .toList();
      docs.isEmpty ? setEmpty() : setSuccess(docs);
    } else {
      setError(response.errorMessage ?? 'Failed to fetch documents');
    }
  }

  // ---------------------------------------------------------------------------
  // Single document
  // ---------------------------------------------------------------------------

  /// Fetch a single document and store it as [selectedDocument].
  ///
  /// Does **not** affect the primary list state. Calls [refreshUI] after
  /// updating [_selectedDocument].
  Future<void> loadDocument(
    String teamId,
    String projectId,
    String documentId,
  ) async {
    final response = await _http.get(
      '/teams/$teamId/projects/$projectId/documents/$documentId',
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      _selectedDocument = ProjectDocument.fromMap(data);
    } else {
      _selectedDocument = null;
    }

    refreshUI();
  }
}
