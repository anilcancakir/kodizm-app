import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic/magic.dart';

import '../../../app/events/websocket_event.dart';
import '../../../app/models/file_change.dart';
import '../../../app/models/session.dart';
import '../../../app/models/task_run_detail.dart';
import '../../../app/models/user.dart';
import '../../../app/services/websocket_service.dart';
import '../../../app/state/agent_run_state.dart';
import '../../widgets/atoms/status_badge.dart';
import '../../widgets/molecules/model_cost_breakdown.dart';
import 'package:magic_starter/magic_starter.dart';
import '../../widgets/organisms/question_panel.dart';
import '../../widgets/organisms/terminal_event_list.dart';

// ---------------------------------------------------------------------------
// AgentRunView
// ---------------------------------------------------------------------------

/// The core agent execution detail screen — real-time terminal view with
/// WebSocket streaming, sidebar metadata, file changes, and elapsed timer.
///
/// Subscribes to WebSocket events on init and forwards them to
/// [AgentRunState]. Manages auto-scroll, elapsed timer, and responsive
/// desktop/mobile layout.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/$projectId/tasks/$taskId/runs/$runId');
/// // or construct directly:
/// AgentRunView(
///   projectId: 'proj-uuid-001',
///   taskId: 'task-uuid-001',
///   runId: 'run-uuid-001',
/// )
/// ```
class AgentRunView extends StatefulWidget {
  /// Creates an [AgentRunView] for the given [projectId], [taskId], and [runId].
  const AgentRunView({
    super.key,
    required this.projectId,
    required this.taskId,
    required this.runId,
  });

  /// The ID of the project this run belongs to.
  final String projectId;

  /// The ID of the task this run belongs to.
  final String taskId;

  /// The ID of the run to display.
  final String runId;

  @override
  State<AgentRunView> createState() => _AgentRunViewState();
}

class _AgentRunViewState extends State<AgentRunView> {
  late AgentRunState _state;
  String _teamId = '';
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _isAnswering = false;
  String _wsChannel = '';
  String? _sessionWsChannel;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _state = Magic.findOrPut<AgentRunState>(AgentRunState.new);
    _teamId = Auth.user<User>()?.currentTeam?.id ?? '';
    _wsChannel = 'private-task-run.${widget.runId}';

    _state.loadRunDetail(
      _teamId,
      widget.projectId,
      widget.taskId,
      widget.runId,
    );
    _state.loadExistingEvents(widget.runId);
    _state.loadQuestions(
      _teamId,
      widget.projectId,
      widget.taskId,
      widget.runId,
    );

    // Subscribe to WebSocket — wrapped in try-catch for test safety.
    try {
      Magic.make<WebSocketService>(
        'websocket',
      ).subscribe(_wsChannel, _state.addEvent);
    } catch (_) {
      // WS may not be connected in tests.
    }

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);

    _scrollController.addListener(_onScrollChanged);

    // Subscribe to session WS channel once session loads.
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _state.removeListener(_onStateChanged);

    try {
      Magic.make<WebSocketService>('websocket').unsubscribe(_wsChannel);
      if (_sessionWsChannel != null) {
        Magic.make<WebSocketService>(
          'websocket',
        ).unsubscribe(_sessionWsChannel!);
      }
    } catch (_) {
      // WS may not be connected in tests.
    }

    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _state.reset();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Timer
  // -----------------------------------------------------------------------

  void _onTimerTick(Timer timer) {
    if (!mounted) return;
    if (_state.runDetail == null) return;

    final status = _state.runDetail!.status;
    if (_isTerminalStatus(status)) {
      timer.cancel();
      return;
    }

    final startTime =
        _state.runDetail!.startedAt ?? _state.runDetail!.createdAt;
    setState(() {
      _elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    });
  }

  // -----------------------------------------------------------------------
  // Scroll
  // -----------------------------------------------------------------------

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;

    final atBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20;

    if (atBottom != _autoScroll) {
      setState(() => _autoScroll = atBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  // -----------------------------------------------------------------------
  // Session WS subscription
  // -----------------------------------------------------------------------

  /// React to state changes — subscribe to session WS channel when session
  /// becomes available.
  void _onStateChanged() {
    final sessionId = _state.session?.id;
    final expectedChannel = sessionId != null
        ? 'private-session.$sessionId'
        : null;

    if (expectedChannel != null && _sessionWsChannel != expectedChannel) {
      // Unsubscribe from the previous session channel if any.
      if (_sessionWsChannel != null) {
        try {
          Magic.make<WebSocketService>(
            'websocket',
          ).unsubscribe(_sessionWsChannel!);
        } catch (_) {}
      }

      _sessionWsChannel = expectedChannel;

      try {
        Magic.make<WebSocketService>(
          'websocket',
        ).subscribe(_sessionWsChannel!, _onSessionWsEvent);
      } catch (_) {
        // WS may not be connected in tests.
      }
    }
  }

  /// Handle live session WebSocket events.
  void _onSessionWsEvent(dynamic event) {
    // WebSocketEvent carries data with session fields.
    if (event is! WebSocketEvent) return;
    _state.updateSessionFromEvent(event.data);
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        if (_state.runDetail == null) {
          return _buildLoading();
        }
        return _buildContent();
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

  Widget _buildContent() {
    final runDetail = _state.runDetail!;

    // Trigger auto-scroll after build.
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-4',
      children: [
        // Header
        _buildHeader(runDetail),

        // Body — responsive (use MediaQuery to avoid LayoutBuilder Flex issues)
        if (MediaQuery.sizeOf(context).width >= 768)
          _buildDesktopBody(runDetail)
        else
          _buildMobileBody(runDetail),

        // Q&A panel — appears below terminal when agent asks a question.
        QuestionPanel(
          questions: _state.questions,
          onSubmitAnswer: _handleSubmitAnswer,
          isSubmitting: _isAnswering,
        ),

        // Footer — cancel button
        if (_isActiveStatus(runDetail.status)) _buildCancelButton(),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Header
  // -----------------------------------------------------------------------

  Widget _buildHeader(TaskRunDetail runDetail) {
    return WDiv(
      className: 'flex flex-row items-center gap-3',
      children: [
        WAnchor(
          onTap: () => MagicRoute.to(
            '/projects/${widget.projectId}/tasks/${widget.taskId}',
          ),
          child: WIcon(Icons.arrow_back, className: 'text-lg text-slate-400'),
        ),
        WText(
          trans('agent_run.title'),
          className: 'text-lg font-semibold text-slate-900 dark:text-white',
        ),
        if (runDetail.agentRoleName != null)
          WDiv(
            className:
                'px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800',
            child: WText(
              runDetail.agentRoleName!,
              className: 'text-xs text-slate-600 dark:text-slate-300',
            ),
          ),
        StatusBadge(status: runDetail.status),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Desktop body
  // -----------------------------------------------------------------------

  Widget _buildDesktopBody(TaskRunDetail runDetail) {
    return WDiv(
      className: 'flex flex-row gap-4',
      children: [
        // Left — terminal (fixed height to bound the ListView)
        WDiv(className: 'flex-1', child: _buildTerminalStack()),

        // Right — sidebar
        WDiv(
          className: 'w-80 flex flex-col gap-4',
          children: [
            _buildRunInfoCard(runDetail),
            if (_state.session != null) _buildSessionInfoCard(_state.session!),
            _buildFileChangesCard(),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Mobile body
  // -----------------------------------------------------------------------

  Widget _buildMobileBody(TaskRunDetail runDetail) {
    return WDiv(
      className: 'flex flex-col gap-4',
      children: [
        _buildRunInfoCard(runDetail),
        if (_state.session != null) _buildSessionInfoCard(_state.session!),
        _buildTerminalStack(),
        _buildFileChangesCard(),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Terminal stack (shared between desktop and mobile)
  // -----------------------------------------------------------------------

  /// Builds the terminal output panel with scroll-to-bottom FAB overlay.
  Widget _buildTerminalStack() {
    return WDiv(
      className: 'h-[500]',
      child: Stack(
        children: [
          TerminalEventList(
            events: _state.events,
            scrollController: _scrollController,
            questions: _state.questions,
          ),
          if (!_autoScroll)
            Positioned(
              bottom: 12,
              right: 12,
              child: WAnchor(
                onTap: () {
                  _scrollToBottom();
                  setState(() => _autoScroll = true);
                },
                child: WDiv(
                  className: 'p-2 rounded-full bg-slate-700/80 shadow-lg',
                  child: WIcon(
                    Icons.arrow_downward,
                    className: 'text-sm text-white',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Run info card
  // -----------------------------------------------------------------------

  Widget _buildRunInfoCard(TaskRunDetail runDetail) {
    return MagicStarterCard(
      title: trans('agent_run.run_info'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Agent
          _InfoRow(
            label: trans('agent_run.agent_role'),
            value: runDetail.agentRoleName ?? trans('common.unknown'),
          ),

          // Model
          _InfoRow(
            label: trans('agent_run.model'),
            value: runDetail.model ?? trans('common.unknown'),
          ),

          // Status
          WDiv(
            className: 'flex flex-col gap-0.5',
            children: [
              WText(
                trans('agent_run.status'),
                className:
                    'text-xs font-semibold text-slate-500 dark:text-slate-400',
              ),
              StatusBadge(status: runDetail.status),
            ],
          ),

          // Elapsed
          _InfoRow(
            label: trans('agent_run.elapsed_time'),
            value: _formatElapsed(runDetail),
          ),

          // Cost
          _InfoRow(
            label: trans('agent_run.cost'),
            value: trans('agent_run.cost_format', {
              'amount': _state.currentCost.toStringAsFixed(2),
            }),
          ),

          // Turns
          _InfoRow(
            label: trans('agent_run.turns'),
            value: _state.turnCount.toString(),
          ),

          // Session ID
          if (runDetail.sessionId != null)
            WDiv(
              className: 'flex flex-col gap-0.5',
              children: [
                WText(
                  trans('agent_run.session_id'),
                  className:
                      'text-xs font-semibold text-slate-500 dark:text-slate-400',
                ),
                WAnchor(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: runDetail.sessionId!),
                    );
                  },
                  child: WText(
                    runDetail.sessionId!,
                    className: '''
                    text-sm text-gray-800 dark:text-gray-200
                    underline decoration-dotted
                  ''',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Session info card
  // -----------------------------------------------------------------------

  Widget _buildSessionInfoCard(Session session) {
    return MagicStarterCard(
      title: trans('agent_run.cost_breakdown'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Phase badge
          WDiv(
            className: 'flex flex-col gap-0.5',
            children: [
              WText(
                trans('agent_run.session_phase'),
                className:
                    'text-xs font-semibold text-slate-500 dark:text-slate-400',
              ),
              WDiv(
                className:
                    'self-start px-2 py-0.5 rounded-full ${_phaseBadgeClassName(session.phase)}',
                child: WText(
                  trans('sessions.phase_${session.phase}'),
                  className: 'text-xs font-medium',
                ),
              ),
            ],
          ),

          // Warm until
          if (session.warmUntil != null)
            _InfoRow(
              label: trans('sessions.warm_until', {
                'time': _formatWarmUntil(session.warmUntil!),
              }),
              value: '',
            ),

          // Model cost breakdown — rendered only when records exist.
          if (session.usageRecords.isNotEmpty)
            ModelCostBreakdown(usageRecords: session.usageRecords),
        ],
      ),
    );
  }

  /// Returns className for session phase badge.
  String _phaseBadgeClassName(String phase) {
    return switch (phase) {
      'provisioning' => 'bg-blue-500/15 text-blue-500',
      'executing' => 'bg-amber-500/15 text-amber-500',
      'warm' => 'bg-emerald-500/15 text-emerald-500',
      'dead' => 'bg-slate-500/15 text-slate-500',
      _ => 'bg-slate-500/15 text-slate-500',
    };
  }

  /// Formats a [DateTime] warm_until value as HH:mm.
  String _formatWarmUntil(DateTime warmUntil) {
    final local = warmUntil.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // -----------------------------------------------------------------------
  // File changes card
  // -----------------------------------------------------------------------

  Widget _buildFileChangesCard() {
    final changes = _sortedFileChanges();

    return MagicStarterCard(
      title: trans('agent_run.file_changes_count', {
        'count': _state.fileChanges.length.toString(),
      }),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          if (changes.isEmpty)
            WText(
              trans('agent_run.no_events'),
              className: 'text-sm text-slate-400 dark:text-slate-500',
            )
          else
            for (final change in changes)
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  WDiv(
                    className:
                        'px-1.5 py-0.5 rounded ${_operationBadgeClassName(change.operation)}',
                    child: WText(
                      change.operation,
                      className: 'text-[11px] font-bold font-mono',
                    ),
                  ),
                  WDiv(
                    className: 'flex-1',
                    child: WText(
                      change.filePath,
                      className:
                          'text-sm text-gray-800 dark:text-gray-200 font-mono',
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Cancel button
  // -----------------------------------------------------------------------

  Widget _buildCancelButton() {
    return WAnchor(
      onTap: () => _showCancelDialog(),
      child: WDiv(
        className: 'self-start px-4 py-2 bg-red-500 rounded-lg',
        child: WText(
          trans('agent_run.cancel_run'),
          className: 'text-sm text-white font-medium',
        ),
      ),
    );
  }

  void _showCancelDialog() {
    MagicStarterConfirmDialog.show(
      context,
      title: trans('agent_run.cancel_confirm_title'),
      description: trans('agent_run.cancel_confirm_message'),
      confirmLabel: trans('agent_run.cancel_confirm_action'),
      variant: ConfirmDialogVariant.danger,
      onConfirm: () async {
        _state.cancelRun(
          _teamId,
          widget.projectId,
          widget.taskId,
          widget.runId,
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Submits the user's answer to the current pending question.
  Future<void> _handleSubmitAnswer(String answerText) async {
    if (_isAnswering) return;
    setState(() => _isAnswering = true);

    try {
      await _state.answerQuestion(
        _teamId,
        widget.projectId,
        widget.taskId,
        widget.runId,
        answerText,
      );
    } finally {
      if (mounted) {
        setState(() => _isAnswering = false);
      }
    }
  }

  /// Formats elapsed time — uses durationMs for terminal runs, live seconds
  /// for active runs.
  String _formatElapsed(TaskRunDetail runDetail) {
    int totalSeconds;

    if (_isTerminalStatus(runDetail.status) && runDetail.durationMs != null) {
      totalSeconds = (runDetail.durationMs! / 1000).round();
    } else {
      totalSeconds = _elapsedSeconds;
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return trans('agent_run.elapsed_format_hours', {
        'hours': hours.toString(),
        'minutes': minutes.toString(),
        'seconds': seconds.toString(),
      });
    }

    return trans('agent_run.elapsed_format_minutes', {
      'minutes': minutes.toString(),
      'seconds': seconds.toString(),
    });
  }

  /// Whether the run status is terminal (no more updates expected).
  bool _isTerminalStatus(String status) {
    return status == 'completed' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'timed_out';
  }

  /// Whether the run is in an active state that supports cancellation.
  bool _isActiveStatus(String status) {
    return status == 'running' || status == 'waiting_for_input';
  }

  /// Returns file changes sorted: A first, M second, D last.
  List<FileChange> _sortedFileChanges() {
    final changes = List<FileChange>.from(_state.fileChanges);
    changes.sort((a, b) {
      const order = {'A': 0, 'M': 1, 'D': 2};
      final orderA = order[a.operation] ?? 3;
      final orderB = order[b.operation] ?? 3;
      return orderA.compareTo(orderB);
    });
    return changes;
  }

  /// Returns className for file operation badge.
  String _operationBadgeClassName(String operation) {
    return switch (operation) {
      'A' => 'bg-emerald-500/15 text-emerald-400',
      'D' => 'bg-red-500/15 text-red-400',
      'M' => 'bg-blue-500/15 text-blue-400',
      _ => 'bg-slate-500/15 text-slate-400',
    };
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-0.5',
      children: [
        WText(
          label,
          className: 'text-xs font-semibold text-slate-500 dark:text-slate-400',
        ),
        WText(value, className: 'text-sm text-gray-800 dark:text-gray-200'),
      ],
    );
  }
}
