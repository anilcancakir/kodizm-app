import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/project.dart';
import 'package:app/app/state/project_state.dart';
import 'package:app/resources/views/project/project_list_view.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kProjectAlpha = {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'slug': 'alpha',
  'description': 'First project.',
  'repository_url': 'git@github.com:acme/alpha.git',
  'default_branch': 'main',
  'tech_stack': 'Flutter, Dart',
  'execution_mode': 'manual',
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
  'task_count': 10,
  'active_run_count': 1,
};

const Map<String, dynamic> kProjectBravo = {
  'id': 'proj-uuid-002',
  'team_id': 'team-uuid-001',
  'name': 'Bravo',
  'slug': 'bravo',
  'description': 'Second project.',
  'repository_url': null,
  'default_branch': 'develop',
  'tech_stack': 'Laravel, PostgreSQL',
  'execution_mode': 'auto',
  'created_at': '2025-03-01T08:00:00.000Z',
  'updated_at': '2025-03-20T12:00:00.000Z',
  'task_count': 5,
  'active_run_count': 0,
};

// ---------------------------------------------------------------------------
// Minimal fake HTTP client
// ---------------------------------------------------------------------------

/// Fake [HttpClient] that always returns a configurable [MagicResponse].
class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._response);

  final MagicResponse _response;

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async => _response;

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _response;

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _response;

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _response;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a [ProjectListView] wrapped in a [WindTheme] + [MaterialApp].
///
/// Wind UI widgets require a [WindTheme] ancestor. The [state] must already
/// be registered in the Magic container before calling [pumpWidget].
Widget _buildSubject() {
  return WindTheme(
    data: WindThemeData(),
    child: const MaterialApp(home: Scaffold(body: ProjectListView())),
  );
}

/// Creates and registers a [ProjectState] with the given pre-seeded [projects].
///
/// Returns the state for further inspection. Callers are responsible for
/// calling [Magic.delete] in tearDown.
ProjectState _seedSuccess(List<Map<String, dynamic>> projects) {
  final state = ProjectState(
    httpClient: _FakeHttpClient(
      MagicResponse(data: {'data': projects}, statusCode: 200),
    ),
  );
  state.setSuccess(projects.map(Project.fromMap).toList());
  Magic.put<ProjectState>(state);
  return state;
}

/// Creates and registers a [ProjectState] in the empty state.
ProjectState _seedEmpty() {
  final state = ProjectState(
    httpClient: _FakeHttpClient(
      MagicResponse(data: {'data': <Map<String, dynamic>>[]}, statusCode: 200),
    ),
  );
  state.setEmpty();
  Magic.put<ProjectState>(state);
  return state;
}

/// Creates and registers a [ProjectState] in the error state.
ProjectState _seedError(String message) {
  final state = ProjectState(
    httpClient: _FakeHttpClient(
      MagicResponse(data: {'message': message}, statusCode: 500),
    ),
  );
  state.setError(message);
  Magic.put<ProjectState>(state);
  return state;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    // Remove the singleton from the Magic container after each test.
    if (Magic.isRegistered<ProjectState>()) {
      Magic.find<ProjectState>().dispose();
      Magic.delete<ProjectState>();
    }
  });

  // -------------------------------------------------------------------------
  // 1. Renders project cards when data is loaded
  // -------------------------------------------------------------------------

  testWidgets('renders project cards when data is loaded', (tester) async {
    _seedSuccess([kProjectAlpha, kProjectBravo]);

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    // Both project names should appear.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);

    // Repo URL from kProjectAlpha.
    expect(find.text('git@github.com:acme/alpha.git'), findsOneWidget);

    // kProjectBravo has null repo — placeholder text shown.
    expect(find.text('No repo connected'), findsOneWidget);

    // Tech stack badges.
    expect(find.text('Flutter, Dart'), findsOneWidget);
    expect(find.text('Laravel, PostgreSQL'), findsOneWidget);

    // Task counts.
    expect(find.text('10 tasks'), findsOneWidget);
    expect(find.text('5 tasks'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Shows empty state when no projects
  // -------------------------------------------------------------------------

  testWidgets('shows empty state when there are no projects', (tester) async {
    _seedEmpty();

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    // Empty state messages.
    expect(find.text('No projects yet'), findsOneWidget);
    expect(
      find.text('Get started by creating your first project.'),
      findsOneWidget,
    );

    // CTA button.
    expect(find.text('Create your first project'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Sort toggle calls sortProjects with the correct SortField
  // -------------------------------------------------------------------------

  testWidgets('tapping Last Updated sort button calls sortProjects', (
    tester,
  ) async {
    final state = _seedSuccess([kProjectBravo, kProjectAlpha]);

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    // Tap the "Last Updated" toggle button.
    await tester.tap(find.text('Last Updated'));
    await tester.pump();

    // After sorting by lastUpdated, kProjectBravo (2025-03) should be first.
    final projectTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();

    final alphaIndex = projectTexts.indexOf('Alpha');
    final bravoIndex = projectTexts.indexOf('Bravo');

    // Bravo (more recent) must appear before Alpha.
    expect(bravoIndex, lessThan(alphaIndex));

    // State's rxState should reflect the sort.
    expect(state.rxState?.first.name, equals('Bravo'));
  });

  // -------------------------------------------------------------------------
  // 4. Tapping a project card triggers navigation
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping a project card fires navigation toward the project detail path',
    (tester) async {
      _seedSuccess([kProjectAlpha]);

      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      // The project card for Alpha must be present.
      expect(find.text('Alpha'), findsOneWidget);

      // Tapping fires MagicRoute.to('/projects/proj-uuid-001').
      // In the test environment the Magic router has no routerConfig, so the
      // call throws StateError which Flutter captures in the error handler.
      // tester.takeException() retrieves the most recent framework error.
      await tester.tap(find.text('Alpha'));
      await tester.pump();

      final exception = tester.takeException();
      expect(exception, isA<StateError>());
      expect(
        (exception as StateError).message,
        contains('Router not initialized'),
      );
    },
  );

  // -------------------------------------------------------------------------
  // 5. Active run indicator shown when activeRunCount > 0
  // -------------------------------------------------------------------------

  testWidgets('shows active run indicator for projects with active runs', (
    tester,
  ) async {
    _seedSuccess([kProjectAlpha]); // activeRunCount = 1

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    expect(find.text('1 active'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Error state shows error message
  // -------------------------------------------------------------------------

  testWidgets('shows error message when fetchProjects fails', (tester) async {
    _seedError('Unauthorized');

    await tester.pumpWidget(_buildSubject());
    await tester.pump();

    expect(find.text('Failed to load projects'), findsOneWidget);
    expect(find.text('Unauthorized'), findsOneWidget);
  });
}
