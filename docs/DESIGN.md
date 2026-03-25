# Design System: Kodizm

> Semantic design system for the Kodizm multi-agent SDLC platform.
> Mobile-first, Apple-inspired clarity, Refactoring UI discipline.
> Source brand: logo + tokens from kodizm.com.

---

## 1. Visual Theme & Atmosphere

**Personality**: Confident, precise, trustworthy. The visual language of a professional engineering tool that respects the user's intelligence — not playful, not sterile, but *purposeful*. Think Linear meets Apple's developer tools: every pixel earns its place.

**Mood**: Clean and spacious with deliberate density only where data demands it (task boards, streaming terminals, usage tables). The interface breathes through generous whitespace on primary screens, then tightens into focused, information-rich panels during agent execution.

**Design Philosophy** (Refactoring UI principles):
- **Hierarchy through weight and color, not size** — de-emphasize secondary content with softer colors rather than shrinking text
- **Constrained choices** — all values come from pre-defined scales (spacing, type, color, shadow, radius)
- **Labels are a last resort** — use context, formatting, and position to communicate meaning before reaching for a label
- **Emphasize by de-emphasizing everything else** — make the primary action obvious by making surrounding elements quieter
- **Start with too much whitespace** — then remove only what you must

---

## 2. Color Palette & Roles

### Brand Colors (from logo + tokens.css)

The brand pairs a deep authoritative navy with a warm confident amber — the clock tower and code. All shades are derived from the oklch tokens at hue 230 (primary) and hue 55-80 (secondary), mapped to Tailwind-compatible hex values.

#### Primary — Deep Steel Navy (hue 230)
The color of trust, engineering precision, and quiet authority.

| Token | Hex | Role |
|-------|-----|------|
| `primary-50` | `#F0F4F8` | Tinted backgrounds, hover states on light surfaces |
| `primary-100` | `#D9E2EC` | Subtle borders, divider lines, disabled backgrounds |
| `primary-200` | `#BCCCDC` | Placeholder text, tertiary icons |
| `primary-300` | `#829AB1` | Secondary text, breadcrumbs, metadata |
| `primary-400` | `#486581` | Body text on light backgrounds, inactive nav items |
| `primary-500` | `#334E68` | Primary body text, active nav labels — **the workhorse** |
| `primary-600` | `#2B3F56` | Headings, emphasis text, card titles |
| `primary-700` | `#243346` | Page titles, high-emphasis headings |
| `primary-800` | `#1E2A38` | App shell background (dark mode), sidebar background |
| `primary-900` | `#1A2332` | Terminal/streaming view background |
| `primary-950` | `#0F1520` | Deepest overlay, modal backdrops |

#### Secondary — Warm Amber Gold (hue 55-80)
The color of action, progress, and the clock tower. Used sparingly for maximum impact.

| Token | Hex | Role |
|-------|-----|------|
| `secondary-50` | `#FFFBEB` | Warning/info banner backgrounds |
| `secondary-100` | `#FEF3C7` | Highlight backgrounds, selected row tint |
| `secondary-200` | `#FDE68A` | Progress bar fills (partial), badge backgrounds |
| `secondary-300` | `#FCD34D` | Star ratings, active indicator dots |
| `secondary-400` | `#FBBF24` | Primary CTA buttons, floating action buttons — **the accent** |
| `secondary-500` | `#D9A520` | CTA button hover state, active tab indicators |
| `secondary-600` | `#B8860B` | CTA button pressed state, link hover on dark backgrounds |
| `secondary-700` | `#92690A` | Badge text on light amber backgrounds |
| `secondary-800` | `#755506` | High-contrast text on amber surfaces |
| `secondary-900` | `#604505` | Dark amber for very small high-emphasis text |
| `secondary-950` | `#3D2C03` | Reserved — almost never used |

#### Semantic Colors

| Name | Hex | Role |
|------|-----|------|
| Success — Verdant Green | `#10B981` | Completed tasks, passing tests, healthy status, "done" badges |
| Success Light | `#D1FAE5` | Success banner background |
| Error — Signal Red | `#EF4444` | Failed runs, validation errors, destructive actions |
| Error Light | `#FEE2E2` | Error banner background |
| Warning — Warm Amber | `#F59E0B` | Pending states, attention needed, cost warnings |
| Warning Light | `#FEF3C7` | Warning banner background (= secondary-100) |
| Info — Calm Blue | `#3B82F6` | Informational badges, links, help text |
| Info Light | `#DBEAFE` | Info banner background |

#### Neutral — Cool Slate (primary-tinted greys)
Per Refactoring UI: "Greys don't have to be grey." These carry a subtle blue undertone from the primary hue for visual cohesion.

| Token | Hex | Role |
|-------|-----|------|
| `slate-50` | `#F8FAFC` | Page background (light mode) |
| `slate-100` | `#F1F5F9` | Card backgrounds, inset panels, secondary surfaces |
| `slate-200` | `#E2E8F0` | Borders, dividers, input stroke |
| `slate-300` | `#CBD5E1` | Disabled text, placeholder icons |
| `slate-400` | `#94A3B8` | Placeholder text, caption text |
| `slate-500` | `#64748B` | Secondary body text, form labels |
| `slate-600` | `#475569` | Primary body text (alternative to primary-500) |
| `slate-700` | `#334155` | Subheadings, card titles |
| `slate-800` | `#1E293B` | Main headings, high-emphasis text |
| `slate-900` | `#0F172A` | Page titles, hero text |
| `slate-950` | `#020617` | Maximum contrast text (sparingly) |

#### Agent Role Colors
Each SDLC agent role gets a distinct identifying color for avatars, badges, and timeline markers.

| Agent | Color | Hex | Why |
|-------|-------|-----|-----|
| Business Analyst | Indigo | `#6366F1` | Strategic, analytical |
| Lead Developer | Primary Navy | `#334E68` | Authority, architecture |
| Developer | Teal | `#14B8A6` | Building, crafting |
| Code Reviewer | Violet | `#8B5CF6` | Scrutiny, quality |
| QA Engineer | Emerald | `#10B981` | Verification, green-light |

#### Task Status Colors

| Status | Color | Hex |
|--------|-------|-----|
| Draft | `slate-300` | `#CBD5E1` |
| Analysis | Indigo | `#6366F1` |
| Planning | Blue | `#3B82F6` |
| Design | Violet | `#8B5CF6` |
| In Progress | Amber | `#FBBF24` |
| Review | Orange | `#F97316` |
| Testing | Teal | `#14B8A6` |
| Done | Green | `#10B981` |
| Failed | Red | `#EF4444` |

---

## 3. Typography Rules

**Font Family**: `Albert Sans` — a geometric humanist sans-serif that mirrors Apple's SF Pro DNA: slightly rounded terminals, optical weight distribution, and clean geometric construction with enough warmth to avoid sterility. Variable font with full weight axis (100-900). The most SF Pro-like typeface available on Google Fonts.

**Fallback stack**: `'Albert Sans', ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`

**Flutter equivalent**: Google Fonts package — `GoogleFonts.albertSans()`.

### Type Scale (Constrained — Refactoring UI)

Only these sizes exist. No in-between values.

| Name | Size | Weight | Line Height | Letter Spacing | Use Case |
|------|------|--------|-------------|---------------|----------|
| `display` | 32px | 800 (ExtraBold) | 1.2 | -0.02em | Hero stats (dashboard balance, big numbers) |
| `h1` | 24px | 700 (Bold) | 1.3 | -0.01em | Page titles ("Tasks", "Agent Run #42") |
| `h2` | 20px | 600 (SemiBold) | 1.35 | -0.01em | Section headings, card titles |
| `h3` | 16px | 600 (SemiBold) | 1.4 | 0 | Subsection headings, sidebar group labels |
| `body` | 14px | 400 (Regular) | 1.6 | 0 | Primary body text, form inputs, table cells |
| `body-medium` | 14px | 500 (Medium) | 1.6 | 0 | Labels, nav items, button text |
| `small` | 12px | 400 (Regular) | 1.5 | 0.01em | Captions, timestamps, metadata, badges |
| `tiny` | 11px | 500 (Medium) | 1.4 | 0.02em | Status dots labels, keyboard shortcuts |
| `mono` | 13px | 400 (Regular) | 1.6 | 0 | Code, terminal output, UUIDs, token values |

**Monospace Font**: `JetBrains Mono` — for terminal streaming view, code snippets, and technical identifiers. Ligatures enabled for operator rendering in agent output.

### Weight Rules
- **Never use font-weight alone for hierarchy** — combine with color shifts (Refactoring UI: "Size isn't everything")
- **Bold (700)** for page titles and high-emphasis headings only
- **SemiBold (600)** for section headings and card titles
- **Medium (500)** for interactive labels (buttons, nav, form labels)
- **Regular (400)** for body text and long-form content
- **No light/thin weights** — they reduce readability on mobile screens

---

## 4. Component Stylings

### Buttons

| Variant | Background | Text | Border | Radius | Shadow | Use |
|---------|-----------|------|--------|--------|--------|-----|
| Primary | `secondary-400` (#FBBF24) | `primary-900` (#1A2332) | none | 8px (moderately rounded) | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | Main CTA: "Run Agent", "Create Task", "Save" |
| Secondary | `white` | `primary-600` (#2B3F56) | 1px `slate-200` | 8px | `0 1px 2px rgba(0,0,0,0.05)` | Secondary actions: "Cancel", "Discard", "Filter" |
| Ghost | `transparent` | `primary-500` (#334E68) | none | 8px | none | Tertiary: "Show more", inline actions |
| Danger | `red-500` (#EF4444) | `white` | none | 8px | sm | Destructive: "Delete", "Cancel Run" |
| Icon | `slate-100` (#F1F5F9) | `primary-400` (#486581) | none | 8px | none | Toolbar actions, compact controls |

**Hover behavior**: Darken background by one shade step (e.g., `secondary-400` → `secondary-500`). Transition: 150ms ease-out. No scale transforms — Apple-like restraint.

**Active/pressed**: Darken by two shade steps. Add `inset 0 1px 2px rgba(0,0,0,0.1)`.

**Disabled**: `opacity: 0.5`, `cursor: not-allowed`. No grey replacement — maintain color identity at reduced intensity.

**Button sizing** (constrained scale):
| Size | Padding | Font | Height |
|------|---------|------|--------|
| `sm` | 8px 12px | 12px medium | 32px |
| `md` | 10px 16px | 14px medium | 40px |
| `lg` | 12px 24px | 16px medium | 48px |

### Cards & Containers

| Variant | Background | Border | Radius | Shadow | Use |
|---------|-----------|--------|--------|--------|-----|
| Surface | `white` | 1px `slate-200` | 12px | `0 1px 3px rgba(0,0,0,0.08)` | Task cards, project cards, knowledge docs |
| Inset | `slate-50` | none | 8px | `inset 0 1px 2px rgba(0,0,0,0.06)` | Code blocks, nested info panels, detail sections |
| Elevated | `white` | none | 16px | `0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -2px rgba(0,0,0,0.1)` | Modals, popovers, dropdown menus |
| Terminal | `primary-900` (#1A2332) | none | 12px | none | Agent streaming output, NDJSON terminal |

**Card hover** (interactive cards only): Translate Y -1px, shadow lifts one level. Transition 200ms ease.

### Inputs & Forms

| Element | Background | Border | Radius | Focus State |
|---------|-----------|--------|--------|-------------|
| Text input | `white` | 1px `slate-300` | 8px | 2px ring `secondary-400/30`, border → `secondary-400` |
| Textarea | `white` | 1px `slate-300` | 8px | Same as text input |
| Select | `white` | 1px `slate-300` | 8px | Same as text input |
| Search | `slate-50` | none | 20px (pill) | Border appears as 1px `secondary-400` |
| Toggle | `slate-200` (off) / `secondary-400` (on) | none | full (pill) | Ring on focus |

**Validation states**:
- Error: border → `red-500`, ring → `red-500/20`, helper text in `red-600`
- Success: border → `green-500` (only on explicit validation, not default)

### Badges & Status Indicators

| Variant | Style | Use |
|---------|-------|-----|
| Status badge | Pill shape, `{color}-50` bg + `{color}-700` text | Task status, run status |
| Count badge | Circle, `secondary-400` bg + `primary-900` text | Unread counts, notification dots |
| Agent badge | Pill, `{agent-color}/10` bg + `{agent-color}` text | Agent role identification |
| Priority badge | `P0` = red bg, `P1` = amber bg, `P2` = blue bg, `P3` = slate bg | Task priority |

### Navigation

**Sidebar** (desktop):
- Width: 240px (collapsible to 64px icon-only)
- Background: `white` with right border `slate-200`
- Active item: `secondary-400/10` background + `secondary-600` text + 3px left border `secondary-400`
- Inactive item: `slate-500` text → hover: `primary-600` text + `slate-50` bg
- Section dividers: 1px `slate-100` + uppercase `tiny` label in `slate-400`

**Bottom navigation** (mobile):
- Background: `white` with top border `slate-200`
- Active: `secondary-500` icon + label
- Inactive: `slate-400` icon, no label (icon only for space efficiency)
- Height: 56px + safe area
- Items: Dashboard, Tasks, Runs, Knowledge, Settings

**Tab bar** (within pages):
- Underline style: 2px bottom border `secondary-400` on active tab
- Active text: `primary-700` semibold
- Inactive text: `slate-400` regular → hover: `slate-600`

### Task Board (Kanban)

**Column headers**: Uppercase `small` text in respective status color, with colored dot indicator (8px circle).

**Task card** (in board):
- Width: fills column (min 280px)
- Padding: 12px
- Content stack: Title (h3 weight) → Assignee avatar (24px circle) + Priority badge → bottom row: task ID (`mono tiny slate-400`) + comment count icon
- Drag handle: subtle 6-dot grip pattern in `slate-300`, visible on hover only
- Drop zone: dashed 2px `secondary-400` border with `secondary-50` fill

### Agent Streaming Terminal

- Background: `primary-900` (#1A2332)
- Text: `slate-100` (#F1F5F9) at `mono` 13px
- System messages: `slate-400` italic
- Assistant output: `slate-100` regular
- Error text: `red-400` (#F87171)
- Question highlight: `secondary-400` (#FBBF24) with left border accent
- File change indicator: `teal-400` (#2DD4BF)
- Scrollbar: thin, `slate-700` thumb on `primary-900` track
- Line height: 1.6 for readability in long streaming sessions
- Max height: 60vh on desktop, 70vh on mobile — sticky at bottom with auto-scroll

### AI Chat / Q&A Panel

**Question from agent** (incoming):
- Left-aligned bubble, `slate-100` bg, `slate-700` text
- Agent avatar (28px) with role color ring
- Max width: 80% of container

**Answer from user** (outgoing):
- Right-aligned bubble, `secondary-400/15` bg, `primary-600` text
- No avatar needed (it's you)
- Max width: 80% of container

**Input area**:
- Sticky bottom, `white` bg with top shadow
- Multi-line textarea with "Send" button (`secondary-400` primary style)
- Placeholder: "Answer the agent's question..." in `slate-400`

---

## 5. Spacing & Layout System

### Spacing Scale (Constrained — Refactoring UI)

Based on a 4px base unit. Only these values exist.

| Token | Value | Common Use |
|-------|-------|-----------|
| `space-0` | 0 | Reset |
| `space-1` | 4px | Tight inline gaps (icon + label) |
| `space-2` | 8px | Badge padding, compact list items |
| `space-3` | 12px | Card inner padding (compact), form field gap |
| `space-4` | 16px | Standard card padding, section gap |
| `space-5` | 20px | Between form groups |
| `space-6` | 24px | Between cards, standard section spacing |
| `space-8` | 32px | Between major sections |
| `space-10` | 40px | Page top padding |
| `space-12` | 48px | Between page sections |
| `space-16` | 64px | Hero spacing, major visual breaks |

### Layout Breakpoints

| Name | Width | Layout Behavior |
|------|-------|----------------|
| `mobile` | < 640px | Single column, bottom nav, full-width cards, sidebar hidden |
| `tablet` | 640-1023px | Two-column task board, sidebar as overlay drawer |
| `desktop` | 1024-1279px | Sidebar visible, 3-column task board, split view |
| `wide` | >= 1280px | 4+ column board, expanded detail panels, generous padding |

### Layout Patterns

**App Shell** (desktop):
```
+----------+----------------------------------------+
| Sidebar  |  Header (breadcrumb + search + avatar) |
| 240px    |----------------------------------------|
|          |  Page Content (max-width: 1200px)      |
|          |  centered with auto margins             |
+----------+----------------------------------------+
```

**App Shell** (mobile):
```
+----------------------------------------+
|  Header (hamburger + title + avatar)   |
|----------------------------------------|
|  Page Content (full width, 16px pad)   |
|                                        |
|                                        |
|----------------------------------------|
|  Bottom Nav (5 items)                  |
+----------------------------------------+
```

**Split View** (agent run, desktop):
```
+----------+---------------------+------------------+
| Sidebar  | Task Detail         | Terminal Stream  |
| 240px    | (scrollable)        | (auto-scroll)    |
|          | 400px               | flex-1           |
+----------+---------------------+------------------+
```

**Split View** (agent run, mobile):
- Swipeable tabs: Detail | Terminal | Q&A
- Active tab fills viewport height minus header and bottom nav

### Content Width Constraints

| Context | Max Width | Why |
|---------|-----------|-----|
| Prose content | 640px | Readable line length (Refactoring UI: ~65 chars) |
| Form layouts | 480px | Focused input experience |
| Card grids | 1200px | Enough for 3-4 columns with gutters |
| Task board | 100% viewport | Horizontal scroll is expected for boards |
| Tables | 100% container | With horizontal scroll on overflow |

---

## 6. Depth & Elevation

Following Refactoring UI's "emulate a light source" principle — light comes from above. Shadows are always soft and directional (down + slightly spread).

### Shadow Scale

| Level | CSS | Use |
|-------|-----|-----|
| `shadow-none` | none | Flat elements, inset panels |
| `shadow-xs` | `0 1px 2px rgba(0,0,0,0.05)` | Subtle lift: buttons at rest, input borders |
| `shadow-sm` | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | Cards at rest, raised buttons |
| `shadow-md` | `0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -2px rgba(0,0,0,0.1)` | Cards on hover, dropdown menus |
| `shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -4px rgba(0,0,0,0.1)` | Modals, slide-over panels |
| `shadow-xl` | `0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1)` | Command palette, full-screen overlays |

### Elevation Hierarchy

1. **Base layer** (`shadow-none`): Page background, sidebar, bottom nav
2. **Content layer** (`shadow-sm`): Cards, form containers, list items
3. **Interactive layer** (`shadow-md`): Hovered cards, dropdown menus, tooltips
4. **Overlay layer** (`shadow-lg`): Modals, slide-over detail panels, notification toasts
5. **Command layer** (`shadow-xl`): Command palette (Cmd+K), full-screen dialogs

**No borders between elevation levels** — use shadow alone to communicate depth (Refactoring UI: "Use fewer borders"). Borders are reserved for same-level separation (table cells, form inputs, list dividers).

---

## 7. Motion & Transitions

Restrained, purposeful motion. No gratuitous animations — every transition serves comprehension.

| Trigger | Duration | Easing | Property |
|---------|----------|--------|----------|
| Button hover/press | 150ms | ease-out | background-color, box-shadow |
| Card hover lift | 200ms | ease-out | transform, box-shadow |
| Sidebar collapse | 200ms | ease-in-out | width |
| Modal enter | 200ms | ease-out | opacity, transform (scale 0.95→1) |
| Modal exit | 150ms | ease-in | opacity, transform (scale 1→0.95) |
| Page transition | 200ms | ease-in-out | opacity |
| Toast enter | 300ms | spring (overdamp) | transform (slide-up), opacity |
| Toast exit | 200ms | ease-in | opacity, transform (slide-down) |
| Streaming text | 0ms | — | Immediate append, no typewriter effect |
| Skeleton pulse | 1500ms | ease-in-out | opacity (0.5→1→0.5 loop) |
| Task drag | 0ms pickup, 200ms drop | ease-out | transform, box-shadow |

**Loading states**: Skeleton screens over spinners. Pulsing rectangles in `slate-200` → `slate-100` that mirror the shape of the content being loaded. Spinners only for indeterminate async actions (agent starting, container provisioning).

---

## 8. Iconography

**Icon set**: Heroicons (outline variant for navigation, solid variant for active states and small inline indicators).

**Why Heroicons**: Tailwind ecosystem native, Apple-inspired simplicity, consistent stroke width, MIT licensed.

| Context | Style | Size |
|---------|-------|------|
| Navigation (sidebar, bottom nav) | Outline (inactive), Solid (active) | 24px |
| Inline with text (labels, metadata) | Outline, 1.5px stroke | 16px |
| Buttons | Outline, 1.5px stroke | 20px |
| Empty states | Outline, 1px stroke | 48px |
| Status indicators | Solid filled circle | 8px |

**Custom icons** (not in Heroicons): Agent role avatars use a simple monogram system — first letter of role name in a colored circle (per agent role color).

---

## 9. Dark Mode (Post-MVP)

The color system is designed for dark mode compatibility. Invert the neutral scale, keep semantic colors at adjusted lightness:

| Light | Dark |
|-------|------|
| `slate-50` (page bg) | `primary-900` (#1A2332) |
| `white` (card bg) | `primary-800` (#1E2A38) |
| `slate-200` (border) | `primary-700` (#243346) |
| `slate-800` (heading text) | `slate-100` (#F1F5F9) |
| `slate-500` (body text) | `slate-400` (#94A3B8) |
| `secondary-400` (CTA) | `secondary-400` (unchanged — amber works on dark) |

The terminal/streaming view is *always* dark (`primary-900` bg) regardless of system theme — it provides natural visual separation and is easier on the eyes during long agent runs.

---

## 10. Responsive Patterns (Mobile-First)

### Information Density Ladder

| Screen | Mobile | Tablet | Desktop |
|--------|--------|--------|---------|
| Task Board | Vertical list (no columns) | 2 columns | 3-4 columns (horizontal scroll) |
| Task Detail | Full-screen sheet | Half-screen panel | Side panel (40% width) |
| Agent Run | Tab switcher (Detail/Terminal/Q&A) | Detail left + Terminal right | Three-pane split |
| Dashboard | Stacked stat cards | 2x2 grid | 4-column grid |
| Settings | Full-width sections | Two-column form | Sidebar nav + content |

### Touch Targets
- Minimum tap target: 44x44px (Apple HIG)
- Minimum spacing between targets: 8px
- Swipe gestures: Task cards (swipe right = quick-assign), Agent run tabs (horizontal swipe)

### Safe Areas
- Bottom navigation respects `safe-area-inset-bottom`
- Sticky headers respect `safe-area-inset-top`
- No content under notch/dynamic island

---

## 11. Token Reference (Flutter)

For the Flutter implementation using magic_starter framework:

```dart
// Colors — define in app theme
static const primaryNavy = Color(0xFF334E68);      // primary-500
static const primaryDark = Color(0xFF1A2332);       // primary-900
static const accentAmber = Color(0xFFFBBF24);       // secondary-400
static const accentAmberDark = Color(0xFFD9A520);   // secondary-500
static const surfaceBg = Color(0xFFF8FAFC);         // slate-50
static const cardBg = Color(0xFFFFFFFF);            // white
static const borderColor = Color(0xFFE2E8F0);       // slate-200
static const textPrimary = Color(0xFF334E68);       // primary-500
static const textSecondary = Color(0xFF64748B);     // slate-500
static const textTertiary = Color(0xFF94A3B8);      // slate-400

// Agent Role Colors
static const agentBA = Color(0xFF6366F1);           // indigo
static const agentLead = Color(0xFF334E68);         // navy
static const agentDev = Color(0xFF14B8A6);          // teal
static const agentReviewer = Color(0xFF8B5CF6);     // violet
static const agentQA = Color(0xFF10B981);           // emerald

// Spacing scale (use as multiples of base unit)
static const double spaceUnit = 4.0;
// space-1: 4, space-2: 8, space-3: 12, space-4: 16, etc.

// Border radius
static const double radiusSm = 6.0;
static const double radiusMd = 8.0;
static const double radiusLg = 12.0;
static const double radiusXl = 16.0;
static const double radiusFull = 9999.0;  // pills, avatars
```

---

## 12. Refactoring UI Checklist

Apply these checks to every screen before shipping:

- [ ] **Hierarchy**: Can you tell what's most important in < 2 seconds?
- [ ] **Weight over size**: Are you using font weight + color to create hierarchy, not just font size?
- [ ] **De-emphasis**: Is supporting content visually quieter (lighter color, smaller, or less bold)?
- [ ] **Labels**: Have you eliminated any labels that are obvious from context?
- [ ] **Whitespace**: Does the layout feel spacious? Start with too much and remove.
- [ ] **Borders**: Are you using shadows/spacing/background instead of borders where possible?
- [ ] **Color purpose**: Does every use of color convey meaning, not just decoration?
- [ ] **Constrained values**: Are all sizes, spacings, and colors from the defined scales?
- [ ] **Empty states**: Does every list/table/panel have a meaningful empty state?
- [ ] **Touch targets**: Are all interactive elements >= 44x44px on mobile?
- [ ] **Contrast**: Does text meet WCAG AA (4.5:1 for body, 3:1 for large text)?
