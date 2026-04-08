import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/app/models/user.dart';
import 'package:app/app/state/project_repository_state.dart';
import 'package:app/app/state/project_state.dart';
import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/project/project_detail_view.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> _kBaseProject = {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'short_name': 'ALP',
  'slug': 'alpha',
  'description': 'Test project description.',
  'tech_stack': <String>['Flutter'],
  'execution_mode': 'manual',
};

const Map<String, dynamic> _kCommitSettings = {
  'commit_author_name': 'Jane Dev',
  'commit_author_email': 'jane@example.com',
  'co_author_enabled': false,
};

// ---------------------------------------------------------------------------
// Fake RepoWebSocket
// ---------------------------------------------------------------------------

class _FakeRepoWebSocket implements RepoWebSocket {
  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {}

  @override
  void unsubscribe(String channel) {}
}

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
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

Widget _buildTestWidget({required String projectId}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProjectDetailView(projectId: projectId),
        ),
      ),
    ),
  );
}

Future<void> _pumpTestWidget(
  WidgetTester tester, {
  required String projectId,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(_buildTestWidget(projectId: projectId));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  late FakeNetworkDriver driver;
  late ProjectState state;
  late TaskState taskState;
  late ProjectRepositoryState repoState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());

    driver = Http.fake();
    driver.stub('*', Http.response({'data': _kBaseProject}));
    driver.stub('*/tasks*', Http.response({'data': <dynamic>[]}));
    driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));
    driver.stub(
      '*/repo/status*',
      Http.response({
        'data': <String, dynamic>{'status': 'cloned'},
      }),
    );
    driver.stub('*/mcp-servers*', Http.response({'data': <dynamic>[]}));

    state = ProjectState();
    taskState = TaskState();
    repoState = ProjectRepositoryState(ws: _FakeRepoWebSocket());

    Magic.put<ProjectState>(state);
    Magic.put<TaskState>(taskState);
    Magic.put<ProjectRepositoryState>(repoState);

    // Authenticate as owner so _canManageProject returns true.
    Auth.fake();
    Auth.manager.setUserFactory((data) => User.fromMap(data));
    Auth.guard().setUser(
      User.fromMap({
        'id': 'user-uuid-001',
        'name': 'Test User',
        'current_team': {
          'id': 'team-uuid-001',
          'name': 'Test Team',
          'owner_id': 'user-uuid-001',
          'user_role': 'owner',
        },
      }),
    );
  });

  // -------------------------------------------------------------------------
  // 1. Commit settings renders with project data
  // -------------------------------------------------------------------------

  testWidgets('commit settings renders with project data', (tester) async {
    // Stub the project with commit settings in the settings map.
    driver.stub(
      '*',
      Http.response({
        'data': {..._kBaseProject, 'settings': _kCommitSettings},
      }),
    );
    driver.stub('*/tasks*', Http.response({'data': <dynamic>[]}));
    driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));
    driver.stub('*/mcp-servers*', Http.response({'data': <dynamic>[]}));

    await state.fetchProject('team-uuid-001', 'proj-uuid-001');

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Section title is present.
    expect(find.text(trans('projects.commit_settings')), findsOneWidget);

    // Section subtitle is present.
    expect(
      find.text(trans('projects.commit_settings_subtitle')),
      findsOneWidget,
    );

    // Author name field shows the value from settings.
    expect(find.widgetWithText(WFormInput, 'Jane Dev'), findsOneWidget);

    // Author email field shows the value from settings.
    expect(find.widgetWithText(WFormInput, 'jane@example.com'), findsOneWidget);

    // Co-author label is present.
    expect(find.text(trans('projects.co_author_enabled')), findsOneWidget);

    // Co-author switch reflects the value from settings (co_author_enabled=false).
    final coAuthorSwitches = tester.widgetList<Switch>(find.byType(Switch));
    final coAuthorSwitch = coAuthorSwitches.last;
    expect(coAuthorSwitch.value, isFalse);
  });

  // -------------------------------------------------------------------------
  // 2. Commit settings defaults co_author_enabled to true when absent
  // -------------------------------------------------------------------------

  testWidgets(
    'commit settings defaults co_author_enabled to true when key is absent',
    (tester) async {
      // Project settings without co_author_enabled key.
      driver.stub(
        '*',
        Http.response({
          'data': {
            ..._kBaseProject,
            'settings': {
              'commit_author_name': 'Default Author',
              'commit_author_email': 'default@example.com',
              // co_author_enabled intentionally absent — should default to true
            },
          },
        }),
      );
      driver.stub('*/tasks*', Http.response({'data': <dynamic>[]}));
      driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));
      driver.stub('*/mcp-servers*', Http.response({'data': <dynamic>[]}));

      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Section is visible.
      expect(find.text(trans('projects.commit_settings')), findsOneWidget);

      // Co-author switch must default to ON (true).
      final coAuthorSwitches = tester.widgetList<Switch>(find.byType(Switch));
      final coAuthorSwitch = coAuthorSwitches.last;
      expect(coAuthorSwitch.value, isTrue);
    },
  );

  // -------------------------------------------------------------------------
  // 3. Commit settings hidden for non-managers
  // -------------------------------------------------------------------------

  testWidgets(
    'commit settings section is hidden for users without manage permission',
    (tester) async {
      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      // Override auth to a non-manager (member) role.
      Auth.guard().setUser(
        User.fromMap({
          'id': 'user-uuid-002',
          'name': 'Regular Member',
          'current_team': {
            'id': 'team-uuid-001',
            'name': 'Test Team',
            'owner_id': 'user-uuid-001',
            'user_role': 'member',
          },
        }),
      );

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Commit settings section title must NOT appear.
      expect(find.text(trans('projects.commit_settings')), findsNothing);
      // Settings section is also gated — also absent.
      expect(find.text(trans('projects.settings')), findsNothing);
    },
  );
}
