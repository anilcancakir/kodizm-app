# Kodizm Flutter Frontend

Multi-agent SDLC orchestrator UI. Web + mobile from single Flutter codebase.
Built on **magic** + **magic_starter** framework (Laravel-inspired Flutter architecture).

## Architecture

```
lib/
├── main.dart                     # Magic.init() + WindThemeData + runApp
├── app/
│   ├── models/                   # Data models (extend magic's base Model)
│   ├── state/                    # State classes (ChangeNotifier + MagicStateMixin)
│   ├── providers/                # Service + route providers (boot lifecycle)
│   └── middleware/               # Route middleware (auth guards)
├── config/                       # Config files (app, auth, network, cache, view)
├── resources/
│   ├── views/                    # Pages (full screens, feature-grouped)
│   ├── widgets/                  # Atomic design: atoms/ molecules/ organisms/ templates/
│   └── layouts/                  # App shell layouts
├── routes/app.dart               # All route definitions (MagicRoute)
└── docs/DESIGN.md                # Single source of truth for visual decisions
```

## Key Decisions

- **State**: `ChangeNotifier` + `MagicStateMixin`. No Riverpod, no Bloc.
- **HTTP**: `Http` facade. Never raw Dio.
- **Routing**: `MagicRoute.page()` / `MagicRoute.group()`. Not raw GoRouter.
- **IDs**: All model IDs are `String` (UUID). Never `int`.
- **UI**: Wind UI first (`WDiv`, `WText`, `WIcon`, `WSpacer`, `WAnchor` with Tailwind `className`). Never Flutter native Row, Column, Container, Expanded, SizedBox (except CircularProgressIndicator wrapper), Icon, Text, TextFormField.
- **i18n**: All user-facing strings via `trans('dot.key')` from `assets/lang/en.json`. Never hardcode.
- **Design tokens**: `docs/DESIGN.md` is the single source of truth for all colors, spacing, typography, components.

## View Layout Standard

```dart
WDiv(
  className: 'p-4 lg:p-6 flex flex-col gap-6',
  children: [
    PageHeader(title: '...', subtitle: '...', actions: [...]),
    SectionCard(title: '...', children: [...]),
  ],
)
```

No `max-w-*` constraints. No `SingleChildScrollView` (layout handles scrolling).

## Widget Rules

| Need | Use (Wind UI) | Never Use |
|------|--------------|-----------|
| Container/Box | `WDiv(className: '...')` | `Container`, `SizedBox` for layout |
| Row/Column | `WDiv(className: 'flex flex-row/col gap-N')` | `Row`, `Column` |
| Fill space | `WDiv(className: 'flex-1')` | `Expanded`, `Flexible` |
| Text | `WText('...', className: '...')` | `Text()`, `RichText()` |
| Tap target | `WAnchor(onTap: ..., child: ...)` | `GestureDetector`, `InkWell` |
| Input | `WFormInput(controller:, label:, ...)` | `TextFormField` |

## Gotchas

- `magic_starter` screens (auth, team, profile) are pre-built. Configure, don't reimplement.
- `.env` is loaded as a Flutter asset, not dart-define.
- Wind UI `flex flex-row` with `flex-1` children requires `axis-max` className.
- Dynamic color maps must use className variant maps, not `Color()` objects.
- `WDiv` with `flex justify-center/end` MUST include `w-full`.
- NEVER `w-full` inside `flex-wrap` or around `DropdownButton` (crashes production).
