import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../app/models/dashboard_data.dart';
import '../../app/models/user.dart';
import '../../app/state/dashboard_state.dart';

/// Team dashboard view — the default landing page after authentication.
///
/// Displays aggregated team metrics: balance, active runs, task breakdown,
/// recent runs, and quick-action placeholders.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/dashboard');
/// ```
class DashboardView extends StatefulWidget {
  /// Creates the [DashboardView].
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await DashboardState.instance.fetchDashboard(teamId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DashboardState.instance,
      builder: (context, _) {
        return DashboardState.instance.renderState(
          (data) => _DashboardContent(data: data),
          onLoading: const _LoadingView(),
          onError: (msg) => _ErrorView(message: msg),
          onEmpty: const _EmptyView(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Loading view
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const WDiv(
      className: 'flex items-center justify-center py-16',
      child: CircularProgressIndicator(),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          'Failed to load dashboard',
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        WText(message, className: 'text-sm text-slate-500 dark:text-slate-400'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty view
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.dashboard_outlined,
          className: 'text-4xl text-slate-400 dark:text-slate-500',
        ),
        WText(
          'No dashboard data available',
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard content
// ---------------------------------------------------------------------------

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: WDiv(
        className: 'w-full max-w-5xl mx-auto p-4 lg:p-8',
        child: WDiv(
          className: 'flex flex-col gap-6',
          children: [
            _HeaderRow(data: data),
            _StatsRow(data: data),
            _ActiveRunsSection(activeRuns: data.activeRuns),
            _TasksByStatusSection(summary: data.tasksSummary),
            _RecentRunsSection(recentRuns: data.recentRuns),
            const _QuickActionsSection(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header row
// ---------------------------------------------------------------------------

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final user = Auth.user<User>();
    final teamName = user?.currentTeam?.name ?? 'Team';

    return WDiv(
      className: 'flex flex-row items-center justify-between flex-wrap gap-3',
      children: [
        WDiv(
          className: 'flex flex-col gap-1',
          children: [
            WText(
              'Dashboard',
              className: '''
                text-2xl font-bold
                text-gray-900 dark:text-white
              ''',
            ),
            WText(
              teamName,
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
          ],
        ),
        _BalanceBadge(balance: data.balance),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Balance badge
// ---------------------------------------------------------------------------

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String colorClass;
    if (balance > 10) {
      color = const Color(0xFF10B981);
      colorClass = 'text-[#10B981]';
    } else if (balance >= 1) {
      color = const Color(0xFFF59E0B);
      colorClass = 'text-[#F59E0B]';
    } else {
      color = const Color(0xFFEF4444);
      colorClass = 'text-[#EF4444]';
    }

    return WDiv(
      className: '''
        flex flex-row items-center gap-2
        px-4 py-2 rounded-xl
        bg-slate-50 dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
      ''',
      children: [
        WIcon(
          Icons.account_balance_wallet_outlined,
          className: 'text-base $colorClass',
        ),
        WText(
          '\$${balance.toStringAsFixed(2)}',
          className: 'text-base font-bold',
          textStyle: TextStyle(color: color),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'grid grid-cols-1 md:grid-cols-3 gap-4',
      children: [
        _StatCard(
          label: 'Active Runs',
          value: data.activeRuns.length.toString(),
          icon: Icons.play_circle_outline,
        ),
        _StatCard(
          label: 'Tasks',
          value: data.tasksSummary.total.toString(),
          icon: Icons.task_alt,
          hint: data.tasksSummary.byStatus.entries
              .map((e) => '${e.value} ${e.key}')
              .join(', '),
        ),
        _StatCard(
          label: 'Monthly Usage',
          value: '\$${data.monthlyUsage.totalCostUsd.toStringAsFixed(2)}',
          icon: Icons.receipt_long_outlined,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        rounded-xl p-4
        bg-slate-50 dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
      ''',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-2',
          children: [
            WIcon(
              icon,
              className: 'text-base text-slate-400 dark:text-slate-500',
            ),
            WText(
              label,
              className: 'text-sm text-slate-500 dark:text-slate-400',
            ),
          ],
        ),
        WText(
          value,
          className: '''
            text-3xl font-bold
            text-gray-900 dark:text-white
          ''',
        ),
        if (hint != null) ...[
          const WSpacer(className: 'h-1'),
          WText(hint!, className: 'text-xs text-slate-400 dark:text-slate-500'),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active runs section
// ---------------------------------------------------------------------------

class _ActiveRunsSection extends StatelessWidget {
  const _ActiveRunsSection({required this.activeRuns});

  final List<ActiveRun> activeRuns;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        WText(
          'Active Runs',
          className: '''
            text-lg font-semibold
            text-gray-900 dark:text-white
          ''',
        ),
        if (activeRuns.isEmpty)
          WDiv(
            className: '''
              rounded-xl p-6
              bg-slate-50 dark:bg-gray-800
              border border-slate-200 dark:border-gray-700
              flex items-center justify-center
            ''',
            child: WText(
              'No active runs',
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
          )
        else
          ...activeRuns.map((run) => _ActiveRunItem(run: run)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active run item
// ---------------------------------------------------------------------------

/// Maps agent roles to their DESIGN.md brand colors.
Color _agentRoleColor(String role) {
  return switch (role.toLowerCase()) {
    'ba' => const Color(0xFF6366F1),
    'lead' => const Color(0xFF334E68),
    'dev' => const Color(0xFF14B8A6),
    'reviewer' => const Color(0xFF8B5CF6),
    'qa' => const Color(0xFF10B981),
    _ => const Color(0xFF64748B),
  };
}

class _ActiveRunItem extends StatelessWidget {
  const _ActiveRunItem({required this.run});

  final ActiveRun run;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().toUtc().difference(run.startedAt);
    final elapsedStr = _formatDuration(elapsed);
    final roleColor = _agentRoleColor(run.agentRole);

    return WDiv(
      className: '''
        rounded-xl p-4
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
        shadow-sm
        flex flex-row items-center gap-3
      ''',
      children: [
        _AgentRoleBadge(role: run.agentRole, color: roleColor),
        Expanded(
          child: WDiv(
            className: 'flex flex-col gap-1',
            children: [
              WText(
                run.taskTitle,
                className: '''
                  text-sm font-semibold
                  text-gray-900 dark:text-white
                ''',
              ),
              WText(
                '${run.status} \u00B7 $elapsedStr',
                className: 'text-xs text-slate-400 dark:text-slate-500',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agent role badge
// ---------------------------------------------------------------------------

class _AgentRoleBadge extends StatelessWidget {
  const _AgentRoleBadge({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: WText(
        role,
        className: 'text-xs font-semibold',
        textStyle: TextStyle(color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks by status section
// ---------------------------------------------------------------------------

/// Status slug to display color mapping per DESIGN.md.
Color _statusColor(String status) {
  return switch (status) {
    'draft' => const Color(0xFF94A3B8),
    'analysis' => const Color(0xFF818CF8),
    'planning' => const Color(0xFF60A5FA),
    'in_progress' => const Color(0xFFFBBF24),
    'done' => const Color(0xFF22C55E),
    'failed' => const Color(0xFFF87171),
    _ => const Color(0xFF94A3B8),
  };
}

/// Human-friendly status label.
String _statusLabel(String status) {
  return switch (status) {
    'in_progress' => 'In Progress',
    _ =>
      status.isEmpty ? status : status[0].toUpperCase() + status.substring(1),
  };
}

class _TasksByStatusSection extends StatelessWidget {
  const _TasksByStatusSection({required this.summary});

  final TasksSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.byStatus.entries.toList();
    final total = summary.total;

    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        WText(
          'Tasks by Status',
          className: '''
            text-lg font-semibold
            text-gray-900 dark:text-white
          ''',
        ),
        if (total == 0)
          WDiv(
            className: '''
              rounded-xl p-6
              bg-slate-50 dark:bg-gray-800
              border border-slate-200 dark:border-gray-700
              flex items-center justify-center
            ''',
            child: WText(
              'No tasks yet',
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
          )
        else ...[
          // Stacked horizontal bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: entries.map((entry) {
                  final fraction = entry.value / total;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(color: _statusColor(entry.key)),
                  );
                }).toList(),
              ),
            ),
          ),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor(entry.key),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const WSpacer(className: 'w-1'),
                  WText(
                    '${_statusLabel(entry.key)} (${entry.value})',
                    className: 'text-xs text-slate-500',
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent runs section
// ---------------------------------------------------------------------------

class _RecentRunsSection extends StatelessWidget {
  const _RecentRunsSection({required this.recentRuns});

  final List<RecentRun> recentRuns;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        WText(
          'Recent Runs',
          className: '''
            text-lg font-semibold
            text-gray-900 dark:text-white
          ''',
        ),
        if (recentRuns.isEmpty)
          WDiv(
            className: '''
              rounded-xl p-6
              bg-slate-50 dark:bg-gray-800
              border border-slate-200 dark:border-gray-700
              flex items-center justify-center
            ''',
            child: WText(
              'No recent runs',
              className: 'text-sm text-slate-400 dark:text-slate-500',
            ),
          )
        else
          ...recentRuns.map((run) => _RecentRunItem(run: run)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent run item
// ---------------------------------------------------------------------------

class _RecentRunItem extends StatelessWidget {
  const _RecentRunItem({required this.run});

  final RecentRun run;

  @override
  Widget build(BuildContext context) {
    final roleColor = _agentRoleColor(run.agentRole);
    final durationStr = run.durationMs != null
        ? _formatDuration(Duration(milliseconds: run.durationMs!))
        : '--';

    return WDiv(
      className: '''
        rounded-xl p-4
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
        shadow-sm
        flex flex-row items-center gap-3
      ''',
      children: [
        _AgentRoleBadge(role: run.agentRole, color: roleColor),
        Expanded(
          child: WDiv(
            className: 'flex flex-col gap-1',
            children: [
              WText(
                run.taskTitle,
                className: '''
                  text-sm font-semibold
                  text-gray-900 dark:text-white
                ''',
              ),
              WDiv(
                className: 'flex flex-row items-center gap-2',
                children: [
                  _StatusBadge(status: run.status),
                  WText(
                    '\$${run.costUsd.toStringAsFixed(2)}',
                    className: 'text-xs text-slate-400 dark:text-slate-500',
                  ),
                  WText(
                    durationStr,
                    className: 'text-xs text-slate-400 dark:text-slate-500',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: WText(
        _statusLabel(status),
        className: 'font-semibold',
        textStyle: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions section
// ---------------------------------------------------------------------------

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        WText(
          'Quick Actions',
          className: '''
            text-lg font-semibold
            text-gray-900 dark:text-white
          ''',
        ),
        WDiv(
          className: 'flex flex-row gap-3 flex-wrap',
          children: [
            _DisabledActionButton(
              label: 'Create Task',
              icon: Icons.add_task,
              tooltip: 'Coming in Wave 3',
            ),
            _DisabledActionButton(
              label: 'BA Chat',
              icon: Icons.chat_outlined,
              tooltip: 'Coming in Wave 5',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disabled action button
// ---------------------------------------------------------------------------

class _DisabledActionButton extends StatelessWidget {
  const _DisabledActionButton({
    required this.label,
    required this.icon,
    required this.tooltip,
  });

  final String label;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: 0.5,
        child: WDiv(
          className: '''
            flex flex-row items-center gap-2
            px-4 py-2 rounded-xl
            bg-amber-400
            cursor-not-allowed
          ''',
          children: [
            WIcon(icon, className: 'text-base text-primary'),
            WText(label, className: 'text-sm font-semibold text-primary'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Formats a [Duration] into a human-readable string (e.g. `2h 15m`, `45s`).
String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60);
    return '${duration.inHours}h ${minutes}m';
  }
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60);
    return '${duration.inMinutes}m ${seconds}s';
  }
  return '${duration.inSeconds}s';
}
