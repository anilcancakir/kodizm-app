# Kodizm Flutter Frontend - Agent Guide

## Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `flutter test test/path_test.dart` | Run single test file |
| `dart format lib/ test/` | Format all Dart code |
| `dart analyze` | Static analysis |
| `flutter run -d chrome` | Run on web |

## Development Flow (TDD)

1. Write a failing test first (Red)
2. Write minimum code to pass (Green)
3. Refactor while keeping tests green

## Verification Checklist

After every change:
- `dart analyze` passes with zero warnings
- `flutter test` passes (or relevant test group)
- `dart format lib/ test/` applied

## Git Conventions

- English only for all code, comments, commit messages
- Strict types on every param, return, property
- Zero linter warnings, no suppressions

## Framework Conventions

- **Import order**: `dart:` -> `package:flutter/` -> `package:magic/` -> `package:magic_starter/` -> relative imports
- **State classes**: `extends ChangeNotifier with MagicStateMixin`
- **HTTP**: `Http.get()`, `Http.post()`, `Http.put()`, `Http.delete()`
- **Routing**: `MagicRoute.to()`, `MagicRoute.page()`, `MagicRoute.group()`
- **Auth**: `Auth.check()`, `Auth.id()`, `Auth.user<User>()`, `Auth.logout()`
- **Config**: `Config.get('key.nested', defaultValue)`
- **Logging**: `Log.debug()`, `Log.error()`, `Log.info()` (never `print()`)
- **Storage**: `Vault` facade (never flutter_secure_storage directly)
- **Environment**: `env('KEY', defaultValue)` helper

## Model Convention

- All IDs are `String` (UUID), `incrementing` always `false`
- Typed getters: `getAttribute('key') as Type?`
- `fromMap()` uses `setRawAttributes(map, sync: true)`
- `fromJson()` delegates to `fromMap()`

## UI Rules

- All layout via Wind UI widgets with Tailwind `className` strings
- Design tokens from `docs/DESIGN.md`
- i18n via `trans('section.key')` from `assets/lang/en.json`
- Atomic design: atoms/ molecules/ organisms/ templates/ in `lib/resources/widgets/`
- Views: `lib/resources/views/`, named `{feature}_view.dart`

## Related Projects

| Project | Purpose |
|---------|---------|
| Kodizm API | Laravel backend (API response shapes, controllers) |
| magic | Core framework (Http, Auth, Vault, MagicRoute, Config) |
| magic_starter | App scaffold (auth screens, layout, PageHeader/Card patterns) |
| Wind UI | Tailwind-for-Flutter widget library |
