import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/models/agent_question.dart';
import 'package:app/resources/widgets/organisms/question_panel.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

AgentQuestion _pendingQuestion() => AgentQuestion(
  id: 'q-001',
  taskRunId: 'run-001',
  questionText: 'Should I proceed with the refactor?',
  createdAt: DateTime.utc(2025, 6, 10),
);

AgentQuestion _answeredQuestion() => AgentQuestion(
  id: 'q-002',
  taskRunId: 'run-001',
  questionText: 'Which database?',
  answerText: 'PostgreSQL',
  answeredAt: DateTime.utc(2025, 6, 10, 1),
  answeredByUserId: 'user-001',
  createdAt: DateTime.utc(2025, 6, 10),
);

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// Reads `assets/lang/en.json` via [rootBundle] and flattens nested keys.
class _TestAssetLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async {
    try {
      final String content = await rootBundle.loadString(
        'assets/lang/${locale.languageCode}.json',
      );
      final Map<String, dynamic> nested =
          jsonDecode(content) as Map<String, dynamic>;
      return _flatten(nested);
    } catch (_) {
      return {};
    }
  }

  // -------

  /// Recursively flattens nested JSON into dot-separated keys.
  Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = {};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
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

/// Pumps a [QuestionPanel] inside the standard test scaffold.
///
/// Uses a 1440x900 viewport so Wind UI flex layouts do not overflow.
Future<void> _pumpPanel(
  WidgetTester tester,
  List<AgentQuestion> questions, {
  void Function(String)? onSubmitAnswer,
  bool isSubmitting = false,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuestionPanel(
              questions: questions,
              onSubmitAnswer: onSubmitAnswer ?? (_) {},
              isSubmitting: isSubmitting,
            ),
          ),
        ),
      ),
    ),
  );
  // Pump to build, then advance past the 300ms AnimatedSize duration.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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
  // 1. Renders question text when pending question exists
  // -------------------------------------------------------------------------

  testWidgets('renders question text when pending question exists', (
    tester,
  ) async {
    await _pumpPanel(tester, [_pendingQuestion()]);

    // Question text should always render regardless of trans().
    expect(find.text('Should I proceed with the refactor?'), findsOneWidget);
    // Panel title from trans('question.panel_title') = 'Agent Question'.
    // If trans() returns the key itself as fallback, check for that too.
    expect(find.textContaining('Agent Question'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2. Hides panel when no pending questions (empty list)
  // -------------------------------------------------------------------------

  testWidgets('hides panel when no pending questions', (tester) async {
    await _pumpPanel(tester, []);

    expect(find.text('Should I proceed with the refactor?'), findsNothing);
    // Empty WDiv should be rendered inside AnimatedSize.
    expect(find.byType(WDiv), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // 3. Hides panel when all questions are answered
  // -------------------------------------------------------------------------

  testWidgets('hides panel when all questions answered', (tester) async {
    await _pumpPanel(tester, [_answeredQuestion()]);

    expect(find.text('Which database?'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 4. Send button disabled when input is empty
  // -------------------------------------------------------------------------

  testWidgets('send button does not call onSubmitAnswer when input is empty', (
    tester,
  ) async {
    var callCount = 0;
    await _pumpPanel(tester, [
      _pendingQuestion(),
    ], onSubmitAnswer: (_) => callCount++);

    // Tap the send WAnchor without entering any text.
    expect(find.byIcon(Icons.send), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(callCount, equals(0));
  });

  // -------------------------------------------------------------------------
  // 5. Calls onSubmitAnswer with trimmed text on send tap
  // -------------------------------------------------------------------------

  testWidgets('calls onSubmitAnswer with trimmed text on send tap', (
    tester,
  ) async {
    String? captured;
    await _pumpPanel(tester, [
      _pendingQuestion(),
    ], onSubmitAnswer: (text) => captured = text);

    // Find the editable text input (WFormInput wraps an EditableText).
    final editableFinder = find.byType(EditableText);
    expect(editableFinder, findsOneWidget);
    await tester.enterText(editableFinder, '  Yes, proceed.  ');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(captured, equals('Yes, proceed.'));
  });

  // -------------------------------------------------------------------------
  // 6. Shows spinner when isSubmitting is true
  // -------------------------------------------------------------------------

  testWidgets('shows CircularProgressIndicator when isSubmitting is true', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuestionPanel(
                questions: [_pendingQuestion()],
                onSubmitAnswer: (_) {},
                isSubmitting: true,
              ),
            ),
          ),
        ),
      ),
    );
    // Use pump() only — pumpAndSettle hangs with CircularProgressIndicator.
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Send icon is replaced by spinner.
    expect(find.byIcon(Icons.send), findsNothing);
  });
}
