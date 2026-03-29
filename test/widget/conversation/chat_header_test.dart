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
    expect(find.text('Business Analyst'), findsOneWidget);
    // cost_format: "$:amount" → "$0.0012"
    expect(find.text('\$0.0012'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Test 2: complete button visibility based on status
  // -------------------------------------------------------------------------

  testWidgets(
    'complete button visible for active conversation, hidden for completed',
    (tester) async {
      _setViewport(tester);

      // Active — button must appear
      await tester.pumpWidget(
        _buildHeader(conversation: _makeConversation(status: 'active')),
      );
      await tester.pump();

      expect(find.text('Complete Chat'), findsOneWidget);

      // Completed — button must be absent
      await tester.pumpWidget(
        _buildHeader(conversation: _makeConversation(status: 'completed')),
      );
      await tester.pump();

      expect(find.text('Complete Chat'), findsNothing);
    },
  );

  // -------------------------------------------------------------------------
  // Test 3: debug toggle appearance based on debugExpanded
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
}
