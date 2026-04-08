import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Compact version and environment badge for the sidebar footer.
///
/// Displays the app version and current environment (e.g., "v1.0.0 · production")
/// between the navigation items and user menu in both desktop sidebar and
/// mobile drawer. Tapping navigates to the app settings view.
///
/// ## Usage
///
/// ```dart
/// MagicStarter.useSidebarFooter(
///   (context) => const SidebarFooter(),
/// );
/// ```
class SidebarFooter extends StatefulWidget {
  /// Creates the [SidebarFooter].
  const SidebarFooter({super.key});

  @override
  State<SidebarFooter> createState() => _SidebarFooterState();
}

class _SidebarFooterState extends State<SidebarFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final appEnv = env('APP_ENV', 'local');
    final versionText = _version.isEmpty
        ? trans('sidebar.env_label', {'env': appEnv})
        : '${trans('sidebar.version_label', {'version': _version})} · $appEnv';

    return WAnchor(
      onTap: () => MagicRoute.to('/settings/app'),
      child: WDiv(
        className: 'px-4 py-3',
        child: WDiv(
          className: '''
            flex flex-row items-center gap-2
            px-3 py-2 rounded-lg
            bg-primary-50/50 dark:bg-white/5
          ''',
          children: [
            WIcon(
              Icons.info_outline,
              className: 'text-xs text-primary-300 dark:text-slate-500',
            ),
            WText(
              versionText,
              className: 'text-xs text-primary-300 dark:text-slate-500',
            ),
          ],
        ),
      ),
    );
  }
}
