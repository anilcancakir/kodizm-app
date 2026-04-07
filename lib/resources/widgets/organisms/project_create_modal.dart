import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../../../app/models/project.dart';
import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';

// ---------------------------------------------------------------------------
// ProjectCreateModal
// ---------------------------------------------------------------------------

/// Modal organism for creating a new project.
///
/// Renders a [MagicStarterDialogShell] with form fields for project name,
/// short name (auto-generated from name), description, and tech stack.
/// Returns the created [Project] on success, or `null` on cancel.
///
/// ## Usage
///
/// ```dart
/// final Project? created = await ProjectCreateModal.show(context);
/// if (created != null) {
///   MagicRoute.to('/projects/${created.id}');
/// }
/// ```
class ProjectCreateModal extends StatefulWidget {
  /// Private constructor — use [show] static entry point.
  const ProjectCreateModal._();

  // -----------------------------------------------------------------------
  // Static entry point
  // -----------------------------------------------------------------------

  /// Opens the create project modal and returns the created [Project],
  /// or `null` if the user cancels.
  static Future<Project?> show(BuildContext context) {
    return showDialog<Project>(
      context: context,
      builder: (_) => const ProjectCreateModal._(),
    );
  }

  @override
  State<ProjectCreateModal> createState() => _ProjectCreateModalState();
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ProjectCreateModalState extends State<ProjectCreateModal> {
  final _formKey = GlobalKey<FormState>();

  // -----------------------------------------------------------------------
  // Controllers
  // -----------------------------------------------------------------------

  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _techStackController = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  /// Whether the user has manually edited the short_name field.
  bool _shortNameManuallyEdited = false;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _shortNameController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  /// Computes a short name suggestion from the project name.
  ///
  /// Takes the first letter of each word, uppercases, max 5 chars.
  void _onNameChanged() {
    if (_shortNameManuallyEdited) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _shortNameController.text = '';
      return;
    }

    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(5)
        .join();

    _shortNameController.text = initials;
  }

  // -----------------------------------------------------------------------
  // Submit handler
  // -----------------------------------------------------------------------

  /// Validates the form and submits the create project request.
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

    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'short_name': _shortNameController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      if (_techStackController.text.trim().isNotEmpty)
        'tech_stack': _techStackController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
    };

    final project = await ProjectState.instance.createProject(teamId, data);

    if (!mounted) return;

    if (project != null) {
      Navigator.of(context).pop(project);
    } else {
      setState(() {
        _submitting = false;
        _submitError = trans('projects.failed_to_create');
      });
    }
  }

  /// Closes the dialog without creating a project.
  void _onCancel() => Navigator.of(context).pop();

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = MagicStarter.modalTheme;

    return MagicStarterDialogShell(
      title: trans('projects.create_project'),
      description: trans('projects.create_subtitle'),
      body: Form(
        key: _formKey,
        child: WDiv(
          className: 'flex flex-col gap-5',
          children: [
            _buildField(
              label: trans('projects.project_name'),
              hint: trans('projects.name_placeholder'),
              controller: _nameController,
              required: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return trans('projects.name_required');
                }
                if (value.trim().length > 255) {
                  return trans('projects.name_max');
                }
                return null;
              },
            ),
            _buildShortNameField(),
            _buildField(
              label: trans('projects.description'),
              hint: trans('projects.description_placeholder_optional'),
              controller: _descriptionController,
              maxLines: 3,
            ),
            _buildField(
              label: trans('projects.tech_stack'),
              hint: trans('projects.tech_stack_placeholder_optional'),
              controller: _techStackController,
            ),
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
          ],
        ),
      ),
      footerBuilder: (_) => WDiv(
        className: 'flex flex-row gap-2 w-full justify-end',
        children: [
          WAnchor(
            onTap: _submitting ? null : _onCancel,
            child: WDiv(
              className: theme.secondaryButtonClassName,
              child: WText(trans('common.cancel'), className: 'text-inherit'),
            ),
          ),
          WAnchor(
            onTap: _submitting ? null : _submit,
            child: WDiv(
              className: '''
                px-4 py-2 rounded-lg
                bg-amber-400 text-primary-900
                text-sm font-medium
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
                  _submitting
                      ? trans('projects.creating')
                      : trans('projects.create_project'),
                  className: 'text-inherit',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Short name field
  // -----------------------------------------------------------------------

  /// Builds the short name [WFormInput] with uppercase enforcement and validation.
  Widget _buildShortNameField() {
    return WFormInput(
      controller: _shortNameController,
      label: '${trans('projects.short_name')} *',
      labelClassName: '''
        text-sm font-medium mb-2
        text-slate-600 dark:text-slate-300
      ''',
      placeholder: trans('projects.short_name_placeholder'),
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        _shortNameManuallyEdited = true;
      },
      validator: (value) {
        final trimmed = value?.trim() ?? '';
        if (trimmed.isEmpty) {
          return trans('projects.short_name_invalid');
        }
        if (trimmed.length < 2 ||
            trimmed.length > 5 ||
            !RegExp(r'^[A-Z]+$').hasMatch(trimmed)) {
          return trans('projects.short_name_invalid');
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

  // -----------------------------------------------------------------------
  // Field builder
  // -----------------------------------------------------------------------

  /// Builds a labelled [WFormInput] field with proper label-input spacing.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return WFormInput(
      controller: controller,
      type: maxLines > 1 ? InputType.multiline : InputType.text,
      label: required ? '$label *' : label,
      labelClassName: '''
        text-sm font-medium mb-2
        text-slate-600 dark:text-slate-300
      ''',
      placeholder: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      validator: validator,
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
}
