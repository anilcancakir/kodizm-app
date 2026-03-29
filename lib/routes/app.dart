import 'package:flutter/material.dart';
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
import '../resources/views/conversation/conversation_chat_view.dart';
import '../resources/views/conversation/conversation_list_view.dart';
import '../resources/views/nav/project_scoped_nav_view.dart';
import '../resources/views/session/session_detail_view.dart';
import '../resources/views/session/session_list_view.dart';

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
      MagicRoute.page(
        '/conversations',
        () => const ProjectScopedNavView(targetPath: 'conversations'),
      );

      // Session routes.
      MagicRoute.page('/sessions', () => const SessionListView());
      MagicRoute.page(
        '/sessions/:sessionId',
        (String sessionId) => SessionDetailView(sessionId: sessionId),
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

      // Project-scoped conversation routes.
      MagicRoute.page(
        '/projects/:projectId/conversations',
        (String projectId) => ConversationListView(projectId: projectId),
      );
    },
  );

  // Chat routes — responsive layout:
  // Desktop: AppLayout shell (sidebar + header) with bounded content area.
  // Mobile: bare fullscreen (chat provides its own header + input bar).
  MagicRoute.group(
    layout: (child) => _ChatLayout(child: child),
    middleware: ['auth'],
    layoutId: 'app.chat',
    routes: () {
      MagicRoute.page(
        '/projects/:projectId/chat',
        (String projectId) => ConversationChatView(projectId: projectId),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Chat Layout — responsive desktop/mobile shell
// ---------------------------------------------------------------------------

/// Responsive chat layout.
///
/// - **Desktop** (`lg`+): delegates to [MagicStarterAppLayout] via
///   `layout.app` so the sidebar and header are visible. The child is wrapped
///   in [_BoundedContent] to provide bounded height inside AppLayout's
///   `SingleChildScrollView`.
/// - **Mobile**: bare [Scaffold] + [SafeArea] — identical to the previous
///   fullscreen layout so the chat remains immersive.
class _ChatLayout extends StatelessWidget {
  const _ChatLayout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDesktop = wScreenIs(context, 'lg');

    if (isDesktop) {
      return MagicStarter.view.makeLayout(
        'layout.app',
        child: _BoundedContent(child: child),
      );
    }

    // Mobile — bare fullscreen.
    return Scaffold(
      backgroundColor: wColor(
        context,
        'gray',
        shade: 50,
        darkColorName: 'gray',
        darkShade: 950,
      ),
      body: SafeArea(child: child),
    );
  }
}

/// Provides bounded height inside AppLayout's scrollable content area.
///
/// AppLayout wraps children in `WDiv(className: 'flex-1 overflow-y-auto',
/// scrollPrimary: true)` which resolves to a [SingleChildScrollView] —
/// giving children unbounded vertical constraints. The chat view's
/// `Column` + `Expanded` layout requires bounded height, so this widget
/// constrains itself to the viewport height (screen minus top safe area,
/// since AppLayout's desktop header is `SizedBox.shrink`).
class _BoundedContent extends StatelessWidget {
  const _BoundedContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SizedBox(height: mq.size.height - mq.padding.top, child: child);
  }
}
