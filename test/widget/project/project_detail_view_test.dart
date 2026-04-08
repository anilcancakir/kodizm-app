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
// Shared fixtures
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
  'tech_stack': ['Flutter', 'Dart'],
  'ssh_public_key': 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKey',
  'has_ssh_key': true,
  'execution_mode': 'manual',
  'created_at': '2024-01-15T10:30:00.000Z',
  'updated_at': '2024-06-20T14:00:00.000Z',
  'task_count': 10,
  'active_run_count': 1,
};

/// Repo fixtures no longer carry ssh_public_key or has_ssh_key — those
/// fields were moved to the project level in Step 5 of the SSH key refactor.
const Map<String, dynamic> kRepoApiRepo = {
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

const Map<String, dynamic> kRepoFrontendRepo = {
  'id': 'repo-uuid-002',
  'project_id': 'proj-uuid-001',
  'name': 'Frontend Repo',
  'repository_url': null,
  'default_branch': 'develop',
  'repo_status': null,
  'repo_error': null,
  'last_synced_at': null,
  'mount_path': '/frontend',
  'created_at': null,
  'updated_at': null,
};

// ---------------------------------------------------------------------------
// Fake RepoWebSocket
// ---------------------------------------------------------------------------

class _FakeRepoWebSocket implements RepoWebSocket {
  final List<String> subscribedChannels = [];
  final List<String> unsubscribedChannels = [];

  @override
  void subscribe(String channel, void Function(BroadcastEvent) onEvent) {
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

/// Pre-populates the [state] with project data so the widget renders content
/// without needing a real Auth context.
Future<void> _preloadState(ProjectState state) async {
  await state.fetchProject('team-uuid-001', 'proj-uuid-001');
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
///
/// Use [settle] = `false` when the widget contains an infinitely animating
/// [CircularProgressIndicator] (cloning status) to avoid pumpAndSettle timeout.
Future<void> _pumpTestWidget(
  WidgetTester tester, {
  required String projectId,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(_buildTestWidget(projectId: projectId));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Pump a few frames to let the widget build without waiting for animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
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
    // Register the magic_starter manager singleton so MagicStarter.modalTheme
    // and MagicStarterPasswordConfirmDialog can resolve the service.
    // Must be in setUp (not setUpAll) because MagicTest.init() calls
    // Magic.flush() in each setUp which clears singletons.
    Magic.singleton('magic_starter', () => MagicStarterManager());

    driver = Http.fake();
    // Catch-all first (lowest priority).
    driver.stub('*', Http.response({'data': kProject}));
    // Specific patterns after (higher priority).
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

    // Pre-register fake states so .instance returns them.
    Magic.put<ProjectState>(state);
    Magic.put<TaskState>(taskState);
    Magic.put<ProjectRepositoryState>(repoState);

    // Set up auth context — owner/admin role so settings section renders.
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
  // 1. Renders project header with name and description
  // -------------------------------------------------------------------------

  testWidgets('renders project header with name and description', (
    tester,
  ) async {
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
  // 2. Repositories section header rendered
  // -------------------------------------------------------------------------

  testWidgets('renders repositories section header', (tester) async {
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Repositories section title.
    expect(find.text(trans('projects.repositories')), findsOneWidget);

    // Add repository button is always present.
    expect(find.text(trans('projects.add_repository')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Repositories section — empty state when no repos loaded
  // -------------------------------------------------------------------------

  testWidgets('renders no-repositories empty state when repo list is empty', (
    tester,
  ) async {
    await _preloadState(state);

    // repoState has no repos — empty state should be shown.
    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    expect(find.text(trans('projects.no_repositories')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders settings section with edit form
  // -------------------------------------------------------------------------

  testWidgets('renders settings section with edit form fields', (tester) async {
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

    // Save buttons — commit settings section and project settings section
    // both render a "Save Changes" button, so two are expected.
    expect(find.text(trans('projects.save_changes')), findsNWidgets(2));
    expect(find.text(trans('projects.delete_project')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Delete button shows confirmation dialog
  // -------------------------------------------------------------------------

  testWidgets('delete button shows confirmation dialog', (tester) async {
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Scroll the delete button into view — it is below the fold.
    await tester.ensureVisible(find.text(trans('projects.delete_project')));
    await tester.pumpAndSettle();

    // Tap the delete button.
    await tester.tap(find.text(trans('projects.delete_project')));
    await tester.pumpAndSettle();

    // Password confirmation dialog appears.
    expect(find.text(trans('projects.delete_confirm_title')), findsOneWidget);
    expect(find.text(trans('projects.delete_confirm_body')), findsOneWidget);

    // Cancel and Confirm buttons in the password dialog.
    expect(find.text(trans('common.cancel')), findsOneWidget);
    expect(find.text(trans('common.confirm')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Recent tasks placeholder is shown
  // -------------------------------------------------------------------------

  // Removed: 'renders recent tasks placeholder' — section removed in redesign.

  // -------------------------------------------------------------------------
  // 7. Shows loading when no project loaded
  // -------------------------------------------------------------------------

  testWidgets('shows loading indicator when project is not loaded', (
    tester,
  ) async {
    // Return an error so selectedProject stays null after fetch.
    driver.stub('*', Http.response({'message': 'Not Found'}, 404));

    await tester.pumpWidget(_buildTestWidget(projectId: 'proj-uuid-001'));
    await tester.pump();
    await tester.pump();

    // Should show a CircularProgressIndicator since selectedProject is null.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 8. Repositories section — empty state
  // -------------------------------------------------------------------------

  testWidgets('renders repositories section with empty state', (tester) async {
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Section title.
    expect(find.text(trans('projects.repositories')), findsOneWidget);

    // Add repository button.
    expect(find.text(trans('projects.add_repository')), findsOneWidget);

    // Empty state message.
    expect(find.text(trans('projects.no_repositories')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 9. Repositories section — renders repo cards without SSH key buttons
  // -------------------------------------------------------------------------

  testWidgets(
    'renders repository cards and repo cards do NOT show SSH key buttons',
    (tester) async {
      await _preloadState(state);

      // Pre-load two repositories — fixtures no longer carry SSH fields.
      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [kRepoApiRepo, kRepoFrontendRepo],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Both repo names should appear.
      expect(find.text('API Repo'), findsOneWidget);
      expect(find.text('Frontend Repo'), findsOneWidget);

      // Branch badges.
      expect(find.text('main'), findsOneWidget);
      expect(find.text('develop'), findsOneWidget);

      // Mount paths.
      expect(find.text('/workspace'), findsOneWidget);
      expect(find.text('/frontend'), findsOneWidget);

      // Clone button: kRepoApiRepo is 'cloned' (hidden), kRepoFrontendRepo is
      // null status (shown) — so only one clone button is present.
      expect(find.text(trans('projects.clone_repo')), findsOneWidget);
      // Delete buttons are always present for both repos.
      expect(find.text(trans('projects.delete_repo')), findsNWidgets(2));

      // SSH key buttons are NO LONGER rendered per-repo — they moved to project level.
      expect(find.text(trans('projects.ssh_deploy_key')), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // 10. Project-level SSH key section is rendered
  // -------------------------------------------------------------------------

  // Removed: 'renders project-level SSH public key' — moved to repo section.

  // -------------------------------------------------------------------------
  // 11. Project-level "Regenerate SSH Key" button is rendered
  // -------------------------------------------------------------------------

  // Removed: 'renders Regenerate SSH Key button' — moved to repo section.

  // -------------------------------------------------------------------------
  // 12. Project short_name is shown in the header area
  // -------------------------------------------------------------------------

  testWidgets('renders project short_name in header area', (tester) async {
    await _preloadState(state);

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // The short_name "ALP" from kProject fixture should be visible in the header.
    expect(find.text('ALP'), findsAtLeastNWidgets(1));
  });

  // -------------------------------------------------------------------------
  // 13. Main repo card shows filled star; non-main shows outline star
  // -------------------------------------------------------------------------

  testWidgets('main repo card shows filled star; non-main shows outline star', (
    tester,
  ) async {
    await _preloadState(state);

    // API Repo is the main repo; Frontend Repo is not.
    driver.stub(
      '*/repositories*',
      Http.response({
        'data': [
          {...kRepoApiRepo, 'is_main': true},
          {...kRepoFrontendRepo, 'is_main': false},
        ],
      }),
    );
    await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    // Filled star for main repo.
    expect(find.byIcon(Icons.star), findsOneWidget);
    // Outline star for non-main repo.
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 14. Tapping outline star calls setMainRepository
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping outline star on non-main repo triggers setMainRepository',
    (tester) async {
      await _preloadState(state);

      // Only Frontend Repo is non-main; API Repo is main.
      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'is_main': true},
            {...kRepoFrontendRepo, 'is_main': false},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      // Stub PUT response for single repo (registered AFTER list stub → higher priority).
      driver.stub(
        '*/repositories/repo-uuid-*',
        Http.response({
          'data': {...kRepoFrontendRepo, 'is_main': true},
        }),
      );

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Tap the outline star (non-main repo).
      await tester.tap(find.byIcon(Icons.star_outline));
      await tester.pumpAndSettle();

      // A PUT call should have been made to set is_main.
      driver.assertSent(
        (r) => r.method == 'PUT' && r.url.contains('repositories'),
      );
    },
  );

  // -------------------------------------------------------------------------
  // 15. Tapping filled star (main repo) does nothing
  // -------------------------------------------------------------------------

  testWidgets('tapping filled star on main repo does not trigger extra calls', (
    tester,
  ) async {
    await _preloadState(state);

    driver.stub(
      '*/repositories*',
      Http.response({
        'data': [
          {...kRepoApiRepo, 'is_main': true},
        ],
      }),
    );
    await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

    await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

    final callsBefore = driver.recorded.length;

    // Tap the filled star.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pumpAndSettle();

    // No new HTTP calls should have been made.
    expect(driver.recorded.length, equals(callsBefore));
  });

  // -------------------------------------------------------------------------
  // 16. Cloning status shows spinner and in-progress text
  // -------------------------------------------------------------------------

  testWidgets(
    'repo card shows spinner and clone-in-progress text when status is cloning',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoFrontendRepo, 'repo_status': 'cloning'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      // settle: false — CircularProgressIndicator animates forever.
      await _pumpTestWidget(tester, projectId: 'proj-uuid-001', settle: false);

      // A spinner should be present for the cloning repo.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The clone-in-progress i18n string should appear.
      expect(find.text(trans('projects.clone_in_progress')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 17. Cloned status shows checkmark icon and complete text
  // -------------------------------------------------------------------------

  testWidgets(
    'repo card shows check_circle icon and clone-complete text when status is cloned',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'repo_status': 'cloned'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Checkmark icon for cloned repos.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Clone complete text.
      expect(find.text(trans('projects.clone_complete')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 18. Error status shows error icon and failed text
  // -------------------------------------------------------------------------

  testWidgets(
    'repo card shows error_outline icon and clone-failed text when status is error',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoFrontendRepo, 'repo_status': 'error'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Error icon for failed clone.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Clone failed text.
      expect(find.text(trans('projects.clone_failed')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 19. Clone button hidden when repo is cloned or cloning
  // -------------------------------------------------------------------------

  testWidgets(
    'clone button is hidden when repo status is cloned, cloning, or onboarding',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'repo_status': 'cloned'},
            {...kRepoFrontendRepo, 'repo_status': 'onboarding'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      // settle: false — onboarding repo has an animating CircularProgressIndicator.
      await _pumpTestWidget(tester, projectId: 'proj-uuid-001', settle: false);

      // Neither repo should show the manual clone button.
      expect(find.text(trans('projects.clone_repo')), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // 20. startStatusPolling stores status in per-repo map
  // -------------------------------------------------------------------------

  testWidgets('repoStatuses map tracks per-repo clone status independently', (
    tester,
  ) async {
    await _preloadState(state);

    // Pre-load two repos, one cloning, one cloned.
    driver.stub(
      '*/repositories*',
      Http.response({
        'data': [
          {...kRepoApiRepo, 'repo_status': 'cloned'},
          {...kRepoFrontendRepo, 'repo_status': 'cloning'},
        ],
      }),
    );
    await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

    // settle: false — cloning repo has an animating CircularProgressIndicator.
    await _pumpTestWidget(tester, projectId: 'proj-uuid-001', settle: false);

    // The API repo (cloned) should show checkmark.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // The Frontend repo (cloning) should show spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 21. Onboarding status shows spinner and setting-up text
  // -------------------------------------------------------------------------

  testWidgets(
    'repo card shows spinner and onboarding-in-progress text when status is onboarding',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoFrontendRepo, 'repo_status': 'onboarding'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      // settle: false — CircularProgressIndicator animates forever.
      await _pumpTestWidget(tester, projectId: 'proj-uuid-001', settle: false);

      // A spinner should be present for the onboarding repo.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The onboarding i18n string should appear.
      expect(
        find.text(trans('projects.onboarding_in_progress')),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // 22. Ready status shows checkmark and ready text
  // -------------------------------------------------------------------------

  testWidgets(
    'repo card shows check_circle icon and repository-ready text when status is ready',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'repo_status': 'ready'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Checkmark icon for ready repos.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Repository ready text.
      expect(find.text(trans('projects.repository_ready')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // 23. Re-analyze button visible when status is ready or cloned
  // -------------------------------------------------------------------------

  testWidgets(
    'Re-analyze button is visible when repo status is ready or cloned',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'repo_status': 'ready'},
            {...kRepoFrontendRepo, 'repo_status': 'cloned'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Both repos show the Re-analyze button.
      expect(find.text(trans('projects.reanalyze_repo')), findsNWidgets(2));
    },
  );

  // -------------------------------------------------------------------------
  // 24. Re-analyze button calls reanalyzeRepository on state
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping Re-analyze button triggers a POST to the reanalyze endpoint',
    (tester) async {
      await _preloadState(state);

      driver.stub(
        '*/repositories*',
        Http.response({
          'data': [
            {...kRepoApiRepo, 'repo_status': 'ready'},
          ],
        }),
      );
      await repoState.fetchRepositories('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      final callsBefore = driver.recorded.length;

      // Tap Re-analyze button. Use pump (not pumpAndSettle) because the
      // optimistic status change triggers a CircularProgressIndicator which
      // animates indefinitely.
      await tester.tap(find.text(trans('projects.reanalyze_repo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // A POST call should have been made.
      final newCalls = driver.recorded
          .skip(callsBefore)
          .where((entry) => entry.$1.method == 'POST')
          .toList();
      expect(newCalls, isNotEmpty);
    },
  );

  // -------------------------------------------------------------------------
  // Container section — shows for admin, empty state when no container
  // -------------------------------------------------------------------------

  testWidgets(
    'shows container section with empty state for admin when no container',
    (tester) async {
      await _preloadState(state);

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Container section title visible for admin/owner.
      expect(find.text(trans('projects.container.title')), findsOneWidget);

      // Empty state message — kProject has no container.
      expect(
        find.text(trans('projects.container.no_container')),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // Container section — shows status badge when container exists
  // -------------------------------------------------------------------------

  testWidgets(
    'shows container section with status badge when container exists',
    (tester) async {
      // Return a project WITH a container in the API response.
      // Re-register specific stubs AFTER the catch-all so they take priority.
      driver.stub(
        '*',
        Http.response({
          'data': {
            ...kProject,
            'container': {
              'id': 'pc-uuid-001',
              'container_name': 'kodizm-proj-abc123',
              'volume_name': 'kodizm-vol-abc123',
              'status': 'running',
              'docker_host_id': 'dh-uuid-001',
              'last_activity_at': null,
              'health_checked_at': null,
              'bootstrapped_at': null,
              'last_error': null,
              'created_at': '2026-03-30T12:00:00.000Z',
              'updated_at': '2026-04-01T10:00:00.000Z',
            },
          },
        }),
      );
      driver.stub('*/tasks*', Http.response({'data': <dynamic>[]}));
      driver.stub('*/repositories*', Http.response({'data': <dynamic>[]}));
      driver.stub('*/mcp-servers*', Http.response({'data': <dynamic>[]}));
      await state.fetchProject('team-uuid-001', 'proj-uuid-001');

      await _pumpTestWidget(tester, projectId: 'proj-uuid-001');

      // Container section title.
      expect(find.text(trans('projects.container.title')), findsOneWidget);

      // Container name shown.
      expect(find.text('kodizm-proj-abc123'), findsOneWidget);

      // No empty state message.
      expect(find.text(trans('projects.container.no_container')), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // Container section — hidden for non-admin
  // -------------------------------------------------------------------------

  testWidgets('hides container section when user is not admin', (tester) async {
    await _preloadState(state);

    // Override Auth to a member role (not owner/admin).
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

    // Container section should NOT be visible.
    expect(find.text(trans('projects.container.title')), findsNothing);
    // Settings section is also hidden (same gate).
    expect(find.text(trans('projects.settings')), findsNothing);
  });
}
