import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/billing_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kBalancePayload = {
  'balance': '125.50',
  'currency': 'USD',
  'max_concurrent_runs': 3,
};

const Map<String, dynamic> kUsagePayload = {
  'data': [
    {
      'id': 'rec-uuid-001',
      'team_id': 'team-uuid-001',
      'conversation_id': 'run-uuid-001',
      'model': 'claude-3-5-sonnet-20241022',
      'input_tokens': 1000,
      'output_tokens': 500,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '0.003000',
      'period': '2025-03',
      'recorded_at': '2025-03-15T10:00:00.000Z',
      'conversation': {
        'agent_role_name': 'Dev',
        'task': {'title': 'Implement login', 'project_id': 'proj-uuid-001'},
      },
    },
    {
      'id': 'rec-uuid-002',
      'team_id': 'team-uuid-001',
      'conversation_id': 'run-uuid-002',
      'model': 'claude-3-5-sonnet-20241022',
      'input_tokens': 800,
      'output_tokens': 300,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '0.002000',
      'period': '2025-03',
      'recorded_at': '2025-03-16T11:00:00.000Z',
      'conversation': {
        'agent_role_name': 'Reviewer',
        'task': {'title': 'Review PR', 'project_id': 'proj-uuid-001'},
      },
    },
    {
      'id': 'rec-uuid-003',
      'team_id': 'team-uuid-001',
      'conversation_id': 'run-uuid-003',
      'model': 'claude-3-5-sonnet-20241022',
      'input_tokens': 1200,
      'output_tokens': 600,
      'cache_read_tokens': null,
      'cache_write_tokens': null,
      'cost_usd': '0.004000',
      'period': '2025-03',
      'recorded_at': '2025-03-17T12:00:00.000Z',
      'conversation': {
        'agent_role_name': 'Dev',
        'task': {'title': 'Add unit tests', 'project_id': 'proj-uuid-001'},
      },
    },
  ],
  'meta': {
    'total': 3,
    'totals': {'total_cost_usd': '0.009000'},
  },
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('BillingState', () {
    late FakeNetworkDriver driver;
    late BillingState state;

    setUp(() {
      driver = Http.fake();
      state = BillingState();
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
      expect(state.totalCostUsd, equals(0.0));
      expect(state.runCount, equals(0));
      expect(state.avgCostPerRun, equals(0.0));
      expect(state.usageByRole, isEmpty);
      expect(state.isSummaryLoading, isFalse);
      expect(state.isRoleLoading, isFalse);
    });

    // -----------------------------------------------------------------------
    // 2. loadBalance — success, parses balance from string
    // -----------------------------------------------------------------------

    test('loadBalance sets loading then transitions to success', () async {
      driver.stub(
        '*/balance',
        MagicResponse(data: {'data': kBalancePayload}, statusCode: 200),
      );

      expect(state.isEmpty, isTrue);

      final future = state.loadBalance('team-uuid-001');

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
        equals('/teams/team-uuid-001/balance'),
      );
    });

    // -----------------------------------------------------------------------
    // 3. loadBalance — balance parsed from decimal string via double.parse
    // -----------------------------------------------------------------------

    test('loadBalance parses balance correctly from decimal string', () async {
      driver.stub(
        '*/balance',
        MagicResponse(data: {'data': kBalancePayload}, statusCode: 200),
      );

      await state.loadBalance('team-uuid-001');

      final balance = state.rxState!;
      expect(balance.balance, equals(125.50));
      expect(balance.currency, equals('USD'));
      expect(balance.maxConcurrentRuns, equals(3));
    });

    // -----------------------------------------------------------------------
    // 4. loadBalance — error handling
    // -----------------------------------------------------------------------

    test('loadBalance sets error state on non-2xx response', () async {
      driver.stub(
        '*/balance',
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.loadBalance('team-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.rxState, isNull);
      expect(state.rxStatus.message, equals('Unauthorized'));
    });

    // -----------------------------------------------------------------------
    // 5. loadMonthlySummary — uses meta.totals for totals
    // -----------------------------------------------------------------------

    test(
      'loadMonthlySummary populates totalCostUsd and runCount from meta',
      () async {
        driver.stub(
          '*/usage',
          MagicResponse(data: kUsagePayload, statusCode: 200),
        );

        await state.loadMonthlySummary('team-uuid-001');

        expect(state.totalCostUsd, closeTo(0.009, 0.0001));
        expect(state.runCount, equals(3));
        expect(state.avgCostPerRun, closeTo(0.003, 0.0001));
        expect(state.isSummaryLoading, isFalse);

        // Verify URL.
        expect(driver.recorded.length, equals(1));
        expect(
          driver.recorded.first.$1.url,
          equals('/teams/team-uuid-001/usage'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // 6. loadMonthlySummary — guards division by zero
    // -----------------------------------------------------------------------

    test(
      'loadMonthlySummary sets avgCostPerRun to 0 when runCount is 0',
      () async {
        driver.stub(
          '*/usage',
          MagicResponse(
            data: {
              'data': [],
              'meta': {
                'total': 0,
                'totals': {'total_cost_usd': '0.000000'},
              },
            },
            statusCode: 200,
          ),
        );

        await state.loadMonthlySummary('team-uuid-001');

        expect(state.runCount, equals(0));
        expect(state.avgCostPerRun, equals(0.0));
      },
    );

    // -----------------------------------------------------------------------
    // 7. loadUsageByRole — groups records by agentRoleName
    // -----------------------------------------------------------------------

    test(
      'loadUsageByRole groups usage records by agentRoleName and sums costUsd',
      () async {
        driver.stub(
          '*/usage',
          MagicResponse(data: kUsagePayload, statusCode: 200),
        );

        await state.loadUsageByRole('team-uuid-001');

        expect(state.usageByRole, isNotEmpty);
        expect(state.isRoleLoading, isFalse);

        // Dev has two records: 0.003 + 0.004 = 0.007.
        expect(state.usageByRole['Dev'], closeTo(0.007, 0.0001));

        // Reviewer has one record: 0.002.
        expect(state.usageByRole['Reviewer'], closeTo(0.002, 0.0001));
      },
    );

    // -----------------------------------------------------------------------
    // 8. loadBalance — fallback error message
    // -----------------------------------------------------------------------

    test(
      'loadBalance uses fallback message when response has no message',
      () async {
        driver.stub('*/balance', MagicResponse(data: null, statusCode: 500));

        await state.loadBalance('team-uuid-001');

        expect(state.isError, isTrue);
        expect(state.rxStatus.message, equals('Failed to fetch balance'));
      },
    );
  });
}
