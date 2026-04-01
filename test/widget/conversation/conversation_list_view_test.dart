import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/conversation_list_state.dart';
import 'package:app/resources/views/conversation/conversation_list_view.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kConversation1 = {
  'id': 'conv-uuid-001',
  'project_id': 'proj-uuid-001',
  'user': {'id': 'user-uuid-001', 'name': 'Alice Smith'},
  'agent_role': {
    'id': 'role-uuid-001',
    'name': 'Business Analyst',
    'slug': 'ba',
  },
  'title': 'Project Kickoff',
  'status': 'active',
  'model': 'claude-sonnet-4-6',
  'total_cost_usd': '0.042',
  'total_input_tokens': 1200,
  'total_output_tokens': 800,
  'messages_count': 5,
  'last_activity_at': '2025-06-10T08:30:00.000Z',
  'started_at': '2025-06-10T08:00:00.000Z',
  'completed_at': null,
  'created_at': '2025-06-10T08:00:00.000Z',
  'updated_at': '2025-06-10T08:30:00.000Z',
};

const Map<String, dynamic> kConversation2 = {
  'id': 'conv-uuid-002',
  'project_id': 'proj-uuid-001',
  'user': {'id': 'user-uuid-001', 'name': 'Alice Smith'},
  'agent_role': {
    'id': 'role-uuid-002',
    'name': 'Lead Developer',
    'slug': 'lead',
  },
  'title': null,
  'status': 'completed',
  'model': null,
  'total_cost_usd': '0.180',
  'total_input_tokens': 4500,
  'total_output_tokens': 3200,
  'messages_count': 12,
  'last_activity_at': '2025-06-10T10:00:00.000Z',
  'started_at': '2025-06-10T09:00:00.000Z',
  'completed_at': '2025-06-10T10:00:00.000Z',
  'created_at': '2025-06-10T09:00:00.000Z',
  'updated_at': '2025-06-10T10:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeConversationHttpClient implements ConversationListHttpClient {
  final List<String> calls = [];
  late MagicResponse Function(String url) _responder;

  void whenAny(MagicResponse Function(String url) responder) {
    _responder = responder;
  }

  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add('GET $url');
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add('POST $url');
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add('DELETE $url');
    return _responder(url);
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

/// Pumps a [ConversationListView] inside the standard test scaffold.
Future<void> _pumpView(
  WidgetTester tester, {
  String projectId = 'proj-uuid-001',
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConversationListView(projectId: projectId),
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
  late _FakeConversationHttpClient http;
  late ConversationListState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeConversationHttpClient();
    state = ConversationListState(httpClient: http);
    Magic.put<ConversationListState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<ConversationListState>();
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed with a projectId
  // -------------------------------------------------------------------------

  testWidgets('widget constructor accepts projectId', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    await _pumpView(tester, projectId: 'proj-test-001');

    expect(find.byType(ConversationListView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders MagicStarterPageHeader with conversations.title text
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state before conversations load', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    // Manually set loading state before pumping.
    state.setLoading();

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConversationListView(projectId: 'proj-uuid-001'),
            ),
          ),
        ),
      ),
    );
    // Use pump() NOT pumpAndSettle() — animation never settles.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Shows empty state when no conversations exist
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when no conversations exist', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    // Pre-load empty state.
    await state.loadConversations('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    // trans('conversations.empty_title') = 'No Conversations'
    expect(find.textContaining('No Conversations'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Renders conversation rows when conversations are loaded
  // -------------------------------------------------------------------------

  testWidgets('renders conversation rows when conversations are loaded', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(
        data: {
          'data': [kConversation1, kConversation2],
        },
        statusCode: 200,
      ),
    );

    // Pre-load conversations.
    await state.loadConversations('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    // Conversation 1 title is visible.
    expect(find.text('Project Kickoff'), findsOneWidget);

    // Conversation 2 falls back to agent role name.
    expect(find.text('Lead Developer'), findsOneWidget);

    // MagicStarterCard wraps the list.
    expect(find.byType(MagicStarterCard), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Conversation rows are wrapped in WAnchor for navigation
  // -------------------------------------------------------------------------

  testWidgets('conversation rows are wrapped in WAnchor for navigation', (
    tester,
  ) async {
    http.alwaysReturn(
      MagicResponse(
        data: {
          'data': [kConversation1],
        },
        statusCode: 200,
      ),
    );

    // Pre-load conversations.
    await state.loadConversations('team-uuid-001', 'proj-uuid-001');

    await _pumpView(tester);

    expect(find.text('Project Kickoff'), findsOneWidget);
    expect(find.byType(WAnchor), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 7. New Conversation button is rendered
  // -------------------------------------------------------------------------

  testWidgets('renders New Conversation action button', (tester) async {
    http.alwaysReturn(
      MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200),
    );

    await _pumpView(tester);

    // trans('conversations.new') = 'New Conversation'
    expect(find.textContaining('New Conversation'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Status badge is visible for active conversation
  // -------------------------------------------------------------------------

  testWidgets('renders status badge for active conversation', (tester) async {
    http.alwaysReturn(
      MagicResponse(
        data: {
          'data': [kConversation1],
        },
        statusCode: 200,
      ),
    );

    await state.loadConversations('team-uuid-001', 'proj-uuid-001');
    await _pumpView(tester);

    // trans('conversations.status_active') = 'Active'
    expect(find.textContaining('Active'), findsOneWidget);
  });
}
