import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/conversation.dart';
import 'package:app/resources/widgets/organisms/chat_header.dart';

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
// Fixtures
// ---------------------------------------------------------------------------

Conversation _makeConversation({
  String status = 'active',
  String? title,
  String? agentRoleSlug,
  String? agentRoleName,
  double? totalCostUsd,
}) {
  return Conversation(
    id: 'conv-uuid-001',
    projectId: 'proj-uuid-001',
    userId: 'user-uuid-001',
    agentRoleId: 'role-uuid-001',
    status: status,
    title: title ?? 'Test Conversation',
    agentRoleName: agentRoleName ?? 'Business Analyst',
    agentRoleSlug: agentRoleSlug ?? 'ba',
    totalCostUsd: totalCostUsd ?? 0.0012,
    createdAt: DateTime(2026, 3, 27),
    updatedAt: DateTime(2026, 3, 27),
  );
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Widget _buildHeader({
  required Conversation conversation,
  String? sessionPhase,
  String? runningCostUsd,
  bool debugExpanded = false,
  VoidCallback? onComplete,
  VoidCallback? onToggleDebug,
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatHeader(
            conversation: conversation,
            sessionPhase: sessionPhase,
            runningCostUsd: runningCostUsd,
            debugExpanded: debugExpanded,
            onComplete: onComplete,
            onToggleDebug: onToggleDebug,
          ),
        ),
      ),
    ),
  );
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
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
  // Test 1: title, role badge, cost
  // -------------------------------------------------------------------------

  testWidgets('renders conversation title, role badge name, and cost', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(
        conversation: _makeConversation(
          title: 'My Test Conv',
          agentRoleName: 'Business Analyst',
          agentRoleSlug: 'ba',
          totalCostUsd: 0.0012,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('My Test Conv'), findsOneWidget);
    // cost_format: "$:amount" → "$0.0012"
    expect(find.text('\$0.0012'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 2: status badge NOT shown in header (moved to config modal)
  // -------------------------------------------------------------------------

  testWidgets('status badge and complete button not shown in header', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(conversation: _makeConversation(status: 'active')),
    );
    await tester.pump();

    // Status badge and complete button moved to config modal
    expect(find.text('Active'), findsNothing);
    expect(find.text('Complete Chat'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Test 3: running cost preferred over static cost
  // -------------------------------------------------------------------------

  testWidgets('running session cost preferred over static cost', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(
        conversation: _makeConversation(totalCostUsd: 0.0012),
        runningCostUsd: '0.0500',
      ),
    );
    await tester.pump();

    // Running cost shown, not static
    expect(find.text('\$0.0500'), findsOneWidget);
    expect(find.text('\$0.0012'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Test 4: debug toggle appearance based on debugExpanded
  // -------------------------------------------------------------------------

  testWidgets('debug toggle changes appearance based on debugExpanded', (
    tester,
  ) async {
    _setViewport(tester);

    // Collapsed state
    await tester.pumpWidget(
      _buildHeader(conversation: _makeConversation(), debugExpanded: false),
    );
    await tester.pump();

    final collapsedIcon = tester.widget<WIcon>(find.byType(WIcon).last);
    expect(collapsedIcon.className, contains('text-slate-400'));

    // Expanded state
    await tester.pumpWidget(
      _buildHeader(conversation: _makeConversation(), debugExpanded: true),
    );
    await tester.pump();

    final expandedIcon = tester.widget<WIcon>(find.byType(WIcon).last);
    expect(expandedIcon.className, contains('text-amber-600'));
  });

  // -------------------------------------------------------------------------
  // Test 5: session phase badge — hidden when null
  // -------------------------------------------------------------------------

  testWidgets('no phase badge rendered when sessionPhase is null', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(_buildHeader(conversation: _makeConversation()));
    await tester.pump();

    expect(find.text('Provisioning'), findsNothing);
    expect(find.text('Running'), findsNothing);
    expect(find.text('Warm'), findsNothing);
    expect(find.text('Stopped'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Test 6: session phase badge — provisioning with spinner
  // -------------------------------------------------------------------------

  testWidgets('provisioning phase renders blue badge with spinner', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(
        conversation: _makeConversation(),
        sessionPhase: 'provisioning',
      ),
    );
    await tester.pump();

    expect(find.text('Provisioning'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 7: session phase badge — executing with play icon
  // -------------------------------------------------------------------------

  testWidgets('executing phase renders green badge with play icon', (
    tester,
  ) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(
        conversation: _makeConversation(),
        sessionPhase: 'executing',
      ),
    );
    await tester.pump();

    expect(find.text('Running'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_rounded), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 8: session phase badge — warm with pause icon
  // -------------------------------------------------------------------------

  testWidgets('warm phase renders amber badge with pause icon', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(conversation: _makeConversation(), sessionPhase: 'warm'),
    );
    await tester.pump();

    expect(find.text('Warm'), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_rounded), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 9: session phase badge — dead with stop icon
  // -------------------------------------------------------------------------

  testWidgets('dead phase renders slate badge with stop icon', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildHeader(conversation: _makeConversation(), sessionPhase: 'dead'),
    );
    await tester.pump();

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);
  });
}
