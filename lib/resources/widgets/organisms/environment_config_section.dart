import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Runtime key → icon mapping
// ---------------------------------------------------------------------------

const _runtimeIcons = <String, IconData>{
  'python': Icons.code,
  'node': Icons.javascript,
  'php': Icons.php,
  'ruby': Icons.diamond_outlined,
  'go': Icons.directions_run,
  'rust': Icons.settings_outlined,
  'java': Icons.coffee_outlined,
};

const _serviceIcons = <String, IconData>{
  'pg': Icons.storage_outlined,
  'redis': Icons.memory_outlined,
};

/// Organism widget that displays runtime version dropdowns and service toggles
/// for a project's environment configuration.
///
/// Accumulates changes locally and persists them via [onSave] when the user
/// taps the "Save Changes" button. Shows a snackbar on success.
///
/// ## Usage
///
/// ```dart
/// EnvironmentConfigSection(
///   environment: project.environment,
///   resolvedEnvironment: project.resolvedEnvironment,
///   runtimes: runtimesFromApi,
///   onSave: (updated) async {
///     await state.updateProject(teamId, projectId, {'environment': updated});
///   },
/// )
/// ```
class EnvironmentConfigSection extends StatefulWidget {
  /// Creates an [EnvironmentConfigSection].
  const EnvironmentConfigSection({
    required this.environment,
    required this.resolvedEnvironment,
    this.teamEnvironment,
    required this.runtimes,
    required this.onSave,
    this.enabled = true,
    super.key,
  });

  /// Raw project-level overrides. Null keys indicate inherited values.
  final Map<String, dynamic>? environment;

  /// Merged effective values after inheritance resolution.
  final Map<String, dynamic>? resolvedEnvironment;

  /// Team-level defaults used to show the "(Team default)" badge.
  final Map<String, dynamic>? teamEnvironment;

  /// Available runtime versions from the API `/environment/runtimes` endpoint.
  ///
  /// Expected shape:
  /// `{'python': ['3.12', '3.11', ...], 'node': ['22', '20', ...], ...}`.
  final Map<String, dynamic> runtimes;

  /// Called with the updated environment map when the user saves changes.
  /// Should return a [Future] that completes when the save is done.
  final Future<void> Function(Map<String, dynamic> environment) onSave;

  /// Whether the controls are interactive. Set to `false` for read-only mode.
  final bool enabled;

  @override
  State<EnvironmentConfigSection> createState() =>
      _EnvironmentConfigSectionState();
}

class _EnvironmentConfigSectionState extends State<EnvironmentConfigSection> {
  late Map<String, dynamic> _pending;
  bool _saving = false;

  // -------------------------------------------------------------------------
  // Constants
  // -------------------------------------------------------------------------

  static const _runtimeKeys = [
    'python',
    'node',
    'php',
    'ruby',
    'go',
    'rust',
    'java',
  ];

  static const _serviceKeys = ['pg', 'redis'];

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _pending = Map<String, dynamic>.from(widget.environment ?? {});
  }

  @override
  void didUpdateWidget(covariant EnvironmentConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Sync pending state when parent provides fresh data (e.g. after save).
    if (oldWidget.environment != widget.environment) {
      _pending = Map<String, dynamic>.from(widget.environment ?? {});
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Whether the given [key] is a project-level override (not inherited).
  bool _isOverride(String key) => _pending[key] != null;

  /// The resolved effective value for [key].
  String? _resolvedValue(String key) =>
      widget.resolvedEnvironment?[key]?.toString();

  /// Available version strings for a runtime [key].
  List<String> _versionsForKey(String key) {
    final raw = widget.runtimes[key];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Whether there are unsaved changes compared to the original environment.
  bool get _hasChanges {
    final original = widget.environment ?? {};
    if (_pending.length != original.length) return true;

    for (final entry in _pending.entries) {
      if (original[entry.key]?.toString() != entry.value?.toString()) {
        return true;
      }
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Updates a single key in the pending state.
  void _updateKey(String key, dynamic value) {
    setState(() {
      _pending[key] = value;
    });
  }

  /// Resets a single key back to inherited (removes from pending).
  void _resetKey(String key) {
    setState(() {
      _pending.remove(key);
    });
  }

  /// Saves the pending state via the [onSave] callback.
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await widget.onSave(_pending);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans('projects.environment.saved')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: WindTheme.dataOf(context).getColor('emerald', 500),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans('projects.environment.save_failed')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: WindTheme.dataOf(context).getColor('red', 500),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        bg-white dark:bg-slate-800
        border border-slate-200 dark:border-slate-700
        rounded-2xl shadow-sm
      ''',
      children: [
        // Section header
        WDiv(
          className: 'p-6 pb-0',
          children: [
            WText(
              trans('projects.environment.title'),
              className:
                  'text-lg font-semibold text-slate-800 dark:text-slate-100',
            ),
            WSpacer(className: 'h-1'),
            WText(
              trans('projects.environment.subtitle'),
              className: 'text-sm text-slate-400',
            ),
          ],
        ),

        // -------
        // Language Runtimes subsection
        // -------
        WDiv(
          className: 'p-6',
          children: [
            WText(
              trans('projects.environment.runtime_section'),
              className:
                  'text-sm font-semibold text-slate-600 dark:text-slate-300 mb-4',
            ),
            WDiv(
              className: 'flex flex-col gap-3',
              children: [
                for (final key in _runtimeKeys) _buildRuntimeField(key),
              ],
            ),
          ],
        ),

        // Divider
        WDiv(className: 'border-b border-slate-200 dark:border-slate-700 mx-6'),

        // -------
        // Services subsection
        // -------
        WDiv(
          className: 'p-6',
          children: [
            WText(
              trans('projects.environment.services_section'),
              className:
                  'text-sm font-semibold text-slate-600 dark:text-slate-300 mb-4',
            ),
            WDiv(
              className: 'flex flex-col gap-3',
              children: [
                for (final key in _serviceKeys) _buildServiceToggle(key),
              ],
            ),
          ],
        ),

        // -------
        // Divider + Save button
        // -------
        WDiv(className: 'border-t border-slate-200 dark:border-slate-700 mx-6'),
        WDiv(
          className: 'w-full p-6 flex flex-row justify-end',
          children: [
            WButton(
              onTap: _hasChanges ? _save : null,
              isLoading: _saving,
              disabled: !_hasChanges,
              className: '''
                px-5 py-2 rounded-lg text-sm font-semibold
                bg-amber-400 dark:bg-amber-500
                text-primary dark:text-primary-900
                disabled:opacity-50
              ''',
              child: WText(trans('projects.environment.save')),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Runtime dropdown field
  // -------------------------------------------------------------------------

  /// Builds a single runtime version row with icon, label, dropdown, and badge.
  Widget _buildRuntimeField(String key) {
    final versions = _versionsForKey(key);
    final resolved = _resolvedValue(key);
    final isProjectOverride = _isOverride(key);
    final icon = _runtimeIcons[key] ?? Icons.code;

    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-3 rounded-xl
        bg-slate-50 dark:bg-slate-800/50
      ''',
      children: [
        // Icon
        WIcon(icon, className: 'text-lg text-slate-400'),

        // Label + inherited badge
        WDiv(
          className: 'flex-1 flex flex-col gap-0.5',
          children: [
            WText(
              trans('projects.environment.$key'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            if (isProjectOverride)
              WAnchor(
                onTap: widget.enabled ? () => _resetKey(key) : null,
                child: WText(
                  trans('projects.environment.reset_to_default'),
                  className: 'text-xs text-blue-500',
                ),
              )
            else
              WText(
                trans('projects.environment.inherited'),
                className: 'text-xs text-slate-400 italic',
              ),
          ],
        ),

        // Dropdown — constrained width
        SizedBox(
          width: 160,
          child: WFormSelect<String>(
            value: isProjectOverride ? _pending[key]?.toString() : null,
            options: [
              for (final version in versions)
                SelectOption(value: version, label: version),
            ],
            onChange: widget.enabled
                ? (value) {
                    if (value != null) {
                      _updateKey(key, value);
                    }
                  }
                : null,
            placeholder:
                resolved ?? trans('projects.environment.version_placeholder'),
            className: '''
              px-3 py-2 rounded-lg text-sm
              bg-white dark:bg-slate-900
              text-slate-700 dark:text-slate-200
              border border-slate-200 dark:border-slate-700
            ''',
            menuClassName: '''
              bg-white dark:bg-slate-900
              border border-slate-200 dark:border-slate-700
              rounded-xl shadow-xl
            ''',
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Service toggle
  // -------------------------------------------------------------------------

  /// Builds a single service toggle row with label, description, and switch.
  Widget _buildServiceToggle(String key) {
    final isProjectOverride = _isOverride(key);
    final pendingVal = _pending[key];
    final resolvedVal = widget.resolvedEnvironment?[key];
    final currentValue =
        (pendingVal is bool ? pendingVal : null) ??
        (resolvedVal is bool ? resolvedVal : null) ??
        true;
    final icon = _serviceIcons[key] ?? Icons.miscellaneous_services_outlined;

    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-3 rounded-xl
        bg-slate-50 dark:bg-slate-800/50
      ''',
      children: [
        // Icon
        WIcon(icon, className: 'text-lg text-slate-400'),

        // Label + description + inherited badge
        WDiv(
          className: 'flex-1 flex flex-col gap-1',
          children: [
            WText(
              trans('projects.environment.$key'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            WText(
              trans('projects.environment.${key}_description'),
              className: 'text-xs text-slate-400',
            ),
            if (isProjectOverride)
              WAnchor(
                onTap: widget.enabled ? () => _resetKey(key) : null,
                child: WText(
                  trans('projects.environment.reset_to_default'),
                  className: 'text-xs text-blue-500',
                ),
              )
            else
              WText(
                trans('projects.environment.inherited'),
                className: 'text-xs text-slate-400 italic',
              ),
          ],
        ),

        // Toggle
        Switch(
          value: currentValue,
          onChanged: widget.enabled ? (value) => _updateKey(key, value) : null,
          activeThumbColor: WindTheme.dataOf(context).getColor('emerald', 500),
        ),
      ],
    );
  }
}
