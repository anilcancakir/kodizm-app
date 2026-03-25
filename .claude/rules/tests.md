---
path: "test/**/*.dart"
---

# Testing (TDD with Magic Framework)

## TDD Flow

1. **Red**: Write a failing test that describes the expected behavior
2. **Green**: Write minimum code to make it pass
3. **Refactor**: Clean up while keeping tests green

Every feature branch starts with a test file. No implementation without a failing test first.

## Test File Naming

- Unit tests: `test/unit/{domain}/{class}_test.dart` — e.g., `test/unit/project/project_state_test.dart`
- Widget tests: `test/widget/{domain}/{widget}_test.dart` — e.g., `test/widget/dashboard/dashboard_view_test.dart`
- Integration: `test/integration/{flow}_test.dart` — e.g., `test/integration/auth_flow_test.dart`

## State Class Testing Pattern

```dart
void main() {
  group('ProjectState', () {
    late ProjectState state;

    setUp(() {
      state = ProjectState();
    });

    test('initial state has empty projects and is not loading', () {
      expect(state.projects, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadProjects sets loading then populates list', () async {
      // Mock Http facade responses for the state under test
      await state.loadProjects('team-uuid');
      expect(state.isLoading, isFalse);
      expect(state.projects, isNotEmpty);
    });
  });
}
```

## Widget Testing Pattern

- Use `pumpWidget` with `MaterialApp` wrapper for navigation context
- Verify Wind UI className output via `find.byType(WDiv)` / `find.byType(WText)`
- Test user interactions: `tester.tap()`, `tester.enterText()`, `tester.pump()`
- Verify navigation: mock `MagicRoute` and assert route changes

## What to Test

- State classes: loading/error/success transitions via MagicStateMixin
- Models: `fromMap()` factory with real API response shapes, typed accessor correctness
- Views: renders expected widgets, handles empty/loading/error states, user interactions trigger state methods
- Middleware: auth check redirects correctly
