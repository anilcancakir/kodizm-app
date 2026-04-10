import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/agent_role.dart';
import '../../../app/models/project.dart';
import '../../../app/state/project_state.dart';

// ---------------------------------------------------------------------------
// PipelineConfigSection
// ---------------------------------------------------------------------------

/// Organism widget that displays pipeline auto-advance configuration for a
/// project.
///
/// Shows an enable/disable toggle, a max-retries input, and a save button.
/// Changes are accumulated locally and persisted via [onSave].
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
  late int _maxRetries;
  late String _agentRole;
  final _retriesController = TextEditingController();
  bool _saving = false;
  bool _rolesLoading = false;
  List<AgentRole> _roles = [];

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _syncFromProject();
    _fetchAgentRoles();
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
    _agentRole = (config?['agent_role'] as String?) ?? 'main-agent';
    _retriesController.text = _maxRetries.toString();
  }

  /// Fetches available agent roles for the project's team.
  Future<void> _fetchAgentRoles() async {
    final teamId = widget.project.teamId;
    if (teamId == null) return;

    setState(() => _rolesLoading = true);

    try {
      final response = await Http.get('/teams/$teamId/agent-roles');
      if (!response.successful) return;

      final rawData = response.data['data'];
      if (rawData is! List) return;

      final roles = rawData
          .whereType<Map<String, dynamic>>()
          .map(AgentRole.fromMap)
          .toList();

      if (mounted) {
        setState(() => _roles = roles);
      }
    } catch (_) {
      // Silently handle fetch failures (network, parse errors).
      return;
    } finally {
      if (mounted) {
        setState(() => _rolesLoading = false);
      }
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
      'agent_role': _agentRole,
    };
  }

  /// Whether local state differs from the project's persisted config.
  bool get _hasChanges {
    final config = widget.project.pipelineConfig;
    final currentEnabled = (config?['enabled'] as bool?) ?? false;
    final currentRetries = (config?['max_retries'] as int?) ?? 3;
    final currentRole = (config?['agent_role'] as String?) ?? 'main-agent';

    if (_enabled != currentEnabled) return true;
    if (_maxRetries != currentRetries) return true;
    if (_agentRole != currentRole) return true;

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
        // Max retries row (animated expand when enabled)
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

              // Agent role
              _buildAgentRoleRow(),

              // Max retries
              _buildMaxRetriesRow(),

              // Divider
              WDiv(
                className:
                    'border-b border-slate-200 dark:border-slate-700 mt-1',
              ),
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
  // Agent role row
  // -------------------------------------------------------------------------

  /// Builds the agent role selector row.
  Widget _buildAgentRoleRow() {
    return WDiv(
      className: '''
        flex flex-row items-center gap-4
        p-3 rounded-xl
        bg-slate-50 dark:bg-slate-800/50
      ''',
      children: [
        WIcon(
          Icons.manage_accounts_outlined,
          className: 'text-lg text-slate-400',
        ),
        WDiv(
          className: 'flex-1 flex flex-col gap-0.5',
          children: [
            WText(
              trans('projects.pipeline.agent_role'),
              className:
                  'text-sm font-medium text-slate-700 dark:text-slate-200',
            ),
            WText(
              trans('projects.pipeline.agent_role_description'),
              className: 'text-xs text-slate-400',
            ),
          ],
        ),
        if (_rolesLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          DropdownButton<String>(
            value: _roles.any((r) => r.slug == _agentRole) ? _agentRole : null,
            underline: const SizedBox.shrink(),
            items: _roles
                .map(
                  (r) => DropdownMenuItem<String>(
                    value: r.slug,
                    child: Text(r.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _agentRole = value);
              }
            },
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
