---
trigger: glob
globs: lib/resources/**/*.dart
---

# Views & Widgets (Wind UI + Atomic Design)

## Wind UI Widget System

All layout uses Wind UI widgets with Tailwind CSS className strings:

- `WDiv(className: '...', child/children: [])` — container/div equivalent
- `WText('content', className: '...')` — text rendering
- `WIcon(Icons.name, className: '...')` — icon rendering
- `WSpacer(className: 'h-N w-N')` — spacing
- `WAnchor(onTap: () => ..., child: ...)` — tappable element
- `Launch.url('https://...')` — open external URLs

className uses Tailwind utility classes: `flex`, `items-center`, `gap-3`, `p-4`, `rounded-xl`, `text-sm`, `font-bold`, `bg-primary`, `dark:bg-gray-800`, etc.

Multi-line className: use triple-quote strings for readability when >3 classes.

## Atomic Design Structure

```
lib/resources/
├── views/          # Pages — full screens (organisms/templates level)
├── widgets/
│   ├── atoms/      # Smallest: buttons, badges, status dots, text styles, icons
│   ├── molecules/  # Combinations: card headers, form fields, agent badges, nav items
│   ├── organisms/  # Complex: task cards, terminal panels, chat bubbles, data tables
│   └── templates/  # Page scaffolds: split views, list-detail layouts
└── layouts/        # App shell (managed by magic_starter)
```

- Views are full screens registered in `routes/app.dart`
- Widgets are reusable, composed bottom-up (atoms → molecules → organisms)
- Name convention: file name matches class name in snake_case — e.g., class `SectionCard` → `section_card.dart`, class `PageHeader` → `page_header.dart`
- View naming: `{feature}_view.dart` — e.g., `dashboard_view.dart`, `project_list_view.dart`

## DESIGN.md Compliance (Mandatory)

Before building ANY UI component, read `docs/DESIGN.md` and apply:

- **Colors**: Primary Navy `#334E68`, Accent Amber `#FBBF24`, semantic colors for status
- **Typography**: Albert Sans body, JetBrains Mono code — use constrained type scale only
- **Spacing**: 4px base unit — only defined tokens (space-1 through space-16)
- **Shadows**: 5-level elevation (shadow-none through shadow-xl)
- **Radius**: 6/8/12/16/9999px — only defined values
- **Agent colors**: BA=`#6366F1`, Lead=`#334E68`, Dev=`#14B8A6`, Reviewer=`#8B5CF6`, QA=`#10B981`
- **Task status colors**: Draft=slate, Analysis=indigo, Planning=blue, InProgress=amber, Done=green, Failed=red
- **Buttons**: Primary (amber bg, navy text), Secondary (white, border), Ghost, Danger, Icon
- **Cards**: Surface (white, border, shadow-sm), Inset (slate-50), Elevated (shadow-lg), Terminal (primary-900)

## View Pattern (magic_starter standard)

```dart
class MyFeatureView extends StatelessWidget {
  const MyFeatureView({super.key});

  @override
  Widget build(BuildContext context) {
    return WDiv(
      className: 'p-4 lg:p-6 flex flex-col gap-6',
      children: [
        PageHeader(title: 'Page Title', subtitle: 'Description', actions: [...]),
        SectionCard(title: 'Section', children: [ /* content */ ]),
        SectionCard(children: [ /* more content */ ]),
      ],
    );
  }
}
```

- NO `max-w-*` constraints — views are full-width
- NO `SingleChildScrollView` — layout's `overflow-y-auto` handles scrolling
- `PageHeader` from `molecules/page_header.dart` — border-b, responsive sm:flex-row, actions list
- `SectionCard` from `molecules/section_card.dart` — rounded-2xl, p-6, gap-4, noPadding option
