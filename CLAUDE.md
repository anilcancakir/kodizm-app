# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Mission

Kodizm Flutter frontend — multi-agent SDLC orchestrator UI. Web + mobile from single codebase.
Built on **magic** + **magic_starter** framework (Laravel-inspired Flutter architecture).

## Related Projects

| Project | Path | Purpose |
|---------|------|---------|
| **Kodizm API** | `/Users/anilcan/Code/kodizm/api` | Laravel backend — source of truth for API response shapes, controllers, resources |
| **magic** | `/Users/anilcan/Code/fluttersdk/magic` | Core framework — Http, Auth, Vault, MagicRoute, MagicStateMixin, Config |
| **magic_starter** | `/Users/anilcan/Code/fluttersdk/magic_starter` | App scaffold — auth screens, layout, PageHeader/Card patterns. **Reference for view standards** |
| **Wind UI** | `/Users/anilcan/Code/fluttersdk/wind` | Tailwind-for-Flutter — WDiv, WText, WIcon, WSpacer, WAnchor, WFormInput |

When building views, cross-reference magic_starter's default views for layout patterns. When debugging Wind UI className issues, read the Wind source.

## Commands

| Command | Description |
|---------|-------------|
| `flutter test` | Run all tests |
| `flutter test test/path_test.dart` | Run single test file |
| `dart format lib/ test/` | Format all Dart code |
| `dart analyze` | Static analysis |
| `flutter run -d chrome` | Run on web |

## Architecture

Magic framework follows a **Laravel-inspired** directory convention:

```
lib/
├── main.dart                    # Magic.init() + WindThemeData + runApp
├── app/
│   ├── models/                   # Data models (extend magic's base)
│   ├── state/                    # State classes (ChangeNotifier + MagicStateMixin)
│   ├── providers/                # Service + route providers (boot lifecycle)
│   └── middleware/               # Route middleware (auth guards)
├── config/                       # Config files (app, auth, network, cache, view)
├── resources/
│   ├── views/                    # Pages — full screens, feature-grouped
│   ├── widgets/                  # Atomic design: atoms/ molecules/ organisms/ templates/
│   └── layouts/                  # App shell layouts (magic manages these)
├── routes/app.dart               # All route definitions (MagicRoute)
└── docs/DESIGN.md                # Single source of truth for all visual decisions
```

## Key Decisions

- **State**: `ChangeNotifier` + `MagicStateMixin` — no Riverpod, no Bloc
- **HTTP**: `Http` facade — never raw Dio
- **Routing**: `MagicRoute.page()` / `MagicRoute.group()` — not raw GoRouter
- **IDs**: All model IDs are `String` (UUID) — never `int`
- **Auth**: Sanctum token via magic_starter — do NOT reimplement auth/team/profile screens
- **Dart SDK**: ^3.11.3
- **UI**: Wind UI first — never Flutter native equivalents (see Widget Rules)

## Widget Rules (STRICT)

**Wind UI widgets MUST be used. Zero exceptions outside the allowed list.**

| Need | Use (Wind UI) | NEVER Use (Flutter Native) |
|------|--------------|---------------------------|
| Container/Box | `WDiv(className: '...')` | `Container`, `DecoratedBox`, `SizedBox` for layout |
| Flex Row | `WDiv(className: 'flex flex-row gap-N')` | `Row` |
| Flex Column | `WDiv(className: 'flex flex-col gap-N')` | `Column` |
| Flex child fill | `WDiv(className: 'flex-1')` | `Expanded`, `Flexible` |
| Text | `WText('...', className: '...')` | `Text()`, `RichText()` |
| Icon | `WIcon(Icons.x, className: '...')` | `Icon()` |
| Spacing | `WSpacer(className: 'h-N w-N')` or parent `gap-N` | `SizedBox(height/width:)` |
| Tap target | `WAnchor(onTap: ..., child: ...)` | `GestureDetector`, `InkWell` |
| Text input | `WFormInput(controller:, label:, ...)` | `TextFormField`, `TextField` |
| Clipping | `WDiv(className: 'rounded-lg overflow-hidden')` | `ClipRRect` |
| Wrap layout | `WDiv(className: 'flex flex-wrap gap-N')` | `Wrap` |
| Opacity | `className: 'opacity-50'` | `Opacity` widget |
| Decoration | `className` tokens | `BoxDecoration`, `TextStyle()`, `EdgeInsets`, raw `Color()` |

**Styling**: All visual properties via Tailwind `className` strings. Use `docs/DESIGN.md` tokens.

**Dynamic colors** (agent roles, task status): Use predefined className variant maps, not `Color()` objects. Example: `_agentRoleClassName('ba') => 'bg-indigo-500/10 text-indigo-500'`.

**Exceptions** (Flutter native allowed):
- `Form(key:)`, `AlertDialog`/`showDialog`, `CircularProgressIndicator`, `SelectableText`, `Scaffold`, `RefreshIndicator`, `ListView` (for scroll physics)
- `SizedBox` ONLY when wrapping `CircularProgressIndicator` for sizing

## Design System

**`docs/DESIGN.md` is the single source of truth for all visual decisions.** Load it before building ANY UI.

- Color palette: Primary Navy (hue 230) + Amber Gold (hue 55-80) + semantic colors
- Typography: Albert Sans (body) + JetBrains Mono (code) — constrained type scale
- Spacing: 4px base unit scale — only defined tokens
- Components: Buttons, cards, inputs, badges, navigation — all specified with exact values
- Agent role colors: BA=Indigo, Lead=Navy, Dev=Teal, Reviewer=Violet, QA=Emerald
- Task status colors: Draft=slate, Analysis=indigo, Planning=blue, InProgress=amber, Done=green

## View Layout Standard

**All views follow magic_starter's layout pattern exactly:**

```dart
// Root wrapper — NO max-w-*, NO SingleChildScrollView (layout handles scrolling)
WDiv(
  className: 'p-4 lg:p-6 flex flex-col gap-6',
  children: [
    PageHeader(title: '...', subtitle: '...', actions: [...]),
    SectionCard(title: '...', children: [...]),
    SectionCard(children: [...]),
  ],
)
```

- `PageHeader` molecule: `lib/resources/widgets/molecules/page_header.dart` — border-b divider, responsive, actions list
- `SectionCard` molecule: `lib/resources/widgets/molecules/section_card.dart` — rounded-2xl, p-6, gap-4, optional noPadding
- File naming: class name → snake_case file name (e.g., `SectionCard` → `section_card.dart`)

## Testing

- Widget tests: wrap in `Scaffold(body: SingleChildScrollView(child: widget))` — magic_starter test pattern
- Wind UI flex layouts may need larger test viewport (1440x900) with `tester.view.physicalSize`
- State classes: test loading/error/success via `MagicStateMixin`

## Skills (Always Active)

| Skill | When | Priority |
|-------|------|----------|
| `magic-framework` | **Every** code task — framework patterns, conventions, lifecycle | Mandatory |
| `wind-ui` | **Every** UI task — Wind UI tokens, components, theme system | Mandatory |
| `frontend-design:frontend-design` | **Every** design/UI task — visual hierarchy, layout, components | Mandatory |

## Gotchas

- magic_starter screens (auth, team, profile) are pre-built — configure, don't reimplement
- `.env` is loaded as a Flutter asset (declared in pubspec.yaml), not dart-define
- `magic_notifications` is a local path dependency (`../magic_notifications`)
- Wind UI `flex flex-row` with `flex-1` children requires `axis-max` className for `MainAxisSize.max`
- Dynamic color maps (agent roles, task status) must use className variant maps, not `Color()` objects — exception: chart fills needing proportional widths with dynamic colors
- `SelectableText` needs `TextStyle` (allowed exception) — can't use className for font-family
