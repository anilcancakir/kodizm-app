import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/agent_role.dart';

// ---------------------------------------------------------------------------
// AgentRolePickerModal
// ---------------------------------------------------------------------------

/// Modal organism for selecting an [AgentRole] before starting a conversation.
///
/// Displays a radio-style list of roles — each row shows the role name,
/// optional description, and a scope colour indicator derived from the
/// [_scopeClassName] map. The BA role (`slug == 'ba'`) is pre-selected; when
/// no BA role is present the first role in the list is selected instead.
///
/// A single-role list still shows the modal so the user can confirm their
/// selection.
///
/// Shows a loading spinner while [roles] is empty **only** when the caller
/// passes an empty list (pre-fetching is the caller's responsibility).
/// Shows an error state when [roles] is empty at display time.
///
/// ## Usage
///
/// ```dart
/// final AgentRole? selected = await AgentRolePickerModal.show(
///   context,
///   roles,
/// );
/// if (selected != null) { /* start conversation */ }
/// ```
class AgentRolePickerModal extends StatefulWidget {
  /// Creates an [AgentRolePickerModal].
  ///
  /// [roles] must be pre-fetched by the caller before invoking [show].
  const AgentRolePickerModal._({required this.roles});

  /// The list of available agent roles to display.
  final List<AgentRole> roles;

  // -----------------------------------------------------------------------
  // Static entry point
  // -----------------------------------------------------------------------

  /// Opens the agent role picker as a dialog and returns the selected
  /// [AgentRole], or `null` if the user cancels.
  ///
  /// [roles] must be pre-fetched by the caller. An empty list triggers the
  /// error state.
  static Future<AgentRole?> show(BuildContext context, List<AgentRole> roles) {
    return showDialog<AgentRole>(
      context: context,
      builder: (_) => AgentRolePickerModal._(roles: roles),
    );
  }

  @override
  State<AgentRolePickerModal> createState() => _AgentRolePickerModalState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _AgentRolePickerModalState extends State<AgentRolePickerModal> {
  // -------

  /// The currently highlighted role.
  AgentRole? _selected;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _selected = _initialSelection(widget.roles);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Returns the BA role when present, otherwise the first role, or `null`
  /// when [roles] is empty.
  AgentRole? _initialSelection(List<AgentRole> roles) {
    if (roles.isEmpty) return null;
    try {
      return roles.firstWhere((r) => r.slug == 'ba');
    } catch (_) {
      return roles.first;
    }
  }

  /// Returns a Tailwind className pair for a given [scope] slug.
  ///
  /// Colours follow DESIGN.md agent role palette:
  /// - BA / analysis  → Indigo  (`#6366F1`)
  /// - lead           → Navy    (`#334E68`)
  /// - dev            → Teal    (`#14B8A6`)
  /// - reviewer       → Violet  (`#8B5CF6`)
  /// - qa             → Emerald (`#10B981`)
  String _scopeClassName(String scope) {
    const Map<String, String> scopeMap = {
      'ba': 'bg-indigo-500/10 text-indigo-500',
      'analysis': 'bg-indigo-500/10 text-indigo-500',
      'lead': 'bg-primary/10 text-primary-500',
      'architecture': 'bg-primary/10 text-primary-500',
      'dev': 'bg-teal-500/10 text-teal-500',
      'implementation': 'bg-teal-500/10 text-teal-500',
      'reviewer': 'bg-violet-500/10 text-violet-500',
      'review': 'bg-violet-500/10 text-violet-500',
      'qa': 'bg-emerald-500/10 text-emerald-500',
      'testing': 'bg-emerald-500/10 text-emerald-500',
    };

    final key = scope.toLowerCase();
    return scopeMap[key] ?? 'bg-slate-100 text-slate-500';
  }

  /// Returns `true` when the confirm button should accept taps.
  bool get _canConfirm => _selected != null;

  /// Closes the dialog, returning the selected role.
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
      title: trans('conversations.select_agent'),
      description: trans('conversations.select_agent_subtitle'),
      body: _buildBody(),
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
              child: WText(
                trans('conversations.start_conversation'),
                className: 'text-inherit',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the scrollable body: role list, loading state, or error state.
  Widget _buildBody() {
    if (widget.roles.isEmpty) {
      return _buildEmptyState();
    }

    return WDiv(
      className: 'w-full flex flex-col gap-1',
      children: [for (final role in widget.roles) _buildRoleRow(role)],
    );
  }

  /// Builds a single role row with radio indicator, name, description, and
  /// scope colour chip.
  Widget _buildRoleRow(AgentRole role) {
    final bool isSelected = _selected?.id == role.id;

    return WAnchor(
      onTap: () => setState(() => _selected = role),
      child: WDiv(
        className: isSelected
            ? '''
                p-3 rounded-xl
                bg-amber-400/10 border border-amber-400
                flex flex-row items-start gap-3
              '''
            : '''
                p-3 rounded-xl
                bg-slate-50 dark:bg-gray-800
                flex flex-row items-start gap-3
              ''',
        children: [
          // ----------------------------------------------------------------
          // Radio indicator
          // ----------------------------------------------------------------
          WDiv(
            className:
                '''
              w-5 h-5 rounded-full mt-0.5 flex-shrink-0
              items-center justify-center
              ${isSelected ? 'border-2 border-amber-400' : 'border-2 border-slate-300 dark:border-slate-600'}
            ''',
            child: isSelected
                ? WDiv(
                    className: '''
                      w-2.5 h-2.5 rounded-full
                      bg-amber-400
                    ''',
                  )
                : null,
          ),

          // ----------------------------------------------------------------
          // Role info
          // ----------------------------------------------------------------
          WDiv(
            className: 'flex-1 flex flex-col gap-1',
            children: [
              WText(
                role.name,
                className: isSelected
                    ? 'text-sm font-semibold text-amber-600 dark:text-amber-400'
                    : 'text-sm font-semibold text-slate-800 dark:text-slate-100',
              ),
              if (role.description != null && role.description!.isNotEmpty)
                WText(
                  role.description!,
                  className:
                      'text-xs text-slate-500 dark:text-slate-400 leading-relaxed',
                ),
            ],
          ),

          // ----------------------------------------------------------------
          // Scope colour chip
          // ----------------------------------------------------------------
          WDiv(
            className:
                '''
              px-2 py-0.5 rounded-full
              text-xs font-medium
              ${_scopeClassName(role.scope)}
            ''',
            child: WText(
              role.scope,
              className: 'text-inherit text-xs font-medium',
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the error / empty state when no roles are available.
  Widget _buildEmptyState() {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-8 gap-3',
      children: [
        WIcon(
          Icons.smart_toy_outlined,
          className: 'text-4xl text-slate-300 dark:text-slate-600',
        ),
        WText(
          trans('conversations.no_roles_available'),
          className: 'text-sm text-slate-500 dark:text-slate-400 text-center',
        ),
      ],
    );
  }
}
