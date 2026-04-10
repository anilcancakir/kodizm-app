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
  if (pipelineConfig case final config?) ...<String, dynamic>{
    'pipeline_config': config,
  },
};

const Map<String, dynamic> kPipelineEnabled = {
  'enabled': true,
  'max_retries': 3,
  'agent_role': 'main-agent',
};

const Map<String, dynamic> kPipelineDisabled = {
  'enabled': false,
  'max_retries': 3,
  'agent_role': 'main-agent',
};

/// Two fake agent roles returned by the roles endpoint.
const List<Map<String, dynamic>> kAgentRoles = [
  {
    'id': 'role-001',
    'team_id': 'team-uuid-001',
    'name': 'Main Agent',
    'slug': 'main-agent',
    'scope': 'general',
    'is_active': true,
    'sort_order': 0,
  },
  {
    'id': 'role-002',
    'team_id': 'team-uuid-001',
    'name': 'Developer',
    'slug': 'dev',
    'scope': 'implementation',
    'is_active': true,
    'sort_order': 1,
  },
];

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

/// Stubs the agent-roles endpoint and pumps [PipelineConfigSection].
///
/// Returns the [FakeHttpDriver] so individual tests can add additional stubs
/// or assert sent requests.
Future<FakeNetworkDriver> _pumpWidget(
  WidgetTester tester,
  Project project, {
  VoidCallback? onSave,
  List<Map<String, dynamic>> roles = kAgentRoles,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final FakeNetworkDriver driver = Http.fake();
  driver.stub('*/agent-roles*', Http.response({'data': roles}));

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PipelineConfigSection(project: project, onSave: onSave),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return driver;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Widget tests for the agent_role dropdown in [PipelineConfigSection].
void main() {
  MagicTest.init();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  // -------------------------------------------------------------------------
  // 1. Dropdown NOT visible when pipeline is disabled
  // -------------------------------------------------------------------------

  group('agent role dropdown visibility', () {
    testWidgets('expanded section collapsed when pipeline is disabled', (
      tester,
    ) async {
      final project = Project.fromMap(
        _projectMap(pipelineConfig: kPipelineDisabled),
      );

      await _pumpWidget(tester, project);

      // AnimatedCrossFade uses showSecond (collapsed) when _enabled is false.
      // The agent role dropdown lives in the firstChild of the AnimatedCrossFade.
      final crossFade = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      expect(crossFade.crossFadeState, CrossFadeState.showSecond);

      // Pipeline toggle shows the disabled label.
      expect(find.text(trans('projects.pipeline.disabled')), findsOneWidget);
      expect(find.text(trans('projects.pipeline.enabled')), findsNothing);
    });

    testWidgets('dropdown visible when pipeline is enabled', (tester) async {
      final project = Project.fromMap(
        _projectMap(pipelineConfig: kPipelineEnabled),
      );

      await _pumpWidget(tester, project);

      // Pipeline is enabled — expanded section is visible.
      expect(find.byType(DropdownButton<String>), findsOneWidget);

      // Agent role label should be present.
      expect(find.text(trans('projects.pipeline.agent_role')), findsOneWidget);
    });

    testWidgets('toggling switch expands agent role section', (tester) async {
      // Start with pipeline disabled (no pipeline_config set).
      final project = Project.fromMap(_projectMap());

      await _pumpWidget(tester, project);

      // Collapsed while switch is OFF.
      final crossFadeBefore = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      expect(crossFadeBefore.crossFadeState, CrossFadeState.showSecond);

      // Tap the toggle switch.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Expanded after switch is ON.
      final crossFadeAfter = tester.widget<AnimatedCrossFade>(
        find.byType(AnimatedCrossFade),
      );
      expect(crossFadeAfter.crossFadeState, CrossFadeState.showFirst);

      // DropdownButton rendered in the expanded section.
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Selecting a role marks _hasChanges (save button becomes enabled)
  // -------------------------------------------------------------------------

  group('role selection updates config', () {
    testWidgets('selecting a different role enables the save button', (
      tester,
    ) async {
      // Project starts with agent_role = 'main-agent' and pipeline enabled.
      final project = Project.fromMap(
        _projectMap(pipelineConfig: kPipelineEnabled),
      );

      await _pumpWidget(tester, project);

      // Save button should be disabled initially (no changes).
      final buttonBefore = tester.widget<WButton>(find.byType(WButton));
      expect(buttonBefore.disabled, isTrue);

      // Open the DropdownButton and select 'Developer' (slug: 'dev').
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // The dropdown items are rendered in an Overlay — tap by displayed name.
      await tester.tap(find.text('Developer').last);
      await tester.pumpAndSettle();

      // Save button should now be enabled because agent_role changed.
      final buttonAfter = tester.widget<WButton>(find.byType(WButton));
      expect(buttonAfter.disabled, isFalse);
    });

    testWidgets('selecting same role keeps save button disabled', (
      tester,
    ) async {
      // Project starts with agent_role = 'main-agent' and pipeline enabled.
      final project = Project.fromMap(
        _projectMap(pipelineConfig: kPipelineEnabled),
      );

      await _pumpWidget(tester, project);

      // Open the dropdown and pick the already-selected 'Main Agent'.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // 'Main Agent' appears both in the button and in the dropdown list.
      // Tap the last occurrence (dropdown item).
      await tester.tap(find.text('Main Agent').last);
      await tester.pumpAndSettle();

      // No actual change — save button stays disabled.
      final button = tester.widget<WButton>(find.byType(WButton));
      expect(button.disabled, isTrue);
    });

    testWidgets('enabling pipeline with changed role enables save button', (
      tester,
    ) async {
      // Start disabled, agent_role not set.
      final project = Project.fromMap(_projectMap());

      await _pumpWidget(tester, project);

      // Enable pipeline via toggle.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // Open dropdown and pick 'Developer'.
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Developer').last);
      await tester.pumpAndSettle();

      // Both enabled flag and agent_role differ from defaults — save enabled.
      final button = tester.widget<WButton>(find.byType(WButton));
      expect(button.disabled, isFalse);
    });
  });
}
