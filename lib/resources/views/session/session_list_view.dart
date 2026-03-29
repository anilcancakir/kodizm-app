import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project.dart';
import '../../../app/models/session.dart';
import '../../../app/state/project_state.dart';
import '../../../app/state/session_state.dart';

/// Session list view — displays all sessions globally with filters.
///
/// Supports filtering by project, type (autonomous/interactive/system), and
/// phase (provisioning/executing/warm/dead). Fetches sessions via
/// [SessionState.instance] on init and renders loading, empty, and content
/// states.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/sessions');
/// // or construct directly:
/// const SessionListView()
/// ```
class SessionListView extends StatefulWidget {
  /// Creates the [SessionListView].
  const SessionListView({super.key});

  @override
  State<SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends State<SessionListView> {
  SessionState get _state => Magic.findOrPut(SessionState.new);

  /// Currently selected project filter ID, or `null` for all projects.
  String? _selectedProjectId;

  /// Currently selected type filter, or `null` for all types.
  String? _selectedType;

  /// Currently selected phase filter, or `null` for all phases.
  String? _selectedPhase;

  // -----------------------------------------------------------------------
  // Filter options
  // -----------------------------------------------------------------------

  static const List<String> _typeOptions = [
    'autonomous',
    'interactive',
    'system',
  ];

  static const List<String> _phaseOptions = [
    'provisioning',
    'executing',
    'warm',
    'dead',
  ];

  // -----------------------------------------------------------------------
  // Phase badge helpers
  // -----------------------------------------------------------------------

  /// Returns the Tailwind className for a phase badge pill.
  static String _phaseBadgeClassName(String phase) {
    return switch (phase) {
      'provisioning' => 'bg-blue-500/15 text-blue-500',
      'executing' => 'bg-amber-500/15 text-amber-500',
      'warm' => 'bg-emerald-500/15 text-emerald-500',
      'dead' => 'bg-slate-500/15 text-slate-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  /// Returns the i18n translation for a phase label.
  static String _phaseLabel(String phase) {
    return switch (phase) {
      'provisioning' => trans('sessions.phase_provisioning'),
      'executing' => trans('sessions.phase_executing'),
      'warm' => trans('sessions.phase_warm'),
      'dead' => trans('sessions.phase_dead'),
      _ => phase,
    };
  }

  // -----------------------------------------------------------------------
  // Cost helpers
  // -----------------------------------------------------------------------

  /// Formats [totalCostUsd] as `$X.XX`.
  static String _formatCost(double cost) => '\$${cost.toStringAsFixed(2)}';

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// Loads sessions with the current filter selections.
  Future<void> _loadSessions() async {
    await _state.loadSessions(
      projectId: _selectedProjectId,
      type: _selectedType,
      phase: _selectedPhase,
    );
  }

  // -----------------------------------------------------------------------
  // Filter handlers
  // -----------------------------------------------------------------------

  /// Opens the project picker dialog and applies the selected project filter.
  Future<void> _pickProject() async {
    final projects = ProjectState.instance.rxState ?? const <Project>[];

    final String? picked = await showDialog<String>(
      context: context,
      builder: (_) => MagicStarterDialogShell(
        title: trans('sessions.filter_project'),
        body: ListView(
          shrinkWrap: true,
          children: [
            // "All Projects" option
            WAnchor(
              onTap: () => Navigator.of(context).pop(''),
              child: WDiv(
                className:
                    'p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-gray-800',
                child: WText(
                  trans('sessions.all_projects'),
                  className: 'text-sm text-slate-700 dark:text-slate-300',
                ),
              ),
            ),
            // Per-project options
            for (final project in projects)
              WAnchor(
                onTap: () => Navigator.of(context).pop(project.id),
                child: WDiv(
                  className:
                      'p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-gray-800',
                  child: WText(
                    project.name ?? project.id,
                    className: 'text-sm text-slate-700 dark:text-slate-300',
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return; // Dialog dismissed — no change.
    final newId = picked.isEmpty ? null : picked;
    if (newId == _selectedProjectId) return;
    setState(() => _selectedProjectId = newId);
    await _loadSessions();
  }

  /// Applies the selected type filter.
  Future<void> _selectType(String? type) async {
    if (type == _selectedType) return;
    setState(() => _selectedType = type);
    await _loadSessions();
  }

  /// Applies the selected phase filter.
  Future<void> _selectPhase(String? phase) async {
    if (phase == _selectedPhase) return;
    setState(() => _selectedPhase = phase);
    await _loadSessions();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // -----------------------------------------------------------------
        // Header
        // -----------------------------------------------------------------
        MagicStarterPageHeader(
          title: trans('sessions.title'),
          subtitle: trans('sessions.subtitle'),
        ),

        // -----------------------------------------------------------------
        // State-driven content (SectionCard with filter row + list)
        // -----------------------------------------------------------------
        ListenableBuilder(
          listenable: _state,
          builder: (context, _) {
            if (_state.isLoading) {
              return _buildLoading();
            }
            return MagicStarterCard(
              noPadding: true,
              child: WDiv(
                className: 'flex flex-col',
                children: [
                  _buildFilterRow(),
                  if (_state.sessions.isEmpty)
                    _buildEmpty()
                  else
                    _buildSessionList(_state.sessions),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Loading state
  // -----------------------------------------------------------------------

  /// Centred spinner shown while sessions are loading.
  Widget _buildLoading() {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }

  // -----------------------------------------------------------------------
  // Filter row
  // -----------------------------------------------------------------------

  /// Horizontal filter row — project picker, type dropdown, phase dropdown.
  Widget _buildFilterRow() {
    final selectedProjectName = _resolveProjectName();

    return WDiv(
      className: 'p-4 flex flex-wrap gap-3',
      children: [
        // Project picker — opens MagicStarterDialogShell
        WAnchor(
          onTap: _pickProject,
          child: WDiv(
            className: '''
              flex flex-row items-center gap-1.5
              px-3 py-1.5 rounded-lg
              border border-slate-200 dark:border-slate-700
              bg-white dark:bg-gray-800
            ''',
            children: [
              WIcon(Icons.folder_outlined, className: 'text-sm text-slate-500'),
              WText(
                selectedProjectName,
                className: 'text-sm text-slate-600 dark:text-slate-300',
              ),
              WIcon(
                Icons.arrow_drop_down,
                className: 'text-base text-slate-400',
              ),
            ],
          ),
        ),

        // Type filter dropdown
        _buildDropdown(
          label: trans('sessions.filter_type'),
          selectedValue: _selectedType,
          allLabel: trans('sessions.all_types'),
          options: _typeOptions,
          labelBuilder: (v) => trans('sessions.type_$v'),
          icon: Icons.category_outlined,
          onSelected: _selectType,
        ),

        // Phase filter dropdown
        _buildDropdown(
          label: trans('sessions.filter_phase'),
          selectedValue: _selectedPhase,
          allLabel: trans('sessions.all_phases'),
          options: _phaseOptions,
          labelBuilder: (v) => _phaseLabel(v),
          icon: Icons.timeline_outlined,
          onSelected: _selectPhase,
        ),
      ],
    );
  }

  /// Resolves the display name for the project filter button.
  String _resolveProjectName() {
    if (_selectedProjectId == null) return trans('sessions.all_projects');
    final projects = ProjectState.instance.rxState ?? const <Project>[];
    final match = projects.cast<Project?>().firstWhere(
      (p) => p?.id == _selectedProjectId,
      orElse: () => null,
    );
    return match?.name ?? _selectedProjectId!;
  }

  /// Builds a pill-shaped dropdown button that shows a popup menu.
  Widget _buildDropdown({
    required String label,
    required String? selectedValue,
    required String allLabel,
    required List<String> options,
    required String Function(String) labelBuilder,
    required IconData icon,
    required void Function(String?) onSelected,
  }) {
    final displayLabel = selectedValue != null
        ? labelBuilder(selectedValue)
        : allLabel;
    final isActive = selectedValue != null;

    return WAnchor(
      onTap: () async {
        final String? picked = await showDialog<String>(
          context: context,
          builder: (_) => MagicStarterDialogShell(
            title: label,
            body: ListView(
              shrinkWrap: true,
              children: [
                WAnchor(
                  onTap: () => Navigator.of(context).pop(''),
                  child: WDiv(
                    className:
                        'p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-gray-800',
                    child: WText(
                      allLabel,
                      className: 'text-sm text-slate-700 dark:text-slate-300',
                    ),
                  ),
                ),
                for (final option in options)
                  WAnchor(
                    onTap: () => Navigator.of(context).pop(option),
                    child: WDiv(
                      className:
                          'p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-gray-800',
                      child: WText(
                        labelBuilder(option),
                        className: 'text-sm text-slate-700 dark:text-slate-300',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) return;
        onSelected(picked.isEmpty ? null : picked);
      },
      child: WDiv(
        className: isActive
            ? '''
                flex flex-row items-center gap-1.5
                px-3 py-1.5 rounded-lg
                border border-amber-400/30
                bg-amber-400/10
              '''
            : '''
                flex flex-row items-center gap-1.5
                px-3 py-1.5 rounded-lg
                border border-slate-200 dark:border-slate-700
                bg-white dark:bg-gray-800
              ''',
        children: [
          WIcon(
            icon,
            className: isActive
                ? 'text-sm text-amber-600'
                : 'text-sm text-slate-500',
          ),
          WText(
            displayLabel,
            className: isActive
                ? 'text-sm text-amber-600 dark:text-amber-400'
                : 'text-sm text-slate-600 dark:text-slate-300',
          ),
          WIcon(Icons.arrow_drop_down, className: 'text-base text-slate-400'),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Empty state
  // -----------------------------------------------------------------------

  /// Centred empty state shown when no sessions exist.
  Widget _buildEmpty() {
    return WDiv(
      className: 'w-full flex flex-col items-center justify-center py-16 gap-4',
      children: [
        WIcon(Icons.terminal_outlined, className: 'text-4xl text-slate-300'),
        WText(
          trans('sessions.empty_title'),
          className: 'text-lg font-semibold text-slate-500',
        ),
        WText(
          trans('sessions.empty_subtitle'),
          className: 'text-sm text-slate-400',
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Session list
  // -----------------------------------------------------------------------

  /// Pull-to-refresh scrollable list of session rows.
  Widget _buildSessionList(List<Session> sessions) {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sessions.length,
        itemBuilder: (context, index) => _buildSessionRow(sessions[index]),
      ),
    );
  }

  /// A tappable row for a single [Session].
  Widget _buildSessionRow(Session session) {
    return WAnchor(
      onTap: () => MagicRoute.to('/sessions/${session.id}'),
      child: WDiv(
        className:
            'px-4 py-3 flex flex-row items-center gap-3 border-b border-slate-100',
        children: [
          // Phase badge
          WDiv(
            className:
                'px-2.5 py-1 rounded-full ${_phaseBadgeClassName(session.phase)}',
            child: WText(
              _phaseLabel(session.phase),
              className: 'text-xs font-medium',
            ),
          ),

          // Type + model text stack
          WDiv(
            className: 'flex-1 flex flex-col gap-1',
            children: [
              WText(
                '${session.type} \u2014 ${session.model ?? ''}',
                className:
                    'text-sm font-semibold text-slate-800 dark:text-white',
              ),
              WText(
                session.createdAt.toIso8601String().substring(0, 10),
                className: 'text-xs text-slate-500',
              ),
            ],
          ),

          // Cost
          WText(
            _formatCost(session.totalCostUsd),
            className: 'text-sm font-mono text-slate-600',
          ),

          // Chevron
          WIcon(Icons.chevron_right, className: 'text-lg text-slate-400'),
        ],
      ),
    );
  }
}
