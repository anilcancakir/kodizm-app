import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/resources/widgets/organisms/chat_question_card.dart';

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
  required Map<String, dynamic> question,
  required TextEditingController answerController,
  bool isDisabled = false,
  void Function(String questionId, String answer)? onAnswer,
}) {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatQuestionCard(
            question: question,
            isDisabled: isDisabled,
            answerController: answerController,
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

  // -----------------------------------------------------------------------
  // 1. Renders question text and option cards
  // -----------------------------------------------------------------------

  testWidgets('renders question text and option cards', (tester) async {
    _setViewport(tester);
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildWidget(
        answerController: controller,
        question: {
          'questionId': 'q-001',
          'message': 'Which database should we use?',
          'header': 'Architecture Decision',
          'options': [
            {'label': 'PostgreSQL', 'description': 'Relational, ACID'},
            {'label': 'MongoDB'},
          ],
        },
      ),
    );
    await tester.pump();

    // Title from i18n — Wind UI `uppercase` className transforms the text.
    expect(
      find.text(trans('conversation_chat.question_title').toUpperCase()),
      findsOneWidget,
    );
    // Question message
    expect(find.text('Which database should we use?'), findsOneWidget);
    // Option labels
    expect(find.text('PostgreSQL'), findsOneWidget);
    expect(find.text('MongoDB'), findsOneWidget);
    // Option description
    expect(find.text('Relational, ACID'), findsOneWidget);
    // Submit button label
    expect(
      find.text(trans('conversation_chat.question_submit')),
      findsOneWidget,
    );
  });

  // -----------------------------------------------------------------------
  // 2. Tapping an option card calls onAnswer with correct questionId and label
  // -----------------------------------------------------------------------

  testWidgets('tapping option card fires onAnswer with correct args', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    String? capturedId;
    String? capturedAnswer;

    await tester.pumpWidget(
      _buildWidget(
        answerController: controller,
        question: {
          'questionId': 'q-abc',
          'message': 'Pick one:',
          'options': [
            {'label': 'Option A'},
            {'label': 'Option B'},
          ],
        },
        onAnswer: (id, answer) {
          capturedId = id;
          capturedAnswer = answer;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Option A'));
    await tester.pump();

    expect(capturedId, equals('q-abc'));
    expect(capturedAnswer, equals('Option A'));
  });

  // -----------------------------------------------------------------------
  // 3. Free-form submit button fires onAnswer and clears input
  // -----------------------------------------------------------------------

  testWidgets('free-form submit fires onAnswer and clears input', (
    tester,
  ) async {
    _setViewport(tester);
    final controller = TextEditingController();
    String? capturedId;
    String? capturedAnswer;

    await tester.pumpWidget(
      _buildWidget(
        answerController: controller,
        question: {'questionId': 'q-xyz', 'message': 'Describe the issue:'},
        onAnswer: (id, answer) {
          capturedId = id;
          capturedAnswer = answer;
        },
      ),
    );
    await tester.pump();

    // Type into the free-form input
    await tester.enterText(find.byType(WFormInput), 'My free-form answer');
    await tester.pump();

    // Tap the submit button
    await tester.tap(find.text(trans('conversation_chat.question_submit')));
    await tester.pump();

    expect(capturedId, equals('q-xyz'));
    expect(capturedAnswer, equals('My free-form answer'));
    expect(controller.text, isEmpty);
  });
}
