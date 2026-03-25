/// A single file change produced by an agent execution run.
///
/// Records which file was touched and the operation type: `M` (modified),
/// `A` (added), or `D` (deleted).
///
/// ## Usage
/// ```dart
/// final change = FileChange.fromMap(json['file_changes'][0]);
/// print('${change.operation}: ${change.filePath}');
/// ```
class FileChange {
  // -------

  /// Creates a [FileChange] with all fields.
  const FileChange({required this.filePath, required this.operation});

  // -------

  /// The relative path of the file that was changed.
  final String filePath;

  /// The operation type: `M` (modified), `A` (added), or `D` (deleted).
  final String operation;

  // -------

  /// Parses a [FileChange] from a JSON-decoded map.
  factory FileChange.fromMap(Map<String, dynamic> map) {
    return FileChange(
      filePath: map['file_path'] as String,
      operation: map['operation'] as String,
    );
  }
}
