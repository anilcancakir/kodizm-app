import 'package:magic/magic.dart';

import '../concerns/sentry_state_mixin.dart';
import '../models/project_document.dart';

// ---------------------------------------------------------------------------
// KnowledgeState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for unified knowledge (documents + memories) CRUD.
///
/// Manages the list of knowledge entries for a project, a single selected
/// entry, and an in-progress editing flag. Supports both document and memory
/// operations through the unified `/documents` API endpoint with type
/// filtering.
///
/// The primary state (`rxState`) holds the `List<ProjectDocument>` for the
/// active project. The secondary state fields ([selectedDocument],
/// [isEditing]) are managed independently with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final knowledge = KnowledgeState.instance;
///
/// // Fetch all documents for a project.
/// await knowledge.loadDocuments('team-uuid-001', 'proj-uuid-001');
/// final list = knowledge.documents; // List<ProjectDocument>
///
/// // Fetch memories for a project.
/// await knowledge.loadMemories('team-uuid-001', 'proj-uuid-001');
/// ```
class KnowledgeState extends MagicController
    with
        MagicStateMixin<List<ProjectDocument>>,
        SentryStateMixin<List<ProjectDocument>> {
  /// Creates a [KnowledgeState].
  KnowledgeState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static KnowledgeState get instance => Magic.findOrPut(KnowledgeState.new);

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
  /// When [type] is provided, it filters by knowledge type ('document' or
  /// 'memory').
  /// Sets loading, then populates `rxState` with the parsed document list on
  /// success, or transitions to error on failure.
  Future<void> loadDocuments(
    String teamId,
    String projectId, {
    String? category,
    String? type,
  }) async {
    final Map<String, String> query = {};
    if (category != null) query['category'] = category;
    if (type != null) query['type'] = type;

    await fetchList<ProjectDocument>(
      '/teams/$teamId/projects/$projectId/documents',
      ProjectDocument.fromMap,
      query: query.isNotEmpty ? query : null,
    );
  }

  /// Fetch all memory entries for the given [teamId] and [projectId].
  ///
  /// Convenience method that calls [loadDocuments] with `type='memory'`.
  /// An optional [memoryType] filter (feedback, user, project, reference)
  /// can be passed as a query parameter.
  Future<void> loadMemories(
    String teamId,
    String projectId, {
    String? memoryType,
  }) async {
    final Map<String, String> query = {'type': 'memory'};
    if (memoryType != null) query['memory_type'] = memoryType;

    await fetchList<ProjectDocument>(
      '/teams/$teamId/projects/$projectId/documents',
      ProjectDocument.fromMap,
      query: query,
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

  /// Create a new memory entry under the given [teamId] and [projectId].
  ///
  /// On success, the created memory is appended to the in-memory list and
  /// returned. Returns `null` on failure.
  Future<ProjectDocument?> createMemory(
    String teamId,
    String projectId,
    String title,
    String content,
    String memoryType, {
    String? description,
  }) async {
    final Map<String, dynamic> payload = {
      'title': title,
      'content': content,
      'type': 'memory',
      'memory_type': memoryType,
    };
    if (description != null) payload['description'] = description;

    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/documents',
      data: payload,
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

  /// Delete a document or memory entry.
  ///
  /// On success, the entry is removed from the in-memory list.
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
