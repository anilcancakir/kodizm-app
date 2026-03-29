import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Operation className helpers
// ---------------------------------------------------------------------------

/// Returns the badge background + text className for a file [operation] code.
///
/// Supported operations:
/// - `A` — added (emerald)
/// - `M` — modified (blue)
/// - `D` — deleted (red)
/// - anything else — fallback (slate)
String operationBadgeClassName(String operation) {
  return switch (operation) {
    'A' => 'bg-emerald-500/15 text-emerald-500',
    'M' => 'bg-blue-500/15 text-blue-500',
    'D' => 'bg-red-500/15 text-red-500',
    _ => 'bg-slate-500/15 text-slate-400',
  };
}

/// Returns the human-readable i18n label for a file [operation] code.
///
/// Falls back to the raw operation string if unrecognised.
String operationLabel(String operation) {
  return switch (operation) {
    'A' => trans('conversation_chat.event_file_created'),
    'M' => trans('conversation_chat.event_file_modified'),
    'D' => trans('conversation_chat.event_file_deleted'),
    _ => operation,
  };
}

// ---------------------------------------------------------------------------
// ChatFileChangeRow widget
// ---------------------------------------------------------------------------

/// A compact row displaying a single file change event in a chat stream.
///
/// Shows a file icon, a colour-coded operation badge (A/M/D), and the
/// affected file path. Designed for inline rendering inside a chat message
/// list — not for the terminal dark view.
///
/// ## Usage
///
/// ```dart
/// ChatFileChangeRow(
///   operation: 'A',
///   filePath: 'lib/main.dart',
/// )
/// ChatFileChangeRow(
///   operation: 'M',
///   filePath: 'lib/app/models/user.dart',
/// )
/// ChatFileChangeRow(
///   operation: 'D',
///   filePath: 'test/old_test.dart',
/// )
/// ```
class ChatFileChangeRow extends StatelessWidget {
  /// Creates a [ChatFileChangeRow] for the given [operation] and [filePath].
  const ChatFileChangeRow({
    required this.operation,
    required this.filePath,
    super.key,
  });

  /// The file operation code (`A`, `M`, or `D`).
  final String operation;

  /// The path of the affected file.
  final String filePath;

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final badgeClassName = operationBadgeClassName(operation);

    return WDiv(
      className: 'flex flex-row items-center gap-2 px-3 py-1.5',
      children: [
        WIcon(Icons.insert_drive_file, className: 'text-sm text-slate-400'),
        WDiv(
          className: 'px-1.5 py-0.5 rounded $badgeClassName',
          child: WText(
            operationLabel(operation),
            className: 'text-[11px] font-bold font-mono',
          ),
        ),
        WText(
          filePath,
          className: 'text-sm font-mono text-slate-600 dark:text-slate-300',
        ),
      ],
    );
  }
}
