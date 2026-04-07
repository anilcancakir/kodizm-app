import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/conversation.dart';
import 'package:app/app/models/task_section.dart';
import 'package:app/resources/widgets/atoms/status_badge.dart';
import 'package:app/resources/widgets/organisms/task_activity_feed.dart';

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

Widget _wrap(Widget widget) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime.utc(2025, 6, 15, 10, 0, 0);

TaskSection _makeSection({
  String type = 'analysis',
  String title = 'Analysis Output',
  String content = '## Summary\n\nSome analysis.',
  int version = 1,
  DateTime? createdAt,
}) {
  return TaskSection(
    id: 'sec-001',
    taskId: 'task-001',
    type: type,
    title: title,
    content: content,
    version: version,
    createdAt: createdAt ?? _now.subtract(const Duration(hours: 2)),
    updatedAt: _now,
  );
}

Conversation _makeConversation({
  String id = 'conv-001',
  String status = 'completed',
  String? agentRoleName = 'Business Analyst',
  double? totalCostUsd = 0.42,
  DateTime? startedAt,
  DateTime? createdAt,
}) {
  final created = createdAt ?? _now.subtract(const Duration(hours: 1));
  return Conversation(
    id: id,
    projectId: 'proj-001',
    userId: 'user-001',
    agentRoleId: 'role-001',
    status: status,
    createdAt: created,
    updatedAt: _now,
    agentRoleName: agentRoleName,
    totalCostUsd: totalCostUsd,
    startedAt: startedAt,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  // -------------------------------------------------------------------------
  // 1. Tab bar renders with "All" and "Runs" tabs
  // -------------------------------------------------------------------------

  group('tab bar', () {
    testWidgets('renders All and Runs tabs', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: const [],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(trans('tasks.detail_tab_all')), findsOneWidget);
      expect(find.text(trans('tasks.detail_tab_runs')), findsOneWidget);
    });

    testWidgets('tapping Runs tab switches to runs content', (tester) async {
      _setViewport(tester);

      final conv = _makeConversation();

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on All tab — agent role name should appear.
      expect(find.text(conv.agentRoleName!), findsOneWidget);

      // Tap Runs tab.
      await tester.tap(find.text(trans('tasks.detail_tab_runs')));
      await tester.pumpAndSettle();

      // Runs tab still shows conversations.
      expect(find.text(conv.agentRoleName!), findsOneWidget);
    });

    testWidgets('tapping All tab after Runs returns to All content', (
      tester,
    ) async {
      _setViewport(tester);

      final section = _makeSection();
      final conv = _makeConversation();

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [section],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Runs.
      await tester.tap(find.text(trans('tasks.detail_tab_runs')));
      await tester.pumpAndSettle();

      // Switch back to All.
      await tester.tap(find.text(trans('tasks.detail_tab_all')));
      await tester.pumpAndSettle();

      // Section title should be visible again in All tab.
      expect(find.text(section.title), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 2. "All" tab content
  // -------------------------------------------------------------------------

  group('All tab', () {
    testWidgets('shows section title and type badge', (tester) async {
      _setViewport(tester);

      final section = _makeSection(type: 'analysis', title: 'My Analysis');

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [section],
            conversations: const [],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Analysis'), findsOneWidget);
      expect(find.text(trans('tasks.section_type_analysis')), findsOneWidget);
    });

    testWidgets('shows conversation agent role and status badge', (
      tester,
    ) async {
      _setViewport(tester);

      final conv = _makeConversation(
        agentRoleName: 'Business Analyst',
        status: 'completed',
      );

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Business Analyst'), findsOneWidget);
      expect(find.byType(StatusBadge), findsOneWidget);
    });

    testWidgets('shows cost formatted correctly', (tester) async {
      _setViewport(tester);

      final conv = _makeConversation(totalCostUsd: 1.5);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$1.50'), findsOneWidget);
    });

    testWidgets('shows -- when cost is null', (tester) async {
      _setViewport(tester);

      final conv = _makeConversation(totalCostUsd: null);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('shows version badge on section', (tester) async {
      _setViewport(tester);

      final section = _makeSection(version: 3);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [section],
            conversations: const [],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('v3'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. "Runs" tab content
  // -------------------------------------------------------------------------

  group('Runs tab', () {
    testWidgets('shows only conversations (no sections)', (tester) async {
      _setViewport(tester);

      final section = _makeSection(title: 'Section Only In All');
      final conv = _makeConversation(agentRoleName: 'Lead');

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [section],
            conversations: [conv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(trans('tasks.detail_tab_runs')));
      await tester.pumpAndSettle();

      // Section title should NOT appear in Runs tab.
      expect(find.text('Section Only In All'), findsNothing);
      // Conversation role should appear.
      expect(find.text('Lead'), findsOneWidget);
    });

    testWidgets('shows multiple conversations', (tester) async {
      _setViewport(tester);

      final conv1 = _makeConversation(
        id: 'conv-001',
        agentRoleName: 'Business Analyst',
        createdAt: _now.subtract(const Duration(hours: 2)),
      );
      final conv2 = _makeConversation(
        id: 'conv-002',
        agentRoleName: 'Developer',
        createdAt: _now.subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [conv1, conv2],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(trans('tasks.detail_tab_runs')));
      await tester.pumpAndSettle();

      expect(find.text('Business Analyst'), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Empty state
  // -------------------------------------------------------------------------

  group('empty state', () {
    testWidgets('shows empty state when both lists are empty', (tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: const [],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(trans('tasks.detail_no_activity')), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('does not show empty state when sections exist', (
      tester,
    ) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [_makeSection()],
            conversations: const [],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(trans('tasks.detail_no_activity')), findsNothing);
    });

    testWidgets('does not show empty state when conversations exist', (
      tester,
    ) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: const [],
            conversations: [_makeConversation()],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(trans('tasks.detail_no_activity')), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Sorting — newest first
  // -------------------------------------------------------------------------

  group('sorting', () {
    testWidgets('All tab items ordered newest first by date', (tester) async {
      _setViewport(tester);

      // Older section, newer conversation.
      final olderSection = _makeSection(
        title: 'Old Section',
        createdAt: _now.subtract(const Duration(hours: 5)),
      );
      final newerConv = _makeConversation(
        agentRoleName: 'New Run',
        createdAt: _now.subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(
        _wrap(
          TaskActivityFeed(
            sections: [olderSection],
            conversations: [newerConv],
            projectId: 'proj-001',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify both are present — order checked via widget positions.
      final convFinder = find.text('New Run');
      final sectionFinder = find.text('Old Section');

      expect(convFinder, findsOneWidget);
      expect(sectionFinder, findsOneWidget);

      // Newer item (conversation) should appear before older item (section).
      final convOffset = tester.getTopLeft(convFinder).dy;
      final sectionOffset = tester.getTopLeft(sectionFinder).dy;
      expect(convOffset, lessThan(sectionOffset));
    });
  });
}
