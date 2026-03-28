import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/session_share.dart';

void main() {
  group('SessionShare', () {
    // -------

    const Map<String, dynamic> readShareFixture = {
      'id': 'share-uuid-1',
      'session_id': 'sess-uuid-1',
      'shareable_type': 'App\\Models\\Project',
      'shareable_id': 'proj-uuid-1',
      'permission': 'read',
      'shared_by': 'user-uuid-1',
      'created_at': '2025-03-10T09:00:00.000Z',
      'updated_at': '2025-03-10T09:05:00.000Z',
    };

    const Map<String, dynamic> writeShareFixture = {
      'id': 'share-uuid-2',
      'session_id': 'sess-uuid-2',
      'shareable_type': 'App\\Models\\Team',
      'shareable_id': 'team-uuid-1',
      'permission': 'write',
      'shared_by': 'user-uuid-2',
      'created_at': '2025-03-11T10:00:00.000Z',
      'updated_at': '2025-03-11T10:00:00.000Z',
    };

    // -------

    test('fromMap parses all required fields correctly', () {
      final share = SessionShare.fromMap(readShareFixture);

      expect(share.id, 'share-uuid-1');
      expect(share.sessionId, 'sess-uuid-1');
      expect(share.shareableType, 'App\\Models\\Project');
      expect(share.shareableId, 'proj-uuid-1');
    });

    test('fromMap parses permission field', () {
      final readShare = SessionShare.fromMap(readShareFixture);
      final writeShare = SessionShare.fromMap(writeShareFixture);

      expect(readShare.permission, 'read');
      expect(writeShare.permission, 'write');
    });

    test('fromMap parses sharedBy field', () {
      final share = SessionShare.fromMap(readShareFixture);

      expect(share.sharedBy, 'user-uuid-1');
    });

    test('fromMap parses createdAt and updatedAt as DateTimes', () {
      final share = SessionShare.fromMap(readShareFixture);

      expect(share.createdAt, DateTime.parse('2025-03-10T09:00:00.000Z'));
      expect(share.updatedAt, DateTime.parse('2025-03-10T09:05:00.000Z'));
    });

    test('fromMap handles different shareable types', () {
      final share = SessionShare.fromMap(writeShareFixture);

      expect(share.shareableType, 'App\\Models\\Team');
      expect(share.shareableId, 'team-uuid-1');
    });
  });
}
