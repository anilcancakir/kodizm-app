import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Compact version badge for the sidebar footer — toggles between App and API
/// info on tap.
///
/// Displays real version + formatted build date from `.env` (App) or
/// `/health` endpoint (API). Single tap switches the displayed source;
/// long-press navigates to `/settings/app`.
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
  /// `true` = showing App info, `false` = showing API info.
  bool _showApp = true;

  String _appCommit = '';
  String _appBuildDate = '';

  String _apiCommit = '';
  String _apiBuildDate = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadApiHealth();
  }

  // -----------------------------------------------------------------------
  // Data loaders
  // -----------------------------------------------------------------------

  void _loadAppInfo() {
    final commitRaw = env('APP_BUILD_HASH', '');
    setState(() {
      _appCommit = commitRaw.length >= 7
          ? commitRaw.substring(0, 7)
          : commitRaw;
      _appBuildDate = _formatDate(env('APP_BUILD_DATE', ''));
    });
  }

  Future<void> _loadApiHealth() async {
    try {
      final response = await Http.get('/health');
      if (!mounted) return;
      final version = response['version'] as Map<String, dynamic>?;
      if (version == null) return;
      final commitRaw = (version['commit'] as String?) ?? '';
      setState(() {
        _apiCommit = commitRaw.length >= 7
            ? commitRaw.substring(0, 7)
            : commitRaw;
        _apiBuildDate = _formatDate((version['date'] as String?) ?? '');
      });
    } catch (_) {
      // Health endpoint unavailable — leave fields empty.
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Formats an ISO 8601 date string as `MMM d, yyyy`.
  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final dt = parsed.toUtc();
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final source = _showApp
        ? trans('sidebar.app_label')
        : trans('sidebar.api_label');
    final commit = _showApp ? _appCommit : _apiCommit;
    final buildDate = _showApp ? _appBuildDate : _apiBuildDate;

    final commitText = commit.isNotEmpty ? '$source · $commit' : source;

    final dateText = buildDate.isEmpty
        ? ''
        : trans('sidebar.build_date_label', {'date': buildDate});

    return WAnchor(
      onTap: () => setState(() => _showApp = !_showApp),
      onLongPress: () => MagicRoute.to('/settings/app'),
      child: WDiv(
        className: 'w-full px-4 py-3',
        child: WDiv(
          className: '''
            flex flex-col gap-1
            px-3 py-2 rounded-lg
            bg-primary-50/50 dark:bg-white/5
          ''',
          children: [
            WDiv(
              className: 'flex flex-row items-center gap-2',
              children: [
                WIcon(
                  _showApp ? Icons.phone_iphone : Icons.cloud_outlined,
                  className: 'text-xs text-primary-300 dark:text-slate-500',
                ),
                WText(
                  commitText,
                  className: 'text-xs text-primary-300 dark:text-slate-500',
                ),
              ],
            ),
            if (dateText.isNotEmpty)
              WText(
                dateText,
                className: '''
                  text-xs text-primary-300/70 dark:text-slate-600
                  pl-5
                ''',
              ),
          ],
        ),
      ),
    );
  }
}
