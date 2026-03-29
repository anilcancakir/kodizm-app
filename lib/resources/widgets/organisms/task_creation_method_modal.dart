import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// TaskCreationMethodModal
// ---------------------------------------------------------------------------

/// Modal organism for choosing how to create a task: manually or via chat
/// with a Business Analyst agent.
///
/// Returns `'manual'`, `'chat'`, or `null` (dismissed/cancelled).
///
/// ## Usage
///
/// ```dart
/// final result = await TaskCreationMethodModal.show(context);
/// if (result == 'manual') { /* navigate to form */ }
/// if (result == 'chat')   { /* open agent role picker */ }
/// ```
class TaskCreationMethodModal extends StatelessWidget {
  const TaskCreationMethodModal._();

  /// Opens the creation method picker as a dialog.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const TaskCreationMethodModal._(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;

    return MagicStarterDialogShell(
      title: trans('tasks.creation_method'),
      description: trans('tasks.create_subtitle'),
      body: WDiv(
        className: 'w-full flex flex-col gap-3',
        children: [
          // -------
          // Create Manually option
          // -------
          WAnchor(
            onTap: () => Navigator.of(context).pop('manual'),
            child: WDiv(
              className: '''
                p-4 rounded-xl border
                bg-white dark:bg-gray-800
                border-slate-200 dark:border-slate-700
                flex flex-row items-start gap-3
              ''',
              children: [
                WDiv(
                  className: '''
                    w-10 h-10 rounded-lg flex-shrink-0
                    bg-slate-100 dark:bg-slate-700
                    flex items-center justify-center
                  ''',
                  child: WIcon(
                    Icons.edit_note_outlined,
                    className: 'text-xl text-slate-500 dark:text-slate-400',
                  ),
                ),
                WDiv(
                  className: 'flex-1 flex flex-col gap-0.5',
                  children: [
                    WText(
                      trans('tasks.create_manually'),
                      className:
                          'text-sm font-semibold text-slate-800 dark:text-slate-100',
                    ),
                    WText(
                      trans('tasks.create_manually_desc'),
                      className:
                          'text-xs text-slate-500 dark:text-slate-400 leading-relaxed',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // -------
          // Chat with BA option
          // -------
          WAnchor(
            onTap: () => Navigator.of(context).pop('chat'),
            child: WDiv(
              className: '''
                p-4 rounded-xl border
                bg-amber-400/10 dark:bg-amber-400/10
                border-amber-400/30 dark:border-amber-400/30
                flex flex-row items-start gap-3
              ''',
              children: [
                WDiv(
                  className: '''
                    w-10 h-10 rounded-lg flex-shrink-0
                    bg-amber-400/20 dark:bg-amber-400/20
                    flex items-center justify-center
                  ''',
                  child: WIcon(
                    Icons.smart_toy_outlined,
                    className: 'text-xl text-amber-600 dark:text-amber-400',
                  ),
                ),
                WDiv(
                  className: 'flex-1 flex flex-col gap-0.5',
                  children: [
                    WText(
                      trans('tasks.chat_with_ba'),
                      className:
                          'text-sm font-semibold text-amber-600 dark:text-amber-400',
                    ),
                    WText(
                      trans('tasks.chat_with_ba_desc'),
                      className:
                          'text-xs text-slate-500 dark:text-slate-400 leading-relaxed',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row w-full justify-end',
        children: [
          WAnchor(
            onTap: () => Navigator.of(context).pop(),
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
        ],
      ),
    );
  }
}
