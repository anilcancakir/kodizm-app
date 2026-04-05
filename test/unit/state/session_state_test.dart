import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/session_state.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kSession = {
  'id': 'session-uuid-001',
  'type': 'autonomous',
  'phase': 'executing',
  'model': 'claude-sonnet-4-6',
  'total_cost_usd': '0.012600',
  'total_input_tokens': 4200,
  'total_output_tokens': 800,
  'total_cache_read_tokens': 0,
  'total_cache_creation_tokens': 0,
  'warm_until': null,
  'started_at': '2025-06-10T08:01:00.000Z',
  'completed_at': null,
  'created_at': '2025-06-10T08:00:55.000Z',
  'updated_at': '2025-06-10T08:01:00.000Z',
  'usage_records': [],
  'shares': [],
};

const Map<String, dynamic> kSession2 = {
  'id': 'session-uuid-002',
  'type': 'interactive',
  'phase': 'warm',
  'model': 'claude-opus-4-6',
  'total_cost_usd': '0.025000',
  'total_input_tokens': 9000,
  'total_output_tokens': 1500,
  'total_cache_read_tokens': 200,
  'total_cache_creation_tokens': 100,
  'warm_until': '2025-06-10T09:00:00.000Z',
  'started_at': '2025-06-10T07:30:00.000Z',
  'completed_at': '2025-06-10T07:45:00.000Z',
  'created_at': '2025-06-10T07:29:55.000Z',
  'updated_at': '2025-06-10T07:45:00.000Z',
  'usage_records': [],
  'shares': [],
};

const Map<String, dynamic> kUsageRecord = {
  'id': 'usage-uuid-001',
  'session_id': 'session-uuid-001',
  'turn_number': 1,
  'model': 'claude-sonnet-4-6',
  'input_tokens': 4200,
  'output_tokens': 800,
  'cache_read_tokens': 0,
  'cache_creation_tokens': 0,
  'cost_usd': '0.012600',
  'is_subagent': false,
  'subagent_type': null,
  'created_at': '2025-06-10T08:01:30.000Z',
};

const Map<String, dynamic> kShare = {
  'id': 'share-uuid-001',
  'session_id': 'session-uuid-001',
  'shareable_type': 'App\\Models\\Project',
  'shareable_id': 'project-uuid-001',
  'permission': 'read',
  'shared_by': 'user-uuid-001',
  'created_at': '2025-06-10T08:05:00.000Z',
  'updated_at': '2025-06-10T08:05:00.000Z',
};

const Map<String, dynamic> kStreamEventFixture = {
  'id': 'evt-uuid-001',
  'type': 'assistant_delta',
  'data': {'delta': 'Hello'},
  'content_text': 'Hello',
  'file_path': null,
  'is_question': false,
  'occurred_at': '2025-06-10T08:01:05.000Z',
  'session_id': 'session-uuid-001',
  'subagent_id': null,
  'parent_event_id': null,
  'model': 'claude-sonnet-4-6',
  'turn_number': 1,
  'metadata': null,
};

// ---------------------------------------------------------------------------
// Fake WebSocket client
// ---------------------------------------------------------------------------

/// Injectable WebSocket client for testing [SessionState] WS behaviour
/// without a real connection. Records subscribe/unsubscribe calls.
class _FakeSessionWebSocket implements SessionWebSocket {
  final List<String> subscribed = [];
  final List<String> unsubscribed = [];
  void Function(WebSocketEvent)? lastHandler;

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribed.add(channel);
    lastHandler = onEvent;
  }

  @override
  void unsubscribe(String channel) {
    unsubscribed.add(channel);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  group('SessionState', () {
    late FakeNetworkDriver driver;
    late _FakeSessionWebSocket ws;
    late SessionState state;

    setUp(() {
      driver = Http.fake();
      ws = _FakeSessionWebSocket();
      state = SessionState(webSocket: ws);
    });

    tearDown(() {
      state.dispose();
    });

    // -----------------------------------------------------------------------
    // 1. Initial state is empty
    // -----------------------------------------------------------------------

    test('initial state has empty collections and null values', () {
      expect(state.sessions, isEmpty);
      expect(state.currentSession, isNull);
      expect(state.events, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    // -----------------------------------------------------------------------
    // 2. loadSessions — success with list of sessions
    // -----------------------------------------------------------------------

    test('loadSessions parses sessions list from response', () async {
      driver.stub(
        '*/sessions*',
        Http.response({
          'data': [kSession, kSession2],
        }),
      );

      await state.loadSessions();

      expect(state.sessions.length, equals(2));
      expect(state.sessions[0].id, equals('session-uuid-001'));
      expect(state.sessions[0].type, equals('autonomous'));
      expect(state.sessions[1].id, equals('session-uuid-002'));

      driver.assertSentCount(1);
      driver.assertSent((r) => r.method == 'GET' && r.url == '/v1/sessions');
    });

    // -----------------------------------------------------------------------
    // 3. loadSessions — with filters passed as query params
    // -----------------------------------------------------------------------

    test(
      'loadSessions sends projectId, type, and phase as query params',
      () async {
        driver.stub(
          '*/sessions*',
          Http.response({'data': <Map<String, dynamic>>[]}),
        );

        await state.loadSessions(
          projectId: 'proj-uuid-001',
          type: 'autonomous',
          phase: 'executing',
        );

        final request = driver.recorded.first.$1;
        expect(request.queryParameters?['project_id'], equals('proj-uuid-001'));
        expect(request.queryParameters?['type'], equals('autonomous'));
        expect(request.queryParameters?['phase'], equals('executing'));
      },
    );

    // -----------------------------------------------------------------------
    // 4. loadSessions — null filters are omitted from query
    // -----------------------------------------------------------------------

    test('loadSessions omits null filters from query params', () async {
      driver.stub(
        '*/sessions*',
        Http.response({'data': <Map<String, dynamic>>[]}),
      );

      await state.loadSessions(projectId: 'proj-uuid-001');

      final request = driver.recorded.first.$1;
      expect(request.queryParameters?['project_id'], equals('proj-uuid-001'));
      expect(request.queryParameters?.containsKey('type'), isFalse);
      expect(request.queryParameters?.containsKey('phase'), isFalse);
    });

    // -----------------------------------------------------------------------
    // 5. loadSessions — error sets empty list
    // -----------------------------------------------------------------------

    test('loadSessions sets empty list on error', () async {
      driver.stub(
        '*/sessions*',
        Http.response({'message': 'Internal Server Error'}, 500),
      );

      await state.loadSessions();

      expect(state.sessions, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 6. loadSession — success populates currentSession with relations
    // -----------------------------------------------------------------------

    test('loadSession parses session with usage records and shares', () async {
      final sessionWithRelations = {
        ...kSession,
        'usage_records': [kUsageRecord],
        'shares': [kShare],
      };

      driver.stub(
        '*/sessions/*',
        Http.response({'data': sessionWithRelations}),
      );

      await state.loadSession('session-uuid-001');

      expect(state.currentSession, isNotNull);
      expect(state.currentSession!.id, equals('session-uuid-001'));
      expect(state.currentSession!.usageRecords.length, equals(1));
      expect(state.currentSession!.shares.length, equals(1));
      expect(
        state.currentSession!.usageRecords.first.costUsd,
        closeTo(0.0126, 0.0001),
      );

      driver.assertSent(
        (r) => r.url == '/v1/sessions/session-uuid-001' && r.method == 'GET',
      );
    });

    // -----------------------------------------------------------------------
    // 7. loadSession — error sets currentSession to null
    // -----------------------------------------------------------------------

    test('loadSession sets currentSession to null on error', () async {
      driver.stub('*/sessions/*', Http.response({'message': 'Not found'}, 404));

      await state.loadSession('session-uuid-999');

      expect(state.currentSession, isNull);
    });

    // -----------------------------------------------------------------------
    // 8. loadEvents — success populates events list
    // -----------------------------------------------------------------------

    test('loadEvents populates events from response', () async {
      driver.stub(
        '*/events*',
        Http.response({
          'data': [kStreamEventFixture],
        }),
      );

      await state.loadEvents('session-uuid-001');

      expect(state.events.length, equals(1));
      expect(state.events.first.id, equals('evt-uuid-001'));
      expect(state.events.first.contentText, equals('Hello'));

      driver.assertSent((r) => r.url == '/v1/sessions/session-uuid-001/events');
    });

    // -----------------------------------------------------------------------
    // 9. loadEvents — with type filter
    // -----------------------------------------------------------------------

    test('loadEvents passes type as query param', () async {
      driver.stub(
        '*/events*',
        Http.response({'data': <Map<String, dynamic>>[]}),
      );

      await state.loadEvents('session-uuid-001', type: 'assistant_delta');

      final request = driver.recorded.first.$1;
      expect(request.queryParameters?['type'], equals('assistant_delta'));
    });

    // -----------------------------------------------------------------------
    // 10. loadEvents — error sets empty list
    // -----------------------------------------------------------------------

    test('loadEvents sets empty list on error', () async {
      driver.stub('*/events*', Http.response({'message': 'Server error'}, 500));

      await state.loadEvents('session-uuid-001');

      expect(state.events, isEmpty);
    });

    // -----------------------------------------------------------------------
    // 11. share — success returns true
    // -----------------------------------------------------------------------

    test('share posts to correct URL and returns true on success', () async {
      driver.stub('*/share', Http.response({'data': kShare}, 201));

      final result = await state.share(
        'session-uuid-001',
        'App\\Models\\Project',
        'project-uuid-001',
        'read',
      );

      expect(result, isTrue);

      final request = driver.recorded.first.$1;
      expect(request.method, equals('POST'));
      expect(request.url, equals('/v1/sessions/session-uuid-001/share'));
      expect(
        (request.data as Map<String, dynamic>)['shareable_type'],
        equals('App\\Models\\Project'),
      );
      expect(
        (request.data as Map<String, dynamic>)['shareable_id'],
        equals('project-uuid-001'),
      );
      expect(
        (request.data as Map<String, dynamic>)['permission'],
        equals('read'),
      );
    });

    // -----------------------------------------------------------------------
    // 12. share — error returns false
    // -----------------------------------------------------------------------

    test('share returns false on error', () async {
      driver.stub('*/share', Http.response({'message': 'Forbidden'}, 403));

      final result = await state.share(
        'session-uuid-001',
        'App\\Models\\Project',
        'project-uuid-001',
        'write',
      );

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 13. unshare — success returns true
    // -----------------------------------------------------------------------

    test('unshare sends DELETE to correct URL and returns true', () async {
      driver.stub('*/shares/*', Http.response(null, 204));

      final result = await state.unshare('session-uuid-001', 'share-uuid-001');

      expect(result, isTrue);

      final request = driver.recorded.first.$1;
      expect(request.method, equals('DELETE'));
      expect(
        request.url,
        equals('/v1/sessions/session-uuid-001/shares/share-uuid-001'),
      );
    });

    // -----------------------------------------------------------------------
    // 14. unshare — error returns false
    // -----------------------------------------------------------------------

    test('unshare returns false on error', () async {
      driver.stub('*/shares/*', Http.response({'message': 'Not found'}, 404));

      final result = await state.unshare('session-uuid-001', 'share-uuid-999');

      expect(result, isFalse);
    });

    // -----------------------------------------------------------------------
    // 15. reset — clears all state fields
    // -----------------------------------------------------------------------

    test(
      'reset clears sessions, currentSession, events, and filters',
      () async {
        driver.stub(
          '*/sessions*',
          Http.response({
            'data': [kSession],
          }),
        );

        await state.loadSessions(projectId: 'proj-001', type: 'autonomous');

        expect(state.sessions, isNotEmpty);

        state.reset();

        expect(state.sessions, isEmpty);
        expect(state.currentSession, isNull);
        expect(state.events, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
      },
    );

    // -----------------------------------------------------------------------
    // WebSocket event handler tests
    // -----------------------------------------------------------------------

    group('WebSocket event handlers', () {
      setUp(() async {
        driver.stub('*/sessions/*', Http.response({'data': kSession}));
        await state.loadSession('session-uuid-001');
      });

      // ---------------------------------------------------------------------
      // 16. .session.status updates currentSession.phase
      // ---------------------------------------------------------------------

      test(
        '.session.status event updates currentSession phase via copyWith',
        () {
          expect(state.currentSession!.phase, equals('executing'));

          final wsEvent = WebSocketEvent(
            id: 'ws:status:1',
            channel: 'private-session.session-uuid-001',
            eventName: '.session.status',
            data: {'phase': 'warm'},
            receivedAt: DateTime.now(),
          );

          state.handleWebSocketEvent(wsEvent);

          expect(state.currentSession!.phase, equals('warm'));
        },
      );

      // ---------------------------------------------------------------------
      // 17. .session.status with unknown phase is ignored if null
      // ---------------------------------------------------------------------

      test('.session.status without phase field leaves phase unchanged', () {
        final originalPhase = state.currentSession!.phase;

        final wsEvent = WebSocketEvent(
          id: 'ws:status:2',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.status',
          data: {'other_field': 'value'},
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent);

        expect(state.currentSession!.phase, equals(originalPhase));
      });

      // ---------------------------------------------------------------------
      // 18. .session.cost updates cost fields and appends usage record
      // ---------------------------------------------------------------------

      test('.session.cost updates cost fields and appends usage record', () {
        expect(state.currentSession!.totalCostUsd, closeTo(0.0126, 0.0001));
        expect(state.currentSession!.usageRecords, isEmpty);

        final wsEvent = WebSocketEvent(
          id: 'ws:cost:1',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.cost',
          data: {
            'total_cost_usd': '0.025000',
            'total_input_tokens': 8400,
            'total_output_tokens': 1600,
            'total_cache_read_tokens': 0,
            'total_cache_creation_tokens': 0,
            'usage_record': kUsageRecord,
          },
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent);

        expect(state.currentSession!.totalCostUsd, closeTo(0.025, 0.0001));
        expect(state.currentSession!.totalInputTokens, equals(8400));
        expect(state.currentSession!.totalOutputTokens, equals(1600));
        expect(state.currentSession!.usageRecords.length, equals(1));
        expect(
          state.currentSession!.usageRecords.first.id,
          equals('usage-uuid-001'),
        );
      });

      // ---------------------------------------------------------------------
      // 19. .session.cost without usage_record leaves usageRecords unchanged
      // ---------------------------------------------------------------------

      test('.session.cost without usage_record only updates cost totals', () {
        final wsEvent = WebSocketEvent(
          id: 'ws:cost:2',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.cost',
          data: {
            'total_cost_usd': '0.030000',
            'total_input_tokens': 10000,
            'total_output_tokens': 2000,
            'total_cache_read_tokens': 100,
            'total_cache_creation_tokens': 50,
          },
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent);

        expect(state.currentSession!.totalCostUsd, closeTo(0.030, 0.0001));
        expect(state.currentSession!.usageRecords, isEmpty);
      });

      // ---------------------------------------------------------------------
      // 20. .session.stream appends StreamEvent to events
      // ---------------------------------------------------------------------

      test('.session.stream appends StreamEvent to events list', () {
        expect(state.events, isEmpty);

        final wsEvent = WebSocketEvent(
          id: 'ws:stream:1',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.stream',
          data: {
            'id': 'evt-ws-001',
            'type': 'assistant_delta',
            'data': {'delta': 'Hello world'},
            'content_text': 'Hello world',
            'file_path': null,
            'is_question': false,
            'occurred_at': '2025-06-10T08:02:00.000Z',
            'session_id': 'session-uuid-001',
            'subagent_id': null,
            'parent_event_id': null,
            'model': 'claude-sonnet-4-6',
            'turn_number': 1,
            'metadata': null,
          },
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent);

        expect(state.events.length, equals(1));
        expect(state.events.first.id, equals('evt-ws-001'));
        expect(state.events.first.contentText, equals('Hello world'));
        expect(state.events.first.type, equals('assistant_delta'));
      });

      // ---------------------------------------------------------------------
      // 21. .session.question stores pending question
      // ---------------------------------------------------------------------

      test('.session.question stores pending question', () {
        expect(state.pendingQuestion, isNull);

        final wsEvent = WebSocketEvent(
          id: 'ws:question:1',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.question',
          data: {
            'question_id': 'question-uuid-ws-001',
            'question_text': 'Should I proceed with the refactor?',
          },
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent);

        expect(state.pendingQuestion, isNotNull);
        expect(
          state.pendingQuestion!['question_id'],
          equals('question-uuid-ws-001'),
        );
        expect(
          state.pendingQuestion!['question_text'],
          equals('Should I proceed with the refactor?'),
        );
      });

      // ---------------------------------------------------------------------
      // 22. .session.question stores new question overwriting previous
      // ---------------------------------------------------------------------

      test('.session.question overwrites previous pending question', () {
        final wsEvent1 = WebSocketEvent(
          id: 'ws:question:overwrite:1',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.question',
          data: {'question_id': 'q-001', 'question_text': 'First question?'},
          receivedAt: DateTime.now(),
        );
        final wsEvent2 = WebSocketEvent(
          id: 'ws:question:overwrite:2',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.question',
          data: {'question_id': 'q-002', 'question_text': 'Second question?'},
          receivedAt: DateTime.now(),
        );

        state.handleWebSocketEvent(wsEvent1);
        state.handleWebSocketEvent(wsEvent2);

        expect(state.pendingQuestion!['question_id'], equals('q-002'));
      });

      // ---------------------------------------------------------------------
      // 23. unknown event name is ignored gracefully
      // ---------------------------------------------------------------------

      test('unknown event name is ignored without throwing', () {
        expect(
          () => state.handleWebSocketEvent(
            WebSocketEvent(
              id: 'ws:unknown:1',
              channel: 'private-session.session-uuid-001',
              eventName: '.session.unknown',
              data: {},
              receivedAt: DateTime.now(),
            ),
          ),
          returnsNormally,
        );

        expect(state.events, isEmpty);
        expect(state.currentSession!.phase, equals('executing'));
      });
    });

    // -----------------------------------------------------------------------
    // 24. subscribeToSession sets active channel name
    // -----------------------------------------------------------------------

    test('subscribeToSession registers correct channel name', () {
      state.subscribeToSession('session-uuid-001');

      expect(state.activeChannel, equals('private-session.session-uuid-001'));
    });

    // -----------------------------------------------------------------------
    // 25. unsubscribeFromSession clears active channel
    // -----------------------------------------------------------------------

    test('unsubscribeFromSession clears active channel', () {
      state.subscribeToSession('session-uuid-001');
      expect(state.activeChannel, isNotNull);

      state.unsubscribeFromSession();

      expect(state.activeChannel, isNull);
    });

    // -----------------------------------------------------------------------
    // 26. reset also clears activeChannel and pendingQuestion
    // -----------------------------------------------------------------------

    test('reset clears activeChannel and pendingQuestion', () async {
      driver.stub('*/sessions/*', Http.response({'data': kSession}));
      await state.loadSession('session-uuid-001');

      state.subscribeToSession('session-uuid-001');
      state.handleWebSocketEvent(
        WebSocketEvent(
          id: 'ws:q:reset',
          channel: 'private-session.session-uuid-001',
          eventName: '.session.question',
          data: {'question_id': 'q-reset', 'question_text': 'Reset?'},
          receivedAt: DateTime.now(),
        ),
      );

      expect(state.activeChannel, isNotNull);
      expect(state.pendingQuestion, isNotNull);

      state.reset();

      expect(state.activeChannel, isNull);
      expect(state.pendingQuestion, isNull);
    });
  });
}
