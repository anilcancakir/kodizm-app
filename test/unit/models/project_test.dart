import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/project.dart';

void main() {
  group('Project', () {
    // ---------------------------------------------------------------------------
    // Shared fixture
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kApiPayload = {
      'id': 'proj-uuid-001',
      'team_id': 'team-uuid-001',
      'name': 'Kodizm Backend',
      'slug': 'kodizm-backend',
      'description': 'Laravel API powering the Kodizm platform.',
      'repository_url': 'git@github.com:acme/kodizm-api.git',
      'default_branch': 'main',
      'tech_stack': 'Laravel, PostgreSQL, Redis',
      'ssh_public_key': 'ssh-ed25519 AAAAC3... agent@kodizm',
      'execution_mode': 'auto',
      'settings': {'timeout': 300, 'retries': 3},
      'created_at': '2024-01-15T10:30:00.000Z',
      'updated_at': '2024-06-20T14:00:00.000Z',
      'task_count': 42,
      'active_run_count': 2,
    };

    // ---------------------------------------------------------------------------
    // fromMap
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all required string fields', () {
      final project = Project.fromMap(kApiPayload);

      expect(project.id, equals('proj-uuid-001'));
      expect(project.teamId, equals('team-uuid-001'));
      expect(project.name, equals('Kodizm Backend'));
      expect(project.slug, equals('kodizm-backend'));
    });

    test('fromMap hydrates optional string fields', () {
      final project = Project.fromMap(kApiPayload);

      expect(
        project.description,
        equals('Laravel API powering the Kodizm platform.'),
      );
      expect(
        project.repositoryUrl,
        equals('git@github.com:acme/kodizm-api.git'),
      );
      expect(project.techStack, equals('Laravel, PostgreSQL, Redis'));
      expect(
        project.sshPublicKey,
        equals('ssh-ed25519 AAAAC3... agent@kodizm'),
      );
    });

    test('fromMap hydrates defaultBranch and executionMode', () {
      final project = Project.fromMap(kApiPayload);

      expect(project.defaultBranch, equals('main'));
      expect(project.executionMode, equals('auto'));
    });

    test('fromMap hydrates settings as Map', () {
      final project = Project.fromMap(kApiPayload);

      expect(project.settings, isA<Map<String, dynamic>>());
      expect(project.settings!['timeout'], equals(300));
      expect(project.settings!['retries'], equals(3));
    });

    test('fromMap parses createdAt and updatedAt as Carbon', () {
      final project = Project.fromMap(kApiPayload);

      expect(project.createdAt, isA<Carbon>());
      expect(project.updatedAt, isA<Carbon>());
      expect(project.createdAt!.toDateTime.year, equals(2024));
      expect(project.createdAt!.toDateTime.month, equals(1));
      expect(project.createdAt!.toDateTime.day, equals(15));
      expect(project.updatedAt!.toDateTime.year, equals(2024));
      expect(project.updatedAt!.toDateTime.month, equals(6));
    });

    test(
      'fromMap hydrates computed int fields taskCount and activeRunCount',
      () {
        final project = Project.fromMap(kApiPayload);

        expect(project.taskCount, equals(42));
        expect(project.activeRunCount, equals(2));
      },
    );

    test('fromMap sets exists to true when id is present', () {
      final project = Project.fromMap(kApiPayload);

      expect(project.exists, isTrue);
    });

    test('fromMap sets exists to false when id is absent', () {
      final map = Map<String, dynamic>.from(kApiPayload)..remove('id');
      final project = Project.fromMap(map);

      expect(project.exists, isFalse);
    });

    // ---------------------------------------------------------------------------
    // Nullable fields
    // ---------------------------------------------------------------------------

    test('nullable fields return null when absent from map', () {
      final minimal = {
        'id': 'proj-uuid-002',
        'team_id': 'team-uuid-001',
        'name': 'Minimal Project',
        'slug': 'minimal-project',
        'default_branch': 'main',
        'execution_mode': 'manual',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final project = Project.fromMap(minimal);

      expect(project.description, isNull);
      expect(project.repositoryUrl, isNull);
      expect(project.techStack, isNull);
      expect(project.sshPublicKey, isNull);
      expect(project.settings, isNull);
      expect(project.taskCount, isNull);
      expect(project.activeRunCount, isNull);
    });

    // ---------------------------------------------------------------------------
    // fromJson
    // ---------------------------------------------------------------------------

    test('fromJson delegates to fromMap and returns equivalent model', () {
      final json = jsonEncode(kApiPayload);
      final project = Project.fromJson(json);

      expect(project.id, equals('proj-uuid-001'));
      expect(project.name, equals('Kodizm Backend'));
      expect(project.teamId, equals('team-uuid-001'));
      expect(project.taskCount, equals(42));
      expect(project.exists, isTrue);
    });

    // ---------------------------------------------------------------------------
    // Typed setters
    // ---------------------------------------------------------------------------

    test('typed setters mutate the underlying attribute store', () {
      final project = Project.fromMap(kApiPayload);

      project.name = 'Renamed Project';
      project.description = 'Updated description.';
      project.defaultBranch = 'develop';

      expect(project.name, equals('Renamed Project'));
      expect(project.description, equals('Updated description.'));
      expect(project.defaultBranch, equals('develop'));
    });

    // ---------------------------------------------------------------------------
    // ORM configuration
    // ---------------------------------------------------------------------------

    test('incrementing is false (UUID primary keys)', () {
      final project = Project();

      expect(project.incrementing, isFalse);
    });

    test('table is projects', () {
      final project = Project();

      expect(project.table, equals('projects'));
    });

    test('resource is projects', () {
      final project = Project();

      expect(project.resource, equals('projects'));
    });
  });
}
