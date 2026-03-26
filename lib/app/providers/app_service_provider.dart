import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import '../models/user.dart';
import '../services/websocket_service.dart';

/// Application Service Provider.
///
/// Use this provider to bind your own services to the IoC container and
/// to perform any bootstrap logic that requires other services to be ready.
class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  void register() {
    // WebSocket: Pusher-compatible client for Laravel Reverb real-time events.
    app.singleton('websocket', () => WebSocketService());
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
          icon: Icons.library_books_outlined,
          labelKey: 'nav.knowledge',
          path: '/knowledge',
        ),
        MagicStarterNavItem(
          icon: Icons.account_balance_wallet_outlined,
          labelKey: 'nav.billing',
          path: '/billing',
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
      bottomItems: [
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
          icon: Icons.library_books_outlined,
          labelKey: 'nav.knowledge',
          path: '/knowledge',
        ),
        MagicStarterNavItem(
          icon: Icons.account_balance_wallet_outlined,
          labelKey: 'nav.billing',
          path: '/billing',
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
    );

    // Magic Starter: Logout callback.
    MagicStarter.useLogout(() async {
      await Auth.logout();
      MagicRoute.to(MagicStarterConfig.loginRoute());
    });

    // Connect WebSocket on boot so it's ready before any view subscribes.
    try {
      await Magic.make<WebSocketService>('websocket').connect();
    } catch (e) {
      Log.error('WebSocket: initial connect failed — $e');
    }

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
