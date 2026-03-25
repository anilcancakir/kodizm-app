import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/usage_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _makeRecord(String id) => {
  'id': id,
  'team_id': 'team-uuid-001',
  'task_run_id': 'run-uuid-001',
  'model': 'claude-3-5-sonnet-20241022',
  'input_tokens': 1000,
  'output_tokens': 200,
  'cache_read_tokens': 50,
  'cache_write_tokens': 10,
  'cost_usd': '0.00420',
  'period': '2025-03',
  'recorded_at': '2025-03-15T10:00:00.000Z',
  'task_run': {
    'agent_role_name': 'Dev',
    'task': {'title': 'Implement login', 'project_id': 'proj-uuid-001'},
  },
};

Map<String, dynamic> _makeResponse({
  List<Map<String, dynamic>>? records,
  int currentPage = 1,
  int lastPage = 1,
  int total = 2,
  String totalCostUsd = '12.50',
}) => {
  'data':
      records ?? [_makeRecord('usage-uuid-001'), _makeRecord('usage-uuid-002')],
  'meta': {
    'current_page': currentPage,
    'last_page': lastPage,
    'total': total,
    'totals': {
      'total_cost_usd': totalCostUsd,
      'total_input_tokens': 150000,
      'total_output_tokens': 30000,
    },
  },
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// Injectable HTTP client for testing [UsageState] without hitting the
/// network. Records calls and returns a pre-configured [MagicResponse].
class FakeUsageHttpClient implements UsageHttpClient {
  final List<_HttpCall> calls = [];
  late MagicResponse Function(String url) _responder;

  /// Always return [response] regardless of the requested URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  /// Return a different [MagicResponse] per call index.
  void respondWith(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('GET', url, query));
    return _responder(url);
  }
}

class _HttpCall {
  _HttpCall(this.method, this.url, this.query);

  final String method;
  final String url;
  final Map<String, dynamic>? query;

  @override
  String toString() => '$method $url';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UsageState', () {
    late FakeUsageHttpClient http;
    late UsageState state;

    setUp(() {
      http = FakeUsageHttpClient();
      state = UsageState(httpClient: http);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. loadUsage success
    // -----------------------------------------------------------------------

    test(
      'loadUsage success — returns records and transitions to success state',
      () async {
        http.alwaysReturn(
          MagicResponse(data: _makeResponse(), statusCode: 200),
        );

        await state.loadUsage('team-uuid-001');

        expect(state.isSuccess, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.records, hasLength(2));
        expect(state.records.first.id, equals('usage-uuid-001'));
        expect(state.records.first.model, equals('claude-3-5-sonnet-20241022'));
        expect(state.records.first.costUsd, equals(0.0042));
      },
    );

    // -----------------------------------------------------------------------
    // 2. loadUsage with filters — query params are sent
    // -----------------------------------------------------------------------

    test(
      'loadUsage with filters — query params include period, projectId, agentRole',
      () async {
        http.alwaysReturn(
          MagicResponse(data: _makeResponse(), statusCode: 200),
        );

        await state.loadUsage(
          'team-uuid-001',
          period: '2025-03',
          projectId: 'proj-uuid-001',
          agentRole: 'Dev',
        );

        expect(http.calls, hasLength(1));
        final query = http.calls.first.query;
        expect(query, isNotNull);
        expect(query!['period'], equals('2025-03'));
        expect(query['project_id'], equals('proj-uuid-001'));
        expect(query['agent_role'], equals('Dev'));
      },
    );

    // -----------------------------------------------------------------------
    // 3. loadMore appends records
    // -----------------------------------------------------------------------

    test(
      'loadMore appends records from second page to existing list',
      () async {
        var callCount = 0;
        http.respondWith((_) {
          callCount += 1;
          if (callCount == 1) {
            return MagicResponse(
              data: _makeResponse(
                records: [_makeRecord('usage-uuid-001')],
                currentPage: 1,
                lastPage: 2,
                total: 2,
              ),
              statusCode: 200,
            );
          }
          return MagicResponse(
            data: _makeResponse(
              records: [_makeRecord('usage-uuid-002')],
              currentPage: 2,
              lastPage: 2,
              total: 2,
            ),
            statusCode: 200,
          );
        });

        await state.loadUsage('team-uuid-001');
        expect(state.records, hasLength(1));
        expect(state.hasMore, isTrue);

        await state.loadMore();
        expect(state.records, hasLength(2));
        expect(state.records[0].id, equals('usage-uuid-001'));
        expect(state.records[1].id, equals('usage-uuid-002'));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Pagination fields update from meta
    // -----------------------------------------------------------------------

    test('pagination fields update correctly from meta', () async {
      http.alwaysReturn(
        MagicResponse(
          data: _makeResponse(currentPage: 2, lastPage: 5, total: 45),
          statusCode: 200,
        ),
      );

      await state.loadUsage('team-uuid-001');

      expect(state.currentPage, equals(2));
      expect(state.lastPage, equals(5));
      expect(state.totalRecords, equals(45));
      expect(state.hasMore, isTrue);
    });

    // -----------------------------------------------------------------------
    // 5. clearFilters resets filter values
    // -----------------------------------------------------------------------

    test('clearFilters resets all filter values to null', () async {
      state.setFilter(
        period: '2025-03',
        projectId: 'proj-uuid-001',
        agentRole: 'Dev',
      );

      expect(state.filterPeriod, equals('2025-03'));
      expect(state.filterProjectId, equals('proj-uuid-001'));
      expect(state.filterAgentRole, equals('Dev'));

      state.clearFilters();

      expect(state.filterPeriod, isNull);
      expect(state.filterProjectId, isNull);
      expect(state.filterAgentRole, isNull);
    });

    // -----------------------------------------------------------------------
    // 6. totalCostUsd from meta.totals
    // -----------------------------------------------------------------------

    test(
      'totalCostUsd is parsed from meta.totals.total_cost_usd as double',
      () async {
        http.alwaysReturn(
          MagicResponse(
            data: _makeResponse(totalCostUsd: '99.75'),
            statusCode: 200,
          ),
        );

        await state.loadUsage('team-uuid-001');

        expect(state.totalCostUsd, equals(99.75));
      },
    );

    // -----------------------------------------------------------------------
    // 7. loadUsage error handling
    // -----------------------------------------------------------------------

    test('loadUsage sets error state on non-2xx response', () async {
      http.alwaysReturn(
        MagicResponse(data: {'message': 'Forbidden'}, statusCode: 403),
      );

      await state.loadUsage('team-uuid-001');

      expect(state.isError, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.rxStatus.message, equals('Forbidden'));
    });

    // -----------------------------------------------------------------------
    // 8. loadMore no-ops when already on last page
    // -----------------------------------------------------------------------

    test('loadMore does nothing when hasMore is false', () async {
      http.alwaysReturn(
        MagicResponse(
          data: _makeResponse(currentPage: 1, lastPage: 1),
          statusCode: 200,
        ),
      );

      await state.loadUsage('team-uuid-001');
      expect(state.hasMore, isFalse);

      final callsBefore = http.calls.length;
      await state.loadMore();
      expect(http.calls.length, equals(callsBefore));
    });
  });
}
