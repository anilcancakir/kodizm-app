import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/ai_token_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTokenPayload = {
  'id': 'tok-uuid-001',
  'team_id': 'team-uuid-001',
  'provider': 'anthropic',
  'auth_type': 'api_key',
  'label': 'Production Key',
  'status': 'active',
  'rotation_algorithm': null,
  'last_used_at': '2025-06-10T12:00:00.000Z',
  'usage_count': 150,
  'cooldown_until': null,
  'health_checked_at': '2025-06-10T11:00:00.000Z',
  'settings': <String, dynamic>{},
  'created_at': '2025-01-01T00:00:00.000Z',
  'updated_at': '2025-06-10T12:00:00.000Z',
};

const Map<String, dynamic> kApiPayload = {
  'data': [kTokenPayload],
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('AiTokenState', () {
    late FakeNetworkDriver driver;
    late AiTokenState state;

    setUp(() {
      driver = Http.fake();
      state = AiTokenState();
    });

    tearDown(() {
      state.dispose();
      Http.unfake();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state
    // -----------------------------------------------------------------------

    test('initial state is empty, not loading, not error', () {
      expect(state.isEmpty, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 2. loadTokens — loading then success
    // -----------------------------------------------------------------------

    test('loadTokens sets loading then transitions to success', () async {
      driver.stub(
        '*/ai-tokens',
        MagicResponse(data: kApiPayload, statusCode: 200),
      );

      expect(state.isEmpty, isTrue);

      final future = state.loadTokens('team-uuid-001');

      // setLoading() is synchronous — verified before awaiting.
      expect(state.isLoading, isTrue);
      expect(state.isSuccess, isFalse);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.rxState, isNotNull);

      // Verify URL.
      expect(driver.recorded.length, equals(1));
      expect(driver.recorded.first.$1.method, equals('GET'));
      expect(
        driver.recorded.first.$1.url,
        equals('/teams/team-uuid-001/ai-tokens'),
      );
    });

    // -----------------------------------------------------------------------
    // 3. loadTokens — empty list
    // -----------------------------------------------------------------------

    test('loadTokens returns empty list and isEmpty is true', () async {
      driver.stub(
        '*/ai-tokens',
        MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
      );

      await state.loadTokens('team-uuid-001');

      expect(state.isEmpty, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isError, isFalse);
    });

    // -----------------------------------------------------------------------
    // 4. loadTokens — error handling
    // -----------------------------------------------------------------------

    test('loadTokens sets error state on non-2xx response', () async {
      driver.stub(
        '*/ai-tokens',
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.loadTokens('team-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.rxState, isNull);
      expect(state.rxStatus.message, equals('Unauthorized'));
    });

    // -----------------------------------------------------------------------
    // 5. loadTokens — parses AiToken list correctly
    // -----------------------------------------------------------------------

    test('loadTokens parses AiToken list with all fields', () async {
      driver.stub(
        '*/ai-tokens',
        MagicResponse(data: kApiPayload, statusCode: 200),
      );

      await state.loadTokens('team-uuid-001');

      final tokens = state.rxState!;

      expect(tokens.length, equals(1));

      final token = tokens.first;
      expect(token.id, equals('tok-uuid-001'));
      expect(token.teamId, equals('team-uuid-001'));
      expect(token.provider, equals('anthropic'));
      expect(token.authType, equals('api_key'));
      expect(token.label, equals('Production Key'));
      expect(token.status, equals('active'));
      expect(token.usageCount, equals(150));
      expect(token.rotationAlgorithm, isNull);
      expect(token.cooldownUntil, isNull);
      expect(token.lastUsedAt, isNotNull);
    });

    // -----------------------------------------------------------------------
    // 6. providerBadgeClassName
    // -----------------------------------------------------------------------

    test(
      'providerBadgeClassName returns correct classes for known providers',
      () {
        expect(
          AiTokenState.providerBadgeClassName('anthropic'),
          equals('bg-violet-500/10 text-violet-500'),
        );
        expect(
          AiTokenState.providerBadgeClassName('openai'),
          equals('bg-emerald-500/10 text-emerald-500'),
        );
        expect(
          AiTokenState.providerBadgeClassName('google'),
          equals('bg-blue-500/10 text-blue-500'),
        );
        expect(
          AiTokenState.providerBadgeClassName('openrouter'),
          equals('bg-amber-500/10 text-amber-500'),
        );
        expect(
          AiTokenState.providerBadgeClassName('unknown'),
          equals('bg-slate-500/10 text-slate-500'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 7. statusDotClassName
    // -----------------------------------------------------------------------

    test('statusDotClassName returns correct classes for known statuses', () {
      expect(
        AiTokenState.statusDotClassName('active'),
        equals('bg-emerald-400'),
      );
      expect(
        AiTokenState.statusDotClassName('inactive'),
        equals('bg-slate-400'),
      );
      expect(
        AiTokenState.statusDotClassName('rate_limited'),
        equals('bg-amber-400'),
      );
      expect(AiTokenState.statusDotClassName('expired'), equals('bg-red-400'));
      expect(
        AiTokenState.statusDotClassName('unknown'),
        equals('bg-slate-400'),
      );
    });
  });
}
