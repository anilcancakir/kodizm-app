import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../../../app/models/user.dart';
import '../../../app/state/project_state.dart';

/// View for creating a new project.
///
/// Renders a form with fields for name, description, repository URL,
/// tech stack, and default branch. Submits via [ProjectState.createProject]
/// and navigates to the created project on success.
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
  final _repositoryUrlController = TextEditingController();
  final _techStackController = TextEditingController();
  final _defaultBranchController = TextEditingController(text: 'main');

  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _repositoryUrlController.dispose();
    _techStackController.dispose();
    _defaultBranchController.dispose();
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
      setState(() => _submitError = 'No active team found.');
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
      if (_repositoryUrlController.text.trim().isNotEmpty)
        'repository_url': _repositoryUrlController.text.trim(),
      if (_techStackController.text.trim().isNotEmpty)
        'tech_stack': _techStackController.text.trim(),
      'default_branch': _defaultBranchController.text.trim().isEmpty
          ? 'main'
          : _defaultBranchController.text.trim(),
    };

    final project = await ProjectState.instance.createProject(teamId, data);

    if (!mounted) return;

    if (project != null) {
      MagicRoute.to('/projects/${project.id}');
    } else {
      setState(() {
        _submitting = false;
        _submitError = 'Failed to create project. Please try again.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'w-full max-w-2xl mx-auto p-4 lg:p-8',
      child: WDiv(
        className: '''
          rounded-2xl bg-white dark:bg-gray-800
          border border-gray-200 dark:border-gray-700
          p-6 lg:p-8
        ''',
        children: [
          // --------------------------------------------------
          // Page title
          // --------------------------------------------------
          WText(
            'Create Project',
            className: '''
              text-2xl font-bold
              text-gray-900 dark:text-white
            ''',
          ),
          const WSpacer(className: 'h-2'),
          WText(
            'Set up a new project for your team.',
            className: 'text-sm text-gray-500 dark:text-gray-400',
          ),
          const WSpacer(className: 'h-6'),

          // --------------------------------------------------
          // Form
          // --------------------------------------------------
          Form(
            key: _formKey,
            child: WDiv(
              className: 'flex flex-col gap-4',
              children: [
                _buildField(
                  label: 'Project Name',
                  hint: 'My Awesome Project',
                  controller: _nameController,
                  required: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Project name is required.';
                    }
                    if (value.trim().length > 255) {
                      return 'Project name must not exceed 255 characters.';
                    }
                    return null;
                  },
                ),
                _buildField(
                  label: 'Description',
                  hint: 'A short description of the project (optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                _buildField(
                  label: 'Repository URL',
                  hint: 'https://github.com/org/repo (optional)',
                  controller: _repositoryUrlController,
                  keyboardType: TextInputType.url,
                ),
                _buildField(
                  label: 'Tech Stack',
                  hint: 'Laravel, Flutter, Docker (optional)',
                  controller: _techStackController,
                ),
                _buildField(
                  label: 'Default Branch',
                  hint: 'main',
                  controller: _defaultBranchController,
                ),

                // --------------------------------------------------
                // Inline error
                // --------------------------------------------------
                if (_submitError != null) ...[
                  const WSpacer(className: 'h-1'),
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

                const WSpacer(className: 'h-2'),

                // --------------------------------------------------
                // Action buttons
                // --------------------------------------------------
                WDiv(
                  className: 'flex flex-row gap-3 justify-end',
                  children: [_buildSecondaryButton(), _buildPrimaryButton()],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field builder
  // ---------------------------------------------------------------------------

  /// Builds a labelled [WFormInput] field.
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return WFormInput(
      controller: controller,
      type: maxLines > 1 ? InputType.multiline : InputType.text,
      label: required ? '$label *' : label,
      labelClassName: '''
        text-sm font-medium
        text-gray-700 dark:text-gray-300
      ''',
      placeholder: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      validator: validator,
      className: '''
        p-3 border border-slate-200 dark:border-gray-600
        rounded-lg bg-white dark:bg-gray-900
        text-sm text-slate-800 dark:text-slate-200
        focus:border-primary focus:ring-2 focus:ring-primary/20
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
            _submitting ? 'Creating...' : 'Create Project',
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
          'Cancel',
          className: '''
            text-sm font-medium
            text-gray-700 dark:text-gray-300
          ''',
        ),
      ),
    );
  }
}
