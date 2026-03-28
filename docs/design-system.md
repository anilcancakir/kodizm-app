# Design System Reference

Quick reference for the Kodizm design system tokens. The authoritative source is [`DESIGN.md`](DESIGN.md).

## Color Palette

### Brand Colors

| Role | Token | Hex | Tailwind Class |
|------|-------|-----|---------------|
| Primary (workhorse) | `primary-500` | `#334E68` | `text-primary-500`, `bg-primary-500` |
| Primary (headings) | `primary-600` | `#2B3F56` | `text-primary-600` |
| Primary (terminal bg) | `primary-900` | `#1A2332` | `bg-primary-900` |
| Accent (CTA) | `secondary-400` | `#FBBF24` | `bg-secondary-400` |

### Agent Role Colors

| Role | Color | Hex | className Pattern |
|------|-------|-----|------------------|
| BA | Indigo | `#6366F1` | `bg-indigo-500/10 text-indigo-500` |
| Lead | Navy | `#334E68` | `bg-primary-500/10 text-primary-500` |
| Dev | Teal | `#14B8A6` | `bg-teal-500/10 text-teal-500` |
| Reviewer | Violet | `#8B5CF6` | `bg-violet-500/10 text-violet-500` |
| QA | Emerald | `#10B981` | `bg-emerald-500/10 text-emerald-500` |

### Task Status Colors

| Status | Color Family |
|--------|-------------|
| draft | slate |
| analysis | indigo |
| planning | blue |
| design | violet |
| in_progress | amber |
| review | orange |
| testing | teal |
| done | emerald |
| failed | red |

### Session Phase Colors

| Phase | className |
|-------|----------|
| provisioning | `bg-blue-500/15 text-blue-500` |
| executing | `bg-amber-500/15 text-amber-500` |
| warm | `bg-emerald-500/15 text-emerald-500` |
| dead | `bg-slate-500/15 text-slate-500` |

## Typography

| Role | Font | Usage |
|------|------|-------|
| Body | Albert Sans | All UI text |
| Code | JetBrains Mono | Terminal, code blocks, model names, costs |

Constrained type scale -- only defined sizes from DESIGN.md.

## Spacing

4px base unit scale. Only use defined tokens: `space-1` (4px) through `space-16` (64px).

## Shadows

5-level elevation: `shadow-none`, `shadow-sm`, `shadow`, `shadow-md`, `shadow-lg`, `shadow-xl`.

## Border Radius

Defined values only: 6px, 8px, 12px, 16px, 9999px (pill).

## Component Patterns

| Component | Token Reference |
|-----------|---------------|
| Primary button | Amber bg, navy text -- `bg-secondary-400 text-primary-700` |
| Secondary button | White, border -- `bg-white border border-slate-200` |
| Surface card | White, border, shadow-sm -- `bg-white border border-slate-200 shadow-sm rounded-2xl` |
| Terminal card | Dark bg -- `bg-primary-900 text-white` |
| Badge pill | `px-2.5 py-1 rounded-full` + status color className |

## Implementation Notes

- Dynamic colors (agent roles, task status) use predefined className variant maps, not `Color()` objects
- `SelectableText` is the allowed exception requiring `TextStyle` -- can't use className for font-family
- All styling via Tailwind `className` strings on Wind UI widgets

For the complete token reference with all shades, semantic colors, and detailed component specs, see [`DESIGN.md`](DESIGN.md).

## Related Docs

- [Widgets](widgets.md) -- component inventory
- See `CLAUDE.md` for widget rules and coding conventions
