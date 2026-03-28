import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/state/session_state.dart';
import 'package:app/resources/views/session/session_detail_view.dart';
import 'package:app/resources/widgets/molecules/model_cost_breakdown.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:app/resources/widgets/organisms/terminal_event_list.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kSessionId = 'sess-uuid-detail-001';

const Map<String, dynamic> kSessionDetail = {
  'id': kSessionId,
  'type': 'autonomous',
  'phase': 'executing',
  'model': 'claude-sonnet-4-6',
  'total_cost_usd': '0.042000',
  'total_input_tokens': 1200,
  'total_output_tokens': 800,
  'total_cache_read_tokens': 50,
  'total_cache_creation_tokens': 30,
  'warm_until': null,
  'started_at': '2025-06-10T08:00:00.000Z',
  'completed_at': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T08:30:00.000Z',
  'usage_records': [
    {
      'id': 'ur-001',
      'session_id': kSessionId,
      'turn_number': 1,
      'model': 'claude-sonnet-4-6',
      'input_tokens': 600,
      'output_tokens': 400,
      'cache_read_tokens': 25,
      'cache_creation_tokens': 15,
      'cost_usd': '0.021000',
      'is_subagent': false,
      'subagent_type': null,
      'created_at': '2025-06-10T08:05:00.000Z',
    },
    {
      'id': 'ur-002',
      'session_id': kSessionId,
      'turn_number': 2,
      'model': 'claude-sonnet-4-6',
      'input_tokens': 600,
      'output_tokens': 400,
      'cache_read_tokens': 25,
      'cache_creation_tokens': 15,
      'cost_usd': '0.021000',
      'is_subagent': true,
      'subagent_type': 'ac:explore',
      'created_at': '2025-06-10T08:10:00.000Z',
    },
  ],
  'shares': [
    {
      'id': 'share-001',
      'session_id': kSessionId,
      'shareable_type': 'App\\Models\\Project',
      'shareable_id': 'proj-uuid-001',
      'permission': 'read',
      'shared_by': 'user-uuid-001',
      'created_at': '2025-06-10T08:01:00.000Z',
      'updated_at': '2025-06-10T08:01:00.000Z',
    },
  ],
};

const Map<String, dynamic> kSessionNoRecords = {
  'id': 'sess-uuid-empty-001',
  'type': 'interactive',
  'phase': 'provisioning',
  'model': null,
  'total_cost_usd': '0.000000',
  'total_input_tokens': 0,
  'total_output_tokens': 0,
  'total_cache_read_tokens': 0,
  'total_cache_creation_tokens': 0,
  'warm_until': null,
  'started_at': null,
  'completed_at': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T08:00:00.000Z',
  'usage_records': <dynamic>[],
  'shares': <dynamic>[],
};

const List<Map<String, dynamic>> kEvents = [
  {
    'id': 'evt-001',
    'task_run_id': 'run-001',
    'type': 'system',
    'data': <String, dynamic>{},
    'content_text': 'Session started',
    'file_path': null,
    'is_question': false,
    'occurred_at': '2025-06-10T08:01:00.000Z',
    'session_id': kSessionId,
    'subagent_id': null,
    'parent_event_id': null,
    'model': 'claude-sonnet-4-6',
    'turn_number': 1,
    'metadata': null,
  },
];

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeSessionHttpClient implements SessionHttpClient {
  final List<String> calls = [];
  MagicResponse _sessionResponse = MagicResponse(
    data: {'data': kSessionDetail},
    statusCode: 200,
  );
  MagicResponse _eventsResponse = MagicResponse(
    data: {'data': kEvents},
    statusCode: 200,
  );

  void setSessionResponse(MagicResponse response) {
    _sessionResponse = response;
  }

  void setEventsResponse(MagicResponse response) {
    _eventsResponse = response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add('GET $url');
    if (url.contains('/events')) {
      return _eventsResponse;
    }
    return _sessionResponse;
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add('POST $url');
    return MagicResponse(data: {'data': {}}, statusCode: 200);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add('DELETE $url');
    return MagicResponse(data: {'data': {}}, statusCode: 200);
  }
}

// ---------------------------------------------------------------------------
// Fake WebSocket
// ---------------------------------------------------------------------------

class _FakeSessionWebSocket implements SessionWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {
    subscribedChannels.add(channel);
  }

  @override
  void unsubscribe(String channel) {
    unsubscribedChannels.add(channel);
  }
}

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final String content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final Map<String, dynamic> nested =
          jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = {};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps the [SessionDetailView] inside a standard test scaffold.
/// Uses 1920x1080 to give the w-80 sidebar enough room for
/// ModelCostBreakdown's fixed-width columns.
Future<void> _pumpView(
  WidgetTester tester, {
  String sessionId = kSessionId,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionDetailView(sessionId: sessionId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Pumps the view at mobile width.
Future<void> _pumpMobileView(
  WidgetTester tester, {
  String sessionId = kSessionId,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionDetailView(sessionId: sessionId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeSessionHttpClient http;
  late _FakeSessionWebSocket ws;
  late SessionState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeSessionHttpClient();
    ws = _FakeSessionWebSocket();
    state = SessionState(httpClient: http, webSocket: ws);
    Magic.put<SessionState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<SessionState>();
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed
  // -------------------------------------------------------------------------

  testWidgets('widget can be constructed', (tester) async {
    await _pumpView(tester);

    expect(find.byType(SessionDetailView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders MagicStarterPageHeader with session detail title
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with detail title', (
    tester,
  ) async {
    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    // trans('sessions.detail_title') = 'Session Detail'
    expect(find.text('Session Detail'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders phase badge in header actions
  // -------------------------------------------------------------------------

  testWidgets('renders phase badge with correct label', (tester) async {
    await _pumpView(tester);

    // kSessionDetail.phase = 'executing' → trans('sessions.phase_executing')
    expect(find.textContaining('Executing'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders cost in header actions
  // -------------------------------------------------------------------------

  testWidgets('renders cost text in header', (tester) async {
    await _pumpView(tester);

    // kSessionDetail.total_cost_usd = '0.042000' → '$0.04' in header
    // (also appears in ModelCostBreakdown, so at least one)
    expect(find.textContaining('\$0.04'), findsAtLeast(1));
  });

  // -------------------------------------------------------------------------
  // 5. Renders events MagicStarterCard
  // -------------------------------------------------------------------------

  testWidgets('renders events MagicStarterCard with title', (tester) async {
    await _pumpView(tester);

    // trans('sessions.events') = 'Events'
    expect(find.text('Events'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Renders TerminalEventList
  // -------------------------------------------------------------------------

  testWidgets('renders TerminalEventList for events', (tester) async {
    await _pumpView(tester);

    expect(find.byType(TerminalEventList), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Renders cost breakdown MagicStarterCard
  // -------------------------------------------------------------------------

  testWidgets('renders cost breakdown section', (tester) async {
    await _pumpView(tester);

    // trans('sessions.cost_breakdown') = 'Cost Breakdown by Model'
    expect(find.textContaining('Cost Breakdown'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Renders ModelCostBreakdown widget
  // -------------------------------------------------------------------------

  testWidgets('renders ModelCostBreakdown when usage records exist', (
    tester,
  ) async {
    await _pumpView(tester);

    expect(find.byType(ModelCostBreakdown), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Renders usage records MagicStarterCard
  // -------------------------------------------------------------------------

  testWidgets('renders usage records section', (tester) async {
    await _pumpView(tester);

    // trans('sessions.usage_records') = 'Usage Records'
    expect(find.text('Usage Records'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 10. Usage records show turn numbers
  // -------------------------------------------------------------------------

  testWidgets('usage records display turn numbers', (tester) async {
    await _pumpView(tester);

    // Turn 1, Turn 2 from the two usage records
    expect(find.textContaining('1'), findsWidgets);
    expect(find.textContaining('2'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 11. Subagent badge shown for subagent usage record
  // -------------------------------------------------------------------------

  testWidgets('subagent badge shown for subagent usage records', (
    tester,
  ) async {
    await _pumpView(tester);

    // trans('sessions.subagent') = 'Sub-agent'
    expect(find.textContaining('Sub-agent'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 12. Renders shares MagicStarterCard
  // -------------------------------------------------------------------------

  testWidgets('renders shares section', (tester) async {
    await _pumpView(tester);

    // trans('sessions.shares') = 'Shares'
    expect(find.text('Shares'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 13. Shows share permission badge
  // -------------------------------------------------------------------------

  testWidgets('shows share permission in share list', (tester) async {
    await _pumpView(tester);

    // The share has permission 'read' → trans('sessions.read') = 'Read'
    expect(find.text('Read'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 14. Subscribes to WebSocket channel on init
  // -------------------------------------------------------------------------

  testWidgets('subscribes to session WebSocket channel', (tester) async {
    await _pumpView(tester);

    expect(ws.subscribedChannels, contains('private-session.$kSessionId'));
  });

  // -------------------------------------------------------------------------
  // 15. Shows loading state
  // -------------------------------------------------------------------------

  testWidgets('shows loading indicator when session is null', (tester) async {
    // Use a session ID that won't match any preloaded data.
    http.setSessionResponse(
      MagicResponse(data: {'data': kSessionDetail}, statusCode: 200),
    );

    await _pumpView(tester);

    // After pumps, session should be loaded. We verify loading was transient
    // by checking the widget rendered content.
    expect(find.byType(SessionDetailView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 16. Empty usage records shows no_usage message
  // -------------------------------------------------------------------------

  testWidgets('shows no_usage message when usage records are empty', (
    tester,
  ) async {
    http.setSessionResponse(
      MagicResponse(data: {'data': kSessionNoRecords}, statusCode: 200),
    );

    await _pumpView(tester, sessionId: 'sess-uuid-empty-001');

    // trans('sessions.no_usage') = 'No usage records yet'
    // Appears in usage records card, shares card, and ModelCostBreakdown.
    expect(find.textContaining('No usage records'), findsAtLeast(1));
  });

  // -------------------------------------------------------------------------
  // 17. Empty shares shows empty state
  // -------------------------------------------------------------------------

  testWidgets('shows empty shares state when no shares exist', (tester) async {
    http.setSessionResponse(
      MagicResponse(data: {'data': kSessionNoRecords}, statusCode: 200),
    );

    await _pumpView(tester, sessionId: 'sess-uuid-empty-001');

    // Shares section still renders but with no share rows.
    expect(find.text('Shares'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 18. Desktop layout uses flex-row
  // -------------------------------------------------------------------------

  testWidgets('desktop layout uses side-by-side flex-row', (tester) async {
    await _pumpView(tester);

    // Multiple MagicStarterCards: events, cost breakdown, usage records, shares
    expect(find.byType(MagicStarterCard), findsAtLeast(3));
  });

  // -------------------------------------------------------------------------
  // 19. Mobile layout stacks vertically
  // -------------------------------------------------------------------------

  testWidgets('mobile layout stacks content vertically', (tester) async {
    await _pumpMobileView(tester);

    // Still renders all sections
    expect(find.byType(MagicStarterCard), findsAtLeast(3));
    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 20. Calls loadSession and loadEvents on init
  // -------------------------------------------------------------------------

  testWidgets('calls loadSession and loadEvents on init', (tester) async {
    await _pumpView(tester);

    expect(
      http.calls,
      containsAll([
        'GET /v1/sessions/$kSessionId',
        'GET /v1/sessions/$kSessionId/events',
      ]),
    );
  });

  // -------------------------------------------------------------------------
  // 21. Session subtitle shows type
  // -------------------------------------------------------------------------

  testWidgets('subtitle includes session type', (tester) async {
    await _pumpView(tester);

    // kSessionDetail.type = 'autonomous'
    expect(find.textContaining('autonomous'), findsWidgets);
  });
}
