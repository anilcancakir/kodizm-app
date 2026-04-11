import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/user.dart';
import '../../../app/state/task_state.dart';

// ---------------------------------------------------------------------------
// Segment model
// ---------------------------------------------------------------------------

/// A single option in a [_SegmentedControl].
class _Segment {
  /// Creates a [_Segment] with the given [value] and [label].
  const _Segment({required this.value, required this.label});

  /// The raw value sent in the API request body.
  final String value;

  /// The human-readable label displayed in the UI.
  final String label;
}

// ---------------------------------------------------------------------------
// _SegmentedControl
// ---------------------------------------------------------------------------

/// A horizontal pill-style segmented control for selecting a single option.
///
/// Each segment is an [WAnchor] button styled with Tailwind tokens.
/// The active segment receives amber background; inactive segments are white/gray.
///
/// ## Usage
///
/// ```dart
/// _SegmentedControl(
///   label: 'Type',
///   options: const [_Segment(value: 'task', label: 'Task')],
///   selected: _type,
///   onChanged: (v) => setState(() => _type = v ?? 'task'),
/// )
/// ```
class _SegmentedControl extends StatelessWidget {
  /// Creates a [_SegmentedControl].
  const _SegmentedControl({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// The label displayed above the control.
  final String label;

  /// The list of selectable segments.
  final List<_Segment> options;

  /// The currently selected segment value. May be `null` for "none" selection.
  final String? selected;

  /// Callback invoked when the user taps a segment.
  final ValueChanged<String?> onChanged;

  // -------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'flex flex-col gap-2',
      children: [
        WText(
          label,
          className: 'text-sm font-medium text-slate-600 dark:text-slate-300',
        ),
        WDiv(
          className: 'wrap gap-2',
          children: options.map(_buildSegment).toList(),
        ),
      ],
    );
  }

  // -------

  /// Builds an individual segment button.
  Widget _buildSegment(_Segment segment) {
    final isActive = selected == segment.value;

    return WAnchor(
      onTap: () => onChanged(segment.value),
      child: WDiv(
        className: isActive
            ? '''
                bg-amber-400/20 text-amber-600 dark:text-amber-400
                border border-amber-400/30 px-3 py-1.5 rounded-lg text-sm font-medium
              '''
            : '''
                bg-white dark:bg-gray-800 text-slate-500
                border border-slate-200 dark:border-slate-700
                px-3 py-1.5 rounded-lg text-sm
              ''',
        child: WText(
          segment.label,
          className: isActive
              ? 'text-amber-600 dark:text-amber-400 text-sm font-medium'
              : 'text-slate-500 text-sm',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TaskCreateView
// ---------------------------------------------------------------------------

/// View for creating a new task within a project.
///
/// Renders a page header + form card following the magic_starter
/// "page header + section cards" layout standard. Submits via
/// [TaskState.createTask] and navigates to the task detail on success.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/tasks/$projectId/create');
/// ```
class TaskCreateView extends StatefulWidget {
  /// Creates a [TaskCreateView] for the given [projectId].
  const TaskCreateView({super.key, required this.projectId});

  /// The ID of the project this task will belong to.
  final String projectId;

  @override
  State<TaskCreateView> createState() => _TaskCreateViewState();
}

class _TaskCreateViewState extends State<TaskCreateView> {
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _acceptanceCriteriaController = TextEditingController();

  // ---------------------------------------------------------------------------
  // Segmented control state
  // ---------------------------------------------------------------------------

  String _type = 'task';
  String _priority = 'p2';
  String? _complexity;

  // ---------------------------------------------------------------------------
  // Submission state
  // ---------------------------------------------------------------------------

  bool _submitting = false;
  String? _submitError;

  // ---------------------------------------------------------------------------
  // Segment option definitions
  // ---------------------------------------------------------------------------

  List<_Segment> get _typeOptions => [
    _Segment(value: 'story', label: trans('tasks.type_story')),
    _Segment(value: 'task', label: trans('tasks.type_task')),
    _Segment(value: 'bug', label: trans('tasks.type_bug')),
    _Segment(value: 'spike', label: trans('tasks.type_spike')),
  ];

  List<_Segment> get _priorityOptions => [
    _Segment(value: 'p0', label: trans('tasks.priority_p0')),
    _Segment(value: 'p1', label: trans('tasks.priority_p1')),
    _Segment(value: 'p2', label: trans('tasks.priority_p2')),
    _Segment(value: 'p3', label: trans('tasks.priority_p3')),
  ];

  List<_Segment> get _complexityOptions => [
    _Segment(value: 'none', label: trans('tasks.complexity_none')),
    _Segment(value: 'xs', label: trans('tasks.complexity_xs')),
    _Segment(value: 's', label: trans('tasks.complexity_s')),
    _Segment(value: 'm', label: trans('tasks.complexity_m')),
    _Segment(value: 'l', label: trans('tasks.complexity_l')),
    _Segment(value: 'xl', label: trans('tasks.complexity_xl')),
  ];

  // -------

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _acceptanceCriteriaController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit handler
  // ---------------------------------------------------------------------------

  /// Validates the form and submits the create task request.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final teamId = User.current.currentTeam?.id;
    if (teamId == null || teamId.isEmpty) {
      setState(() => _submitError = trans('projects.no_active_team'));
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final description = _descriptionController.text.trim();
    final acceptanceCriteria = _acceptanceCriteriaController.text.trim();

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'type': _type,
      'priority': _priority,
      if (description.isNotEmpty) 'description': description,
      if (acceptanceCriteria.isNotEmpty)
        'acceptance_criteria': acceptanceCriteria,
      if (_complexity != null && _complexity != 'none')
        'estimated_complexity': _complexity,
    };

    final task = await TaskState.instance.createTask(
      teamId,
      widget.projectId,
      data,
    );

    if (!mounted) return;

    if (task != null) {
      MagicRoute.to('/tasks/${widget.projectId}/${task.id}');
    } else {
      setState(() {
        _submitting = false;
        _submitError = trans('tasks.failed_to_create');
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        // Page header — outside the card.
        MagicStarterPageHeader(
          title: trans('tasks.create_task'),
          subtitle: trans('tasks.create_subtitle'),
        ),

        // Form section card.
        MagicStarterCard(
          title: trans('tasks.create_task'),
          child: Form(
            key: _formKey,
            child: WDiv(
              className: 'flex flex-col gap-5',
              children: [
                // Title field.
                _buildTitleField(),

                // Description field.
                _buildField(
                  label: trans('tasks.description_label'),
                  hint: trans('tasks.description_placeholder'),
                  controller: _descriptionController,
                  maxLines: 3,
                ),

                // Acceptance criteria field.
                _buildField(
                  label: trans('tasks.acceptance_criteria_label'),
                  hint: trans('tasks.acceptance_criteria_placeholder'),
                  controller: _acceptanceCriteriaController,
                  maxLines: 3,
                ),

                // Type segmented control.
                _SegmentedControl(
                  label: trans('tasks.type_label'),
                  options: _typeOptions,
                  selected: _type,
                  onChanged: (v) => setState(() => _type = v ?? 'task'),
                ),

                // Priority segmented control.
                _SegmentedControl(
                  label: trans('tasks.priority_label'),
                  options: _priorityOptions,
                  selected: _priority,
                  onChanged: (v) => setState(() => _priority = v ?? 'p2'),
                ),

                // Estimated complexity segmented control.
                _SegmentedControl(
                  label: trans('tasks.complexity_label'),
                  options: _complexityOptions,
                  selected: _complexity ?? 'none',
                  onChanged: (v) =>
                      setState(() => _complexity = (v == 'none') ? null : v),
                ),

                // Inline error banner.
                if (_submitError != null)
                  WDiv(
                    className: '''
                      p-3 rounded-lg
                      bg-red-50 dark:bg-red-900/20
                      border border-red-200 dark:border-red-800
                    ''',
                    child: WText(
                      _submitError!,
                      className: 'text-sm text-red-600 dark:text-red-400',
                    ),
                  ),

                const WSpacer(className: 'h-1'),

                // Action buttons.
                WDiv(
                  className: 'flex flex-row gap-3 justify-end',
                  children: [_buildSecondaryButton(), _buildPrimaryButton()],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Field builders
  // ---------------------------------------------------------------------------

  /// Builds the required title [WFormInput] with validation.
  Widget _buildTitleField() {
    return WFormInput(
      controller: _titleController,
      type: InputType.text,
      label: '${trans('tasks.task_title_label')} *',
      labelClassName:
          'text-sm font-medium mb-2 text-slate-600 dark:text-slate-300',
      placeholder: trans('tasks.task_title_label'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return trans('tasks.title_required');
        }
        if (value.trim().length > 500) {
          return trans('tasks.title_max');
        }
        return null;
      },
      className: '''
        p-3 border border-slate-200 dark:border-gray-600
        rounded-lg bg-white dark:bg-gray-900
        text-sm text-slate-800 dark:text-slate-200
        focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
        error:border-red-500 error:ring-2 error:ring-red-200
      ''',
      errorClassName: 'text-red-500 text-xs mt-1',
    );
  }

  /// Builds a generic multiline [WFormInput] field.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return WFormInput(
      controller: controller,
      type: maxLines > 1 ? InputType.multiline : InputType.text,
      label: label,
      labelClassName:
          'text-sm font-medium mb-2 text-slate-600 dark:text-slate-300',
      placeholder: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      className: '''
        p-3 border border-slate-200 dark:border-gray-600
        rounded-lg bg-white dark:bg-gray-900
        text-sm text-slate-800 dark:text-slate-200
        focus:border-amber-400 focus:ring-2 focus:ring-amber-400/20
      ''',
      errorClassName: 'text-red-500 text-xs mt-1',
    );
  }

  // ---------------------------------------------------------------------------
  // Button builders
  // ---------------------------------------------------------------------------

  /// Primary "Create Task" button — amber background, primary text.
  Widget _buildPrimaryButton() {
    return WAnchor(
      key: const ValueKey('btn_create_task'),
      onTap: _submitting ? null : _submit,
      child: WDiv(
        className: '''
          px-5 py-2 rounded-lg
          bg-amber-400 dark:bg-amber-500
          flex flex-row items-center gap-2
        ''',
        children: [
          if (_submitting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  WindTheme.dataOf(context).getColor('primary', 500)!,
                ),
              ),
            ),
          WText(
            _submitting ? trans('tasks.creating') : trans('tasks.create_task'),
            className:
                'text-sm font-semibold text-primary dark:text-primary-900',
          ),
        ],
      ),
    );
  }

  /// Secondary "Cancel" button — white background, slate border.
  Widget _buildSecondaryButton() {
    return WAnchor(
      onTap: _submitting ? null : () => MagicRoute.back(),
      child: WDiv(
        className: '''
          px-5 py-2 rounded-lg
          bg-white dark:bg-gray-700
          border border-slate-200 dark:border-gray-600
        ''',
        child: WText(
          trans('common.cancel'),
          className: 'text-sm font-medium text-slate-600 dark:text-slate-300',
        ),
      ),
    );
  }
}
