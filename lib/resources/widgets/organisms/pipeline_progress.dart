import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/conversation.dart';
import '../../../app/models/task.dart';

// ---------------------------------------------------------------------------
// Stage state enum
// ---------------------------------------------------------------------------

/// The visual state of a pipeline stage.
enum _StageState {
  /// Stage has been completed — emerald dot, green line.
  completed,

  /// Stage is currently active with an agent running — amber dot, spinning.
  running,

  /// Stage is active but waiting for user action — orange dot, continue button.
  waiting,

  /// Stage has not started yet — slate dot, gray line.
  pending,
}

// ---------------------------------------------------------------------------
// Pipeline stage definition
// ---------------------------------------------------------------------------

/// Internal value object representing a single pipeline stage.
class _PipelineStage {
  const _PipelineStage({
    required this.status,
    required this.labelKey,
    required this.state,
  });

  /// The backend task status this stage maps to.
  final String status;

  /// The i18n key for the stage label.
  final String labelKey;

  /// The visual state of this stage.
  final _StageState state;
}

// ---------------------------------------------------------------------------
// PipelineProgress organism
// ---------------------------------------------------------------------------

/// A horizontal stepper showing the 5 pipeline stages for a task.
///
/// Derives each stage's visual state from the task's current status and
/// whether any conversation is actively running. Renders completed stages
/// with emerald dots, the active stage with an amber/orange indicator,
/// and future stages with slate dots.
///
/// ## Usage
///
/// ```dart
/// PipelineProgress(
///   task: task,
///   conversations: conversations,
///   onContinue: () => startNextStage(),
/// )
/// ```
class PipelineProgress extends StatelessWidget {
  /// Creates a [PipelineProgress] for the given [task].
  const PipelineProgress({
    required this.task,
    required this.conversations,
    this.onContinue,
    super.key,
  });

  /// The task whose pipeline progress is displayed.
  final Task task;

  /// The list of conversations (runs) for this task.
  final List<Conversation> conversations;

  /// Callback invoked when the user taps "Continue" on a waiting stage.
  final VoidCallback? onContinue;

  // -----------------------------------------------------------------------
  // Stage definitions — ordered pipeline stages
  // -----------------------------------------------------------------------

  static const List<String> _stageStatuses = [
    'analysis',
    'planning',
    'in_progress',
    'review',
    'done',
  ];

  static const List<String> _stageLabelKeys = [
    'pipeline_progress.stage_analysis',
    'pipeline_progress.stage_planning',
    'pipeline_progress.stage_in_progress',
    'pipeline_progress.stage_review',
    'pipeline_progress.stage_done',
  ];

  // -----------------------------------------------------------------------
  // State derivation
  // -----------------------------------------------------------------------

  /// Whether any conversation is actively running.
  bool get _hasActiveRun {
    return conversations.any(
      (c) => c.status == 'active' || c.status == 'running',
    );
  }

  /// Builds the list of pipeline stages with their derived visual states.
  List<_PipelineStage> _buildStages() {
    final currentStatus = task.status ?? 'draft';
    final currentIndex = _stageStatuses.indexOf(currentStatus);

    return List.generate(_stageStatuses.length, (i) {
      final _StageState state;

      if (currentIndex < 0) {
        // Status not in pipeline (e.g. draft, failed) → all pending.
        state = _StageState.pending;
      } else if (i < currentIndex) {
        state = _StageState.completed;
      } else if (i == currentIndex) {
        if (currentStatus == 'done') {
          state = _StageState.completed;
        } else if (_hasActiveRun) {
          state = _StageState.running;
        } else {
          state = _StageState.waiting;
        }
      } else {
        state = _StageState.pending;
      }

      return _PipelineStage(
        status: _stageStatuses[i],
        labelKey: _stageLabelKeys[i],
        state: state,
      );
    });
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final stages = _buildStages();

    return WDiv(
      className: 'flex flex-col gap-3',
      children: [
        // Title
        WText(
          trans('pipeline_progress.title'),
          className: 'text-sm font-semibold text-slate-700 dark:text-slate-300',
        ),

        // Stepper row
        WDiv(
          className: 'flex flex-row items-start gap-0',
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              _buildStageColumn(stages[i]),
              if (i < stages.length - 1) _buildConnector(stages[i]),
            ],
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Stage column
  // -----------------------------------------------------------------------

  /// Builds a single stage: circle dot + label (+ optional continue button).
  Widget _buildStageColumn(_PipelineStage stage) {
    return WDiv(
      className: 'flex flex-col items-center gap-1',
      children: [
        _buildDot(stage),
        WText(
          trans(stage.labelKey),
          className: 'text-[11px] font-medium ${_labelClassName(stage.state)}',
        ),
        if (stage.state == _StageState.waiting && onContinue != null)
          WAnchor(
            onTap: onContinue,
            child: WDiv(
              className:
                  'mt-1 px-2 py-0.5 rounded bg-amber-400 text-primary-900',
              child: WText(
                trans('pipeline_progress.continue_action'),
                className: 'text-[11px] font-semibold text-primary-900',
              ),
            ),
          ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Dot circle
  // -----------------------------------------------------------------------

  /// Builds the circle indicator for a stage.
  Widget _buildDot(_PipelineStage stage) {
    final dotClassName = _dotClassName(stage.state);
    final key = Key('pipeline-step-${stage.state.name}');

    if (stage.state == _StageState.running) {
      return WDiv(
        key: key,
        className:
            'w-8 h-8 rounded-full flex items-center justify-center $dotClassName',
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    final icon = stage.state == _StageState.completed ? Icons.check : null;

    return WDiv(
      key: key,
      className:
          'w-8 h-8 rounded-full flex items-center justify-center $dotClassName',
      child: icon != null ? WIcon(icon, className: 'text-sm text-white') : null,
    );
  }

  // -----------------------------------------------------------------------
  // Connector line
  // -----------------------------------------------------------------------

  /// Builds the horizontal connector between two stages.
  Widget _buildConnector(_PipelineStage stage) {
    final lineColor = stage.state == _StageState.completed
        ? 'bg-emerald-500'
        : 'bg-slate-200 dark:bg-slate-700';

    return WDiv(className: 'flex-1 h-0.5 mt-4 $lineColor');
  }

  // -----------------------------------------------------------------------
  // ClassName helpers
  // -----------------------------------------------------------------------

  /// Returns the dot background className for a given stage state.
  String _dotClassName(_StageState state) {
    return switch (state) {
      _StageState.completed => 'bg-emerald-500',
      _StageState.running => 'bg-amber-400',
      _StageState.waiting => 'bg-orange-500',
      _StageState.pending => 'bg-slate-300 dark:bg-slate-600',
    };
  }

  /// Returns the label text className for a given stage state.
  String _labelClassName(_StageState state) {
    return switch (state) {
      _StageState.completed => 'text-emerald-600 dark:text-emerald-400',
      _StageState.running => 'text-amber-600 dark:text-amber-400',
      _StageState.waiting => 'text-orange-600 dark:text-orange-400',
      _StageState.pending => 'text-slate-400 dark:text-slate-500',
    };
  }
}
