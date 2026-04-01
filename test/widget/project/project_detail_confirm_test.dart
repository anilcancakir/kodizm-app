import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'package:app/app/events/websocket_event.dart';
import 'package:app/app/models/user.dart';
import 'package:app/app/state/project_repository_state.dart';
import 'package:app/app/state/project_state.dart';
import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/project/project_detail_view.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kProject = {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'short_name': 'ALP',
  'slug': 'alpha',
  'description': 'First project description.',
  'repository_url': 'git@github.com:acme/alpha.git',
  'default_branch': 'main',
  'tech_stack': 'Flutter, Dart',
  'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey',
  'has_ssh_key': true,
  'execution_mode': 'manual',
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
  'task_count': 10,
  'active_run_count': 0,
};

const Map<String, dynamic> kRepo = {
  'id': 'repo-uuid-001',
  'project_id': 'proj-uuid-001',
  'name': 'API Repo',
  'repository_url': 'git@github.com:acme/api.git',
  'default_branch': 'main',
  'repo_status': 'cloned',
  'repo_error': null,
  'last_synced_at': null,
  'mount_path': '/workspace',
  'created_at': null,
  'updated_at': null,
};

// ---------------------------------------------------------------------------
// Fake HTTP clients
// ---------------------------------------------------------------------------

class _FakeHttpClient implements HttpClient {
  late MagicResponse Function(String url) _responder;

  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => _responder(url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _responder(url);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _responder(url);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _responder(url);
}

class _FakeTaskHttpClient implements TaskHttpClient {
  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => MagicResponse(data: {'data': {}}, statusCode: 200);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => MagicResponse(data: {'data': {}}, statusCode: 200);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => MagicResponse(data: {'data': {}}, statusCode: 200);
}

class _FakeRepoHttpClient implements ProjectRepositoryHttpClient {
  late MagicResponse _getResponse;
  late MagicResponse _mutationResponse;

  _FakeRepoHttpClient() {
    _getResponse = MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
    _mutationResponse = MagicResponse(
      data: {'data': <String, dynamic>{}},
      statusCode: 200,
    );
  }

  void alwaysReturn(MagicResponse response) => _getResponse = response;
  void alwaysReturnOnMutation(MagicResponse response) =>
      _mutationResponse = response;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    if (url.endsWith('/repo/status')) {
      return MagicResponse(
        data: {
          'data': <String, dynamic>{'status': 'cloned'},
        },
        statusCode: 200,
      );
    }
    return _getResponse;
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _mutationResponse;

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _mutationResponse;

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _mutationResponse;
}

class _FakeRepoWebSocket implements RepoWebSocket {
  @override
  void subscribe(String channel, void Function(WebSocketEvent) onEvent) {}

  @override
  void unsubscribe(String channel) {}
}

// ---------------------------------------------------------------------------
// Translation loader
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
// Test helpers
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
  late _FakeHttpClient http;
  late ProjectState state;
  late TaskState taskState;
  late _FakeRepoHttpClient repoHttp;
  late ProjectRepositoryState repoState;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUpAll(() {
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  setUp(() {
    http = _FakeHttpClient();
    http.alwaysReturn(MagicResponse(data: {'data': kProject}, statusCode: 200));

    state = ProjectState(httpClient: http);
    taskState = TaskState(httpClient: _FakeTaskHttpClient());
    repoHttp = _FakeRepoHttpClient();
    repoState = ProjectRepositoryState(
      httpClient: repoHttp,
      ws: _FakeRepoWebSocket(),
    );

    Magic.put<ProjectState>(state);
    Magic.put<TaskState>(taskState);
    Magic.put<ProjectRepositoryState>(repoState);

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

  tearDown(() {
    state.dispose();
    taskState.dispose();
    repoState.dispose();
    Magic.delete<ProjectState>();
    Magic.delete<TaskState>();
    Magic.delete<ProjectRepositoryState>();
  });

  // -------------------------------------------------------------------------
  // 1. SSH key regeneration shows MagicStarterConfirmDialog with danger variant
  // -------------------------------------------------------------------------

  // Removed: 'regenerate SSH key button shows confirm dialog' — button removed
  // from project detail view in redesign.

  // -------------------------------------------------------------------------
  // 2. Repository deletion shows MagicStarterConfirmDialog with danger variant
  // -------------------------------------------------------------------------

  testWidgets(
    'delete repository button shows MagicStarterConfirmDialog with danger variant',
    (tester) async {
      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      // Pre-load one repository so the delete button appears.
      repoHttp.alwaysReturn(
        MagicResponse(
          data: {
            'data': [kRepo],
          },
          statusCode: 200,
        ),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Scroll to the delete repo button.
      await tester.ensureVisible(find.text(trans('projects.delete_repo')));
      await tester.pumpAndSettle();

      await tester.tap(find.text(trans('projects.delete_repo')));
      await tester.pumpAndSettle();

      // MagicStarterConfirmDialog should appear.
      expect(find.byType(MagicStarterConfirmDialog), findsOneWidget);

      // Title and description from i18n keys.
      expect(
        find.text(trans('projects.delete_repo_confirm_title')),
        findsOneWidget,
      );
      expect(
        find.text(trans('projects.delete_repo_confirm_body')),
        findsOneWidget,
      );

      // Confirm action label (common.delete).
      expect(find.text(trans('common.delete')), findsOneWidget);

      // Cancel button.
      expect(find.text(trans('common.cancel')), findsOneWidget);
    },
  );

  // Removed: 'cancelling regenerate SSH dialog' — button removed from view.
}
