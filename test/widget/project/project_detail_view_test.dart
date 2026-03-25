import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/user.dart';
import 'package:app/app/state/project_state.dart';
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
// Test helpers
// ---------------------------------------------------------------------------

/// Configures a standard responder on the fake HTTP client.
void _configureResponder(_FakeHttpClient http) {
  http.whenAny((url) {
    if (url.contains('/repo-status')) {
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
      home: Scaffold(body: ProjectDetailView(projectId: projectId)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeHttpClient http;
  late ProjectState state;

  setUp(() {
    http = _FakeHttpClient();
    state = ProjectState(httpClient: http);

    // Pre-register the fake state so ProjectState.instance returns it.
    Magic.put<ProjectState>(state);

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
    Magic.delete<ProjectState>();
  });

  // -------------------------------------------------------------------------
  // 1. Renders project header with name and description
  // -------------------------------------------------------------------------

  testWidgets('renders project header with name and description', (
    tester,
  ) async {
    _configureResponder(http);
    await _preloadState(state);

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

    // SSH key section header is displayed.
    expect(find.text('SSH Deploy Key'), findsOneWidget);

    // Public key text is displayed.
    expect(
      find.text('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey'),
      findsOneWidget,
    );

    // Generate button is displayed.
    expect(find.text('Generate New Key'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Renders status indicator
  // -------------------------------------------------------------------------

  testWidgets('renders git status indicator with connected state', (
    tester,
  ) async {
    _configureResponder(http);
    await _preloadState(state);

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

    // Git status section header.
    expect(find.text('Git Status'), findsOneWidget);

    // Status text.
    expect(find.text('connected'), findsOneWidget);

    // Check Status button.
    expect(find.text('Check Status'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders settings section with edit form
  // -------------------------------------------------------------------------

  testWidgets('renders settings section with edit form fields', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

    // Settings section header.
    expect(find.text('Settings'), findsOneWidget);

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
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Delete Project'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Delete button shows confirmation dialog
  // -------------------------------------------------------------------------

  testWidgets('delete button shows confirmation dialog', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

    // Scroll the delete button into view — it is below the fold.
    await tester.ensureVisible(find.text('Delete Project'));
    await tester.pumpAndSettle();

    // Tap the delete button.
    await tester.tap(find.text('Delete Project'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears.
    expect(find.text('Delete Project?'), findsOneWidget);
    expect(
      find.text(
        'This action cannot be undone. All project data will be permanently deleted.',
      ),
      findsOneWidget,
    );

    // Cancel and Confirm buttons in the dialog.
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Recent tasks placeholder is shown
  // -------------------------------------------------------------------------

  testWidgets('renders recent tasks placeholder', (tester) async {
    _configureResponder(http);
    await _preloadState(state);

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pumpAndSettle();

    expect(find.text('Recent Tasks'), findsOneWidget);
    expect(find.text('Tasks will appear here'), findsOneWidget);
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
