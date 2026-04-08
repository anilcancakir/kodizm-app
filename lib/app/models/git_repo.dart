/// GitHub repository returned by the git provider repos endpoint.
///
/// ## Usage
/// ```dart
/// final repo = GitRepo.fromMap(data);
/// print(repo.fullName); // 'owner/repo'
/// ```
class GitRepo {
  // -------

  /// Creates a [GitRepo] with all fields.
  const GitRepo({
    required this.fullName,
    required this.defaultBranch,
    required this.cloneUrl,
    required this.sshUrl,
    required this.isPrivate,
    this.description,
  });

  // -------

  /// The full repository name in `owner/repo` format.
  final String fullName;

  /// The default branch of the repository (e.g. `'main'`, `'master'`).
  final String defaultBranch;

  /// The HTTPS clone URL for the repository.
  final String cloneUrl;

  /// The SSH clone URL for the repository.
  final String sshUrl;

  /// Whether the repository is private.
  final bool isPrivate;

  /// Optional human-readable description of the repository.
  final String? description;

  // -------

  /// Parses a [GitRepo] from a JSON-decoded map.
  factory GitRepo.fromMap(Map<String, dynamic> map) {
    return GitRepo(
      fullName: (map['full_name'] as String?) ?? '',
      defaultBranch: (map['default_branch'] as String?) ?? 'main',
      cloneUrl: (map['clone_url'] as String?) ?? '',
      sshUrl: (map['ssh_url'] as String?) ?? '',
      isPrivate: (map['private'] as bool?) ?? false,
      description: map['description'] as String?,
    );
  }
}
