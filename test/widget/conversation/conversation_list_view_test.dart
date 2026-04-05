import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

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
  MagicTest.init();

  late FakeNetworkDriver driver;
  late ConversationListState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Auth.fake();
    driver = Http.fake();
    driver.stub('*', Http.response({'data': <dynamic>[]}));

    state = ConversationListState();
    Magic.put<ConversationListState>(state);
  });

  // -------------------------------------------------------------------------
  // 1. Widget can be constructed with a projectId
  // -------------------------------------------------------------------------

  testWidgets('widget constructor accepts projectId', (tester) async {
    await _pumpView(tester, projectId: 'proj-test-001');

    expect(find.byType(ConversationListView), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders MagicStarterPageHeader with conversations.title text
  // -------------------------------------------------------------------------

  testWidgets('renders MagicStarterPageHeader with title', (tester) async {
    await _pumpView(tester);

    expect(find.byType(MagicStarterPageHeader), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Shows loading state (CircularProgressIndicator)
  // -------------------------------------------------------------------------

  testWidgets('shows loading state before conversations load', (tester) async {
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
    driver.stub(
      '*',
      Http.response({
        'data': [kConversation1, kConversation2],
      }),
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
    driver.stub(
      '*',
      Http.response({
        'data': [kConversation1],
      }),
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
    await _pumpView(tester);

    // trans('conversations.new') = 'New Conversation'
    expect(find.textContaining('New Conversation'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Status badge is visible for active conversation
  // -------------------------------------------------------------------------

  testWidgets('renders status badge for active conversation', (tester) async {
    driver.stub(
      '*',
      Http.response({
        'data': [kConversation1],
      }),
    );

    await state.loadConversations('team-uuid-001', 'proj-uuid-001');
    await _pumpView(tester);

    // trans('conversations.status_active') = 'Active'
    expect(find.textContaining('Active'), findsOneWidget);
  });
}
