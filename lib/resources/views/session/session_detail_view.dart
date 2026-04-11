import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/session.dart';
import '../../../app/models/session_share.dart';
import '../../../app/models/session_usage_record.dart';
import '../../../app/state/session_state.dart';
import '../../widgets/molecules/model_cost_breakdown.dart';
import 'package:magic_starter/magic_starter.dart';
import '../../widgets/organisms/terminal_event_list.dart';

// ---------------------------------------------------------------------------
// SessionDetailView
// ---------------------------------------------------------------------------

/// Session detail screen — cost breakdown, usage records, events, and shares.
///
/// Displays a responsive layout: desktop uses side-by-side (events left,
/// info cards right), mobile stacks vertically. Subscribes to the
/// `private-session.{id}` WebSocket channel for live phase and cost updates.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/sessions/$sessionId');
/// // or construct directly:
/// SessionDetailView(sessionId: 'sess-uuid-001')
/// ```
class SessionDetailView extends StatefulWidget {
  /// Creates a [SessionDetailView] for the given [sessionId].
  const SessionDetailView({super.key, required this.sessionId});

  /// The session UUID to display.
  final String sessionId;

  @override
  State<SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<SessionDetailView> {
  late SessionState _state;
  final ScrollController _scrollController = ScrollController();

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _state = SessionState.instance;
    _state.loadSession(widget.sessionId);
    _state.loadEvents(widget.sessionId);
    subscribeToSession();
  }

  /// Subscribes to the `private-session.{id}` WebSocket channel.
  void subscribeToSession() {
    _state.subscribeToSession(widget.sessionId);
  }

  @override
  void dispose() {
    _state.unsubscribeFromSession();
    _scrollController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.currentSession == null) {
          return _buildLoading();
        }
        return _buildContent(_state.currentSession!);
      },
    );
  }

  // -----------------------------------------------------------------------
  // Loading
  // -----------------------------------------------------------------------

  Widget _buildLoading() {
    return const WDiv(
      className: 'w-full flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }

  // -----------------------------------------------------------------------
  // Content
  // -----------------------------------------------------------------------

  Widget _buildContent(Session session) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // Header
        _buildHeader(session),

        // Body — responsive
        if (MediaQuery.sizeOf(context).width >= 768)
          _buildDesktopBody(session)
        else
          _buildMobileBody(session),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Header
  // -----------------------------------------------------------------------

  Widget _buildHeader(Session session) {
    return MagicStarterPageHeader(
      title: trans('sessions.detail_title'),
      subtitle: '${session.type} session',
      leading: WAnchor(
        onTap: () => MagicRoute.to('/sessions'),
        child: WIcon(Icons.arrow_back, className: 'text-lg text-slate-400'),
      ),
      actions: [
        // Phase badge
        WDiv(
          className:
              'px-2.5 py-1 rounded-full ${_phaseBadgeClassName(session.phase)}',
          child: WText(
            _phaseLabel(session.phase),
            className: 'text-xs font-medium',
          ),
        ),

        // Cost text
        WText(
          _formatCost(session.totalCostUsd),
          className: 'text-sm font-mono text-slate-600 dark:text-slate-300',
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Desktop body
  // -----------------------------------------------------------------------

  Widget _buildDesktopBody(Session session) {
    return WDiv(
      className: 'flex flex-row gap-4',
      children: [
        // Left — events
        WDiv(className: 'flex-1', child: _buildEventsCard()),

        // Right — sidebar
        WDiv(
          className: 'w-96 flex flex-col gap-4',
          children: [
            _buildExecutionContextCard(session),
            _buildCostBreakdownCard(session),
            _buildUsageRecordsCard(session),
            _buildSharesCard(session),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Mobile body
  // -----------------------------------------------------------------------

  Widget _buildMobileBody(Session session) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        _buildExecutionContextCard(session),
        _buildEventsCard(),
        _buildCostBreakdownCard(session),
        _buildUsageRecordsCard(session),
        _buildSharesCard(session),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Events card
  // -----------------------------------------------------------------------

  Widget _buildEventsCard() {
    return MagicStarterCard(
      title: trans('sessions.events'),
      noPadding: true,
      child: WDiv(
        className: 'h-[500]',
        child: TerminalEventList(
          events: _state.events,
          scrollController: _scrollController,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Cost breakdown card
  // -----------------------------------------------------------------------

  Widget _buildCostBreakdownCard(Session session) {
    return MagicStarterCard(
      title: trans('sessions.cost_breakdown'),
      child: ModelCostBreakdown(usageRecords: session.usageRecords),
    );
  }

  // -----------------------------------------------------------------------
  // Usage records card
  // -----------------------------------------------------------------------

  Widget _buildUsageRecordsCard(Session session) {
    return MagicStarterCard(
      title: trans('sessions.usage_records'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (session.usageRecords.isEmpty)
            WDiv(
              className: 'w-full flex items-center justify-center py-6',
              child: WText(
                trans('sessions.no_usage'),
                className: 'text-sm text-gray-400 dark:text-gray-500',
              ),
            )
          else
            for (final record in session.usageRecords)
              _buildUsageRecordRow(record),
        ],
      ),
    );
  }

  /// A single usage record row — turn number, model, tokens, subagent badge.
  Widget _buildUsageRecordRow(SessionUsageRecord record) {
    return WDiv(
      className: '''
        flex flex-row items-center gap-3
        py-2 border-b border-gray-100 dark:border-gray-800
      ''',
      children: [
        // Turn number
        WDiv(
          className: 'w-10',
          child: WText(
            '#${record.turnNumber}',
            className: 'text-xs font-mono text-slate-500',
          ),
        ),

        // Model name
        WDiv(
          className: 'flex-1',
          child: WText(
            record.model,
            className: 'text-sm font-mono text-gray-700 dark:text-gray-300',
          ),
        ),

        // Tokens (input/output)
        WText(
          '${record.inputTokens}/${record.outputTokens}',
          className: 'text-xs text-gray-500 dark:text-gray-400',
        ),

        // Subagent badge (if applicable)
        if (record.isSubagent)
          WDiv(
            className: 'px-1.5 py-0.5 rounded bg-teal-500/15',
            child: WText(
              trans('sessions.subagent'),
              className: 'text-[11px] font-medium text-teal-500',
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Shares card
  // -----------------------------------------------------------------------

  Widget _buildSharesCard(Session session) {
    return MagicStarterCard(
      title: trans('sessions.shares'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (session.shares.isEmpty)
            WDiv(
              className: 'w-full flex items-center justify-center py-6',
              child: WText(
                trans('sessions.no_usage'),
                className: 'text-sm text-gray-400 dark:text-gray-500',
              ),
            )
          else
            for (final share in session.shares) _buildShareRow(share),
        ],
      ),
    );
  }

  /// A single share row — shareable type, permission badge, unshare button.
  Widget _buildShareRow(SessionShare share) {
    return WDiv(
      className: '''
        flex flex-row items-center gap-3
        py-2 border-b border-gray-100 dark:border-gray-800
      ''',
      children: [
        // Shareable type (short form — last segment of class name)
        WDiv(
          className: 'flex-1',
          child: WText(
            _shortShareableType(share.shareableType),
            className: 'text-sm text-gray-700 dark:text-gray-300',
          ),
        ),

        // Permission badge
        WDiv(
          className:
              'px-2 py-0.5 rounded-full ${_permissionBadgeClassName(share.permission)}',
          child: WText(
            _permissionLabel(share.permission),
            className: 'text-xs font-medium',
          ),
        ),

        // Unshare button
        WAnchor(
          onTap: () => _handleUnshare(share),
          child: WIcon(Icons.close, className: 'text-sm text-slate-400'),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Execution context card
  // -----------------------------------------------------------------------

  /// Builds the execution context card showing mode, container, and workspace.
  ///
  /// Only renders rows for fields that are non-null — legacy sessions
  /// without execution context will render an empty card.
  Widget _buildExecutionContextCard(Session session) {
    return MagicStarterCard(
      title: trans('sessions.execution_context'),
      child: WDiv(
        className: 'flex flex-col gap-3',
        children: [
          if (session.executionMode != null)
            WDiv(
              className: 'flex flex-row items-center gap-3',
              children: [
                WText(
                  trans('sessions.execution_mode'),
                  className: 'text-xs text-slate-400 dark:text-slate-500 w-32',
                ),
                WDiv(
                  className:
                      'px-2 py-0.5 rounded-full ${_executionModeBadgeClassName(session.executionMode!)}',
                  child: WText(
                    _executionModeLabel(session.executionMode!),
                    className: 'text-xs font-semibold',
                  ),
                ),
              ],
            ),
          if (session.containerName != null)
            _buildInfoRow(
              trans('sessions.container_name'),
              session.containerName!,
            ),
          if (session.workspaceBranch != null)
            _buildInfoRow(
              trans('sessions.workspace_branch'),
              session.workspaceBranch!,
            ),
        ],
      ),
    );
  }

  /// Badge className for execution mode — native is green, legacy is slate.
  static String _executionModeBadgeClassName(String mode) {
    return switch (mode) {
      'native' => 'bg-green-500/10 text-green-500',
      _ => 'bg-slate-500/10 text-slate-500',
    };
  }

  /// i18n label for execution mode.
  static String _executionModeLabel(String mode) {
    return switch (mode) {
      'native' => trans('sessions.mode_native'),
      _ => trans('sessions.mode_sidecar'),
    };
  }

  /// A label-value row used in info cards.
  Widget _buildInfoRow(String label, String value) {
    return WDiv(
      className: 'flex flex-row items-center gap-3',
      children: [
        WText(
          label,
          className: 'text-xs text-slate-400 dark:text-slate-500 w-32',
        ),
        WDiv(
          className: 'flex-1',
          child: WText(
            value,
            className: 'text-sm font-mono text-slate-700 dark:text-slate-300',
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Handlers
  // -----------------------------------------------------------------------

  /// Removes a share grant from the current session.
  Future<void> _handleUnshare(SessionShare share) async {
    await _state.unshare(widget.sessionId, share.id);
    await _state.loadSession(widget.sessionId);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Returns Tailwind className for a session phase badge.
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

  /// Formats [totalCostUsd] as `$X.XX`.
  static String _formatCost(double cost) => '\$${cost.toStringAsFixed(2)}';

  /// Extracts the short class name from a fully-qualified PHP class name.
  static String _shortShareableType(String fqcn) {
    final parts = fqcn.split('\\');
    return parts.last;
  }

  /// Returns Tailwind className for a permission badge.
  static String _permissionBadgeClassName(String permission) {
    return switch (permission) {
      'read' => 'bg-blue-500/15 text-blue-500',
      'write' => 'bg-amber-500/15 text-amber-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  /// Returns the i18n translation for a permission label.
  static String _permissionLabel(String permission) {
    return switch (permission) {
      'read' => trans('sessions.read'),
      'write' => trans('sessions.write'),
      _ => permission,
    };
  }
}
