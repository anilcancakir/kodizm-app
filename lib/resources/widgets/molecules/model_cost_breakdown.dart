import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/session_usage_record.dart';

/// Aggregated cost row for a single AI model.
///
/// Holds summed totals across all turns for the same model identifier.
class _ModelRow {
  _ModelRow({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.costUsd,
  });

  final String model;
  final int inputTokens;
  final int outputTokens;
  final double costUsd;
}

/// Per-model cost breakdown molecule.
///
/// Groups a list of [SessionUsageRecord]s by model, sums token counts and cost,
/// then renders a header row followed by one data row per model.
///
/// Used by both the session detail view and the agent run sidebar.
///
/// ## Usage
/// ```dart
/// ModelCostBreakdown(
///   usageRecords: state.session.usageRecords,
/// )
/// ```
class ModelCostBreakdown extends StatelessWidget {
  /// Creates a [ModelCostBreakdown] from a list of [usageRecords].
  const ModelCostBreakdown({required this.usageRecords, super.key});

  /// The raw per-turn usage records to group and display.
  final List<SessionUsageRecord> usageRecords;

  // -------

  /// Aggregates [usageRecords] into one [_ModelRow] per distinct model name.
  List<_ModelRow> _aggregate() {
    final Map<String, _ModelRow> map = {};

    for (final record in usageRecords) {
      if (map.containsKey(record.model)) {
        final existing = map[record.model]!;
        map[record.model] = _ModelRow(
          model: existing.model,
          inputTokens: existing.inputTokens + record.inputTokens,
          outputTokens: existing.outputTokens + record.outputTokens,
          costUsd: existing.costUsd + record.costUsd,
        );
      } else {
        map[record.model] = _ModelRow(
          model: record.model,
          inputTokens: record.inputTokens,
          outputTokens: record.outputTokens,
          costUsd: record.costUsd,
        );
      }
    }

    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (usageRecords.isEmpty) {
      return WDiv(
        className: 'flex items-center justify-center w-full py-6',
        child: WText(
          trans('sessions.no_usage'),
          className: 'text-sm text-gray-400 dark:text-gray-500',
        ),
      );
    }

    final rows = _aggregate();

    return WDiv(
      className: 'flex flex-col gap-0',
      children: [
        _HeaderRow(),
        WDiv(
          className: 'flex flex-col gap-0',
          children: rows.map((row) => _DataRow(row: row)).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Column header row for the cost breakdown table.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        flex flex-row
        border-b border-gray-200 dark:border-gray-700
        pb-2 mb-1
      ''',
      children: [
        WDiv(
          className: 'flex-1',
          child: WText(
            trans('sessions.model'),
            className: 'text-xs font-semibold text-gray-500 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'w-24',
          child: WText(
            trans('sessions.input_tokens'),
            className: 'text-xs font-semibold text-gray-500 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'w-24',
          child: WText(
            trans('sessions.output_tokens'),
            className: 'text-xs font-semibold text-gray-500 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'w-20',
          child: WText(
            trans('sessions.cost'),
            className: 'text-xs font-semibold text-gray-500 dark:text-gray-400',
          ),
        ),
      ],
    );
  }
}

/// A single data row representing one aggregated model entry.
class _DataRow extends StatelessWidget {
  const _DataRow({required this.row});

  final _ModelRow row;

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: '''
        flex flex-row items-center
        py-2
        border-b border-gray-100 dark:border-gray-800
      ''',
      children: [
        WDiv(
          className: 'flex-1',
          child: WText(
            row.model,
            className: 'text-sm font-mono text-gray-700 dark:text-gray-300',
          ),
        ),
        WDiv(
          className: 'w-24',
          child: WText(
            '${row.inputTokens}',
            className: 'text-sm text-gray-600 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'w-24',
          child: WText(
            '${row.outputTokens}',
            className: 'text-sm text-gray-600 dark:text-gray-400',
          ),
        ),
        WDiv(
          className: 'w-20',
          child: WText(
            '\$${row.costUsd.toStringAsFixed(4)}',
            className: 'text-sm font-mono text-gray-900 dark:text-white',
          ),
        ),
      ],
    );
  }
}
