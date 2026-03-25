import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

/// Reusable section card — titled content card for page sections.
///
/// Matches the [MagicStarterCard] pattern: `rounded-2xl`, white background,
/// border, `p-6` padding, `gap-4` between title and content. Each section
/// (Profile Photo, Email Verification, Settings, etc.) gets its own card.
///
/// When [noPadding] is `true`, the card omits default padding so full-bleed
/// content (e.g. list rows) can span edge-to-edge. The title still receives
/// its own horizontal padding when [noPadding] is active.
///
/// ## Usage
///
/// ```dart
/// SectionCard(
///   title: 'Profile Photo',
///   children: [avatarWidget, uploadButton],
/// )
/// ```
class SectionCard extends StatelessWidget {
  /// Creates a [SectionCard] with optional [title] and [children] content.
  const SectionCard({
    required this.children,
    this.title,
    this.noPadding = false,
    super.key,
  });

  /// Optional section title — rendered as h2 (lg semibold).
  final String? title;

  /// Content widgets rendered below the title.
  final List<Widget> children;

  /// When `true`, removes default `p-6 gap-4` padding from the card body.
  ///
  /// The title (if any) always receives `px-6 pt-6 pb-3` padding so it
  /// aligns visually with row content using `px-6`.
  final bool noPadding;

  @override
  Widget build(BuildContext context) {
    final String cardClassName = noPadding
        ? '''
          w-full bg-white dark:bg-gray-800
          border border-gray-200 dark:border-gray-700
          rounded-2xl overflow-hidden flex flex-col
        '''
        : '''
          w-full bg-white dark:bg-gray-800
          border border-gray-200 dark:border-gray-700
          rounded-2xl p-6 flex flex-col gap-4
        ''';

    return WDiv(
      className: cardClassName,
      children: [
        if (title != null)
          if (noPadding)
            WDiv(
              className: 'px-6 pt-6 pb-3',
              child: WText(
                title!,
                className: '''
                  text-lg font-semibold
                  text-gray-900 dark:text-white
                ''',
              ),
            )
          else
            WText(
              title!,
              className: '''
                text-lg font-semibold
                text-gray-900 dark:text-white
              ''',
            ),
        ...children,
      ],
    );
  }
}
