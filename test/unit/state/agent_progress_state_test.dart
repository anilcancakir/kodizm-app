import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/state/agent_progress_state.dart';

/// Helper to create an [AgentProgressItem] with minimal required fields.
AgentProgressItem _makeItem({
  required String conversationId,
  String status = 'implementing',
  String message = 'Working…',
  String projectId = 'proj-1',
  String? projectName,
  int? percentage,
}) {
  return AgentProgressItem(
    conversationId: conversationId,
    projectId: projectId,
    projectName: projectName,
    status: status,
    message: message,
    percentage: percentage,
    occurredAt: DateTime.utc(2026, 4, 7),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // AgentProgressItem
  // -------------------------------------------------------------------------

  group('AgentProgressItem', () {
    test('fromMap parses all required fields', () {
      final map = {
        'conversation_id': 'conv-1',
        'project_id': 'proj-1',
        'project_name': 'My Project',
        'task_id': 'task-1',
        'agent_role_slug': 'dev',
        'agent_role_name': 'Developer',
        'status': 'in_progress',
        'message': 'Analyzing codebase…',
        'percentage': 40,
        'occurred_at': '2026-04-07T12:00:00.000Z',
      };

      final item = AgentProgressItem.fromMap(map);

      expect(item.conversationId, 'conv-1');
      expect(item.projectId, 'proj-1');
      expect(item.projectName, 'My Project');
      expect(item.taskId, 'task-1');
      expect(item.agentRoleSlug, 'dev');
      expect(item.agentRoleName, 'Developer');
      expect(item.status, 'in_progress');
      expect(item.message, 'Analyzing codebase…');
      expect(item.percentage, 40);
      expect(item.occurredAt.year, 2026);
      expect(item.occurredAt.month, 4);
    });

    test('fromMap handles missing optional fields gracefully', () {
      final map = {
        'conversation_id': 'conv-2',
        'project_id': 'proj-2',
        'status': 'completed',
        'message': 'Done.',
        'occurred_at': '2026-04-07T09:00:00.000Z',
      };

      final item = AgentProgressItem.fromMap(map);

      expect(item.projectName, isNull);
      expect(item.taskId, isNull);
      expect(item.agentRoleSlug, isNull);
      expect(item.agentRoleName, isNull);
      expect(item.percentage, isNull);
    });

    test('fromMap falls back to DateTime.now() for invalid occurred_at', () {
      final before = DateTime.now();
      final map = {
        'conversation_id': 'conv-3',
        'project_id': 'proj-3',
        'status': 'running',
        'message': 'Working…',
        'occurred_at': 'not-a-date',
      };

      final item = AgentProgressItem.fromMap(map);
      final after = DateTime.now();

      expect(
        item.occurredAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        item.occurredAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('fromMap parses percentage as num (handles double from JSON)', () {
      final map = {
        'conversation_id': 'conv-num',
        'project_id': 'proj-num',
        'status': 'running',
        'message': 'Working…',
        'percentage': 45.0, // JSON may deserialize as double
        'occurred_at': '2026-04-07T12:00:00.000Z',
      };

      final item = AgentProgressItem.fromMap(map);
      expect(item.percentage, 45);
      expect(item.percentage, isA<int>());
    });

    test('isBlocked returns true only when status is blocked', () {
      final blocked = _makeItem(conversationId: 'b', status: 'blocked');
      final running = _makeItem(conversationId: 'r', status: 'in_progress');

      expect(blocked.isBlocked, isTrue);
      expect(running.isBlocked, isFalse);
    });

    test(
      'fromMap defaults status to unknown and message to empty on missing keys',
      () {
        final map = <String, dynamic>{};

        final item = AgentProgressItem.fromMap(map);

        expect(item.conversationId, '');
        expect(item.projectId, '');
        expect(item.status, 'unknown');
        expect(item.message, '');
      },
    );
  });

  // -------------------------------------------------------------------------
  // AgentProgressState — pure state logic via addToastForTesting
  // -------------------------------------------------------------------------

  group('AgentProgressState', () {
    late AgentProgressState state;

    setUp(() {
      state = AgentProgressState();
    });

    tearDown(() {
      state.dispose();
    });

    test('initial state has empty activeToasts and null teamId', () {
      expect(state.activeToasts, isEmpty);
      expect(state.teamId, isNull);
    });

    test('activeToasts returns unmodifiable list', () {
      expect(
        () => state.activeToasts.add(_makeItem(conversationId: 'x')),
        throwsUnsupportedError,
      );
    });

    test('addToast adds item to activeToasts', () {
      state.addToastForTesting(_makeItem(conversationId: 'conv-1'));

      expect(state.activeToasts, hasLength(1));
      expect(state.activeToasts.first.conversationId, 'conv-1');
    });

    test('max 3 toasts — 4th evicts oldest non-blocked', () {
      state.addToastForTesting(_makeItem(conversationId: 'conv-1'));
      state.addToastForTesting(_makeItem(conversationId: 'conv-2'));
      state.addToastForTesting(_makeItem(conversationId: 'conv-3'));
      expect(state.activeToasts, hasLength(3));

      // 4th toast should evict conv-1 (oldest non-blocked).
      state.addToastForTesting(_makeItem(conversationId: 'conv-4'));
      expect(state.activeToasts, hasLength(3));

      final ids = state.activeToasts.map((t) => t.conversationId).toList();
      expect(ids, isNot(contains('conv-1')));
      expect(ids, contains('conv-4'));
    });

    test('max 3 — blocked toast is evicted last', () {
      // Fill with: blocked, non-blocked, non-blocked.
      state.addToastForTesting(
        _makeItem(conversationId: 'conv-blocked', status: 'blocked'),
      );
      state.addToastForTesting(_makeItem(conversationId: 'conv-2'));
      state.addToastForTesting(_makeItem(conversationId: 'conv-3'));

      // 4th toast should evict conv-2 (oldest non-blocked), NOT conv-blocked.
      state.addToastForTesting(_makeItem(conversationId: 'conv-4'));

      final ids = state.activeToasts.map((t) => t.conversationId).toList();
      expect(ids, contains('conv-blocked'));
      expect(ids, isNot(contains('conv-2')));
      expect(ids, contains('conv-4'));
    });

    test('duplicate conversationId updates existing toast in-place', () {
      state.addToastForTesting(
        _makeItem(conversationId: 'conv-1', message: 'Step 1'),
      );
      state.addToastForTesting(
        _makeItem(conversationId: 'conv-2', message: 'Step 2'),
      );
      expect(state.activeToasts, hasLength(2));

      // Update conv-1 with new message.
      state.addToastForTesting(
        _makeItem(conversationId: 'conv-1', message: 'Step 1 updated'),
      );

      // Should still be 2 toasts, not 3.
      expect(state.activeToasts, hasLength(2));
      final updated = state.activeToasts.firstWhere(
        (t) => t.conversationId == 'conv-1',
      );
      expect(updated.message, 'Step 1 updated');
    });

    test('dismissToast removes specific toast', () {
      state.addToastForTesting(_makeItem(conversationId: 'conv-1'));
      state.addToastForTesting(_makeItem(conversationId: 'conv-2'));
      state.addToastForTesting(_makeItem(conversationId: 'conv-3'));

      state.dismissToast('conv-2');

      expect(state.activeToasts, hasLength(2));
      final ids = state.activeToasts.map((t) => t.conversationId).toList();
      expect(ids, isNot(contains('conv-2')));
      expect(ids, contains('conv-1'));
      expect(ids, contains('conv-3'));
    });

    test('dismissToast on non-existent id does not crash', () {
      state.addToastForTesting(_makeItem(conversationId: 'conv-1'));
      expect(() => state.dismissToast('nonexistent'), returnsNormally);
      expect(state.activeToasts, hasLength(1));
    });

    test('switchTeam clears all toasts', () {
      state.addToastForTesting(_makeItem(conversationId: 'conv-1'));
      state.addToastForTesting(
        _makeItem(conversationId: 'conv-2', status: 'blocked'),
      );
      expect(state.activeToasts, hasLength(2));

      // switchTeam calls unsubscribe() which clears toasts,
      // then subscribeToTeam() which needs Echo — skip the subscribe.
      // Instead test unsubscribe directly which is what clears state.
      state.unsubscribe();

      expect(state.activeToasts, isEmpty);
      expect(state.teamId, isNull);
    });
  });
}
