import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// AppDialog
// ---------------------------------------------------------------------------

/// A themed dialog shell for non-confirm dialogs (pickers, forms, detail panels).
///
/// Reads [MagicStarter.modalTheme] to apply consistent container, header,
/// body, and footer styling across the app without reimplementing
/// `MagicStarterDialogShell`.
///
/// ## Usage
///
/// ```dart
/// // Inline:
/// showDialog(
///   context: context,
///   builder: (_) => AppDialog(
///     title: 'Select Repository',
///     body: RepositoryPickerBody(onSelected: _onSelected),
///     footer: WDiv(
///       className: 'flex flex-row gap-2 justify-end',
///       children: [
///         WAnchor(onTap: () => Navigator.pop(context), child: WText('Cancel')),
///       ],
///     ),
///   ),
/// );
///
/// // Via static helper:
/// final result = await AppDialog.show<String>(
///   context: context,
///   title: 'Select Repository',
///   body: RepositoryPickerBody(onSelected: (v) => Navigator.pop(context, v)),
/// );
/// ```
class AppDialog extends StatelessWidget {
  /// Optional dialog title rendered in the sticky header.
  final String? title;

  /// Optional subtitle rendered below [title] in the header.
  final String? description;

  /// Main content area — rendered inside a scrollable body section.
  final Widget body;

  /// Optional footer widget (e.g. a row of action buttons).
  ///
  /// Callers are responsible for providing [WAnchor]-based buttons.
  final Widget? footer;

  /// Creates an [AppDialog] with the given content.
  const AppDialog({
    super.key,
    this.title,
    this.description,
    required this.body,
    this.footer,
  });

  // -----------------------------------------------------------------------
  // Static helpers
  // -----------------------------------------------------------------------

  /// The active [MagicStarterModalTheme] from [MagicStarter.modalTheme].
  ///
  /// Exposed so callers can read button className values (e.g.
  /// `AppDialog.theme.primaryButtonClassName`) when building footer widgets
  /// without importing [MagicStarter] directly.
  static MagicStarterModalTheme get theme => MagicStarter.modalTheme;

  /// Convenience wrapper around [showDialog] that presents an [AppDialog].
  ///
  /// Returns the value passed to `Navigator.pop<T>(context, value)` from
  /// within the dialog, or `null` if dismissed.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// final picked = await AppDialog.show<String>(
  ///   context: context,
  ///   title: 'Pick a value',
  ///   body: MyPickerWidget(onPick: (v) => Navigator.pop(context, v)),
  /// );
  /// ```
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? description,
    required Widget body,
    Widget? footer,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AppDialog(
        title: title,
        description: description,
        body: body,
        footer: footer,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: theme.maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: WDiv(
          className:
              '${theme.containerClassName} flex flex-col w-full overflow-hidden',
          children: [
            if (title != null || description != null)
              WDiv(
                className: theme.headerClassName,
                children: [
                  if (title != null)
                    WText(title!, className: theme.titleClassName),
                  if (description != null)
                    WText(description!, className: theme.descriptionClassName),
                ],
              ),
            WDiv(
              className: 'flex-1 overflow-y-auto',
              child: WDiv(className: theme.bodyClassName, child: body),
            ),
            if (footer != null)
              WDiv(className: theme.footerClassName, child: footer),
          ],
        ),
      ),
    );
  }
}
