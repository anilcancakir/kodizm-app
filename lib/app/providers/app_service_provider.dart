import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../interceptors/debug_interceptor.dart';
import '../interceptors/sentry_tracing_interceptor.dart';
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
          path: '/documents',
        ),
        MagicStarterNavItem(
          icon: Icons.psychology_outlined,
          labelKey: 'nav.memories',
          path: '/memories',
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

    // Magic Starter: Logout callback.
    MagicStarter.useLogout(() async {
      await Sentry.configureScope((scope) => scope.setUser(null));
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
      });
    }

    // Sentry tracing interceptor — distributed tracing headers + breadcrumbs.
    Magic.make<NetworkDriver>(
      'network',
    ).addInterceptor(SentryTracingInterceptor());

    // Sentry Dio hook — preparation point for sentry_dio SDK integration.
    //
    // SentryTracingInterceptor already handles header injection and breadcrumbs.
    // configureDriver() is the escape hatch for raw Dio access if sentry_dio
    // is added in the future (e.g., `dio.addSentry()`).
    final driver = Magic.make<NetworkDriver>('network');
    if (driver is DioNetworkDriver) {
      driver.configureDriver((dio) {
        // Hook point: add sentry_dio integration here when needed.
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
