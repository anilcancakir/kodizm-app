import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/models/project_container.dart';

void main() {
  // -------

  const Map<String, dynamic> fullFixture = {
    'id': 'pc-uuid-1',
    'container_name': 'kodizm-proj-abc123',
    'volume_name': 'kodizm-vol-abc123',
    'status': 'running',
    'docker_host_id': 'dh-uuid-1',
    'last_activity_at': '2026-04-01T10:00:00.000Z',
    'health_checked_at': '2026-04-01T09:55:00.000Z',
    'bootstrapped_at': '2026-03-30T12:00:00.000Z',
    'last_error': null,
    'created_at': '2026-03-30T12:00:00.000Z',
    'updated_at': '2026-04-01T10:00:00.000Z',
  };

  const Map<String, dynamic> nullTimestampsFixture = {
    'id': 'pc-uuid-2',
    'container_name': 'kodizm-proj-def456',
    'volume_name': 'kodizm-vol-def456',
    'status': 'creating',
    'docker_host_id': 'dh-uuid-2',
    'last_activity_at': null,
    'health_checked_at': null,
    'bootstrapped_at': null,
    'last_error': null,
    'created_at': '2026-03-31T08:00:00.000Z',
    'updated_at': '2026-03-31T08:00:00.000Z',
  };

  const Map<String, dynamic> withErrorFixture = {
    'id': 'pc-uuid-3',
    'container_name': 'kodizm-proj-ghi789',
    'volume_name': 'kodizm-vol-ghi789',
    'status': 'failed',
    'docker_host_id': 'dh-uuid-3',
    'last_activity_at': null,
    'health_checked_at': null,
    'bootstrapped_at': null,
    'last_error': 'Container failed to start: port already in use',
    'created_at': '2026-04-01T07:00:00.000Z',
    'updated_at': '2026-04-01T07:05:00.000Z',
  };

  // -------

  group('ProjectContainer.fromMap', () {
    test('parses all required fields correctly', () {
      final container = ProjectContainer.fromMap(fullFixture);

      expect(container.id, 'pc-uuid-1');
      expect(container.containerName, 'kodizm-proj-abc123');
      expect(container.volumeName, 'kodizm-vol-abc123');
      expect(container.status, 'running');
      expect(container.dockerHostId, 'dh-uuid-1');
    });

    test('parses nullable timestamps when present', () {
      final container = ProjectContainer.fromMap(fullFixture);

      expect(
        container.lastActivityAt,
        DateTime.parse('2026-04-01T10:00:00.000Z'),
      );
      expect(
        container.healthCheckedAt,
        DateTime.parse('2026-04-01T09:55:00.000Z'),
      );
      expect(
        container.bootstrappedAt,
        DateTime.parse('2026-03-30T12:00:00.000Z'),
      );
    });

    test('handles null timestamps', () {
      final container = ProjectContainer.fromMap(nullTimestampsFixture);

      expect(container.lastActivityAt, isNull);
      expect(container.healthCheckedAt, isNull);
      expect(container.bootstrappedAt, isNull);
    });

    test('parses lastError when present', () {
      final container = ProjectContainer.fromMap(withErrorFixture);

      expect(
        container.lastError,
        'Container failed to start: port already in use',
      );
    });

    test('handles null lastError', () {
      final container = ProjectContainer.fromMap(fullFixture);

      expect(container.lastError, isNull);
    });

    test('parses createdAt and updatedAt', () {
      final container = ProjectContainer.fromMap(fullFixture);

      expect(container.createdAt, DateTime.parse('2026-03-30T12:00:00.000Z'));
      expect(container.updatedAt, DateTime.parse('2026-04-01T10:00:00.000Z'));
    });
  });
}
