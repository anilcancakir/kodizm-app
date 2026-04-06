import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic/testing.dart';

import 'package:app/app/models/project.dart';
import 'package:app/resources/widgets/organisms/pipeline_config_section.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _projectMap({Map<String, dynamic>? pipelineConfig}) => {
  'id': 'proj-uuid-001',
  'team_id': 'team-uuid-001',
  'name': 'Alpha',
  'short_name': 'ALP',
  'slug': 'alpha',
  'description': 'Test project.',
  'tech_stack': <String>['Flutter'],
  'execution_mode': 'manual',
  if (pipelineConfig != null) 'pipeline_config': pipelineConfig,
};

const Map<String, dynamic> kPipelineConfig = {
  'enabled': true,
  'max_retries': 3,
  'stages': [
    {'name': 'analysis', 'role': 'product-manager', 'auto': true},
    {'name': 'planning', 'role': 'lead-developer', 'auto': true},
    {'name': 'implement', 'role': 'developer', 'auto': false},
    {'name': 'review', 'role': 'code-reviewer', 'auto': true},
  ],
};

// ---------------------------------------------------------------------------
// Translation loader
// ---------------------------------------------------------------------------

class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final nested = jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final result = <String, dynamic>{};
    for (final entry in json.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildTestWidget(Project project, {VoidCallback? onSave}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PipelineConfigSection(project: project, onSave: onSave),
        ),
      ),
    ),
  );
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Project project, {
  VoidCallback? onSave,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(_buildTestWidget(project, onSave: onSave));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  MagicTest.init();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    Http.fake();
  });

  // -------------------------------------------------------------------------
  // 1. Renders section title and subtitle
  // -------------------------------------------------------------------------

  testWidgets('renders pipeline section title and subtitle', (tester) async {
    final project = Project.fromMap(_projectMap());

    await _pumpWidget(tester, project);

    expect(find.text(trans('projects.pipeline.title')), findsOneWidget);
    expect(find.text(trans('projects.pipeline.subtitle')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Shows disabled state by default
  // -------------------------------------------------------------------------

  testWidgets('shows disabled toggle when pipeline not configured', (
    tester,
  ) async {
    final project = Project.fromMap(_projectMap());

    await _pumpWidget(tester, project);

    // The disabled label should be visible.
    expect(find.text(trans('projects.pipeline.disabled')), findsOneWidget);

    // The main enable switch should be OFF.
    final mainSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(mainSwitch.value, isFalse);
  });

  // -------------------------------------------------------------------------
  // 3. Toggle enables pipeline and shows stage rows
  // -------------------------------------------------------------------------

  testWidgets('toggling switch shows stage rows', (tester) async {
    final project = Project.fromMap(_projectMap());

    await _pumpWidget(tester, project);

    // Tap the main enable switch (first Switch in the widget tree).
    final switchFinder = find.byType(Switch).first;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Now all 4 stage rows should be visible.
    expect(
      find.text(trans('projects.pipeline.stage_analysis')),
      findsOneWidget,
    );
    expect(
      find.text(trans('projects.pipeline.stage_planning')),
      findsOneWidget,
    );
    expect(
      find.text(trans('projects.pipeline.stage_implement')),
      findsOneWidget,
    );
    expect(find.text(trans('projects.pipeline.stage_review')), findsOneWidget);

    // Enabled label should now be visible.
    expect(find.text(trans('projects.pipeline.enabled')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Renders stage rows with role badges when enabled
  // -------------------------------------------------------------------------

  testWidgets('renders role badges for each stage', (tester) async {
    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    await _pumpWidget(tester, project);

    // All 4 role badges should be visible.
    expect(
      find.text(trans('projects.pipeline.role_product_manager')),
      findsOneWidget,
    );
    expect(
      find.text(trans('projects.pipeline.role_lead_developer')),
      findsOneWidget,
    );
    expect(
      find.text(trans('projects.pipeline.role_developer')),
      findsOneWidget,
    );
    expect(
      find.text(trans('projects.pipeline.role_code_reviewer')),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 5. Stage auto/pause toggles reflect config
  // -------------------------------------------------------------------------

  testWidgets('stage toggles reflect persisted config values', (tester) async {
    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    await _pumpWidget(tester, project);

    // The implement stage has auto=false in the fixture, so "Pause" label
    // should appear.
    expect(
      find.text(trans('projects.pipeline.pause_for_approval')),
      findsOneWidget,
    );

    // The other 3 stages should show "Auto".
    expect(
      find.text(trans('projects.pipeline.auto_advance')),
      findsNWidgets(3),
    );
  });

  // -------------------------------------------------------------------------
  // 6. Max retries field renders with correct value
  // -------------------------------------------------------------------------

  testWidgets('max retries field shows configured value', (tester) async {
    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    await _pumpWidget(tester, project);

    // Max retries label.
    expect(find.text(trans('projects.pipeline.max_retries')), findsOneWidget);

    // The input should contain '3'.
    final inputFinder = find.byType(WFormInput);
    expect(inputFinder, findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 7. Save button disabled when no changes
  // -------------------------------------------------------------------------

  testWidgets('save button disabled when no changes made', (tester) async {
    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    await _pumpWidget(tester, project);

    // Save button should be present.
    expect(find.text(trans('projects.pipeline.save')), findsOneWidget);

    // The WButton should be disabled (no changes yet).
    final button = tester.widget<WButton>(find.byType(WButton));
    expect(button.disabled, isTrue);
  });

  // -------------------------------------------------------------------------
  // 8. Save button enabled after toggling a stage
  // -------------------------------------------------------------------------

  testWidgets('save button enabled after toggling a stage', (tester) async {
    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    await _pumpWidget(tester, project);

    // Toggle the first stage switch (the second Switch widget — first is the
    // main enable toggle).
    final switches = find.byType(Switch);
    // Main toggle + 4 stage toggles + max-retries doesn't have a switch = 5
    expect(switches, findsNWidgets(5));

    // Tap the second switch (analysis stage).
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();

    // Save button should now be enabled.
    final button = tester.widget<WButton>(find.byType(WButton));
    expect(button.disabled, isFalse);
  });

  // -------------------------------------------------------------------------
  // 9. Save calls HTTP PUT
  // -------------------------------------------------------------------------

  testWidgets('save sends PUT request with pipeline config', (tester) async {
    final driver = Http.fake();
    driver.stub(
      '*/projects/*',
      Http.response({'data': _projectMap(pipelineConfig: kPipelineConfig)}),
    );

    final project = Project.fromMap(
      _projectMap(pipelineConfig: kPipelineConfig),
    );

    bool onSaveCalled = false;

    await _pumpWidget(tester, project, onSave: () => onSaveCalled = true);

    // Toggle the main switch OFF to create a change.
    final mainSwitch = find.byType(Switch).first;
    await tester.tap(mainSwitch);
    await tester.pumpAndSettle();

    // Tap save.
    final saveButton = find.text(trans('projects.pipeline.save'));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify the PUT was called.
    driver.assertSent((r) => r.url.contains('/projects/'));
    expect(onSaveCalled, isTrue);
  });
}
