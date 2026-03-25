import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

import 'package:app/app/state/task_state.dart';
import 'package:app/resources/views/task/task_create_view.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const Map<String, dynamic> kTaskResponse = {
  'id': 'task-uuid-001',
  'project_id': 'proj-uuid-001',
  'title': 'New Task',
  'type': 'task',
  'priority': 'p2',
  'status': 'draft',
  'created_at': '2024-06-01T10:00:00.000Z',
  'updated_at': '2024-06-01T10:00:00.000Z',
};

// ---------------------------------------------------------------------------
// Fake HTTP client
// ---------------------------------------------------------------------------

/// A test-safe fake [TaskHttpClient] that records calls and returns canned responses.
class FakeTaskHttpClient implements TaskHttpClient {
  /// All recorded HTTP calls.
  final List<TaskHttpCall> calls = [];

  late MagicResponse Function(String url) _responder;

  /// Configures the fake to always return [response] regardless of URL.
  void alwaysReturn(MagicResponse response) {
    _responder = (_) => response;
  }

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('GET', url));
    return _responder(url);
  }

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('POST', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('PUT', url, data: data));
    return _responder(url);
  }

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    calls.add(TaskHttpCall('DELETE', url));
    return _responder(url);
  }
}

/// Records a single HTTP call made through [FakeTaskHttpClient].
class TaskHttpCall {
  /// Creates a [TaskHttpCall].
  TaskHttpCall(this.method, this.url, {this.data});

  /// The HTTP method (GET, POST, PUT, DELETE).
  final String method;

  /// The request URL.
  final String url;

  /// The optional request body.
  final dynamic data;
}

// ---------------------------------------------------------------------------
// Test-safe translation loader
// ---------------------------------------------------------------------------

/// Lightweight [TranslationLoader] for widget tests.
///
/// Reads `assets/lang/en.json` from the asset bundle directly and flattens
/// nested keys into dot-separated form (e.g., `tasks.create_task`).
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

  // -------

  /// Recursively flattens nested JSON into dot-separated keys.
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
// Test helpers
// ---------------------------------------------------------------------------

/// Wraps [TaskCreateView] in [WindTheme] + [MaterialApp] for widget testing.
Widget _buildTestWidget() {
  return WindTheme(
    data: WindThemeData(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskCreateView(projectId: 'proj-uuid-001'),
        ),
      ),
    ),
  );
}

/// Pumps [TaskCreateView] with a wide 1440x900 viewport.
Future<void> _pumpTestWidget(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_buildTestWidget());
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeTaskHttpClient http;
  late TaskState state;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Translator.instance.setLoader(_TestAssetLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  setUp(() {
    http = FakeTaskHttpClient();
    http.alwaysReturn(
      MagicResponse(data: {'data': kTaskResponse}, statusCode: 201),
    );
    state = TaskState(httpClient: http);
    Magic.put<TaskState>(state);
  });

  tearDown(() {
    state.dispose();
    Magic.delete<TaskState>();
  });

  // -------------------------------------------------------------------------
  // 1. Renders form fields for title, description, and acceptance criteria
  // -------------------------------------------------------------------------

  testWidgets(
    'renders form fields for title, description, and acceptance criteria',
    (tester) async {
      await _pumpTestWidget(tester);

      // All three WFormInput widgets must be present.
      expect(find.byType(WFormInput), findsNWidgets(3));

      // Title label.
      expect(find.text('Title *'), findsOneWidget);

      // Description label.
      expect(find.text(trans('tasks.description_label')), findsOneWidget);

      // Acceptance criteria label.
      expect(
        find.text(trans('tasks.acceptance_criteria_label')),
        findsOneWidget,
      );
    },
  );

  // -------------------------------------------------------------------------
  // 2. Validates empty title on submit
  // -------------------------------------------------------------------------

  testWidgets('validates empty title on submit', (tester) async {
    await _pumpTestWidget(tester);

    // Tap the primary button without entering a title.
    await tester.tap(find.byKey(const ValueKey('btn_create_task')));
    await tester.pump();

    // Validation error for empty title should appear.
    expect(find.text(trans('tasks.title_required')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. Type segmented control renders all options
  // -------------------------------------------------------------------------

  testWidgets('type segmented control renders all options', (tester) async {
    await _pumpTestWidget(tester);

    // All four type options must be visible.
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Task'), findsAtLeastNWidgets(1));
    expect(find.text('Bug'), findsOneWidget);
    expect(find.text('Spike'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. Priority segmented control renders all options
  // -------------------------------------------------------------------------

  testWidgets('priority segmented control renders all options', (tester) async {
    await _pumpTestWidget(tester);

    // All four priority options must be visible.
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 5. Cancel button is visible
  // -------------------------------------------------------------------------

  testWidgets('cancel button is visible', (tester) async {
    await _pumpTestWidget(tester);

    // The cancel button should be rendered with the i18n key text.
    expect(find.text(trans('common.cancel')), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 6. Complexity segmented control renders None option
  // -------------------------------------------------------------------------

  testWidgets('complexity segmented control renders None option by default', (
    tester,
  ) async {
    await _pumpTestWidget(tester);

    // The "None" complexity option should be rendered.
    expect(find.text(trans('tasks.complexity_none')), findsOneWidget);

    // All complexity size options must be present.
    expect(find.text(trans('tasks.complexity_xs')), findsOneWidget);
    expect(find.text(trans('tasks.complexity_m')), findsOneWidget);
    expect(find.text(trans('tasks.complexity_xl')), findsOneWidget);
  });
}
