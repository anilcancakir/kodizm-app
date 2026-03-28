import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';
import '../../widgets/molecules/page_header.dart';
import '../../widgets/molecules/section_card.dart';

/// View for creating a new project.
///
/// Renders a page header + form card matching the magic_starter
/// "page header + section cards" layout standard. Submits via
/// [ProjectState.createProject] and navigates on success.
///
/// ## Usage
///
/// ```dart
/// MagicRoute.to('/projects/create');
/// ```
class ProjectCreateView extends StatefulWidget {
  /// Creates the [ProjectCreateView].
  const ProjectCreateView({super.key});

  @override
  State<ProjectCreateView> createState() => _ProjectCreateViewState();
}

class _ProjectCreateViewState extends State<ProjectCreateView> {
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _techStackController = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit handler
  // ---------------------------------------------------------------------------

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
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      if (_techStackController.text.trim().isNotEmpty)
        'tech_stack': _techStackController.text.trim(),
    };

    final project = await ProjectState.instance.createProject(teamId, data);

    if (!mounted) return;

    if (project != null) {
      MagicRoute.to('/projects/${project.id}');
    } else {
      setState(() {
        _submitting = false;
        _submitError = trans('projects.failed_to_create');
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
        // Page header — outside card.
        PageHeader(
          title: trans('projects.create_project'),
          subtitle: trans('projects.create_subtitle'),
        ),

        // Form section card.
        SectionCard(
          title: trans('projects.details'),
          children: [
            Form(
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

                  // Inline error.
                  if (_submitError != null)
                    WDiv(
                      className: '''
                            p-3 rounded-lg
                            bg-red-50 dark:bg-red-900/20
                            border border-red-200 dark:border-red-800
                          ''',
                      child: WText(
                        _submitError!,
                        className: '''
                              text-sm text-red-600 dark:text-red-400
                            ''',
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
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Field builder
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Button builders
  // ---------------------------------------------------------------------------

  /// Primary "Create Project" button — amber background, primary text.
  Widget _buildPrimaryButton() {
    return WAnchor(
      key: const ValueKey('btn_create_project'),
      onTap: _submitting ? null : _submit,
      child: WDiv(
        className: '''
          px-5 py-2 rounded-lg
          bg-amber-400 dark:bg-amber-500
          flex flex-row items-center gap-2
        ''',
        children: [
          if (_submitting)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF334E68)),
              ),
            ),
          WText(
            _submitting
                ? trans('projects.creating')
                : trans('projects.create_project'),
            className: '''
              text-sm font-semibold
              text-primary dark:text-primary-900
            ''',
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
          className: '''
            text-sm font-medium
            text-slate-600 dark:text-slate-300
          ''',
        ),
      ),
    );
  }
}
