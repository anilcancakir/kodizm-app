import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/project.dart';
import '../../../app/state/project_state.dart';

// ---------------------------------------------------------------------------
// Stage definition
// ---------------------------------------------------------------------------

/// Internal model for a single pipeline stage row.
class _StageConfig {
  /// Creates a [_StageConfig].
  const _StageConfig({
    required this.name,
    required this.role,
    required this.labelKey,
    required this.roleKey,
  });

  /// The stage identifier sent to the API (e.g. `analysis`).
  final String name;

  /// The agent role identifier (e.g. `product-manager`).
  final String role;

  /// The i18n key for the stage display name.
  final String labelKey;

  /// The i18n key for the role display name.
  final String roleKey;
}

/// The four SDLC pipeline stages in execution order.
const _stages = [
  _StageConfig(
    name: 'analysis',
    role: 'product-manager',
    labelKey: 'projects.pipeline.stage_analysis',
    roleKey: 'projects.pipeline.role_product_manager',
  ),
  _StageConfig(
    name: 'planning',
    role: 'lead-developer',
    labelKey: 'projects.pipeline.stage_planning',
    roleKey: 'projects.pipeline.role_lead_developer',
  ),
  _StageConfig(
    name: 'implement',
    role: 'developer',
    labelKey: 'projects.pipeline.stage_implement',
    roleKey: 'projects.pipeline.role_developer',
  ),
  _StageConfig(
    name: 'review',
    role: 'code-reviewer',
    labelKey: 'projects.pipeline.stage_review',
    roleKey: 'projects.pipeline.role_code_reviewer',
  ),
];

// ---------------------------------------------------------------------------
// Agent role color className mapping
// ---------------------------------------------------------------------------

/// Returns a className pair for the agent role badge.
String _roleClassName(String role) => switch (role) {
  'product-manager' => 'bg-indigo-500/10 text-indigo-600',
  'lead-developer' => 'bg-primary-500/10 text-primary-600',
  'developer' => 'bg-teal-500/10 text-teal-600',
  'code-reviewer' => 'bg-violet-500/10 text-violet-600',
  _ => 'bg-slate-100 text-slate-500',
};

// ---------------------------------------------------------------------------
// PipelineConfigSection
// ---------------------------------------------------------------------------

/// Organism widget that displays pipeline auto-advance configuration for a
/// project.
///
/// Shows an enable/disable toggle, four SDLC stage rows with auto/pause
/// switches, a max-retries input, and a save button. Changes are accumulated
/// locally and persisted via [onSave].
///
/// ## Usage
///
/// ```dart
/// PipelineConfigSection(
///   project: selectedProject,
///   onSave: () => refreshProjectData(),
/// )
/// ```
class PipelineConfigSection extends StatefulWidget {
  /// Creates a [PipelineConfigSection].
  const PipelineConfigSection({super.key, required this.project, this.onSave});

  /// The project whose pipeline config is being edited.
  final Project project;

  /// Called after a successful save so the parent can refresh data.
  final VoidCallback? onSave;

  @override
  State<PipelineConfigSection> createState() => _PipelineConfigSectionState();
}

class _PipelineConfigSectionState extends State<PipelineConfigSection> {
  // -------------------------------------------------------------------------
  // Local state
  // -------------------------------------------------------------------------

  late bool _enabled;
  late Map<String, bool> _stageAuto;
  late int _maxRetries;
  final _retriesController = TextEditingController();
  bool _saving = false;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _syncFromProject();
  }

  @override
  void didUpdateWidget(covariant PipelineConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) {
      _syncFromProject();
    }
  }

  @override
  void dispose() {
    _retriesController.dispose();
    super.dispose();
  }

  /// Reads the current pipeline config from the project model and populates
  /// local editing state.
  void _syncFromProject() {
    final config = widget.project.pipelineConfig;
    _enabled = (config?['enabled'] as bool?) ?? false;
    _maxRetries = (config?['max_retries'] as int?) ?? 3;
    _retriesController.text = _maxRetries.toString();

    final stages = config?['stages'] as List<dynamic>?;
    _stageAuto = {};
    for (final stage in _stages) {
      bool auto = true;
      if (stages != null) {
        final match = stages.whereType<Map<String, dynamic>>().where(
          (s) => s['name'] == stage.name,
        );
        if (match.isNotEmpty) {
          auto = (match.first['auto'] as bool?) ?? true;
        }
      }
      _stageAuto[stage.name] = auto;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Builds the full config map from local state for the API payload.
  Map<String, dynamic> _buildConfig() {
    return {
      'enabled': _enabled,
      'max_retries': _maxRetries,
      'stages': [
        for (final stage in _stages)
          {
            'name': stage.name,
            'role': stage.role,
            'auto': _stageAuto[stage.name] ?? true,
          },
      ],
    };
  }

  /// Whether local state differs from the project's persisted config.
  bool get _hasChanges {
    final config = widget.project.pipelineConfig;
    final currentEnabled = (config?['enabled'] as bool?) ?? false;
    final currentRetries = (config?['max_retries'] as int?) ?? 3;

    if (_enabled != currentEnabled) return true;
    if (_maxRetries != currentRetries) return true;

    final stages = config?['stages'] as List<dynamic>?;
    for (final stage in _stages) {
      bool originalAuto = true;
      if (stages != null) {
        final match = stages.whereType<Map<String, dynamic>>().where(
          (s) => s['name'] == stage.name,
        );
        if (match.isNotEmpty) {
          originalAuto = (match.first['auto'] as bool?) ?? true;
        }
      }
      if ((_stageAuto[stage.name] ?? true) != originalAuto) return true;
    }

    return false;
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  /// Persists the current config via the project state.
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final teamId = widget.project.teamId;
      final projectId = widget.project.id;

      if (teamId == null) throw Exception('No team');

      final success = await ProjectState.instance.updatePipelineConfig(
        teamId,
        projectId,
        _buildConfig(),
      );

      if (!success) throw Exception('Save failed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans('projects.pipeline.saved')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: WindTheme.dataOf(context).getColor('emerald', 500),
          ),
        );
        widget.onSave?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trans('projects.pipeline.save_failed')),
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
              trans('projects.pipeline.title'),
              className:
                  'text-lg font-semibold text-slate-800 dark:text-slate-100',
            ),
            WSpacer(className: 'h-1'),
            WText(
              trans('projects.pipeline.subtitle'),
              className: 'text-sm text-slate-400',
            ),
          ],
        ),

        // -------
        // Enable/disable toggle
        // -------
        WDiv(
          className: 'p-6',
          children: [
            WDiv(
              className: '''
                flex flex-row items-center gap-4
                p-3 rounded-xl
                bg-slate-50 dark:bg-slate-800/50
              ''',
              children: [
                WIcon(
                  Icons.auto_mode_outlined,
                  className: 'text-lg text-slate-400',
                ),
                WDiv(
                  className: 'flex-1 flex flex-col gap-0.5',
                  children: [
                    WText(
                      trans('projects.pipeline.auto_pipeline'),
                      className: '''
                        text-sm font-medium
                        text-slate-700 dark:text-slate-200
                      ''',
                    ),
                    WText(
                      trans('projects.pipeline.auto_pipeline_description'),
                      className: 'text-xs text-slate-400',
                    ),
                  ],
                ),
                WDiv(
                  className: 'flex flex-row items-center gap-2',
                  children: [
                    WText(
                      _enabled
                          ? trans('projects.pipeline.enabled')
                          : trans('projects.pipeline.disabled'),
                      className: _enabled
                          ? 'text-xs font-medium text-emerald-600'
                          : 'text-xs font-medium text-slate-400',
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                      activeThumbColor: WindTheme.dataOf(
                        context,
                      ).getColor('emerald', 500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // -------
        // Stage rows (animated expand)
        // -------
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _enabled
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: WDiv(
            className: 'px-6 pb-6 flex flex-col gap-3',
            children: [
              // Divider
              WDiv(
                className:
                    'border-b border-slate-200 dark:border-slate-700 mb-1',
              ),

              // Stage rows
              for (final stage in _stages) _buildStageRow(stage),

              // Divider
              WDiv(
                className:
                    'border-b border-slate-200 dark:border-slate-700 mt-1',
              ),

              // Max retries
              _buildMaxRetriesRow(),
            ],
          ),
          secondChild: const WSpacer(className: 'h-0'),
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
              child: WText(trans('projects.pipeline.save')),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Stage row
  // -------------------------------------------------------------------------

  /// Builds a single stage configuration row.
  Widget _buildStageRow(_StageConfig stage) {
    final isAuto = _stageAuto[stage.name] ?? true;

    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-3 rounded-xl
        bg-slate-50 dark:bg-slate-800/50
      ''',
      children: [
        // Stage name + role badge
        WDiv(
          className: 'flex-1 flex flex-col gap-1',
          children: [
            WText(
              trans(stage.labelKey),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            WDiv(
              className: 'flex flex-row items-center gap-2',
              children: [
                WDiv(
                  className:
                      'px-2 py-0.5 rounded-full ${_roleClassName(stage.role)}',
                  child: WText(
                    trans(stage.roleKey),
                    className: 'text-xs font-medium',
                  ),
                ),
              ],
            ),
          ],
        ),

        // Auto/Pause label + toggle
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WText(
              isAuto
                  ? trans('projects.pipeline.auto_advance')
                  : trans('projects.pipeline.pause_for_approval'),
              className: isAuto
                  ? 'text-xs font-medium text-emerald-600'
                  : 'text-xs font-medium text-amber-600',
            ),
            Switch(
              value: isAuto,
              onChanged: (value) {
                setState(() {
                  _stageAuto[stage.name] = value;
                });
              },
              activeThumbColor: WindTheme.dataOf(
                context,
              ).getColor('emerald', 500),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Max retries row
  // -------------------------------------------------------------------------

  /// Builds the max retries configuration row.
  Widget _buildMaxRetriesRow() {
    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-3 rounded-xl
        bg-slate-50 dark:bg-slate-800/50
      ''',
      children: [
        WIcon(Icons.replay_outlined, className: 'text-lg text-slate-400'),
        WDiv(
          className: 'flex-1 flex flex-col gap-0.5',
          children: [
            WText(
              trans('projects.pipeline.max_retries'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            WText(
              trans('projects.pipeline.max_retries_description'),
              className: 'text-xs text-slate-400',
            ),
          ],
        ),
        SizedBox(
          width: 80,
          child: WFormInput(
            controller: _retriesController,
            className: '''
              px-3 py-2 rounded-lg text-sm text-center
              bg-white dark:bg-slate-900
              text-slate-700 dark:text-slate-200
              border border-slate-200 dark:border-slate-700
            ''',
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed >= 0 && parsed <= 10) {
                setState(() => _maxRetries = parsed);
              }
            },
          ),
        ),
      ],
    );
  }
}
