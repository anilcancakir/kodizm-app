import 'package:magic/magic.dart';

import '../models/project_memory.dart';

// ---------------------------------------------------------------------------
// MemoryState controller
// ---------------------------------------------------------------------------

/// Reactive state controller for project memory CRUD operations.
///
/// Manages the list of memory entries for a given project. Supports optional
/// filtering by type via [loadMemories]. CRUD operations update the in-memory
/// list and notify listeners without requiring a full re-fetch.
///
/// The primary state (`rxState`) holds the `List<ProjectMemory>` for the
/// active project. Secondary state fields ([selectedMemory], [isEditing],
/// [filterType]) are managed independently with manual [refreshUI] calls.
///
/// ## Usage
///
/// ```dart
/// // Access the singleton instance.
/// final memState = MemoryState.instance;
///
/// // Load memories for a project.
/// await memState.loadMemories('team-uuid', 'proj-uuid');
/// final list = memState.memories; // List<ProjectMemory>
///
/// // Create a new memory entry.
/// final mem = await memState.createMemory(
///   'team-uuid', 'proj-uuid',
///   'notes.md', 'Notes', 'Sprint notes', 'feedback', 'content here',
/// );
/// ```
class MemoryState extends MagicController
    with MagicStateMixin<List<ProjectMemory>> {
  /// Creates a [MemoryState].
  MemoryState();

  /// Lazy singleton accessor.
  ///
  /// Uses [Magic.findOrPut] to ensure a single instance is shared across
  /// the application.
  static MemoryState get instance => Magic.findOrPut(MemoryState.new);

  // ---------------------------------------------------------------------------
  // Secondary state
  // ---------------------------------------------------------------------------

  ProjectMemory? _selectedMemory;

  /// The currently selected memory entry (set externally for edit/detail views).
  ProjectMemory? get selectedMemory => _selectedMemory;

  bool _isEditing = false;

  /// Whether the edit form is currently open.
  bool get isEditing => _isEditing;

  String? _filterType;

  /// The active type filter applied during [loadMemories].
  ///
  /// Null means no filter (all types returned).
  String? get filterType => _filterType;

  // ---------------------------------------------------------------------------
  // Convenience accessor
  // ---------------------------------------------------------------------------

  /// The currently loaded memory list (empty list when not yet fetched).
  List<ProjectMemory> get memories => rxState ?? [];

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Load all memory entries for [projectId] under [teamId].
  ///
  /// When [type] is provided, passes it as a query parameter to filter results
  /// server-side. Sets [filterType] to [type] for tracking.
  ///
  /// Sets loading, then populates `rxState` with the parsed list on success,
  /// or transitions to error on failure.
  Future<void> loadMemories(
    String teamId,
    String projectId, {
    String? type,
  }) async {
    _filterType = type;

    await fetchList<ProjectMemory>(
      '/teams/$teamId/projects/$projectId/memories',
      ProjectMemory.fromMap,
      query: type != null ? {'type': type} : null,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Create a new memory entry under [projectId].
  ///
  /// POSTs to the memories endpoint. On success, the new entry is appended to
  /// the in-memory list and listeners are notified.
  ///
  /// Returns the created [ProjectMemory] on success, or `null` on failure.
  Future<ProjectMemory?> createMemory(
    String teamId,
    String projectId,
    String fileName,
    String name,
    String description,
    String type,
    String content,
  ) async {
    final response = await Http.post(
      '/teams/$teamId/projects/$projectId/memories',
      data: {
        'file_name': fileName,
        'name': name,
        'description': description,
        'type': type,
        'content': content,
      },
    );

    if (response.successful) {
      final Map<String, dynamic> data =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final memory = ProjectMemory.fromMap(data);
      final updated = [...memories, memory];
      setSuccess(updated);
      return memory;
    }

    return null;
  }

  /// Update an existing memory entry.
  ///
  /// PUTs to the memory endpoint. On success, the updated entry replaces its
  /// counterpart in the in-memory list and listeners are notified.
  ///
  /// Returns the updated [ProjectMemory] on success, or `null` on failure.
  Future<ProjectMemory?> updateMemory(
    String teamId,
    String projectId,
    String memoryId, {
    String? name,
    String? description,
    String? type,
    String? content,
  }) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (type != null) data['type'] = type;
    if (content != null) data['content'] = content;

    final response = await Http.put(
      '/teams/$teamId/projects/$projectId/memories/$memoryId',
      data: data,
    );

    if (response.successful) {
      final Map<String, dynamic> responseData =
          (response.data as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final updated = ProjectMemory.fromMap(responseData);
      final list = memories.map((m) => m.id == memoryId ? updated : m).toList();
      setSuccess(list);
      return updated;
    }

    return null;
  }

  /// Delete a memory entry.
  ///
  /// Sends a DELETE request to the memory endpoint. On success, the entry is
  /// removed from the in-memory list and listeners are notified.
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> deleteMemory(
    String teamId,
    String projectId,
    String memoryId,
  ) async {
    final response = await Http.delete(
      '/teams/$teamId/projects/$projectId/memories/$memoryId',
    );

    if (response.successful) {
      final list = memories.where((m) => m.id != memoryId).toList();
      list.isEmpty ? setEmpty() : setSuccess(list);
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  /// Set [selectedMemory] and notify listeners.
  void selectMemory(ProjectMemory? memory) {
    _selectedMemory = memory;
    refreshUI();
  }

  /// Toggle the editing state and notify listeners.
  void setEditing({required bool value}) {
    _isEditing = value;
    refreshUI();
  }
}
