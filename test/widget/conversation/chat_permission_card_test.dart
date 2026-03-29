import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/organisms/chat_permission_card.dart';

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

Widget _buildWidget({
  required Map<String, dynamic> permission,
  bool isDisabled = false,
  void Function(String questionId, String answer)? onAnswer,
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatPermissionCard(
            permission: permission,
            isDisabled: isDisabled,
            onAnswer: onAnswer ?? (_, _) {},
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
  // 1. Renders tool name and permission title
  // -------------------------------------------------------------------------

  testWidgets('renders permission title and tool name', (tester) async {
    _setViewport(tester);

    await tester.pumpWidget(
      _buildWidget(
        permission: {
          'questionId': 'q-001',
          'toolName': 'WriteFile',
          'input': {'path': '/tmp/out.txt'},
        },
      ),
    );
    await tester.pump();

    expect(
      find.text(trans('conversation_chat.permission_title')),
      findsOneWidget,
    );
    expect(
      find.text(
        trans('conversation_chat.permission_tool', {'tool': 'WriteFile'}),
      ),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // 2. Approve and deny buttons call onAnswer with correct arguments
  // -------------------------------------------------------------------------

  testWidgets('approve and deny buttons call onAnswer with correct args', (
    tester,
  ) async {
    _setViewport(tester);

    final calls = <(String, String)>[];

    await tester.pumpWidget(
      _buildWidget(
        permission: {
          'questionId': 'q-001',
          'toolName': 'ReadFile',
          'input': null,
        },
        onAnswer: (questionId, answer) => calls.add((questionId, answer)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(trans('conversation_chat.permission_approve')));
    await tester.pump();

    await tester.tap(find.text(trans('conversation_chat.permission_deny')));
    await tester.pump();

    expect(calls, equals([('q-001', 'approve'), ('q-001', 'deny')]));
  });

  // -------------------------------------------------------------------------
  // 3. Disabled state — buttons do not fire callbacks
  // -------------------------------------------------------------------------

  testWidgets('disabled state prevents onAnswer from firing', (tester) async {
    _setViewport(tester);

    var callCount = 0;

    await tester.pumpWidget(
      _buildWidget(
        permission: {
          'questionId': 'q-002',
          'toolName': 'DeleteFile',
          'input': null,
        },
        isDisabled: true,
        onAnswer: (_, _) => callCount++,
      ),
    );
    await tester.pump();

    await tester.tap(find.text(trans('conversation_chat.permission_approve')));
    await tester.pump();

    await tester.tap(find.text(trans('conversation_chat.permission_deny')));
    await tester.pump();

    expect(callCount, equals(0));
  });
}
