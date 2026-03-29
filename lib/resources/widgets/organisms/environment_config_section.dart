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
/// Shows inherited values (from team) with a visual "(Team default)" badge.
/// Project overrides display a "Reset to team default" link that clears the
/// override and falls back to the inherited value.
///
/// ## Usage
///
/// ```dart
/// EnvironmentConfigSection(
///   environment: project.environment,
///   resolvedEnvironment: project.resolvedEnvironment,
///   teamEnvironment: team.environment,
///   runtimes: runtimesFromApi,
///   onChanged: (updated) => state.updateEnvironment(updated),
/// )
/// ```
class EnvironmentConfigSection extends StatelessWidget {
  /// Creates an [EnvironmentConfigSection].
  const EnvironmentConfigSection({
    required this.environment,
    required this.resolvedEnvironment,
    this.teamEnvironment,
    required this.runtimes,
    required this.onChanged,
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
  /// Expected shape: `{'python': ['3.12', '3.11', ...], 'node': ['22', '20', ...], ...}`.
  final Map<String, dynamic> runtimes;

  /// Called with the updated environment map when a value changes or resets.
  final ValueChanged<Map<String, dynamic>> onChanged;

  /// Whether the controls are interactive. Set to `false` for read-only mode.
  final bool enabled;

  // -------------------------------------------------------------------------
  // Runtime keys
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
  // Helpers
  // -------------------------------------------------------------------------

  /// Whether the given [key] is a project-level override (not inherited).
  bool _isOverride(String key) => environment?[key] != null;

  /// The resolved effective value for [key].
  String? _resolvedValue(String key) => resolvedEnvironment?[key]?.toString();

  /// Available version strings for a runtime [key].
  List<String> _versionsForKey(String key) {
    final raw = runtimes[key];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Builds an updated map with [key] set to [value].
  Map<String, dynamic> _withUpdate(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(environment ?? {});
    updated[key] = value;
    return updated;
  }

  /// Builds an updated map with [key] removed (reset to inherited).
  Map<String, dynamic> _withReset(String key) {
    final updated = Map<String, dynamic>.from(environment ?? {});
    updated.remove(key);
    return updated;
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
              className: 'flex flex-wrap gap-4',
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
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Runtime dropdown field
  // -------------------------------------------------------------------------

  /// Builds a single runtime version dropdown with inherited/override state.
  Widget _buildRuntimeField(String key) {
    final versions = _versionsForKey(key);
    final resolved = _resolvedValue(key);
    final isProjectOverride = _isOverride(key);
    final icon = _runtimeIcons[key] ?? Icons.code;

    return WDiv(
      className: 'w-full sm:w-[calc(50%-8px)] flex flex-col gap-2',
      children: [
        // Label row
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WIcon(icon, className: 'text-sm text-slate-400'),
            WText(
              trans('projects.environment.$key'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
          ],
        ),

        // Dropdown
        WDiv(
          className: '''
            border border-slate-200 dark:border-slate-700
            rounded-lg bg-white dark:bg-slate-900
            px-3
          ''',
          child: DropdownButton<String>(
            value: isProjectOverride ? environment![key]?.toString() : null,
            hint: WText(
              resolved != null
                  ? trans('projects.environment.using_default', {
                      'version': resolved,
                    })
                  : trans('projects.environment.version_placeholder'),
              className: 'text-sm text-slate-400',
            ),
            underline: const WSpacer(className: 'h-0 w-0'),
            onChanged: enabled
                ? (value) {
                    if (value != null) {
                      onChanged(_withUpdate(key, value));
                    }
                  }
                : null,
            items: [
              for (final version in versions)
                DropdownMenuItem<String>(
                  value: version,
                  child: WText(version, className: 'text-sm text-slate-700'),
                ),
            ],
          ),
        ),

        // Inherited badge OR reset link
        if (isProjectOverride)
          WAnchor(
            onTap: enabled ? () => onChanged(_withReset(key)) : null,
            child: WText(
              trans('projects.environment.reset_to_default'),
              className: 'text-xs text-blue-500 hover:text-blue-600',
            ),
          )
        else
          WText(
            trans('projects.environment.inherited'),
            className: 'text-xs text-slate-400 italic',
          ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Service toggle
  // -------------------------------------------------------------------------

  /// Builds a single service toggle row with label, description, and switch.
  Widget _buildServiceToggle(String key) {
    final i18nKey = key;
    final isProjectOverride = _isOverride(key);
    final currentValue = resolvedEnvironment?[key] as bool? ?? true;
    final icon = _serviceIcons[key] ?? Icons.miscellaneous_services_outlined;

    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-4 rounded-xl
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
              trans('projects.environment.$i18nKey'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            WText(
              trans('projects.environment.${i18nKey}_description'),
              className: 'text-xs text-slate-400',
            ),
            if (isProjectOverride)
              WAnchor(
                onTap: enabled ? () => onChanged(_withReset(key)) : null,
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
          onChanged: enabled
              ? (value) => onChanged(_withUpdate(key, value))
              : null,
          // Emerald-500 from DESIGN.md — Switch requires a Color object.
          activeThumbColor: const Color(0xFF10B981),
        ),
      ],
    );
  }
}
