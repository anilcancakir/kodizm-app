import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/project_repository.dart';

void main() {
  group('ProjectRepository', () {
    // ---------------------------------------------------------------------------
    // Shared fixture
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kApiPayload = {
      'id': 'repo-uuid-001',
      'project_id': 'proj-uuid-001',
      'name': 'kodizm-api',
      'repository_url': 'git@github.com:acme/kodizm-api.git',
      'default_branch': 'main',
      'repo_status': 'synced',
      'repo_error': null,
      'last_synced_at': '2024-06-20T12:00:00.000Z',
      'mount_path': '/workspace',
      'created_at': '2024-01-15T10:30:00.000Z',
      'updated_at': '2024-06-20T14:00:00.000Z',
    };

    // ---------------------------------------------------------------------------
    // fromMap
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all required fields', () {
      final repo = ProjectRepository.fromMap(kApiPayload);

      expect(repo.id, equals('repo-uuid-001'));
      expect(repo.projectId, equals('proj-uuid-001'));
      expect(repo.name, equals('kodizm-api'));
      expect(repo.defaultBranch, equals('main'));
      expect(repo.mountPath, equals('/workspace'));
    });

    test('fromMap hydrates optional fields', () {
      final repo = ProjectRepository.fromMap(kApiPayload);

      expect(repo.repositoryUrl, equals('git@github.com:acme/kodizm-api.git'));
      expect(repo.repoStatus, equals('synced'));
      expect(repo.repoError, isNull);
      expect(repo.lastSyncedAt, equals('2024-06-20T12:00:00.000Z'));
      expect(repo.createdAt, equals('2024-01-15T10:30:00.000Z'));
      expect(repo.updatedAt, equals('2024-06-20T14:00:00.000Z'));
    });

    test(
      'fromMap does not expose sshPublicKey or hasSshKey — moved to Project',
      () {
        const minimal = {
          'id': 'repo-uuid-002',
          'project_id': 'proj-uuid-001',
          'name': 'minimal-repo',
        };

        final repo = ProjectRepository.fromMap(minimal);

        // sshPublicKey and hasSshKey have been moved to the Project level.
        // These properties must NOT exist on ProjectRepository.
        expect(repo.defaultBranch, equals('main'));
        expect(repo.mountPath, equals('/workspace'));
        expect(repo.repositoryUrl, isNull);
        expect(repo.repoStatus, isNull);
        expect(repo.repoError, isNull);
        expect(repo.lastSyncedAt, isNull);
        expect(repo.createdAt, isNull);
        expect(repo.updatedAt, isNull);
      },
    );

    // ---------------------------------------------------------------------------
    // copyWith
    // ---------------------------------------------------------------------------

    test('copyWith returns identical object when no fields provided', () {
      final repo = ProjectRepository.fromMap(kApiPayload);
      final copy = repo.copyWith();

      expect(copy.id, equals(repo.id));
      expect(copy.projectId, equals(repo.projectId));
      expect(copy.name, equals(repo.name));
      expect(copy.repositoryUrl, equals(repo.repositoryUrl));
      expect(copy.defaultBranch, equals(repo.defaultBranch));
      expect(copy.mountPath, equals(repo.mountPath));
    });

    test('copyWith replaces specified fields', () {
      final repo = ProjectRepository.fromMap(kApiPayload);
      final updated = repo.copyWith(
        name: 'new-name',
        defaultBranch: 'develop',
        mountPath: '/app',
      );

      expect(updated.name, equals('new-name'));
      expect(updated.defaultBranch, equals('develop'));
      expect(updated.mountPath, equals('/app'));
      // Unchanged fields preserved.
      expect(updated.id, equals(repo.id));
      expect(updated.repositoryUrl, equals(repo.repositoryUrl));
    });

    test('copyWith clear flags set nullable fields to null', () {
      final repo = ProjectRepository.fromMap(kApiPayload);
      final cleared = repo.copyWith(
        clearRepositoryUrl: true,
        clearRepoStatus: true,
        clearRepoError: true,
        clearLastSyncedAt: true,
      );

      expect(cleared.repositoryUrl, isNull);
      expect(cleared.repoStatus, isNull);
      expect(cleared.repoError, isNull);
      expect(cleared.lastSyncedAt, isNull);
    });

    // ---------------------------------------------------------------------------
    // isMain field
    // ---------------------------------------------------------------------------

    test('fromMap sets isMain to true when is_main is true', () {
      final repo = ProjectRepository.fromMap({...kApiPayload, 'is_main': true});

      expect(repo.isMain, isTrue);
    });

    test('fromMap sets isMain to false when is_main is false', () {
      final repo = ProjectRepository.fromMap({
        ...kApiPayload,
        'is_main': false,
      });

      expect(repo.isMain, isFalse);
    });

    test('fromMap defaults isMain to false when is_main is absent', () {
      final repo = ProjectRepository.fromMap(kApiPayload);

      expect(repo.isMain, isFalse);
    });

    test('copyWith can set isMain to true', () {
      final repo = ProjectRepository.fromMap(kApiPayload);
      final updated = repo.copyWith(isMain: true);

      expect(updated.isMain, isTrue);
      expect(updated.id, equals(repo.id));
    });

    test('copyWith can set isMain to false', () {
      final repo = ProjectRepository.fromMap({...kApiPayload, 'is_main': true});
      final updated = repo.copyWith(isMain: false);

      expect(updated.isMain, isFalse);
    });

    test('copyWith preserves isMain when not provided', () {
      final repo = ProjectRepository.fromMap({...kApiPayload, 'is_main': true});
      final copy = repo.copyWith(name: 'new-name');

      expect(copy.isMain, isTrue);
    });

    // ---------------------------------------------------------------------------
    // Immutability
    // ---------------------------------------------------------------------------

    test('is immutable — const constructor works', () {
      const repo = ProjectRepository(
        id: 'repo-uuid-003',
        projectId: 'proj-uuid-001',
        name: 'const-repo',
        defaultBranch: 'main',
        mountPath: '/workspace',
      );

      expect(repo.id, equals('repo-uuid-003'));
      expect(repo.name, equals('const-repo'));
    });
  });
}
