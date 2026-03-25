# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Mission

Kodizm Flutter frontend — multi-agent SDLC orchestrator UI. Web + mobile from single codebase.
Built on **magic** + **magic_starter** framework (Laravel-inspired Flutter architecture).

## Commands

| Command | Description |
|---------|-------------|
| `flutter run -d chrome` | Run on web |
| `flutter run -d ios` | Run on iOS simulator |
| `flutter test` | Run all tests |
| `flutter test test/path_test.dart` | Run single test file |
| `dart format lib/ test/` | Format all Dart code |
| `dart analyze` | Static analysis |
| `flutter pub get` | Fetch dependencies |
| `flutter run --dart-define=API_BASE_URL=https://api.kodizm.com` | Run with custom env |

## Architecture

Magic framework follows a **Laravel-inspired** directory convention:

```
lib/
├── main.dart                    # Magic.init() + WindThemeData + runApp
├── app/
│   ├── kernel.dart              # Middleware registration (like Laravel Kernel)
│   ├── middleware/               # Route middleware (auth guards)
│   ├── models/                   # Data models (User, Team — extend magic's base)
│   ├── providers/                # Service + route providers (boot lifecycle)
│   ├── controllers/              # (Future: request controllers)
│   ├── enums/                    # Typed enums
│   ├── events/                   # Event classes
│   ├── listeners/                # Event listeners
│   └── policies/                 # Auth policies
├── config/                       # Config files (app, auth, network, cache, view, magic_starter)
├── resources/views/              # View widgets (pages/screens)
├── routes/app.dart               # All route definitions (MagicRoute)
└── database/                     # (If local DB needed)
```

### Kodizm-Specific Additions (Atomic Design)

Widget structure follows **atomic design** within `lib/resources/`:

```
lib/resources/
├── views/                        # Pages (organisms/templates) — full screens
│   ├── dashboard_view.dart
│   ├── project/                  # Feature-grouped views
│   └── task/
├── widgets/                      # Reusable components
│   ├── atoms/                    # Buttons, badges, status dots, text styles
│   ├── molecules/                # Card headers, form fields, agent badges
│   ├── organisms/                # Task cards, terminal panels, chat bubbles
│   └── templates/                # Page layouts, split views
└── layouts/                      # App shell layouts (magic manages these)
```

## Key Decisions

- **State**: `ChangeNotifier` + `MagicStateMixin` — no Riverpod, no Bloc
- **HTTP**: Always use magic's `Http` facade — never raw Dio
- **Storage**: Always use `Vault` — never flutter_secure_storage directly
- **Routing**: `MagicRoute.page()` / `MagicRoute.group()` — not raw GoRouter
- **IDs**: All model IDs are `String` (UUID from backend) — never `int`
- **Auth**: Sanctum token via magic_starter — do NOT reimplement auth/team/profile screens
- **Theme**: WindThemeData in main.dart — colors, spacing, typography via Wind UI tokens
- **WebSocket**: Custom service for Laravel Reverb (not provided by magic)
- **Dart SDK**: ^3.11.3
- **UI Widgets**: Always Wind UI first — never Flutter native equivalents

## Widget Rules (STRICT)

**Wind UI widgets MUST be used instead of Flutter native widgets. Zero exceptions.**

| Need | Use (Wind UI) | NEVER Use (Flutter Native) |
|------|--------------|---------------------------|
| Container/Box | `WDiv(className: '...')` | `Container`, `DecoratedBox`, `SizedBox` for layout |
| Text | `WText('...', className: '...')` | `Text()`, `RichText()` |
| Icon | `WIcon(Icons.x, className: '...')` | `Icon()` |
| Spacing | `WSpacer(className: 'h-N w-N')` | `SizedBox(height/width:)` for spacing |
| Tap target | `WAnchor(onTap: ..., child: ...)` | `GestureDetector`, `InkWell` |
| Text input | `WFormInput(controller:, type:, label:, ...)` | `TextFormField`, `TextField` |
| Dropdown | `WFormSelect<T>(options:, ...)` | `DropdownButton`, `DropdownButtonFormField` |
| Checkbox | `WFormCheckbox(value:, ...)` | `Checkbox`, `CheckboxListTile` |
| Date picker | `WFormDatePicker(...)` | `showDatePicker()` |

**Styling**: All visual properties via Tailwind `className` strings — never `TextStyle()`, `BoxDecoration()`, `EdgeInsets`, or raw `Color()` constants. Use DESIGN.md tokens via className.

**State modifiers in className**: `focus:`, `error:`, `disabled:`, `hover:`, `checked:`, `dark:` prefixes.

**Exceptions** (Flutter native allowed):
- `Form(key:)` wrapper — Wind UI form widgets integrate with Flutter's `Form`
- `AlertDialog` / `showDialog` — for confirmation dialogs (until Wind UI provides modal)
- `CircularProgressIndicator` — for loading spinners (until Wind UI provides loader)
- `SelectableText` — for copyable text blocks (SSH keys, terminal output)
- `Scaffold` — only at root layout level, managed by magic_starter
- `RefreshIndicator` — for pull-to-refresh (native gesture handler)

## Design System

**`docs/DESIGN.md` is the single source of truth for all visual decisions.**

Every UI component must comply 100% with DESIGN.md:
- Color palette: Primary Navy (hue 230) + Amber Gold (hue 55-80) + semantic colors
- Typography: Albert Sans (body) + JetBrains Mono (code) — constrained type scale
- Spacing: 4px base unit scale — only defined tokens
- Shadows: 5-level elevation system
- Components: Button variants, card styles, input states, badges — all specified
- Agent role colors: BA=Indigo, Lead=Navy, Dev=Teal, Reviewer=Violet, QA=Emerald
- Task status colors: Draft=slate, Analysis=indigo, Planning=blue, InProgress=amber, Done=green

When building any UI, load DESIGN.md first and extract relevant tokens.

## Testing

- `flutter test` — widget tests for screens, unit tests for state/services
- TDD: Write failing test first → implement → refactor
- State classes: test loading/error states via MagicStateMixin
- Widget tests: use `pumpWidget` with magic's test helpers if available

## Specs

All feature specs live in `docs/specs/11-flutter-app/`:
- `wave-1-magic-starter-setup.md` — Framework config, theme, auth verification
- `wave-2-project-dashboard.md` — Project CRUD, dashboard stats
- `wave-3-task-management.md` — Task CRUD, state machine, sections
- `wave-4-agent-execution.md` — Real-time terminal, WebSocket streaming
- `wave-5-qa-knowledge.md` — Agent Q&A, knowledge browser
- `wave-6-billing-settings.md` — Billing, usage, settings

Backend API reference and WebSocket channels documented in `docs/specs/11-flutter-app/overview.md`.

## Skills (Always Active)

| Skill | When | Priority |
|-------|------|----------|
| `magic-framework` | **Every** code task — framework patterns, conventions, lifecycle | Mandatory |
| `wind-ui` | **Every** UI task — Wind UI tokens, components, theme system | Mandatory |
| `frontend-design:frontend-design` | **Every** design/UI task — visual hierarchy, layout, components | Mandatory |

These skills MUST be invoked for any code generation, UI work, or component creation in this project.

## Gotchas

- magic_starter screens (auth, team, profile) are pre-built — configure, don't reimplement
- `MagicRoute.group()` wraps routes with layout and middleware — don't use raw GoRouter
- `Magic.init()` must receive all config factories — missing one breaks bootstrap
- `.env` is loaded as a Flutter asset (declared in pubspec.yaml), not dart-define
- `magic_notifications` is a local path dependency (`../magic_notifications`)
- Wind UI theme colors in main.dart are placeholder — must be replaced with DESIGN.md tokens
