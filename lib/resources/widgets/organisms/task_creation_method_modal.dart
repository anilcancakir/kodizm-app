import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// TaskCreationMethodModal
// ---------------------------------------------------------------------------

/// Modal organism for choosing how to create a task: manually or via chat
/// with a Business Analyst agent.
///
/// Displays two selectable option cards. The user taps to highlight, then
/// confirms with the "Next" button — matching the [AgentRolePickerModal]
/// interaction pattern.
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
class TaskCreationMethodModal extends StatefulWidget {
  const TaskCreationMethodModal._();

  /// Opens the creation method picker as a dialog.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const TaskCreationMethodModal._(),
    );
  }

  @override
  State<TaskCreationMethodModal> createState() =>
      _TaskCreationMethodModalState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _TaskCreationMethodModalState extends State<TaskCreationMethodModal> {
  /// The currently selected method — `'manual'` or `'chat'`.
  /// Defaults to `'chat'` (Chat with Agent).
  String? _selected = 'chat';

  /// Whether the confirm button should accept taps.
  bool get _canConfirm => _selected != null;

  /// Closes the dialog, returning the selected method.
  void _onConfirm() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(_selected);
  }

  /// Closes the dialog without a selection.
  void _onCancel() => Navigator.of(context).pop();

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;

    return MagicStarterDialogShell(
      title: trans('tasks.creation_method'),
      description: trans('tasks.create_subtitle'),
      body: WDiv(
        className: 'w-full flex flex-col gap-3',
        children: [
          _buildOption(
            key: 'manual',
            icon: Icons.edit_note_outlined,
            title: trans('tasks.create_manually'),
            description: trans('tasks.create_manually_desc'),
          ),
          _buildOption(
            key: 'chat',
            icon: Icons.smart_toy_outlined,
            title: trans('tasks.chat_with_ba'),
            description: trans('tasks.chat_with_ba_desc'),
          ),
        ],
      ),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: _onCancel,
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          WAnchor(
            onTap: _canConfirm ? _onConfirm : null,
            child: WDiv(
              className: _canConfirm
                  ? '''
                      px-4 py-2 rounded-lg
                      bg-amber-400 text-primary-900
                      text-sm font-medium
                    '''
                  : '''
                      px-4 py-2 rounded-lg
                      bg-amber-400 text-primary-900
                      text-sm font-medium opacity-50
                    ''',
              child: WText(trans('common.next'), className: 'text-inherit'),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Option card builder
  // -----------------------------------------------------------------------

  /// Builds a selectable option card with highlight state.
  Widget _buildOption({
    required String key,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final bool isSelected = _selected == key;
    final bool isChat = key == 'chat';

    return WAnchor(
      onTap: () => setState(() => _selected = key),
      child: WDiv(
        className: isSelected
            ? '''
                p-4 rounded-xl border
                bg-amber-400/10 dark:bg-amber-400/10
                border-amber-400 dark:border-amber-400
                flex flex-row items-start gap-3
              '''
            : '''
                p-4 rounded-xl border
                bg-white dark:bg-gray-800
                border-slate-200 dark:border-slate-700
                flex flex-row items-start gap-3
              ''',
        children: [
          WDiv(
            className:
                '''
              w-10 h-10 rounded-lg flex-shrink-0
              ${isChat ? 'bg-amber-400/20 dark:bg-amber-400/20' : 'bg-slate-100 dark:bg-slate-700'}
              flex items-center justify-center
            ''',
            child: WIcon(
              icon,
              className: isChat
                  ? 'text-xl text-amber-600 dark:text-amber-400'
                  : 'text-xl text-slate-500 dark:text-slate-400',
            ),
          ),
          WDiv(
            className: 'flex-1 flex flex-col gap-0.5',
            children: [
              WText(
                title,
                className: isSelected
                    ? 'text-sm font-semibold text-amber-600 dark:text-amber-400'
                    : isChat
                    ? 'text-sm font-semibold text-amber-600 dark:text-amber-400'
                    : 'text-sm font-semibold text-slate-800 dark:text-slate-100',
              ),
              WText(
                description,
                className:
                    'text-xs text-slate-500 dark:text-slate-400 leading-relaxed',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
