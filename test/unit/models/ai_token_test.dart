import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/ai_token.dart';

void main() {
  group('AiToken', () {
    // ---------------------------------------------------------------------------
    // Shared fixture
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kApiPayload = {
      'id': 'token-uuid-001',
      'team_id': 'team-uuid-001',
      'provider': 'anthropic',
      'auth_type': 'api_key',
      'label': 'Primary Anthropic Key',
      'status': 'active',
      'rotation_algorithm': 'round_robin',
      'last_used_at': '2025-03-20T10:00:00.000Z',
      'usage_count': 1240,
      'cooldown_until': null,
      'health_checked_at': '2025-03-25T06:00:00.000Z',
      'settings': {'timeout': 30, 'max_retries': 3},
      'created_at': '2025-01-10T09:00:00.000Z',
      'updated_at': '2025-03-25T06:00:00.000Z',
    };

    // ---------------------------------------------------------------------------
    // fromMap
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all required fields correctly', () {
      final token = AiToken.fromMap(kApiPayload);

      expect(token.id, equals('token-uuid-001'));
      expect(token.teamId, equals('team-uuid-001'));
      expect(token.provider, equals('anthropic'));
      expect(token.authType, equals('api_key'));
      expect(token.label, equals('Primary Anthropic Key'));
      expect(token.status, equals('active'));
      expect(token.usageCount, equals(1240));
      expect(token.rotationAlgorithm, equals('round_robin'));
      expect(
        token.createdAt,
        equals(DateTime.parse('2025-01-10T09:00:00.000Z')),
      );
      expect(
        token.updatedAt,
        equals(DateTime.parse('2025-03-25T06:00:00.000Z')),
      );
    });

    test('fromMap hydrates optional DateTime fields', () {
      final token = AiToken.fromMap(kApiPayload);

      expect(
        token.lastUsedAt,
        equals(DateTime.parse('2025-03-20T10:00:00.000Z')),
      );
      expect(
        token.healthCheckedAt,
        equals(DateTime.parse('2025-03-25T06:00:00.000Z')),
      );
      expect(token.cooldownUntil, isNull);
    });

    test('fromMap hydrates settings as Map', () {
      final token = AiToken.fromMap(kApiPayload);

      expect(token.settings, isA<Map<String, dynamic>>());
      expect(token.settings['timeout'], equals(30));
      expect(token.settings['max_retries'], equals(3));
    });

    // ---------------------------------------------------------------------------
    // Nullable fields
    // ---------------------------------------------------------------------------

    test('nullable DateTime fields return null when absent from map', () {
      const minimal = {
        'id': 'token-uuid-002',
        'team_id': 'team-uuid-001',
        'provider': 'openai',
        'auth_type': 'api_key',
        'label': 'OpenAI Key',
        'status': 'inactive',
        'rotation_algorithm': null,
        'last_used_at': null,
        'usage_count': 0,
        'cooldown_until': null,
        'health_checked_at': null,
        'settings': <String, dynamic>{},
        'created_at': '2025-02-01T00:00:00.000Z',
        'updated_at': '2025-02-01T00:00:00.000Z',
      };

      final token = AiToken.fromMap(minimal);

      expect(token.rotationAlgorithm, isNull);
      expect(token.lastUsedAt, isNull);
      expect(token.cooldownUntil, isNull);
      expect(token.healthCheckedAt, isNull);
    });

    // ---------------------------------------------------------------------------
    // Specific status and provider values
    // ---------------------------------------------------------------------------

    test('fromMap preserves rate_limited status', () {
      final map = {
        ...kApiPayload,
        'status': 'rate_limited',
        'cooldown_until': '2025-03-26T14:00:00.000Z',
      };
      final token = AiToken.fromMap(map);

      expect(token.status, equals('rate_limited'));
      expect(
        token.cooldownUntil,
        equals(DateTime.parse('2025-03-26T14:00:00.000Z')),
      );
    });

    test('fromMap handles all known providers', () {
      for (final provider in ['anthropic', 'openai', 'google', 'openrouter']) {
        final token = AiToken.fromMap({...kApiPayload, 'provider': provider});
        expect(token.provider, equals(provider));
      }
    });

    test('createdAt and updatedAt are parsed as UTC DateTime', () {
      final token = AiToken.fromMap(kApiPayload);

      expect(token.createdAt.isUtc, isTrue);
      expect(token.updatedAt.isUtc, isTrue);
      expect(token.createdAt.year, equals(2025));
      expect(token.createdAt.month, equals(1));
      expect(token.createdAt.day, equals(10));
    });
  });
}
