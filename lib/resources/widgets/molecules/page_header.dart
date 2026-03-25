import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Reusable page header — title + subtitle + optional actions.
///
/// Matches the [MagicStarterPageHeader] pattern: full-width, `border-b`
/// separator, responsive layout, optional leading and trailing actions.
/// Used at the top of every full-page view for visual consistency.
///
/// ## Usage
///
/// ```dart
/// PageHeader(
///   title: 'Profile Settings',
///   subtitle: 'Manage your account information and preferences',
///   actions: [CreateButton()],
/// )
/// ```
class PageHeader extends StatelessWidget {
  /// Creates a [PageHeader] with [title], optional [subtitle] and [actions].
  const PageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    super.key,
  });

  /// The page title — rendered as h1 (24px bold).
  final String title;

  /// Optional descriptive subtitle — rendered in gray-600.
  final String? subtitle;

  /// Optional leading widget (e.g. back button).
  final Widget? leading;

  /// Optional trailing action widgets.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        w-full flex flex-col sm:flex-row
        items-start sm:items-center sm:justify-between
        gap-4 p-2 lg:p-4
        border-b border-gray-200 dark:border-gray-700
      ''',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-3 sm:flex-1 min-w-0',
          children: [
            ?leading,
            WDiv(
              className: 'flex flex-col gap-1 flex-1 min-w-0',
              children: [
                WText(
                  title,
                  className: '''
                    text-2xl font-bold
                    text-gray-900 dark:text-white truncate
                  ''',
                ),
                if (subtitle != null)
                  WText(
                    subtitle!,
                    className: '''
                      text-sm text-gray-600 dark:text-gray-400 truncate
                    ''',
                  ),
              ],
            ),
          ],
        ),
        if (actions != null && actions!.isNotEmpty)
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: actions!,
          ),
      ],
    );
  }
}
