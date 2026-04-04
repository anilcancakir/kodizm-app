import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../interceptors/debug_interceptor.dart';
import '../models/user.dart';
import '../services/websocket_service.dart';
import '../state/project_repository_state.dart';
import '../state/skill_state.dart';

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
    );

    // Magic Starter: Logout callback.
    MagicStarter.useLogout(() async {
      await Auth.logout();
      MagicRoute.to(MagicStarterConfig.loginRoute());
    });

    // Debug interceptor — logs all HTTP requests/responses in dev mode.
    if (kDebugMode) {
      Magic.make<NetworkDriver>('network').addInterceptor(DebugInterceptor());
    }

    // Connect WebSocket on boot so it's ready before any view subscribes.
    try {
      await Magic.make<WebSocketService>('websocket').connect();
    } catch (e) {
      Log.error('WebSocket: initial connect failed — $e');
    }

    // Register project repository state singleton.
    Magic.findOrPut(ProjectRepositoryState.new);

    // Register skill state singleton.
    Magic.findOrPut(SkillState.new);

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
