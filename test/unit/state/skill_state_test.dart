import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/skill_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kSkillA = {
  'id': 'skill-uuid-001',
  'name': 'my-coding',
  'slug': 'my-coding',
  'description': 'Enforce coding style and conventions.',
  'when_to_use': 'When writing or reviewing code.',
  'category': 'coding',
  'body': 'You are a coding expert...',
  'scope': 'global',
  'source': 'local',
  'source_id': null,
  'source_url': null,
  'is_active': true,
  'sort_order': 1,
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
};

const Map<String, dynamic> kSkillB = {
  'id': 'skill-uuid-002',
  'name': 'my-language',
  'slug': 'my-language',
  'description': 'Write in personal voice.',
  'when_to_use': 'When writing documentation.',
  'category': 'writing',
  'body': 'You are a writing expert...',
  'scope': 'global',
  'source': 'marketplace',
  'source_id': 'mp-skill-002',
  'source_url': 'https://skillsmp.io/skills/my-language',
  'is_active': false,
  'sort_order': 2,
  'created_at': '2025-03-01T08:00:00.000Z',
  'updated_at': '2025-03-20T12:00:00.000Z',
};

const Map<String, dynamic> kMarketplaceResult = {
  'id': 'mp-skill-001',
  'name': 'frontend-design',
  'slug': 'frontend-design',
  'description': 'Production-grade UI design patterns.',
  'category': 'design',
};

// ---------------------------------------------------------------------------
// Fake HTTP client (reuses the HttpClient abstraction from skill_state.dart)
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [SkillState] without hitting the
/// network. Each method records the call and returns a pre-configured
/// [MagicResponse].
class FakeHttpClient implements HttpClient {
  final List<HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Set a responder that maps URL to [MagicResponse].
  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  /// Shortcut: always return the same response regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('GET', url, query: query));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(HttpCall('DELETE', url));
    return _responder(url);
  }
}

class HttpCall {
  HttpCall(this.method, this.url, {this.data, this.query});

  final String method;
  final String url;
  final dynamic data;
  final Map<String, dynamic>? query;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SkillState', () {
    late FakeHttpClient http;
    late SkillState state;

    setUp(() {
      http = FakeHttpClient();
      state = SkillState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. fetchSkills — success
    // -----------------------------------------------------------------------

    test('fetchSkills sets loading then success with skill list', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kSkillA, kSkillB],
          },
          statusCode: 200,
        ),
      );

      // Should start empty.
      expect(state.isEmpty, isTrue);

      final future = state.fetchSkills();

      // Loading is synchronous — should be set immediately.
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isSuccess, isTrue);
      expect(state.rxState, isNotNull);
      expect(state.rxState!.length, equals(2));
      expect(state.rxState![0].id, equals('skill-uuid-001'));
      expect(state.rxState![1].id, equals('skill-uuid-002'));

      // Verify correct URL was called.
      expect(http.calls.length, equals(1));
      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/skills'));
    });

    // -----------------------------------------------------------------------
    // 2. fetchSkills — empty list
    // -----------------------------------------------------------------------

    test('fetchSkills sets empty when API returns empty list', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
      );

      await state.fetchSkills();

      expect(state.isEmpty, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 3. fetchSkills — error
    // -----------------------------------------------------------------------

    test('fetchSkills sets error on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.fetchSkills();
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.rxState, isNull);
    });

    // -----------------------------------------------------------------------
    // 4. fetchSkill — finds from loaded list
    // -----------------------------------------------------------------------

    test(
      'fetchSkill returns skill from in-memory list when already loaded',
      () async {
        http.alwaysReturn(
          MagicResponse(
            data: {
              'data': [kSkillA, kSkillB],
            },
            statusCode: 200,
          ),
        );

        await state.fetchSkills();
        http.calls.clear();

        final skill = await state.fetchSkill('skill-uuid-001');

        expect(skill, isNotNull);
        expect(skill!.name, equals('my-coding'));
        // Should NOT hit network — found in memory.
        expect(http.calls, isEmpty);
      },
    );

    // -----------------------------------------------------------------------
    // 5. fetchSkill — fetches from API when not in list
    // -----------------------------------------------------------------------

    test('fetchSkill fetches from API when skill not in memory', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kSkillA}, statusCode: 200),
      );

      final skill = await state.fetchSkill('skill-uuid-001');

      expect(skill, isNotNull);
      expect(skill!.id, equals('skill-uuid-001'));
      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/skills/skill-uuid-001'));
    });

    // -----------------------------------------------------------------------
    // 6. searchMarketplace — success
    // -----------------------------------------------------------------------

    test('searchMarketplace stores results and returns them', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kMarketplaceResult],
          },
          statusCode: 200,
        ),
      );

      final results = await state.searchMarketplace('frontend');

      expect(results, isNotNull);
      expect(results!.length, equals(1));
      expect(results.first['name'], equals('frontend-design'));
      expect(state.marketplaceResults, isNotNull);
      expect(state.marketplaceResults!.length, equals(1));

      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/skillsmp/search'));
    });

    // -----------------------------------------------------------------------
    // 7. searchMarketplace — error returns null
    // -----------------------------------------------------------------------

    test('searchMarketplace returns null on error', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {'message': 'Service Unavailable'},
          statusCode: 503,
        ),
      );

      final results = await state.searchMarketplace('frontend');

      expect(results, isNull);
      expect(state.marketplaceResults, isNull);
    });

    // -----------------------------------------------------------------------
    // 8. aiSearchMarketplace — success
    // -----------------------------------------------------------------------

    test('aiSearchMarketplace stores results and returns them', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kMarketplaceResult],
          },
          statusCode: 200,
        ),
      );

      final results = await state.aiSearchMarketplace('help me design UI');

      expect(results, isNotNull);
      expect(results!.length, equals(1));
      expect(state.marketplaceResults, isNotNull);

      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/skillsmp/ai-search'));
    });

    // -----------------------------------------------------------------------
    // 9. importSkill — success returns imported skill
    // -----------------------------------------------------------------------

    test(
      'importSkill posts data, refreshes list, and returns imported skill',
      () async {
        http.whenAny((url) {
          if (url == '/skillsmp/import') {
            return MagicResponse(data: {'data': kSkillB}, statusCode: 201);
          }
          // fetchSkills call after import
          return MagicResponse(
            data: {
              'data': [kSkillA, kSkillB],
            },
            statusCode: 200,
          );
        });

        final skill = await state.importSkill({
          'source_id': 'mp-skill-002',
          'source_url': 'https://skillsmp.io/skills/my-language',
        });

        expect(skill, isNotNull);
        expect(skill!.id, equals('skill-uuid-002'));
        expect(skill.source, equals('marketplace'));

        expect(http.calls.first.method, equals('POST'));
        expect(http.calls.first.url, equals('/skillsmp/import'));

        // Should have refreshed the list.
        final refreshCall = http.calls.firstWhere((c) => c.url == '/skills');
        expect(refreshCall.method, equals('GET'));
      },
    );

    // -----------------------------------------------------------------------
    // 10. importSkill — failure returns null
    // -----------------------------------------------------------------------

    test('importSkill returns null on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      final skill = await state.importSkill({'source_id': 'mp-skill-999'});

      expect(skill, isNull);
    });

    // -----------------------------------------------------------------------
    // 11. fetchQuota — success stores quota info
    // -----------------------------------------------------------------------

    test('fetchQuota stores quota info and returns it', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {
            'remaining': 45,
            'limit': 50,
            'resets_at': '2026-04-04T00:00:00.000Z',
          },
          statusCode: 200,
        ),
      );

      final quota = await state.fetchQuota();

      expect(quota, isNotNull);
      expect(quota!['remaining'], equals(45));
      expect(state.quotaInfo, isNotNull);
      expect(state.quotaInfo!['limit'], equals(50));

      expect(http.calls.first.method, equals('GET'));
      expect(http.calls.first.url, equals('/skillsmp/quota'));
    });

    // -----------------------------------------------------------------------
    // 12. fetchQuota — failure returns null
    // -----------------------------------------------------------------------

    test('fetchQuota returns null on failure', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Not Found'}, statusCode: 404),
      );

      final quota = await state.fetchQuota();

      expect(quota, isNull);
      expect(state.quotaInfo, isNull);
    });

    // -----------------------------------------------------------------------
    // 13. createSkill — success returns created skill
    // -----------------------------------------------------------------------

    test('createSkill posts data and returns created skill', () async {
      http.alwaysReturn(
        MagicResponse(data: {'data': kSkillA}, statusCode: 201),
      );

      final skill = await state.createSkill({
        'name': 'my-coding',
        'category': 'coding',
        'body': 'You are a coding expert...',
      });

      expect(skill, isNotNull);
      expect(skill!.id, equals('skill-uuid-001'));
      expect(skill.name, equals('my-coding'));

      expect(http.calls.first.method, equals('POST'));
      expect(http.calls.first.url, equals('/skills'));
    });

    // -----------------------------------------------------------------------
    // 14. createSkill — failure returns null
    // -----------------------------------------------------------------------

    test('createSkill returns null on failure', () async {
      http.alwaysReturn(
        MagicResponse(
          data: {'message': 'Unprocessable Entity'},
          statusCode: 422,
        ),
      );

      final skill = await state.createSkill({'name': ''});

      expect(skill, isNull);
    });

    // -----------------------------------------------------------------------
    // 15. marketplaceLoading flag
    // -----------------------------------------------------------------------

    test('marketplaceLoading is false initially', () {
      expect(state.marketplaceLoading, isFalse);
    });
  });
}
