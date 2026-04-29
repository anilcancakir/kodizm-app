# Design System: Kodizm

> Mobile-first iOS app design system for the Kodizm AI development platform.
> Apple HIG compliant, Refactoring UI discipline, Navy + Amber brand identity.
> Platform: Flutter (iOS primary, web secondary). Wind UI component system.

---

## Configuration Dials

| Dial | Value | Rationale |
|------|-------|-----------|
| **Creativity** | `3` | Professional tool aesthetic. Clean, restrained, purposeful. No decorative flourishes. |
| **Density** | `5` | Balanced: spacious primary screens, denser data views (task lists, chat). iOS native spacing. |
| **Variance** | `3` | Predictable, consistent layouts. Users learn patterns once. iOS platform conventions. |
| **Motion** | `4` | iOS-standard transitions (push, sheet, fade). Subtle haptic feedback. No gratuitous animation. |

---

## 1. Atmosphere

**Atmosphere:** A focused, capable tool that feels like it belongs on your iPhone. Clean surfaces, generous spacing, and clear hierarchy let the content (tasks, agent conversations, project status) speak. The interface fades into the background during agent execution and surfaces just enough information to keep you informed without overwhelming. Think Linear's clarity meets Apple Reminders' simplicity.

**Key Characteristics:**
- **Purposeful restraint**: every element earns its place. No decorative chrome, no dashboard vanity metrics
- **iOS-native feel**: platform navigation patterns, system gestures, haptic feedback, safe areas respected
- **Information on demand**: complexity is accessible but never forced. Pipeline details behind a progress bar, tool usage behind a collapsible accordion
- **Warm professionalism**: Navy conveys trust and engineering precision, Amber signals action and progress. Not cold, not playful.

---

## 2. Color Palette

### Brand Colors

The brand pairs deep authoritative navy with warm confident amber. Derived from oklch tokens at hue 230 (primary) and hue 55-80 (secondary).

#### Primary: Deep Steel Navy (hue 230)

| Token | Hex | Light Mode Role | Dark Mode Role |
|-------|-----|-----------------|----------------|
| `primary-50` | `#F0F4F8` | Tinted backgrounds, hover states | — |
| `primary-100` | `#D9E2EC` | Subtle borders, disabled backgrounds | Faint tint on elevated surfaces |
| `primary-200` | `#BCCCDC` | Placeholder text, tertiary icons | — |
| `primary-300` | `#829AB1` | Secondary text, metadata | Tertiary text |
| `primary-400` | `#486581` | Body text on light surfaces | Secondary text |
| `primary-500` | `#334E68` | **Primary body text**, active nav labels | — |
| `primary-600` | `#2B3F56` | Headings, card titles | — |
| `primary-700` | `#243346` | Page titles, high-emphasis headings | Elevated card background |
| `primary-800` | `#1E2A38` | — | Card/surface background |
| `primary-900` | `#1A2332` | — | **Page background (dark mode)** |
| `primary-950` | `#0F1520` | — | Deepest surfaces, terminal background |

#### Secondary: Warm Amber Gold (hue 55-80)

| Token | Hex | Role |
|-------|-----|------|
| `secondary-50` | `#FFFBEB` | Warning/info banner background (light) |
| `secondary-100` | `#FEF3C7` | Highlight tint, selected row |
| `secondary-200` | `#FDE68A` | Progress bar fill, badge background |
| `secondary-300` | `#FCD34D` | Active indicators, star ratings |
| `secondary-400` | `#FBBF24` | **Primary CTA**, accent actions |
| `secondary-500` | `#D9A520` | CTA hover/pressed state |
| `secondary-600` | `#B8860B` | CTA pressed, link hover on dark |
| `secondary-700` | `#92690A` | Badge text on amber surfaces |

#### Semantic Colors

| Name | Hex (Light) | Hex (Dark) | Usage |
|------|-------------|------------|-------|
| Success | `#34C759` | `#30D158` | Done status, passing tests, healthy |
| Error | `#FF3B30` | `#FF453A` | Failed status, validation errors, destructive |
| Warning | `#FF9500` | `#FF9F0A` | Attention needed, cost warnings |
| Info | `#007AFF` | `#0A84FF` | Links, informational badges, help text |

> Semantic colors follow iOS system color values for native consistency.

#### Neutral: Cool Slate

Primary-tinted greys (subtle blue undertone from hue 230).

| Token | Hex | Light Mode Role | Dark Mode Role |
|-------|-----|-----------------|----------------|
| `slate-50` | `#F8FAFC` | **Page background** | — |
| `slate-100` | `#F1F5F9` | Card/surface background, inset panels | — |
| `slate-200` | `#E2E8F0` | Borders, dividers, input stroke | — |
| `slate-300` | `#CBD5E1` | Disabled text, placeholder icons | Borders, dividers |
| `slate-400` | `#94A3B8` | Placeholder text, caption text | Placeholder text |
| `slate-500` | `#64748B` | Secondary body text, form labels | — |
| `slate-600` | `#475569` | Primary body text (alternative) | Secondary text |
| `slate-700` | `#334155` | Subheadings, card titles | Primary text |
| `slate-800` | `#1E293B` | Main headings | Elevated surfaces |
| `slate-900` | `#0F172A` | Page titles, hero text | Page background (alternative) |

#### Task Status Colors (Simplified)

| Status | Color | Hex (Light) | Hex (Dark) |
|--------|-------|-------------|------------|
| Todo | Slate | `#94A3B8` | `#94A3B8` |
| In Progress | Amber | `#FBBF24` | `#FBBF24` |
| Done | Green | `#34C759` | `#30D158` |
| Failed | Red | `#FF3B30` | `#FF453A` |

> Pipeline sub-states (analyzing, planning, coding, testing) shown as progress bar labels within "In Progress", not as separate statuses.

#### Agent Role Colors

| Agent | Color | Hex |
|-------|-------|-----|
| Business Analyst | Indigo | `#6366F1` |
| Lead Developer | Navy | `#334E68` |
| Developer | Teal | `#14B8A6` |
| Code Reviewer | Violet | `#8B5CF6` |
| QA Engineer | Emerald | `#10B981` |
| Product Manager | Blue | `#007AFF` |

### Dark Mode

Day 1 requirement. Follows iOS elevated surface model: each layer above base is progressively lighter.

| Light Mode | Dark Mode | Surface |
|------------|-----------|---------|
| `slate-50` (#F8FAFC) | `primary-900` (#1A2332) | Page background |
| `white` (#FFFFFF) | `primary-800` (#1E2A38) | Card/surface (base) |
| `slate-100` (#F1F5F9) | `primary-700` (#243346) | Elevated surface (sheet, modal) |
| `slate-200` (#E2E8F0) | `primary-700` (#243346) | Borders, dividers |
| `slate-800` (#1E293B) | `slate-100` (#F1F5F9) | Heading text |
| `primary-500` (#334E68) | `slate-300` (#CBD5E1) | Body text |
| `slate-500` (#64748B) | `slate-400` (#94A3B8) | Secondary text |
| `secondary-400` (#FBBF24) | `secondary-400` (#FBBF24) | Accent (unchanged) |

> Terminal/streaming view is always dark (`primary-950` bg) regardless of system theme.

---

## 3. Typography

### Font Families

- **Primary**: Albert Sans (Google Fonts). Geometric humanist sans-serif, closest to SF Pro available cross-platform. Variable font, weights 100-900.
- **Monospace**: JetBrains Mono. Terminal output, code snippets, UUIDs, technical identifiers. Ligatures enabled.
- **Fallback stack**: `'Albert Sans', ui-sans-serif, system-ui, -apple-system, sans-serif`

### iOS Type Scale

Mapped to iOS HIG text styles. All sizes in logical points (pt). Albert Sans replaces SF Pro at matching optical sizes.

| Style | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| Large Title | 34pt | Bold (700) | 41pt | -0.02em | Dashboard hero stats, page entry headers |
| Title 1 | 28pt | Bold (700) | 34pt | -0.01em | Page titles (rarely, most pages use Title 2) |
| Title 2 | 22pt | Bold (700) | 28pt | -0.01em | Primary page titles ("Tasks", "Chat") |
| Title 3 | 20pt | SemiBold (600) | 25pt | -0.01em | Section headings, modal titles |
| Headline | 17pt | SemiBold (600) | 22pt | 0 | Card titles, list item primary text |
| Body | 17pt | Regular (400) | 22pt | 0 | Primary body text, form inputs, chat messages |
| Callout | 16pt | Regular (400) | 21pt | 0 | Supporting text, form labels |
| Subheadline | 15pt | Regular (400) | 20pt | 0 | Secondary list text, metadata |
| Footnote | 13pt | Regular (400) | 18pt | 0.01em | Timestamps, helper text, badge labels |
| Caption 1 | 12pt | Regular (400) | 16pt | 0.01em | Tertiary metadata, status labels |
| Caption 2 | 11pt | Medium (500) | 13pt | 0.02em | Smallest text (keyboard shortcuts, fine print) |
| Mono | 13pt | Regular (400) | 18pt | 0 | Terminal output, code, UUIDs |

### Weight Rules

- **Bold (700)**: page titles, large title only
- **SemiBold (600)**: section headings, card titles, tab labels
- **Medium (500)**: buttons, nav items, interactive labels, smallest caption
- **Regular (400)**: body text, form inputs, all long-form content
- **No light/thin weights**: reduces readability on mobile screens (iOS HIG)
- Hierarchy through weight + color, not size alone (Refactoring UI)

---

## 4. Component Stylings

### Buttons

iOS HIG button hierarchy: Filled (highest emphasis) to Plain (lowest).

| Variant | Background | Text | Radius | Height | Usage |
|---------|-----------|------|--------|--------|-------|
| Primary (Filled) | `secondary-400` | `primary-900` | 12pt | 50pt (large), 44pt (regular) | Main CTA: "Create Task", "Send", "Run Agent" |
| Secondary (Tinted) | `secondary-400/15` | `secondary-600` | 12pt | 44pt | Secondary actions: "Filter", "Share" |
| Outline | `transparent` + 1px `slate-200` | `primary-500` | 12pt | 44pt | Tertiary: "Cancel", "Discard" |
| Ghost (Plain) | `transparent` | `info` (#007AFF) | 0 | 44pt | Inline actions, links, "Show more" |
| Danger | `error` (#FF3B30) | `white` | 12pt | 44pt | Destructive: "Delete", "Cancel Run" |
| Icon | `slate-100` | `primary-400` | 8pt | 44pt | Toolbar, compact controls |

**States:**
- Hover/press: darken one shade step, 150ms ease-out
- Pressed: `opacity: 0.7` (iOS standard press feedback)
- Disabled: `opacity: 0.35`, no interaction
- Minimum touch target: **44x44pt** (iOS HIG mandatory)

### Cards and Containers

| Variant | Background | Border | Radius | Shadow | Usage |
|---------|-----------|--------|--------|--------|-------|
| Surface | `white` / `primary-800` (dark) | 1px `slate-200` | 12pt | `shadow-sm` | Task cards, project cards, chat bubbles |
| Inset | `slate-50` / `primary-900` (dark) | none | 8pt | none | Code blocks, nested panels, detail sections |
| Elevated | `white` / `primary-700` (dark) | none | 16pt | `shadow-lg` | Modals, sheets, dropdown menus |
| Grouped | `slate-100` / `primary-800` (dark) | none | 12pt | none | iOS grouped list style (Settings, forms) |
| Terminal | `primary-950` (#0F1520) | none | 12pt | none | Agent streaming output (always dark) |

**Concentric corners** (iOS HIG): nested elements reduce radius by padding amount. Card at 12pt radius with 16pt padding = inner elements at max 0pt radius (flat).

### Inputs and Forms

iOS-style inputs, grouped in Inset Grouped table pattern.

| Element | Background | Border | Radius | Focus State |
|---------|-----------|--------|--------|-------------|
| Text field | `white` / `primary-800` | 1px `slate-300` | 8pt | 2px ring `info/30`, border to `info` |
| Textarea | `white` / `primary-800` | 1px `slate-300` | 8pt | Same as text field |
| Search | `slate-100` / `primary-700` | none | 10pt (pill) | Border appears as 1px `info` |
| Toggle | `slate-200` (off) / `success` (on) | none | full (pill) | Ring on focus |
| Segmented Control | `slate-100` / `primary-700` | none | 8pt | Selected segment: `white` raised |

**Validation:**
- Error: border to `error`, helper text in `error`
- Label position: above field (iOS standard), or inline for grouped lists
- Keyboard type: match content (`emailAddress`, `numberPad`, `url`)

### Navigation

#### Tab Bar (Bottom, 4 tabs)

| Property | Value |
|----------|-------|
| Tabs | Home, Chat, Tasks, Settings |
| Height | 49pt + safe area bottom inset |
| Background | `white` / `primary-800` (dark), top 0.5px `slate-200` separator |
| Active icon | `secondary-500` (Amber), filled variant |
| Active label | `secondary-500`, Caption 1 (12pt Medium) |
| Inactive icon | `slate-400`, outline variant |
| Inactive label | `slate-400`, Caption 1 |
| Icon size | 24pt (SF Symbols / Heroicons) |

**HIG rules:**
- Tab bar persistent across all screens (never hidden)
- Re-tap active tab to pop to root
- Badge on tab for unread content (circle, `error` color)
- Never use tab bar for actions, only navigation

#### Navigation Bar (Top)

| Property | Value |
|----------|-------|
| Height | 44pt + safe area top inset |
| Background | `white` / `primary-900` (dark), translucent with blur |
| Title | Title 2 or Headline, centered or left-aligned |
| Large Title | 34pt Bold, left-aligned, collapses on scroll |
| Back button | `info` (#007AFF) color, chevron + previous title |
| Right actions | Max 2 items, `info` color |

**Project switcher:** left side of nav bar, project name + chevron down. Tapping opens a half-sheet (.medium detent) with project list.

### Loaders

- **Primary**: skeleton screens (pulsing `slate-200` to `slate-100`, 1500ms ease-in-out loop)
- **Secondary**: `CupertinoActivityIndicator` for indeterminate actions (agent starting, container provisioning)
- **Progress**: linear progress bar (`secondary-400` fill on `slate-200` track) for pipeline steps
- Never fake progress. Show real pipeline stage labels.

### Empty States

- Centered icon (48pt, outline, `slate-300`) + title (Headline) + description (Body, `slate-500`) + optional CTA button
- Examples: "No tasks yet", "Start a conversation", "Connect a project"
- Tone: encouraging, not apologetic. Guide the user to the next action.

### Error States

- **Inline**: below input field, `error` color text with SF Symbol exclamation
- **Banner**: full-width, `error` light bg (`#FEE2E2` / dark equivalent), icon + message + dismiss
- **Toast**: bottom notification, 300ms slide-up, auto-dismiss after 4s, `shadow-lg`
- **Full page**: centered icon + title + description + retry button (connection lost, server error)

---

## 5. Screen Architecture

> Replaces "Hero Section" from template. Kodizm is an app, not a marketing site.

### App Shell (Mobile)

```
+----------------------------------------+
|  [Project v]    Title         [A] [P]  |  <- Nav bar (44pt + safe area)
|----------------------------------------|
|                                        |
|  Page Content                          |  <- Scrollable area
|  (full width, 16pt horizontal padding) |
|                                        |
|                                        |
|----------------------------------------|
|  Home    Chat    Tasks    Settings     |  <- Tab bar (49pt + safe area)
+----------------------------------------+
```

### Tab Destinations

| Tab | Icon | Content | Large Title |
|-----|------|---------|-------------|
| Home | `house.fill` | Activity feed: in-progress tasks, recent completions, agent questions, quick actions | "Home" |
| Chat | `bubble.left.and.bubble.right.fill` | Conversation list (interactive + task runs). Badge for unread questions. | "Chat" |
| Tasks | `checkmark.circle.fill` | Task list with status filter chips (Todo, In Progress, Done, Failed). Pull-to-refresh. | "Tasks" |
| Settings | `gearshape.fill` | Profile, team, billing, notifications, appearance. Grouped list (Inset Grouped style). | "Settings" |

### Project Switcher

```
+----------------------------------------+
|  -- (grabber)                          |
|  Select Project                  Done  |
|----------------------------------------|
|  [Search projects...]                  |
|                                        |
|  * Kodizm App           3 active       |
|    API Service           1 active       |
|    Marketing Site        idle           |
|                                        |
|  [+ Add Project]                       |
+----------------------------------------+
```

- Half-sheet (.medium detent), swipe down or "Done" to dismiss
- Current project marked with checkmark
- Shows active task count per project
- "All Projects" option at top for cross-project view

### Key Screens Flow

```
Home
 +- Activity card -> push to Task Detail
 +- Activity card -> push to Chat Detail
 +- Quick action "+" -> sheet: New Task

Chat
 +- Conversation list -> push to Chat Detail
 +- Chat Detail: iMessage-style bubbles
 +- "+" button -> sheet: New Conversation (select project + type message)

Tasks
 +- Task list -> push to Task Detail
 +- Task Detail: status badge, progress bar, sections accordion, "Run Agent" CTA
 +- Filter chips: Todo | In Progress | Done | Failed

Settings
 +- Profile -> push to edit
 +- Team -> push to members, roles
 +- Project Settings -> push to knowledge, skills, config, repos
 +- Billing -> push to balance, usage history
 +- Appearance -> push to dark mode toggle, notifications
```

---

## 6. Layout Principles

### Spacing System (iOS Native)

Based on iOS HIG spacing conventions.

| Token | Value | Usage |
|-------|-------|-------|
| `space-1` | 4pt | Tight inline gaps (icon + label), badge internal padding |
| `space-2` | 8pt | Group spacing, compact list item gaps, between related elements |
| `space-3` | 12pt | Card inner padding (compact), input field vertical padding |
| `space-4` | 16pt | **Standard margin** (horizontal page padding), list item padding |
| `space-5` | 20pt | **Section spacing** within grouped lists |
| `space-6` | 24pt | Between cards, between form groups |
| `space-8` | 32pt | Between major content sections |
| `space-10` | 40pt | Page top padding (below nav bar) |
| `space-12` | 48pt | Between page sections (rare, for visual breathing room) |

### Touch Targets

- Minimum tap target: **44x44pt** (iOS HIG, mandatory, no exceptions)
- Minimum spacing between targets: **8pt**
- List row minimum height: **44pt**
- Tab bar item width: distributed equally across screen width

### Content Width

| Context | Behavior |
|---------|----------|
| Mobile (< 640pt) | Full width, 16pt horizontal padding |
| Tablet (640-1024pt) | Max content width 640pt, centered |
| Desktop/Web (> 1024pt) | Sidebar (280pt) + content (max 800pt), centered |

### Safe Areas

- Bottom: tab bar respects `safeAreaInset.bottom` (home indicator)
- Top: nav bar respects `safeAreaInset.top` (Dynamic Island, notch)
- No content under notch/Dynamic Island
- Keyboard: input fields scroll above keyboard with padding

### Alignment

- Text: left-aligned (body, lists, cards). Center-aligned only for empty states and modals.
- Lists: full-width dividers for plain lists, inset dividers for grouped lists (16pt left inset)
- Cards: full-width in mobile, 16pt side margins

---

## 7. Responsive Rules

### Breakpoints

| Name | Width | Layout |
|------|-------|--------|
| Mobile (primary) | < 640pt | Single column, bottom tab bar, full-width content |
| Tablet | 640-1024pt | Two-column where appropriate (chat list + detail), tab bar |
| Desktop/Web | > 1024pt | Sidebar navigation replaces tab bar, multi-pane layouts |

### Mobile Collapse Behavior (Primary Design Target)

- All content single column
- Cards full-width with 16pt horizontal margin
- Chat: full-screen conversation (no split)
- Tasks: vertical list (no kanban board on mobile)
- Project detail: stacked sections, each expandable

### Tablet Adaptations

- Chat: split view (conversation list left, chat detail right)
- Tasks: optional 2-column kanban board
- Settings: sidebar navigation + content pane
- Project switcher: popover instead of sheet

### Desktop/Web Adaptations

- Tab bar replaced by left sidebar (280pt, collapsible to 64pt icons)
- Chat: three-pane (conversations | chat | detail panel)
- Tasks: full kanban board (3-4 columns)
- Dashboard: 2x2 or 4-column stat grid

### Typography Scaling

- iOS type scale maintained across all breakpoints
- No fluid/clamp sizing (matches iOS point-based system)
- Dynamic Type support: layouts must accommodate 12 size variants without clipping

### Testing Viewports

| Device | Width | Purpose |
|--------|-------|---------|
| iPhone SE | 375pt | Minimum supported width |
| iPhone 15 | 393pt | Standard iPhone |
| iPhone 15 Pro Max | 430pt | Large iPhone |
| iPad Mini | 744pt | Tablet minimum |
| iPad Pro 11" | 834pt | Standard tablet |
| Desktop | 1280pt | Web primary |
| Desktop wide | 1440pt | Web maximum content |

---

## 8. Motion Intent

### Animation Philosophy

iOS-standard, restrained, purposeful. Every animation serves spatial comprehension (where did that come from? where did it go?). Motion dial: 4/10.

### Transition Patterns

| Trigger | Animation | Duration | Easing |
|---------|-----------|----------|--------|
| Push navigation | Slide from right | 350ms | iOS spring (damping: 1.0) |
| Pop navigation | Slide to right | 350ms | iOS spring |
| Sheet present | Slide from bottom | 400ms | iOS spring (damping: 0.85) |
| Sheet dismiss | Slide to bottom + fade | 300ms | ease-in |
| Modal present | Scale 0.95 to 1.0 + fade | 250ms | ease-out |
| Modal dismiss | Scale 1.0 to 0.95 + fade | 200ms | ease-in |
| Tab switch | Cross-fade | 0ms | Instant (iOS standard) |
| Toast enter | Slide up from bottom | 300ms | spring (slight overshoot) |
| Toast exit | Fade + slide down | 200ms | ease-in |
| Page transition | Fade | 200ms | ease-in-out |

### Interaction Feedback

| Element | Feedback |
|---------|----------|
| Button press | `opacity: 0.7` on touch down, restore on release. 100ms. |
| Card press | Slight scale down (0.98), restore on release. 150ms. |
| Swipe actions | Elastic resistance at boundaries |
| Pull-to-refresh | iOS native rubber-band + spinner |
| Tab bar tap | Haptic: `selection` feedback |
| Destructive action | Haptic: `notification.warning` |
| Task completion | Haptic: `notification.success` |

### Loading States

- **Skeleton screens** for content loading (pulsing `slate-200` to `slate-100`, 1500ms)
- **CupertinoActivityIndicator** for indeterminate waits
- **Linear progress bar** for pipeline stages with stage label
- **Streaming text**: immediate append, no typewriter effect
- Never fake progress

---

## 9. Anti-Patterns

### Visual Anti-Patterns

- **Gratuitous gradients or glassmorphism**: we are not implementing Liquid Glass in Flutter. Clean solid surfaces only
- **Dashboard vanity metrics**: no "total runs ever" or decorative charts. Every metric must be actionable
- **Colored backgrounds on cards**: cards are `white`/`primary-800`. Status shown via badges, dots, or progress bars, not card background tinting
- **Shadows as decoration**: shadows indicate elevation (sheet above page). No shadows on flat elements

### Typography Anti-Patterns

- **More than 2 font sizes on a single card**: Headline + Body or Headline + Subheadline maximum
- **All-caps text**: except for very short labels (2-3 words) in Caption 2 size
- **Light/thin font weights**: never below Regular (400) on any screen
- **Font size for hierarchy**: use weight + color shifts, not size jumps (Refactoring UI)

### Layout Anti-Patterns

- **Horizontal scrolling content** (except: kanban board columns on tablet/desktop)
- **Cards inside cards**: maximum one level of nesting (card > inset panel). No deeper
- **Fixed position elements in scroll content**: only tab bar (bottom) and nav bar (top) are fixed
- **Max-width constraints on mobile**: content fills available width with 16pt margins, period
- **SingleChildScrollView wrapping entire pages**: layout system handles scrolling

### Interaction Anti-Patterns

- **Custom back button behavior**: always use iOS standard back (chevron + previous title)
- **Swipe gestures replacing visible controls**: swipe is a shortcut, never the only path
- **Hiding the tab bar**: tab bar is always visible (iOS HIG), even during agent execution
- **Auto-switching tabs programmatically**: user controls tab navigation, app never switches
- **Modal on top of modal**: maximum one level of modal presentation

### iOS HIG Violations to Avoid

- Touch targets below 44x44pt
- Text below 11pt (Caption 2 minimum)
- Color as only information channel (always pair with icon, text, or shape)
- Disabling system gestures (edge swipe back, swipe down dismiss)
- Fixed-coded hex colors that don't adapt to dark mode

---

## 10. Chat View Specification

> The chat view is Kodizm's core UX. Detailed specification for the iMessage-style agent conversation.

### Message Types

| Type | Alignment | Style |
|------|-----------|-------|
| Agent text | Left | Surface card bubble, `slate-700` text (light) / `slate-200` (dark) |
| User text | Right | `secondary-400/15` bg bubble, `primary-600` text (light) / `secondary-100` (dark) |
| Agent question | Left | Surface card + amber left border (4pt), question icon, answer buttons below |
| Tool use | Left | Collapsible accordion: "Used 3 tools" with chevron. Collapsed by default. |
| Thinking | Left | Collapsible, italic `slate-400` text: "Thinking..." |
| Code block | Left | Inset card (`primary-950` bg), monospace, syntax highlighted, copy button |
| File change | Left | Compact card: file icon + path + diff summary (green/red counts) |
| Error | Left | `error` left border, error icon, message in `error` color |
| Progress | Left | Linear progress bar + stage label ("Analyzing...", "Planning...", "Coding...") |

### Chat Layout

```
+----------------------------------------+
|  < Back    Fix auth bug        ● Live  |  <- Nav bar
|----------------------------------------|
|                                        |
|  [Agent avatar]                        |
|  +---------------------------+         |
|  | Analyzing the auth module |         |
|  | to find the token issue.  |         |
|  +---------------------------+         |
|                                        |
|  > Used 3 tools                  (v)   |  <- Collapsible
|                                        |
|                  +------------------+  |
|                  | Can you check    |  |
|                  | the refresh flow |  |
|                  +------------------+  |  <- User bubble (right)
|                                        |
|  [Agent avatar]                        |
|  +---------------------------+         |
|  | Found it! The bug is in   |         |
|  | auth_service.dart:42.     |         |
|  | The token...              |         |
|  +---------------------------+         |
|                                        |
|  +-[progress]------ 60% ----+         |
|  | Coding...                 |         |
|  +---------------------------+         |
|                                        |
|----------------------------------------|
|  [+]  Type a message...        [Send]  |  <- Input bar (sticky bottom)
+----------------------------------------+
```

### Agent Question Flow

When agent asks a question, the chat shows structured options:

```
|  [Agent avatar]                        |
|  +---------------------------+         |
|  | amber border                        |
|  | Should I also update the  |         |
|  | refresh token logic?      |         |
|  +---------------------------+         |
|                                        |
|  [Yes, update both]  [No, just fix]   |  <- Tappable chips
|  [Let me explain...]                   |  <- Opens text input
```

### Input Bar

- Sticky at bottom, above keyboard when active
- Background: `white` / `primary-800`, top shadow
- Attachment button (+) on left: images, files
- Text area: auto-growing, max 5 lines before scroll
- Send button: `secondary-400` filled circle with arrow icon, visible only when text is non-empty
- Disabled state when agent is executing (show "Agent is working..." placeholder)

---

## 11. Home Feed Specification

### Feed Item Types

| Type | Content | Action |
|------|---------|--------|
| Task in progress | Task title + project name + progress bar + stage label | Push to task detail |
| Task completed | Task title + project name + "Done" badge + time | Push to task detail |
| Task failed | Task title + project name + "Failed" badge + error snippet | Push to task detail |
| Agent question | Task title + question preview + "Needs your input" | Push to chat view |
| Quick actions | "New Task", "New Conversation" | Sheet / push |

### Feed Layout

```
+----------------------------------------+
|  Kodizm App  v               🔔  👤   |  <- Project switcher + actions
|                                        |
|  Home                                  |  <- Large Title
|----------------------------------------|
|                                        |
|  Needs Input (1)                       |  <- Section header (amber dot)
|  +----------------------------------+  |
|  | Fix auth token refresh           |  |
|  | "Should I also update..."    >   |  |
|  +----------------------------------+  |
|                                        |
|  In Progress (3)                       |  <- Section header (amber dot)
|  +----------------------------------+  |
|  | Add dark mode support            |  |
|  | Marketing Site                   |  |
|  | ████████░░░░ Coding...       >   |  |
|  +----------------------------------+  |
|  +----------------------------------+  |
|  | Refactor auth module             |  |
|  | API Service                      |  |
|  | ██████████░░ Testing...      >   |  |
|  +----------------------------------+  |
|                                        |
|  Recent (5)                            |  <- Section header
|  +----------------------------------+  |
|  | Fix login redirect   ✓ Done  2h  |  |
|  +----------------------------------+  |
|  +----------------------------------+  |
|  | Update README         ✓ Done  4h  |  |
|  +----------------------------------+  |
|                                        |
|                  [+ New Task]          |  <- Floating action
|----------------------------------------|
|  🏠    💬    ✅    ⚙️                  |
+----------------------------------------+
```

### Priority Ordering

1. **Needs Input** (agent questions waiting for answer, always on top, amber accent)
2. **In Progress** (actively running tasks with progress)
3. **Recent** (last 10 completed/failed tasks, chronological)

---

## 12. Depth and Elevation

### Shadow Scale

| Level | Value | Usage |
|-------|-------|-------|
| `shadow-none` | none | Flat elements, inline content, tab bar |
| `shadow-xs` | `0 1px 2px rgba(0,0,0,0.05)` | Subtle lift: input fields, segmented controls |
| `shadow-sm` | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | Cards at rest |
| `shadow-md` | `0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -2px rgba(0,0,0,0.1)` | Pressed cards, dropdowns |
| `shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px -4px rgba(0,0,0,0.1)` | Sheets, modals |
| `shadow-xl` | `0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1)` | Popovers, command palette |

### Elevation Hierarchy

1. **Base** (`shadow-none`): page background, tab bar, nav bar
2. **Content** (`shadow-sm`): cards, list items, form containers
3. **Interactive** (`shadow-md`): active cards, dropdown menus
4. **Overlay** (`shadow-lg`): sheets, modals, project switcher
5. **Command** (`shadow-xl`): command palette, full-screen overlays

Prefer shadow over borders for depth separation (Refactoring UI). Borders reserved for same-level dividers (list separators, input outlines).

---

## 13. Iconography

### Icon Set

Heroicons (outline + solid variants). Closest to SF Symbols aesthetic available cross-platform.

| Context | Variant | Size |
|---------|---------|------|
| Tab bar (inactive) | Outline, 1.5px stroke | 24pt |
| Tab bar (active) | Solid filled | 24pt |
| Nav bar actions | Outline, 1.5px stroke | 22pt |
| List items, inline | Outline, 1.5px stroke | 20pt |
| Buttons (with text) | Outline, 1.5px stroke | 20pt |
| Empty states | Outline, 1px stroke | 48pt |
| Status indicators | Solid circle | 8pt |

### Agent Avatars

Monogram system: first letter of role name in a 28pt colored circle (per agent role color table).

---

## 14. Accessibility Checklist

Per iOS HIG and WCAG AA requirements:

- [ ] All touch targets >= 44x44pt
- [ ] All text meets WCAG AA contrast (4.5:1 body, 3:1 large text)
- [ ] Color never sole information channel (always paired with text/icon/shape)
- [ ] Dynamic Type supported (layout adapts to all 12 sizes without clipping)
- [ ] VoiceOver labels on all interactive elements
- [ ] Reduce Motion respected (disable non-essential animations)
- [ ] Dark mode complete (every screen, every state)
- [ ] Keyboard navigation for web deployment
- [ ] Focus order logical (follows reading order)
- [ ] Minimum text size 11pt (Caption 2)

---

## 15. Stitch Generation Notes

### Atmosphere Language

- **Overall feel:** "Clean, capable, iOS-native professional tool. Navy and amber brand on white surfaces with generous spacing. Linear meets Apple Reminders."
- **Interaction feel:** "Direct, responsive, no unnecessary transitions. Content-focused with ambient awareness of background processes."

### Color References

- Deep Navy (#334E68) - primary brand, headings, body text
- Amber Gold (#FBBF24) - accent, CTAs, active states, progress
- System Blue (#007AFF) - links, info, ghost buttons
- System Green (#34C759) - success, done, healthy
- System Red (#FF3B30) - error, failed, destructive
- Cool Slate (#F8FAFC) - page background (light)
- Dark Navy (#1A2332) - page background (dark)

### Typography References

- **Headings:** Albert Sans, Bold/SemiBold, iOS type scale (34pt down to 17pt)
- **Body:** Albert Sans, Regular 400, 17pt/22pt line height
- **Code/Terminal:** JetBrains Mono, Regular 400, 13pt/18pt

### Component Prompts

- **Task card:** "Rounded 12pt card, white surface, subtle shadow. Task title (Headline weight), project name below (Subheadline, slate-500). Right side: status dot + chevron. If in progress: thin amber progress bar at bottom with stage label."
- **Chat bubble (agent):** "Left-aligned rounded card, slate-50 background, 12pt padding. Body text. Max width 80%. Small agent avatar (28pt circle) above-left."
- **Chat bubble (user):** "Right-aligned rounded card, amber-15% tinted background, 12pt padding. Body text. Max width 80%. No avatar."
- **Activity feed item:** "Full-width list row, 16pt padding. Title (Headline) + subtitle (Subheadline, slate-500) + right accessory (badge or chevron). Min height 44pt. Divider between items."
- **Project switcher:** "Half-sheet with grabber, search bar at top, list of projects with checkmark on current. Each row: project name (Headline) + active task count (Subheadline, slate-400)."

### Incremental Iteration

1. Focus on ONE component per prompt
2. Reference exact color tokens and type styles from this document
3. Always specify light AND dark mode appearance
4. Include safe area handling for all full-screen layouts
5. Verify 44pt minimum touch targets on all interactive elements
