import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// import '../resources/views/welcome_view.dart'; // Replaced by DashboardView
import '../resources/views/dashboard_view.dart';
import '../resources/views/project/project_list_view.dart';
import '../resources/views/project/project_create_view.dart';
import '../resources/views/project/project_detail_view.dart';
import '../resources/views/task/task_list_view.dart';
import '../resources/views/task/task_create_view.dart';
import '../resources/views/task/task_detail_view.dart';

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
    },
  );

  // MagicRoute.page('/', () => const WelcomeView()); // Replaced by DashboardView
}
