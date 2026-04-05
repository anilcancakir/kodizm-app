import 'package:magic/magic.dart';

import '../models/project_document.dart';

// ---------------------------------------------------------------------------
// DocumentState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project document CRUD operations.
///
/// Manages the list of documents for a project, a single selected document,
/// and an in-progress editing flag.
///
/// The primary state (`rxState`) holds the `List<ProjectDocument>` for the
/// active project. The secondary state fields ([selectedDocument],
/// [isEditing]) are managed independently with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final docs = DocumentState.instance;
///
/// // Fetch all documents for a project.
/// await docs.loadDocuments('team-uuid-001', 'proj-uuid-001');
/// final list = docs.documents; // List<ProjectDocument>
///
/// // Fetch a single document.
/// await docs.loadDocument('team-uuid-001', 'proj-uuid-001', 'doc-uuid-001');
/// final selected = docs.selectedDocument;
/// ```
class DocumentState extends MagicController
    with MagicStateMixin<List<ProjectDocument>> {
  /// Creates a [DocumentState].
  DocumentState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static DocumentState get instance => Magic.findOrPut(DocumentState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  ProjectDocument? _selectedDocument;
  bool _isEditing = false;

  /// The currently selected document (set by [loadDocument]).
  ProjectDocument? get selectedDocument => _selectedDocument;

  /// Whether the document editor is open.
  bool get isEditing => _isEditing;

  // ---------------------------------------------------------------------------
  // Convenience accessor
  // ---------------------------------------------------------------------------

  /// The current document list, or an empty list when state is not success.
  List<ProjectDocument> get documents => rxState ?? [];

  // ---------------------------------------------------------------------------
  // List operations
  // ---------------------------------------------------------------------------

  /// Fetch all documents for the given [teamId] and [projectId].
  ///
  /// An optional [category] filter is forwarded as a query parameter.
  /// Sets loading, then populates `rxState` with the parsed document list on
  /// success, or transitions to error on failure.
  Future<void> loadDocuments(
    String teamId,
    String projectId, {
    String? category,
  }) async {
    await fetchList<ProjectDocument>(
      '/teams/$teamId/projects/$projectId/documents',
      ProjectDocument.fromMap,
      query: category != null ? {'category': category} : null,
    );
  }

  /// Fetch a single document and store it as [selectedDocument].
  ///
  /// Does **not** affect the primary list state. Calls [refreshUI] after
  /// updating [_selectedDocument].
  Future<void> loadDocument(
    String teamId,
    String projectId,
    String documentId,
  ) async {
    final response = await Http.get(
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

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new document under the given [teamId] and [projectId].
  ///
  /// On success, the created document is appended to the in-memory list and
  /// returned. Returns `null` on failure.
  Future<ProjectDocument?> createDocument(
    String teamId,
    String projectId,
    String title,
    String content,
    String category,
  ) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/documents',
      data: {'title': title, 'content': content, 'category': category},
    );

    if (response.successful) {
      final Map<String, dynamic> docData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final doc = ProjectDocument.fromMap(docData);
      final updated = [...documents, doc];
      setSuccess(updated);
      return doc;
    }

    return null;
  }

  /// Update an existing document.
  ///
  /// Only non-null fields ([title], [content]) are included in the payload.
  /// On success, the document is replaced in the in-memory list and returned.
  /// Returns `null` on failure.
  Future<ProjectDocument?> updateDocument(
    String teamId,
    String projectId,
    String documentId, {
    String? title,
    String? content,
  }) async {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (content != null) data['content'] = content;

    final response = await Http.put(
      '/teams/$teamId/projects/$projectId/documents/$documentId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> docData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final updated = ProjectDocument.fromMap(docData);
      final updatedList = documents
          .map((d) => d.id == documentId ? updated : d)
          .toList();
      setSuccess(updatedList);
      return updated;
    }

    return null;
  }

  /// Delete a document.
  ///
  /// On success, the document is removed from the in-memory list.
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteDocument(
    String teamId,
    String projectId,
    String documentId,
  ) async {
    final response = await Http.delete(
      '/teams/$teamId/projects/$projectId/documents/$documentId',
    );

    if (response.successful) {
      final remaining = documents.where((d) => d.id != documentId).toList();
      remaining.isEmpty ? setEmpty() : setSuccess(remaining);
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Editing flag
  // ---------------------------------------------------------------------------

  /// Toggle the editing state to [value] and notify listeners.
  void setEditing({required bool value}) {
    _isEditing = value;
    refreshUI();
  }
}
