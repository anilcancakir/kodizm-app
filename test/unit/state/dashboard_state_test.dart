import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/state/dashboard_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kApiPayload = {
  'active_runs': [
    {
      'conversation_id': 'run-uuid-001',
      'task_id': 'task-uuid-001',
      'task_title': 'Implement login screen',
      'agent_role': 'Dev',
      'status': 'in_progress',
      'started_at': '2024-06-01T09:00:00.000Z',
      'cost_usd': 0.42,
    },
  ],
  'tasks_summary': {
    'total': 20,
    'by_status': {'draft': 4, 'in_progress': 3, 'done': 13},
  },
  'recent_runs': [
    {
      'conversation_id': 'run-uuid-002',
      'task_id': 'task-uuid-002',
      'task_title': 'Review PR #12',
      'agent_role': 'Reviewer',
      'status': 'done',
      'cost_usd': 0.15,
      'duration_ms': 4500,
      'completed_at': '2024-05-31T17:30:00.000Z',
    },
  ],
  'balance': 19.99,
  'monthly_usage': {
    'total_cost_usd': 8.75,
    'period': '2024-06',
    'run_count': 31,
  },
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('DashboardState', () {
    late FakeNetworkDriver driver;
    late DashboardState state;

    setUp(() {
      driver = Http.fake();
      state = DashboardState();
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
    // 2. fetchDashboard — loading then success
    // -----------------------------------------------------------------------

    test('fetchDashboard sets loading then transitions to success', () async {
      driver.stub(
        '*/dashboard',
        MagicResponse(data: {'data': kApiPayload}, statusCode: 200),
      );

      expect(state.isEmpty, isTrue);

      final future = state.fetchDashboard('team-uuid-001');

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
        equals('/teams/team-uuid-001/dashboard'),
      );
    });

    // -----------------------------------------------------------------------
    // 3. fetchDashboard — error handling
    // -----------------------------------------------------------------------

    test('fetchDashboard sets error state on non-2xx response', () async {
      driver.stub(
        '*/dashboard',
        MagicResponse(data: {'message': 'Unauthorized'}, statusCode: 401),
      );

      final future = state.fetchDashboard('team-uuid-001');
      expect(state.isLoading, isTrue);

      await future;

      expect(state.isError, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.rxState, isNull);
      expect(state.rxStatus.message, equals('Unauthorized'));
    });

    // -----------------------------------------------------------------------
    // 4. fetchDashboard — parses DashboardData correctly
    // -----------------------------------------------------------------------

    test(
      'fetchDashboard parses DashboardData with all nested fields',
      () async {
        driver.stub(
          '*/dashboard',
          MagicResponse(data: {'data': kApiPayload}, statusCode: 200),
        );

        await state.fetchDashboard('team-uuid-001');

        final data = state.rxState!;

        // Top-level scalar.
        expect(data.balance, equals(19.99));

        // Active runs.
        expect(data.activeRuns.length, equals(1));
        expect(data.activeRuns.first.conversationId, equals('run-uuid-001'));
        expect(data.activeRuns.first.agentRole, equals('Dev'));
        expect(data.activeRuns.first.costUsd, equals(0.42));

        // Tasks summary — including nested byStatus map.
        expect(data.tasksSummary.total, equals(20));
        expect(data.tasksSummary.byStatus['draft'], equals(4));
        expect(data.tasksSummary.byStatus['in_progress'], equals(3));
        expect(data.tasksSummary.byStatus['done'], equals(13));

        // Recent runs.
        expect(data.recentRuns.length, equals(1));
        expect(data.recentRuns.first.conversationId, equals('run-uuid-002'));
        expect(data.recentRuns.first.status, equals('done'));
        expect(data.recentRuns.first.durationMs, equals(4500));

        // Monthly usage.
        expect(data.monthlyUsage.totalCostUsd, equals(8.75));
        expect(data.monthlyUsage.period, equals('2024-06'));
        expect(data.monthlyUsage.runCount, equals(31));
      },
    );

    // -----------------------------------------------------------------------
    // 5. fetchDashboard — error fallback message
    // -----------------------------------------------------------------------

    test(
      'fetchDashboard uses fallback message when response has no message',
      () async {
        driver.stub('*/dashboard', MagicResponse(data: null, statusCode: 500));

        await state.fetchDashboard('team-uuid-001');

        expect(state.isError, isTrue);
        expect(state.rxStatus.message, equals('Failed to fetch dashboard'));
      },
    );
  });
}
