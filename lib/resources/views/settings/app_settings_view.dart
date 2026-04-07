import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/state/settings_state.dart';
import 'package:magic_starter/magic_starter.dart';

/// App-level settings view — theme mode, notifications, and about info.
///
/// Uses [SettingsState] for notification preferences (persisted to secure
/// storage) and [WindThemeController] via [WindTheme.of] for theme toggling
/// (no persistence in SettingsState).
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/settings');
/// ```
class AppSettingsView extends StatefulWidget {
  /// Creates the [AppSettingsView].
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  String _appVersion = '';
  String _buildNumber = '';

  SettingsState get _state => Magic.findOrPut(SettingsState.new);

  @override
  void initState() {
    super.initState();
    _state.init();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) =>
          _SettingsContent(appVersion: _appVersion, buildNumber: _buildNumber),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings content
// ---------------------------------------------------------------------------

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.appVersion, required this.buildNumber});

  final String appVersion;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('settings.title'),
          subtitle: trans('settings.subtitle'),
        ),
        _AppearanceCard(),
        if (!kIsWeb) _NotificationsCard(),
        _AboutCard(appVersion: appVersion, buildNumber: buildNumber),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance section card
// ---------------------------------------------------------------------------

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final controller = WindTheme.of(context);
    final isSystem = controller.data.syncWithSystem;
    final isDark = !isSystem && controller.brightness == Brightness.dark;
    final isLight = !isSystem && controller.brightness == Brightness.light;

    return MagicStarterCard(
      title: trans('settings.appearance'),
      child: WDiv(
        className: 'flex flex-col gap-3',
        children: [
          WText(
            trans('settings.theme_mode'),
            className: 'text-sm font-medium text-slate-700 dark:text-slate-300',
          ),
          WDiv(
            className: 'flex flex-row gap-2',
            children: [
              _ThemeChip(
                label: trans('settings.theme_light'),
                isActive: isLight,
                onTap: () {
                  WindTheme.of(
                    context,
                  ).updateTheme(brightness: Brightness.light);
                },
              ),
              _ThemeChip(
                label: trans('settings.theme_dark'),
                isActive: isDark,
                onTap: () {
                  WindTheme.of(
                    context,
                  ).updateTheme(brightness: Brightness.dark);
                },
              ),
              _ThemeChip(
                label: trans('settings.theme_system'),
                isActive: isSystem,
                onTap: () => WindTheme.of(context).resetToSystem(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme chip atom
// ---------------------------------------------------------------------------

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String chipClassName = isActive
        ? 'px-4 py-2 rounded-lg bg-amber-400'
        : 'px-4 py-2 rounded-lg bg-slate-100 dark:bg-gray-700';

    final String textClassName = isActive
        ? 'text-sm font-medium text-primary-900'
        : 'text-sm font-medium text-slate-600 dark:text-slate-300';

    return WAnchor(
      onTap: onTap,
      child: WDiv(
        className: chipClassName,
        child: WText(label, className: textClassName),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications section card
// ---------------------------------------------------------------------------

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context) {
    final state = Magic.findOrPut(SettingsState.new);

    return MagicStarterCard(
      title: trans('settings.notifications'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          _NotificationToggle(
            label: trans('settings.notify_run_completed'),
            value: state.notifyRunCompleted,
            onChanged: (val) =>
                state.setNotificationPref(SettingsState.keyRunCompleted, val),
          ),
          _NotificationToggle(
            label: trans('settings.notify_run_failed'),
            value: state.notifyRunFailed,
            onChanged: (val) =>
                state.setNotificationPref(SettingsState.keyRunFailed, val),
          ),
          _NotificationToggle(
            label: trans('settings.notify_question_pending'),
            value: state.notifyQuestionPending,
            onChanged: (val) => state.setNotificationPref(
              SettingsState.keyQuestionPending,
              val,
            ),
          ),
          _NotificationToggle(
            label: trans('settings.notify_balance_low'),
            value: state.notifyBalanceLow,
            onChanged: (val) =>
                state.setNotificationPref(SettingsState.keyBalanceLow, val),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification toggle row
// ---------------------------------------------------------------------------

class _NotificationToggle extends StatelessWidget {
  const _NotificationToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center justify-between py-2',
      children: [
        WText(label, className: 'text-sm text-slate-700 dark:text-slate-300'),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          // amber-400 from DESIGN.md — Switch.adaptive requires Color parameters.
          activeThumbColor: WindTheme.dataOf(
            context,
          ).getColor('secondary', 400),
          activeTrackColor: WindTheme.dataOf(
            context,
          ).getColor('secondary', 200),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// About section card
// ---------------------------------------------------------------------------

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.appVersion, required this.buildNumber});

  final String appVersion;
  final String buildNumber;

  @override
  Widget build(BuildContext context) {
    return MagicStarterCard(
      title: trans('settings.about'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          _InfoRow(
            label: trans('settings.app_version'),
            value: appVersion.isEmpty ? '–' : appVersion,
          ),
          _InfoRow(
            label: trans('settings.build_number'),
            value: buildNumber.isEmpty ? '–' : buildNumber,
          ),
          _InfoRow(
            label: trans('settings.api_server'),
            value: env('API_URL', ''),
          ),
          const WSpacer(className: 'h-2'),
          _LinkRow(label: trans('settings.terms'), url: env('TERMS_URL', '')),
          _LinkRow(
            label: trans('settings.privacy'),
            url: env('PRIVACY_URL', ''),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row — label + value pair
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-row items-center justify-between py-1',
      children: [
        WText(label, className: 'text-sm text-slate-500 dark:text-slate-400'),
        WText(
          value,
          className: 'text-sm font-medium text-slate-800 dark:text-slate-200',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Link row — label that opens a URL
// ---------------------------------------------------------------------------

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () => Launch.url(url),
      child: WDiv(
        className: 'flex flex-row items-center justify-between py-2',
        children: [
          WText(
            label,
            className: 'text-sm font-medium text-primary dark:text-amber-400',
          ),
          WIcon(
            Icons.open_in_new,
            className: 'text-sm text-slate-400 dark:text-slate-500',
          ),
        ],
      ),
    );
  }
}
