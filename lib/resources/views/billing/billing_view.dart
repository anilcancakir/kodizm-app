import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/team_balance.dart';
import '../../../app/models/user.dart';
import '../../../app/state/billing_state.dart';
import 'package:magic_starter/magic_starter.dart';

/// Team billing view — balance card, monthly summary, and agent role breakdown.
///
/// Displays the current team balance, a monthly cost summary with run
/// statistics, and a per-agent-role usage breakdown with proportional bars.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/billing');
/// ```
class BillingView extends StatefulWidget {
  /// Creates the [BillingView].
  const BillingView({super.key});

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  @override
  void initState() {
    super.initState();
    _fetchBilling();
  }

  Future<void> _fetchBilling() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await Future.wait([
      BillingState.instance.loadBalance(teamId),
      BillingState.instance.loadMonthlySummary(teamId),
      BillingState.instance.loadUsageByRole(teamId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BillingState.instance,
      builder: (context, _) {
        return BillingState.instance.renderState(
          (balance) => _BillingContent(balance: balance),
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
      className: 'w-full flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.error_outline,
          className: 'text-4xl text-red-500 dark:text-red-400',
        ),
        WText(
          trans('billing.failed_to_load'),
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
      className: 'w-full flex flex-col items-center justify-center py-16 gap-3',
      children: [
        WIcon(
          Icons.account_balance_wallet_outlined,
          className: 'text-4xl text-slate-400 dark:text-slate-500',
        ),
        WText(
          trans('billing.empty'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Billing content
// ---------------------------------------------------------------------------

class _BillingContent extends StatelessWidget {
  const _BillingContent({required this.balance});

  final TeamBalance balance;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('billing.title'),
          subtitle: trans('billing.subtitle'),
        ),
        _BalanceCard(balance: balance),
        _MonthlySummaryCard(),
        _UsageByRoleCard(),
        WAnchor(
          onTap: () => MagicRoute.to('/usage'),
          child: WText(
            trans('billing.view_usage_history'),
            className: 'text-sm font-medium text-amber-500',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

/// Maps balance amount to a Tailwind color class.
String _balanceColorClassName(double balance) {
  if (balance > 10) return 'text-emerald-500';
  if (balance >= 1) return 'text-amber-500';
  return 'text-red-500';
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final TeamBalance balance;

  @override
  Widget build(BuildContext context) {
    final colorCn = _balanceColorClassName(balance.balance);

    return MagicStarterCard(
      title: trans('billing.current_balance'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          WDiv(
            className: 'flex flex-row items-end gap-2',
            children: [
              WText(
                '\$${balance.balance.toStringAsFixed(2)}',
                className: 'text-4xl font-extrabold $colorCn',
              ),
              WText(
                balance.currency,
                className:
                    'text-sm font-medium text-slate-400 dark:text-slate-500 pb-1',
              ),
            ],
          ),
          WDiv(
            className: 'flex flex-row items-center gap-2',
            children: [
              WIcon(
                Icons.speed,
                className: 'text-base text-slate-400 dark:text-slate-500',
              ),
              WText(
                '${trans('billing.max_concurrent_runs')}: ${balance.maxConcurrentRuns}',
                className: 'text-sm text-slate-500 dark:text-slate-400',
              ),
            ],
          ),
          WAnchor(
            onTap: () => Launch.url(env('BILLING_PORTAL_URL', '')),
            child: WDiv(
              className: '''
                flex flex-row items-center gap-2
                px-4 py-2 rounded-lg
                bg-amber-400
                self-start
              ''',
              children: [
                WIcon(Icons.add, className: 'text-base text-primary-900'),
                WText(
                  trans('billing.add_credits'),
                  className: 'text-sm font-semibold text-primary-900',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly summary card
// ---------------------------------------------------------------------------

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard();

  @override
  Widget build(BuildContext context) {
    final billing = BillingState.instance;

    return MagicStarterCard(
      title: trans('billing.monthly_summary'),
      child: WDiv(
        className: 'w-full flex flex-row gap-4 axis-max',
        children: [
          WDiv(
            className: 'flex-1',
            child: _SummaryStatItem(
              label: trans('billing.total_spent'),
              value: '\$${billing.totalCostUsd.toStringAsFixed(2)}',
            ),
          ),
          WDiv(
            className: 'flex-1',
            child: _SummaryStatItem(
              label: trans('billing.runs_count'),
              value: billing.runCount.toString(),
            ),
          ),
          WDiv(
            className: 'flex-1',
            child: _SummaryStatItem(
              label: trans('billing.avg_cost_per_run'),
              value: '\$${billing.avgCostPerRun.toStringAsFixed(4)}',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary stat item
// ---------------------------------------------------------------------------

class _SummaryStatItem extends StatelessWidget {
  const _SummaryStatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        rounded-xl p-4
        bg-slate-50 dark:bg-gray-900
        flex flex-col gap-1
      ''',
      children: [
        WText(
          label,
          className: 'text-xs font-medium text-slate-400 dark:text-slate-500',
        ),
        WText(
          value,
          className: 'text-xl font-bold text-slate-900 dark:text-white',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Usage by role card
// ---------------------------------------------------------------------------

/// Maps agent role slugs to DESIGN.md hex [Color] values for proportional bars.
///
/// This is the allowed exception — proportional-width colored bars need dynamic
/// Color + flex ratios which cannot be expressed via className tokens.
Color _agentRoleColor(String role) {
  return switch (role.toLowerCase()) {
    'ba' || 'business analyst' => const Color(0xFF6366F1),
    'lead' || 'lead developer' => const Color(0xFF334E68),
    'dev' || 'developer' => const Color(0xFF14B8A6),
    'reviewer' || 'code reviewer' => const Color(0xFF8B5CF6),
    'qa' || 'qa engineer' => const Color(0xFF10B981),
    _ => const Color(0xFF94A3B8),
  };
}

/// Maps agent role slugs to Tailwind className tokens for badges.
String _agentRoleClassName(String role) {
  return switch (role.toLowerCase()) {
    'ba' || 'business analyst' => 'bg-indigo-500/10 text-indigo-500',
    'lead' || 'lead developer' => 'bg-primary/10 text-primary',
    'dev' || 'developer' => 'bg-teal-500/10 text-teal-500',
    'reviewer' || 'code reviewer' => 'bg-violet-500/10 text-violet-500',
    'qa' || 'qa engineer' => 'bg-emerald-500/10 text-emerald-500',
    _ => 'bg-slate-500/10 text-slate-500',
  };
}

class _UsageByRoleCard extends StatelessWidget {
  const _UsageByRoleCard();

  @override
  Widget build(BuildContext context) {
    final billing = BillingState.instance;
    final roles = billing.usageByRole;

    if (roles.isEmpty) {
      return const WSpacer(className: 'h-0 w-0');
    }

    final totalCost = roles.values.fold(0.0, (sum, v) => sum + v);
    final sortedEntries = roles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return MagicStarterCard(
      title: trans('billing.usage_by_role'),
      child: WDiv(
        className: 'flex flex-col gap-4',
        children: [
          // Stacked horizontal bar.
          // Row/Expanded/Container justified exception: proportional-width fills
          // need dynamic Color + flex ratios (CLAUDE.md Gotchas).
          if (totalCost > 0)
            WDiv(
              className: 'rounded-md overflow-hidden h-3',
              child: Row(
                children: sortedEntries.where((e) => e.value > 0).map((entry) {
                  final fraction = entry.value / totalCost;
                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(color: _agentRoleColor(entry.key)),
                  );
                }).toList(),
              ),
            ),
          const WSpacer(className: 'h-2'),
          // Role rows.
          WDiv(
            className: 'flex flex-col gap-3',
            children: sortedEntries.map((entry) {
              final cn = _agentRoleClassName(entry.key);
              return WDiv(
                className: 'flex flex-row items-center gap-3',
                children: [
                  WDiv(
                    className: 'px-2 py-1 rounded-md $cn',
                    child: WText(entry.key, className: 'text-xs font-semibold'),
                  ),
                  WDiv(
                    className: 'flex-1',
                    child: WText(
                      '\$${entry.value.toStringAsFixed(4)}',
                      className: 'text-sm text-slate-700 dark:text-slate-300',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
