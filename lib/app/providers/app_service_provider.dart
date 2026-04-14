import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../resources/widgets/molecules/sidebar_footer.dart';
import '../interceptors/debug_interceptor.dart';
import '../models/user.dart';

/// Application Service Provider.
///
/// Use this provider to bind your own services to the IoC container and
/// to perform any bootstrap logic that requires other services to be ready.
class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  void register() {
    // Broadcasting is handled by BroadcastServiceProvider (registered before
    // AppServiceProvider). No manual WebSocket singleton needed.
  }

  @override
  Future<void> boot() async {
    // Perform async bootstrap logic here.
    //
    // IMPORTANT: Call setUserFactory() so Auth.user<T>() returns your model:
    //   Auth.manager.setUserFactory((data) => User.fromMap(data));
    // Magic Starter: Register user factory for auth session restoration.
    Auth.manager.setUserFactory((data) => User.fromMap(data));
    MagicStarter.useUserModel((data) => User.fromMap(data));

    // Magic Starter: Navigation items for sidebar and mobile bottom bar.
    MagicStarter.useNavigation(
      mainItems: [
        MagicStarterNavItem(
          icon: Icons.dashboard_outlined,
          labelKey: 'nav.dashboard',
          path: MagicStarterConfig.homeRoute(),
        ),
        MagicStarterNavItem(
          icon: Icons.folder_outlined,
          labelKey: 'nav.projects',
          path: '/projects',
        ),
        MagicStarterNavItem(
          icon: Icons.task_alt_outlined,
          labelKey: 'nav.tasks',
          path: '/tasks',
        ),
        MagicStarterNavItem(
          icon: Icons.chat_outlined,
          labelKey: 'nav.conversations',
          path: '/conversations',
        ),
        MagicStarterNavItem(
          icon: Icons.auto_awesome_outlined,
          labelKey: 'nav.skills',
          path: '/skills',
        ),
        MagicStarterNavItem(
          icon: Icons.menu_book_outlined,
          labelKey: 'nav.knowledge',
          path: '/knowledge',
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
      bottomItems: [
        MagicStarterNavItem(
          icon: Icons.folder_outlined,
          labelKey: 'nav.projects',
          path: '/projects',
        ),
        MagicStarterNavItem(
          icon: Icons.task_alt_outlined,
          labelKey: 'nav.tasks',
          path: '/tasks',
        ),
        MagicStarterNavItem(
          icon: Icons.chat_outlined,
          labelKey: 'nav.conversations',
          path: '/conversations',
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
      profileMenuItems: [
        MagicStarterNavItem(
          icon: Icons.tune_outlined,
          labelKey: 'nav.settings',
          path: '/settings/app',
        ),
        MagicStarterNavItem(
          icon: Icons.link_outlined,
          labelKey: 'nav.integrations',
          path: '/settings/integrations',
        ),
      ],
    );

    // Magic Starter: Navigation theme — Kodizm brand (DESIGN.md).
    MagicStarter.useNavigationTheme(
      MagicStarterNavigationTheme(
        // Brand: Kodizm logo image instead of default app name text.
        brandBuilder: (context) => Image.asset('assets/logo.png', height: 32),
        // Active sidebar item: amber accent bg + amber text.
        activeItemClassName: '''
          active:text-secondary-600 active:bg-secondary-400/10
          dark:active:text-secondary-400 dark:active:bg-secondary-400/10
        ''',
        // Hover: subtle slate bg shift.
        hoverItemClassName: '''
          hover:bg-slate-50 hover:text-primary-600
          dark:hover:bg-white/5 dark:hover:text-slate-200
        ''',
        // Bottom nav active: amber accent.
        bottomNavActiveClassName: '''
          active:text-secondary-500
          dark:active:text-secondary-400
        ''',
        // Avatar: amber-tinted circle.
        avatarClassName: '''
          bg-secondary-400/10
          dark:bg-secondary-400/10
        ''',
        avatarTextClassName: '''
          text-sm font-bold text-secondary-600
          dark:text-secondary-400
        ''',
        // Profile dropdown avatar: amber gradient.
        dropdownAvatarClassName: '''
          bg-gradient-to-tr from-secondary-500 to-secondary-300
        ''',
      ),
    );

    // Magic Starter: Sidebar footer — compact version + environment badge.
    MagicStarter.useSidebarFooter((context) => const SidebarFooter());

    // Magic Starter: Logout callback.
    MagicStarter.useLogout(() async {
      Notify.stopPolling();
      await Notify.logoutPush();
      await Sentry.configureScope((scope) => scope.clear());
      await Echo.disconnect();
      await Auth.logout();
      MagicRoute.to(MagicStarterConfig.loginRoute());
    });

    // Sentry: Set user context after auth session restoration.
    if (Auth.check()) {
      final user = Auth.user<User>();
      await Sentry.configureScope((scope) {
        scope.setUser(
          SentryUser(
            id: Auth.id(),
            email: user?.email,
            username: user?.name,
            data: {'team_id': user?.currentTeam?.id ?? ''},
          ),
        );
        scope.setTag('team_id', user?.currentTeam?.id ?? '');
        scope.setTag('platform', kIsWeb ? 'web' : 'mobile');
        scope.setContexts('team', {
          'id': user?.currentTeam?.id ?? '',
          'name': user?.currentTeam?.name ?? '',
        });
      });
    }

    // Push notifications: re-initialize OneSignal on every auth state
    // transition to authenticated. stateNotifier bumps on setUser/logout/
    // restore, so both fresh login and session restore are covered.
    // requestPermission() runs inside the same microtask as the login
    // response callback, which preserves the originating user gesture
    // (form submit) — browsers accept the permission prompt.
    var lastPushUserId = '';
    Auth.stateNotifier.addListener(() async {
      if (!Auth.check()) {
        lastPushUserId = '';
        return;
      }
      final userId = Auth.id() ?? '';
      if (userId.isEmpty || userId == lastPushUserId) return;
      lastPushUserId = userId;
      try {
        await Notify.initializePush('user_$userId');
        await Notify.requestPushPermission();
      } catch (e) {
        Log.error('[AppServiceProvider] Push init failed: $e');
      }
    });
    // Cover the case where session is already restored before the
    // listener was attached (cached user path).
    if (Auth.check()) {
      final userId = Auth.id() ?? '';
      if (userId.isNotEmpty) {
        lastPushUserId = userId;
        try {
          await Notify.initializePush('user_$userId');
          await Notify.requestPushPermission();
        } catch (e) {
          Log.error('[AppServiceProvider] Push init failed: $e');
        }
      }
    }

    // Push notification click handler: navigate to deep link URL from
    // notification payload (set by API's toOneSignal data).
    try {
      Notify.manager.pushDriver.onNotificationClicked.listen((event) {
        final url = event.data['url'];
        if (url is String && url.isNotEmpty) {
          MagicRoute.to(url);
        }
      });
    } catch (_) {
      // Push driver not configured yet (no-op on platforms without push).
    }

    // Magic Starter: Notification type icons and colors for the dropdown.
    MagicStarter.useNotificationTypeMapper(
      (String type) => switch (type) {
        'agent_question_asked' => (
          icon: Icons.help_outline,
          colorClass: 'text-indigo-500',
        ),
        'task_completed' => (
          icon: Icons.check_circle_outline,
          colorClass: 'text-green-500',
        ),
        'task_failed' => (
          icon: Icons.error_outline,
          colorClass: 'text-red-500',
        ),
        'pipeline_stage_waiting' => (
          icon: Icons.schedule,
          colorClass: 'text-amber-500',
        ),
        _ => (icon: Icons.notifications_outlined, colorClass: 'text-slate-400'),
      },
    );

    // Sentry Dio integration — automatic HTTP performance spans, detailed
    // breadcrumbs (method, URL, status code, duration), and error capture.
    final driver = Magic.make<NetworkDriver>('network');
    if (driver is DioNetworkDriver) {
      driver.configureDriver((dio) {
        dio.addSentry(captureFailedRequests: true);
      });
    }

    // Debug interceptor — logs all HTTP requests/responses in dev mode.
    if (kDebugMode) {
      Magic.make<NetworkDriver>('network').addInterceptor(DebugInterceptor());
    }

    // BroadcastServiceProvider.boot() already calls Echo.connect() — no
    // manual WebSocket connect needed.

    // Magic Starter: Supported locale options for profile settings.
    MagicStarter.useLocaleOptions({'en': 'English'});

    // Magic Starter: Team resolver for sidebar team switcher.
    MagicStarter.useTeamResolver(
      currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
      allTeams: () =>
          User.current.allTeams.map((t) => t.toMagicStarterTeam()).toList(),
      onSwitch: (teamId) =>
          MagicStarterTeamController.instance.switchTeam(teamId),
    );
  }
}
