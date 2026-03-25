import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// import '../resources/views/welcome_view.dart'; // Replaced by DashboardView
import '../resources/views/dashboard_view.dart';
import '../resources/views/project/project_list_view.dart';
import '../resources/views/project/project_create_view.dart';
import '../resources/views/project/project_detail_view.dart';
import '../resources/views/task/task_list_view.dart';
import '../resources/views/task/task_create_view.dart';
import '../resources/views/task/agent_run_view.dart';
import '../resources/views/task/task_detail_view.dart';
import '../resources/views/knowledge/knowledge_list_view.dart';
import '../resources/views/knowledge/knowledge_detail_view.dart';
import '../resources/views/billing/billing_view.dart';
import '../resources/views/billing/usage_history_view.dart';
import '../resources/views/settings/ai_token_list_view.dart';
import '../resources/views/settings/app_settings_view.dart';
import '../resources/views/nav/project_scoped_nav_view.dart';

/// Application Route Definitions.
///
/// Register all application routes here. This function is called by
/// [RouteServiceProvider.boot()] during the Magic bootstrap lifecycle.
///
/// See also: `lib/app/kernel.dart` for middleware registration.
void registerAppRoutes() {
  // Auth-protected routes with AppLayout
  MagicRoute.group(
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    middleware: ['auth'],
    layoutId: 'app',
    routes: () {
      MagicRoute.page('/', () => const DashboardView());
      MagicRoute.page('/dashboard', () => const DashboardView());
      MagicRoute.page('/projects', () => const ProjectListView());
      MagicRoute.page('/projects/create', () => const ProjectCreateView());
      MagicRoute.page(
        '/projects/:id',
        (String id) => ProjectDetailView(projectId: id),
      );
      MagicRoute.page(
        '/projects/:projectId/tasks',
        (String projectId) => TaskListView(projectId: projectId),
      );
      MagicRoute.page(
        '/projects/:projectId/tasks/create',
        (String projectId) => TaskCreateView(projectId: projectId),
      );
      MagicRoute.page(
        '/projects/:projectId/tasks/:taskId',
        (String projectId, String taskId) =>
            TaskDetailView(projectId: projectId, taskId: taskId),
      );
      MagicRoute.page(
        '/projects/:projectId/tasks/:taskId/runs/:runId',
        (String projectId, String taskId, String runId) =>
            AgentRunView(projectId: projectId, taskId: taskId, runId: runId),
      );

      // Top-level nav redirects — check current project and redirect.
      MagicRoute.page(
        '/tasks',
        () => const ProjectScopedNavView(targetPath: 'tasks'),
      );
      MagicRoute.page(
        '/knowledge',
        () => const ProjectScopedNavView(targetPath: 'knowledge'),
      );

      // Billing routes.
      MagicRoute.page('/billing', () => const BillingView());
      MagicRoute.page('/usage', () => const UsageHistoryView());

      // Settings routes.
      MagicRoute.page('/settings/ai-tokens', () => const AiTokenListView());
      MagicRoute.page('/settings/app', () => const AppSettingsView());

      // Project-scoped knowledge routes.
      MagicRoute.page(
        '/projects/:projectId/knowledge',
        (String projectId) => KnowledgeListView(projectId: projectId),
      );
      MagicRoute.page(
        '/projects/:projectId/knowledge/:documentId',
        (String projectId, String documentId) =>
            KnowledgeDetailView(projectId: projectId, documentId: documentId),
      );
    },
  );

  // MagicRoute.page('/', () => const WelcomeView()); // Replaced by DashboardView
}
