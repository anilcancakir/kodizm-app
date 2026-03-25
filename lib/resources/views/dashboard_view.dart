import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../app/models/dashboard_data.dart';
import '../../app/models/user.dart';
import '../../app/state/dashboard_state.dart';
import '../../app/state/project_state.dart';
import '../widgets/atoms/status_badge.dart';
import '../widgets/molecules/page_header.dart';
import '../widgets/molecules/section_card.dart';

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
      className: 'w-full flex items-center justify-center py-16',
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
          trans('dashboard.failed_to_load'),
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
          trans('dashboard.empty'),
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
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        _DashboardHeader(data: data),
        _StatsRow(data: data),
        // Two-column layout for middle sections on desktop.
        WDiv(
          className: 'w-full flex flex-row items-start gap-6 axis-max',
          children: [
            WDiv(
              className: 'flex-1',
              child: _TasksByStatusCard(summary: data.tasksSummary),
            ),
            WDiv(
              className: 'flex-1',
              child: _ActiveRunsCard(activeRuns: data.activeRuns),
            ),
          ],
        ),
        _RecentRunsCard(recentRuns: data.recentRuns),
        const _QuickActionsSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard header — uses shared PageHeader molecule
// ---------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final user = Auth.user<User>();
    final teamName = user?.currentTeam?.name ?? 'Team';

    return PageHeader(
      title: trans('nav.dashboard'),
      subtitle: teamName,
      actions: [_BalanceBadge(balance: data.balance)],
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
    final balanceClassName = balance > 10
        ? 'text-emerald-500'
        : balance >= 1
        ? 'text-amber-500'
        : 'text-red-500';

    return WDiv(
      className: '''
        flex flex-row items-center gap-2
        px-4 py-2 rounded-xl
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
        shadow-xs
      ''',
      children: [
        WIcon(
          Icons.account_balance_wallet_outlined,
          className: 'text-base $balanceClassName',
        ),
        WText(
          '\$${balance.toStringAsFixed(2)}',
          className: 'text-base font-bold $balanceClassName',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row — 3 equal-width cards
// ---------------------------------------------------------------------------

/// Maps stat card icon types to their className tokens.
String _statIconClassName(String type) {
  return switch (type) {
    'active_runs' => 'bg-amber-400/10 text-amber-400',
    'total_tasks' => 'bg-blue-500/10 text-blue-500',
    'monthly_cost' => 'bg-emerald-500/10 text-emerald-500',
    _ => 'bg-slate-500/10 text-slate-500',
  };
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full flex flex-row gap-4 axis-max',
      children: [
        WDiv(
          className: 'flex-1',
          child: _StatCard(
            label: trans('dashboard.active_runs'),
            value: data.activeRuns.length.toString(),
            icon: Icons.play_circle_outline,
            iconType: 'active_runs',
          ),
        ),
        WDiv(
          className: 'flex-1',
          child: _StatCard(
            label: trans('dashboard.total_tasks'),
            value: data.tasksSummary.total.toString(),
            icon: Icons.task_alt,
            iconType: 'total_tasks',
          ),
        ),
        WDiv(
          className: 'flex-1',
          child: _StatCard(
            label: trans('dashboard.monthly_cost'),
            value: '\$${data.monthlyUsage.totalCostUsd.toStringAsFixed(2)}',
            icon: Icons.receipt_long_outlined,
            iconType: 'monthly_cost',
          ),
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
    required this.iconType,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final String iconType;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final iconCn = _statIconClassName(iconType);

    return WDiv(
      className: '''
        rounded-xl p-5
        bg-white dark:bg-gray-800
        border border-slate-200 dark:border-gray-700
        shadow-xs
      ''',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2 mb-3',
          children: [
            WDiv(
              className: 'p-1.5 rounded-lg $iconCn',
              child: WIcon(icon, className: 'text-lg'),
            ),
            WDiv(
              className: 'flex-1 min-w-0',
              child: WText(
                label,
                className:
                    'text-sm font-medium text-slate-500 dark:text-slate-400',
              ),
            ),
          ],
        ),
        WText(
          value,
          className: 'text-3xl font-bold text-slate-900 dark:text-white',
        ),
        if (subtitle != null) ...[
          const WSpacer(className: 'h-1'),
          WText(
            subtitle!,
            className: 'text-xs text-slate-400 dark:text-slate-500',
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty section placeholder — consistent empty state inside cards
// ---------------------------------------------------------------------------

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        w-full rounded-lg py-10
        bg-slate-50 dark:bg-gray-900
        flex flex-col items-center justify-center gap-2
      ''',
      children: [
        WIcon(icon, className: 'text-2xl text-slate-300 dark:text-slate-600'),
        WText(message, className: 'text-sm text-slate-400 dark:text-slate-500'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active runs card
// ---------------------------------------------------------------------------

class _ActiveRunsCard extends StatelessWidget {
  const _ActiveRunsCard({required this.activeRuns});

  final List<ActiveRun> activeRuns;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: trans('dashboard.active_runs'),
      children: [
        if (activeRuns.isEmpty)
          _EmptySection(
            icon: Icons.play_circle_outline,
            message: trans('dashboard.no_active_runs'),
          )
        else
          WDiv(
            className: 'flex flex-col gap-3',
            children: activeRuns
                .map((run) => _ActiveRunItem(run: run))
                .toList(),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active run item
// ---------------------------------------------------------------------------

/// Maps agent roles to their DESIGN.md brand className tokens.
String _agentRoleClassName(String role) {
  return switch (role.toLowerCase()) {
    'ba' => 'bg-indigo-500/10 text-indigo-500',
    'lead' => 'bg-primary/10 text-primary',
    'dev' => 'bg-teal-500/10 text-teal-500',
    'reviewer' => 'bg-violet-500/10 text-violet-500',
    'qa' => 'bg-emerald-500/10 text-emerald-500',
    _ => 'bg-slate-500/10 text-slate-500',
  };
}

class _ActiveRunItem extends StatelessWidget {
  const _ActiveRunItem({required this.run});

  final ActiveRun run;

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().toUtc().difference(run.startedAt);
    final elapsedStr = _formatDuration(elapsed);

    return WDiv(
      className: '''
        rounded-lg p-3
        bg-slate-50 dark:bg-gray-900
        flex flex-row items-center gap-3
      ''',
      children: [
        _AgentRoleBadge(role: run.agentRole),
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col gap-1',
          children: [
            WText(
              run.taskTitle,
              className: 'text-sm font-medium text-slate-800 dark:text-white',
            ),
            WText(
              '${run.status} \u00b7 $elapsedStr',
              className: 'text-xs text-slate-400 dark:text-slate-500',
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agent role badge
// ---------------------------------------------------------------------------

class _AgentRoleBadge extends StatelessWidget {
  const _AgentRoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final cn = _agentRoleClassName(role);

    return WDiv(
      className: 'px-2 py-1 rounded-md $cn',
      child: WText(role, className: 'text-xs font-semibold'),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks by status card
// ---------------------------------------------------------------------------

/// Status slug to display color mapping per DESIGN.md.
/// Retained only for the stacked bar chart which needs dynamic [Color] values.
Color _statusColor(String status) {
  return switch (status) {
    'draft' => const Color(0xFFCBD5E1),
    'analysis' => const Color(0xFF6366F1),
    'planning' => const Color(0xFF3B82F6),
    'design' => const Color(0xFF8B5CF6),
    'in_progress' => const Color(0xFFFBBF24),
    'review' => const Color(0xFFF97316),
    'testing' => const Color(0xFF14B8A6),
    'done' => const Color(0xFF10B981),
    'failed' => const Color(0xFFEF4444),
    _ => const Color(0xFF94A3B8),
  };
}

class _TasksByStatusCard extends StatelessWidget {
  const _TasksByStatusCard({required this.summary});

  final TasksSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.byStatus.entries.toList();
    final total = summary.total;

    return SectionCard(
      title: trans('dashboard.tasks_by_status'),
      children: [
        if (total == 0)
          _EmptySection(
            icon: Icons.task_alt,
            message: trans('dashboard.no_tasks_yet'),
          )
        else ...[
          // Stacked horizontal bar.
          // Stacked bar chart — Row/Expanded/Container justified exception:
          // proportional-width fills need dynamic Color + flex ratios which
          // cannot be expressed via className tokens (CLAUDE.md Gotchas).
          WDiv(
            className: 'rounded-md overflow-hidden h-3',
            child: Row(
              children: entries.where((e) => e.value > 0).map((entry) {
                final fraction = entry.value / total;
                return Expanded(
                  flex: (fraction * 1000).round().clamp(1, 1000),
                  child: Container(color: _statusColor(entry.key)),
                );
              }).toList(),
            ),
          ),
          const WSpacer(className: 'h-4'),
          // Legend grid.
          WDiv(
            className: 'wrap gap-4',
            children: entries.map((entry) {
              return WDiv(
                className: 'flex flex-row items-center gap-1.5',
                children: [
                  WDiv(
                    className:
                        'w-2 h-2 rounded-sm ${statusDotClassName(entry.key)}',
                  ),
                  WText(
                    '${statusLabel(entry.key)}  ${entry.value}',
                    className: 'text-xs text-slate-500 dark:text-slate-400',
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
// Recent runs card
// ---------------------------------------------------------------------------

class _RecentRunsCard extends StatelessWidget {
  const _RecentRunsCard({required this.recentRuns});

  final List<RecentRun> recentRuns;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: trans('dashboard.recent_runs'),
      children: [
        if (recentRuns.isEmpty)
          _EmptySection(
            icon: Icons.history,
            message: trans('dashboard.no_recent_runs'),
          )
        else
          WDiv(
            className: 'flex flex-col gap-3',
            children: recentRuns
                .map((run) => _RecentRunItem(run: run))
                .toList(),
          ),
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
    final durationStr = run.durationMs != null
        ? _formatDuration(Duration(milliseconds: run.durationMs!))
        : '--';

    return WDiv(
      className: '''
        rounded-lg p-3
        bg-slate-50 dark:bg-gray-900
        flex flex-row items-center gap-3
      ''',
      children: [
        _AgentRoleBadge(role: run.agentRole),
        WDiv(
          className: 'flex-1 min-w-0 flex flex-col gap-1',
          children: [
            WText(
              run.taskTitle,
              className: 'text-sm font-medium text-slate-800 dark:text-white',
            ),
            WDiv(
              className: 'flex flex-row items-center gap-2',
              children: [
                StatusBadge(status: run.status),
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions section
// ---------------------------------------------------------------------------

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  // -------

  /// Shows a project picker dialog, then navigates to task create.
  void _onCreateTask(BuildContext context) {
    final projects = ProjectState.instance.rxState;
    if (projects == null || projects.isEmpty) return;

    // If only one project, navigate directly.
    if (projects.length == 1) {
      MagicRoute.to('/projects/${projects.first.id}/tasks/create');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trans('dashboard.select_project')),
        content: WDiv(
          className: 'w-96',
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: projects.length,
            separatorBuilder: (_, _) => const WSpacer(className: 'h-1'),
            itemBuilder: (_, index) {
              final project = projects[index];
              return WAnchor(
                onTap: () {
                  Navigator.of(ctx).pop();
                  MagicRoute.to('/projects/${project.id}/tasks/create');
                },
                child: WDiv(
                  className: 'p-3 rounded-lg bg-slate-50 dark:bg-gray-800',
                  child: WText(
                    project.name ?? '',
                    className:
                        'text-sm font-medium text-slate-800 dark:text-slate-200',
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(trans('common.cancel')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: trans('dashboard.quick_actions'),
      children: [
        WDiv(
          className: 'wrap gap-3',
          children: [
            WAnchor(
              onTap: () => _onCreateTask(context),
              child: WDiv(
                className: '''
                  flex flex-row items-center gap-2
                  px-4 py-2 rounded-lg
                  bg-amber-400
                ''',
                children: [
                  WIcon(
                    Icons.add_task,
                    className: 'text-base text-primary-900',
                  ),
                  WText(
                    trans('dashboard.create_task'),
                    className: 'text-sm font-semibold text-primary-900',
                  ),
                ],
              ),
            ),
            _DisabledActionButton(
              label: trans('dashboard.ba_chat'),
              icon: Icons.chat_outlined,
              tooltip: trans('dashboard.coming_in_wave', {'wave': '5'}),
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
      child: WDiv(
        className: '''
          flex flex-row items-center gap-2
          px-4 py-2 rounded-lg
          bg-amber-400 opacity-50
          cursor-not-allowed
        ''',
        children: [
          WIcon(icon, className: 'text-base text-primary'),
          WText(label, className: 'text-sm font-semibold text-primary'),
        ],
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
