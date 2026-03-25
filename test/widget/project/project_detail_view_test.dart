import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/user.dart';
import 'package:app/app/state/project_state.dart';
import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/project/project_detail_view.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kProject = {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'slug': 'alpha',
  'description': 'First project description.',
  'repository_url': 'git@github.com:acme/alpha.git',
  'default_branch': 'main',
  'tech_stack': 'Flutter, Dart',
  'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey',
  'execution_mode': 'manual',
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
  'task_count': 10,
  'active_run_count': 1,
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

class _FakeHttpClient implements HttpClient {
  final List<_HttpCall> calls = [];
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
    calls.add(_HttpCall('GET', url));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(_HttpCall('DELETE', url));
    return _responder(url);
  }
}

class _HttpCall {
  _HttpCall(this.method, this.url, {this.data});

  final String method;
  final String url;
  final dynamic data;
}

// ---------------------------------------------------------------------------
// Fake Task HTTP client
// ---------------------------------------------------------------------------

class _FakeTaskHttpClient implements TaskHttpClient {
  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    return MagicResponse(data: {'data': <dynamic>[]}, statusCode: 200);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return MagicResponse(data: {'data': {}}, statusCode: 200);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    return MagicResponse(data: {'data': {}}, statusCode: 200);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    return MagicResponse(data: {'data': {}}, statusCode: 200);
  }
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
// Test helpers
// ---------------------------------------------------------------------------

/// Configures a standard responder on the fake HTTP client.
void _configureResponder(_FakeHttpClient http) {
  http.whenAny((url) {
    if (url.contains('/repo/status')) {
      return MagicResponse(
        data: {
          'data': {'status': 'connected'},
        },
        statusCode: 200,
      );
    }
    return MagicResponse(data: {'data': kProject}, statusCode: 200);
  });
}

/// Pre-populates the [state] with project and repo status data so the widget
/// renders content without needing a real Auth context.
Future<void> _preloadState(ProjectState state) async {
  await state.fetchProject('team-uuid-001', 'proj-uuid-001');
  await state.fetchRepoStatus('team-uuid-001', 'proj-uuid-001');
}

/// Wraps [ProjectDetailView] in a [WindTheme] + [MaterialApp] for widget testing.
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

/// Pumps [ProjectDetailView] with a wide viewport (1440x900) to prevent
/// Wind UI flex-row overflow in tests.
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = _FakeHttpClient();
    state = ProjectState(httpClient: http);
    taskState = TaskState(httpClient: _FakeTaskHttpClient());

    // Pre-register fake states so .instance returns them.
    Magic.put<ProjectState>(state);
    Magic.put<TaskState>(taskState);

    // Set up auth context — owner/admin role so settings section renders.
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
    Magic.delete<ProjectState>();
    Magic.delete<TaskState>();
  });

  // -------------------------------------------------------------------------
  // 1. Renders project header with name and description
  // -------------------------------------------------------------------------

  testWidgets('renders project header with name and description', (
    tester,
  ) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Project name is displayed.
    expect(find.text('Alpha'), findsWidgets);

    // Description is displayed (in header and in the settings form field).
    expect(find.text('First project description.'), findsWidgets);

    // Tech stack badge is displayed.
    expect(find.text('Flutter, Dart'), findsWidgets);

    // Execution mode badge is displayed.
    expect(find.text('manual'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Renders SSH key section
  // -------------------------------------------------------------------------

  testWidgets('renders SSH key section with public key', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // SSH key section header is displayed.
    expect(find.text(trans('projects.ssh_deploy_key')), findsOneWidget);

    // Public key text is displayed.
    expect(
      find.text('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey'),
      findsOneWidget,
    );

    // Generate button is displayed.
    expect(find.text(trans('projects.generate_new_key')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders status indicator
  // -------------------------------------------------------------------------

  testWidgets('renders git status indicator with connected state', (
    tester,
  ) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Git status section header.
    expect(find.text(trans('projects.git_status')), findsOneWidget);

    // Status text.
    expect(find.text('connected'), findsOneWidget);

    // Check Status button.
    expect(find.text(trans('projects.check_status')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders settings section with edit form
  // -------------------------------------------------------------------------

  testWidgets('renders settings section with edit form fields', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Settings section header.
    expect(find.text(trans('projects.settings')), findsOneWidget);

    // Form fields are pre-filled — look for WFormInput instances.
    // The name field should contain the project name.
    final nameField = find.widgetWithText(WFormInput, 'Alpha');
    expect(nameField, findsOneWidget);

    // Description field.
    final descField = find.widgetWithText(
      WFormInput,
      'First project description.',
    );
    expect(descField, findsOneWidget);

    // Save and Delete buttons.
    expect(find.text(trans('projects.save_changes')), findsOneWidget);
    expect(find.text(trans('projects.delete_project')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Delete button shows confirmation dialog
  // -------------------------------------------------------------------------

  testWidgets('delete button shows confirmation dialog', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Scroll the delete button into view — it is below the fold.
    await tester.ensureVisible(find.text(trans('projects.delete_project')));
    await tester.pumpAndSettle();

    // Tap the delete button.
    await tester.tap(find.text(trans('projects.delete_project')));
    await tester.pumpAndSettle();

    // Confirmation dialog appears.
    expect(find.text(trans('projects.delete_confirm_title')), findsOneWidget);
    expect(find.text(trans('projects.delete_confirm_body')), findsOneWidget);

    // Cancel and Confirm buttons in the dialog.
    expect(find.text(trans('common.cancel')), findsOneWidget);
    expect(find.text(trans('common.delete')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Recent tasks placeholder is shown
  // -------------------------------------------------------------------------

  testWidgets('renders recent tasks placeholder', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    expect(find.text(trans('projects.recent_tasks')), findsOneWidget);
    expect(find.text(trans('projects.tasks_placeholder')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Shows loading when no project loaded
  // -------------------------------------------------------------------------

  testWidgets('shows loading indicator when project is not loaded', (
    tester,
  ) async {
    // Return an error so selectedProject stays null after fetch.
    http.alwaysReturn(
      MagicResponse(data: {'message': 'Not Found'}, statusCode: 404),
    );

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pump();
    await tester.pump();

    // Should show a CircularProgressIndicator since selectedProject is null.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
