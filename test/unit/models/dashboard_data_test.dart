import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/dashboard_data.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ActiveRun
  // ---------------------------------------------------------------------------

  group('ActiveRun.fromMap', () {
    test('parses all required fields correctly', () {
      final map = {
        'task_run_id': 'run-uuid-1',
        'task_id': 'task-uuid-1',
        'task_title': 'Implement login',
        'agent_role': 'Dev',
        'status': 'in_progress',
        'started_at': '2024-01-15T10:00:00.000Z',
        'cost_usd': 0.042,
      };

      final run = ActiveRun.fromMap(map);

      expect(run.taskRunId, 'run-uuid-1');
      expect(run.taskId, 'task-uuid-1');
      expect(run.taskTitle, 'Implement login');
      expect(run.agentRole, 'Dev');
      expect(run.status, 'in_progress');
      expect(run.startedAt, DateTime.parse('2024-01-15T10:00:00.000Z'));
      expect(run.costUsd, 0.042);
    });

    test('handles null costUsd gracefully', () {
      final map = {
        'task_run_id': 'run-uuid-2',
        'task_id': 'task-uuid-2',
        'task_title': 'Write tests',
        'agent_role': 'QA',
        'status': 'running',
        'started_at': '2024-01-15T11:00:00.000Z',
        'cost_usd': null,
      };

      final run = ActiveRun.fromMap(map);

      expect(run.costUsd, isNull);
    });

    test('parses startedAt as UTC DateTime', () {
      final map = {
        'task_run_id': 'run-uuid-3',
        'task_id': 'task-uuid-3',
        'task_title': 'Design API',
        'agent_role': 'BA',
        'status': 'running',
        'started_at': '2024-06-01T08:30:00.000Z',
        'cost_usd': 0.001,
      };

      final run = ActiveRun.fromMap(map);

      expect(run.startedAt.isUtc, isTrue);
      expect(run.startedAt.year, 2024);
      expect(run.startedAt.month, 6);
      expect(run.startedAt.day, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // TasksSummary
  // ---------------------------------------------------------------------------

  group('TasksSummary.fromMap', () {
    test('parses total and byStatus correctly', () {
      final map = {
        'total': 42,
        'by_status': {'draft': 5, 'in_progress': 12, 'done': 25},
      };

      final summary = TasksSummary.fromMap(map);

      expect(summary.total, 42);
      expect(summary.byStatus['draft'], 5);
      expect(summary.byStatus['in_progress'], 12);
      expect(summary.byStatus['done'], 25);
    });

    test('handles empty byStatus map', () {
      final map = {'total': 0, 'by_status': <String, dynamic>{}};

      final summary = TasksSummary.fromMap(map);

      expect(summary.total, 0);
      expect(summary.byStatus, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // RecentRun
  // ---------------------------------------------------------------------------

  group('RecentRun.fromMap', () {
    test('parses all fields including nullable ones', () {
      final map = {
        'task_run_id': 'run-uuid-10',
        'task_id': 'task-uuid-10',
        'task_title': 'Refactor auth',
        'agent_role': 'Lead',
        'status': 'done',
        'cost_usd': 0.18,
        'duration_ms': 4500,
        'completed_at': '2024-01-14T16:45:00.000Z',
      };

      final run = RecentRun.fromMap(map);

      expect(run.taskRunId, 'run-uuid-10');
      expect(run.taskId, 'task-uuid-10');
      expect(run.taskTitle, 'Refactor auth');
      expect(run.agentRole, 'Lead');
      expect(run.status, 'done');
      expect(run.costUsd, 0.18);
      expect(run.durationMs, 4500);
      expect(run.completedAt, DateTime.parse('2024-01-14T16:45:00.000Z'));
    });

    test('handles null durationMs and completedAt', () {
      final map = {
        'task_run_id': 'run-uuid-11',
        'task_id': 'task-uuid-11',
        'task_title': 'Review PR',
        'agent_role': 'Reviewer',
        'status': 'failed',
        'cost_usd': 0.05,
        'duration_ms': null,
        'completed_at': null,
      };

      final run = RecentRun.fromMap(map);

      expect(run.durationMs, isNull);
      expect(run.completedAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // MonthlyUsage
  // ---------------------------------------------------------------------------

  group('MonthlyUsage.fromMap', () {
    test('parses all fields correctly', () {
      final map = {
        'total_cost_usd': 12.50,
        'period': '2024-01',
        'run_count': 87,
      };

      final usage = MonthlyUsage.fromMap(map);

      expect(usage.totalCostUsd, 12.50);
      expect(usage.period, '2024-01');
      expect(usage.runCount, 87);
    });
  });

  // ---------------------------------------------------------------------------
  // DashboardData
  // ---------------------------------------------------------------------------

  group('DashboardData.fromMap', () {
    test('parses full dashboard payload correctly', () {
      final map = {
        'active_runs': [
          {
            'task_run_id': 'run-1',
            'task_id': 'task-1',
            'task_title': 'Build feature',
            'agent_role': 'Dev',
            'status': 'in_progress',
            'started_at': '2024-01-15T09:00:00.000Z',
            'cost_usd': 0.02,
          },
        ],
        'tasks_summary': {
          'total': 10,
          'by_status': {'draft': 3, 'done': 7},
        },
        'recent_runs': [
          {
            'task_run_id': 'run-99',
            'task_id': 'task-99',
            'task_title': 'Fix bug',
            'agent_role': 'QA',
            'status': 'done',
            'cost_usd': 0.01,
            'duration_ms': 2000,
            'completed_at': '2024-01-14T20:00:00.000Z',
          },
        ],
        'balance': 50.0,
        'monthly_usage': {
          'total_cost_usd': 5.75,
          'period': '2024-01',
          'run_count': 30,
        },
      };

      final data = DashboardData.fromMap(map);

      expect(data.activeRuns, hasLength(1));
      expect(data.activeRuns.first.taskRunId, 'run-1');
      expect(data.tasksSummary.total, 10);
      expect(data.recentRuns, hasLength(1));
      expect(data.recentRuns.first.taskRunId, 'run-99');
      expect(data.balance, 50.0);
      expect(data.monthlyUsage.period, '2024-01');
    });

    test('handles empty activeRuns and recentRuns lists', () {
      final map = {
        'active_runs': <dynamic>[],
        'tasks_summary': {'total': 0, 'by_status': <String, dynamic>{}},
        'recent_runs': <dynamic>[],
        'balance': 0.0,
        'monthly_usage': {
          'total_cost_usd': 0.0,
          'period': '2024-01',
          'run_count': 0,
        },
      };

      final data = DashboardData.fromMap(map);

      expect(data.activeRuns, isEmpty);
      expect(data.recentRuns, isEmpty);
      expect(data.balance, 0.0);
    });
  });
}
