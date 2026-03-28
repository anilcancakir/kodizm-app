import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/usage_record.dart';
import '../../../app/models/user.dart';
import '../../../app/state/usage_state.dart';
import 'package:magic_starter/magic_starter.dart';

/// Usage history view — paginated list of AI token usage records.
///
/// Displays a team's usage records with per-record breakdowns (model, role,
/// tokens, cost) and aggregated totals from the API meta response.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/billing/usage');
/// ```
class UsageHistoryView extends StatefulWidget {
  /// Creates the [UsageHistoryView].
  const UsageHistoryView({super.key});

  @override
  State<UsageHistoryView> createState() => _UsageHistoryViewState();
}

class _UsageHistoryViewState extends State<UsageHistoryView> {
  @override
  void initState() {
    super.initState();
    _fetchUsage();
  }

  Future<void> _fetchUsage() async {
    final teamId = Auth.user<User>()?.currentTeam?.id;
    if (teamId == null) return;
    await UsageState.instance.loadUsage(teamId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchUsage,
      child: ListenableBuilder(
        listenable: UsageState.instance,
        builder: (context, _) {
          return UsageState.instance.renderState(
            (records) => _UsageContent(records: records),
            onLoading: const _LoadingView(),
            onError: (msg) => _ErrorView(message: msg),
            onEmpty: const _EmptyView(),
          );
        },
      ),
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
          trans('errors.unexpected'),
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
          Icons.receipt_long_outlined,
          className: 'text-4xl text-slate-400 dark:text-slate-500',
        ),
        WText(
          trans('usage.empty_title'),
          className: 'text-base font-semibold text-gray-900 dark:text-white',
        ),
        WText(
          trans('usage.empty_subtitle'),
          className: 'text-sm text-slate-500 dark:text-slate-400',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Usage content
// ---------------------------------------------------------------------------

class _UsageContent extends StatelessWidget {
  const _UsageContent({required this.records});

  final List<UsageRecord> records;

  @override
  Widget build(BuildContext context) {
    final state = UsageState.instance;

    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        MagicStarterPageHeader(
          title: trans('usage.title'),
          subtitle: trans('usage.subtitle'),
        ),
        _SummaryRow(state: state),
        MagicStarterCard(
          title: trans('usage.record_date'),
          noPadding: true,
          child: WDiv(
            className: 'flex flex-col',
            children: [
              ...records.map((record) => _RecordRow(record: record)),
              if (state.hasMore) _LoadMoreButton(state: state),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row — total cost + page info
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.state});

  final UsageState state;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        w-full flex flex-row items-center justify-between gap-4
        px-4 py-3
        bg-white dark:bg-gray-800
        border border-gray-200 dark:border-gray-700
        rounded-xl
      ''',
      children: [
        WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            WText(
              trans('usage.total_cost'),
              className:
                  'text-sm font-medium text-slate-500 dark:text-slate-400',
            ),
            WText(
              '\$${state.totalCostUsd.toStringAsFixed(2)}',
              className: 'text-base font-bold text-gray-900 dark:text-white',
            ),
          ],
        ),
        WText(
          trans('usage.page_info', {
            'current': state.currentPage.toString(),
            'total': state.lastPage.toString(),
          }),
          className: 'text-xs text-slate-400 dark:text-slate-500',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Record row
// ---------------------------------------------------------------------------

/// Maps agent role slugs to their DESIGN.md brand className tokens.
String _roleBadgeClassName(String? role) {
  return switch (role?.toLowerCase()) {
    'ba' => 'bg-indigo-500/10 text-indigo-500',
    'lead' => 'bg-primary/10 text-primary',
    'dev' => 'bg-teal-500/10 text-teal-500',
    'reviewer' => 'bg-violet-500/10 text-violet-500',
    'qa' => 'bg-emerald-500/10 text-emerald-500',
    _ => 'bg-slate-500/10 text-slate-500',
  };
}

/// Formats a [DateTime] to `YYYY-MM-DD`.
String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final UsageRecord record;

  @override
  Widget build(BuildContext context) {
    final roleCn = _roleBadgeClassName(record.agentRoleName);

    return WDiv(
      className: '''
        px-6 py-3 flex flex-row items-center gap-3
        border-b border-slate-100 dark:border-gray-700
      ''',
      children: [
        // Date
        WText(
          _formatDate(record.recordedAt),
          className: 'text-xs text-slate-400 dark:text-slate-500 w-24',
        ),
        // Agent role badge
        WDiv(
          className: 'px-2 py-1 rounded-md $roleCn',
          child: WText(
            record.agentRoleName ?? trans('common.unknown'),
            className: 'text-xs font-semibold',
          ),
        ),
        // Task title
        WDiv(
          className: 'flex-1 min-w-0',
          child: WText(
            record.taskTitle ?? trans('common.unknown'),
            className: 'text-sm text-slate-700 dark:text-slate-300 truncate',
          ),
        ),
        // Model
        WText(
          record.model ?? trans('common.unknown'),
          className: 'text-xs text-slate-500 dark:text-slate-400 w-40 truncate',
        ),
        // Tokens in / out
        WDiv(
          className: 'flex flex-row items-center gap-1',
          children: [
            WText(
              '${record.inputTokens ?? 0}',
              className: 'text-xs text-slate-500 dark:text-slate-400',
            ),
            WText('/', className: 'text-xs text-slate-300 dark:text-slate-600'),
            WText(
              '${record.outputTokens ?? 0}',
              className: 'text-xs text-slate-500 dark:text-slate-400',
            ),
          ],
        ),
        // Cost
        WText(
          '\$${record.costUsd.toStringAsFixed(4)}',
          className:
              'text-xs font-medium text-amber-600 dark:text-amber-400 w-16 text-right',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Load more button
// ---------------------------------------------------------------------------

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.state});

  final UsageState state;

  @override
  Widget build(BuildContext context) {
    return WAnchor(
      onTap: () => state.loadMore(),
      child: WDiv(
        className: 'w-full py-3 flex items-center justify-center',
        child: WText(
          trans('usage.load_more'),
          className: 'text-sm font-medium text-amber-500',
        ),
      ),
    );
  }
}
