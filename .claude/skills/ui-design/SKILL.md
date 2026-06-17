---
name: ui-design
description: >-
  Visual design guide for clide UI development — covers theme tokens,
  surface-specific token selection, control geometry/spacing/alignment,
  and Phosphor icons. Use when building or modifying widgets, panels,
  pane chrome, status indicators, tabs, list items, dialogs, or any
  visual surface. Triggers on: new widget code, theme-related changes,
  "which token", "what color", color/background questions, visual
  inconsistency fixes, "alignment off", "spacing", "padding", control
  geometry questions, new panel/pane/view development, adding or
  looking up Phosphor icons, icon codepoints.
---

# UI design — clide visual surface guide

This skill bundles four concerns that all surface in widget work:

| Concern | Reference | When to read |
|---------|-----------|--------------|
| Token system, palette, typography | [`references/theme.md`](references/theme.md) | Designing or extending the theme pipeline; deciding whether to add a new token |
| Token selection per surface | [`references/surface.md`](references/surface.md) | Building a new widget or modifying an existing one — "which token does this need" |
| Spacing, alignment, control layout | [`references/geometry.md`](references/geometry.md) | Building tab strips, list items, buttons, anything where icons sit next to text or padded edges |
| Phosphor icon usage and codepoints | [`references/icons.md`](references/icons.md) | Adding or referencing an icon |
| Full Phosphor glyph table (1512, with codepoints) | [`references/phosphor-glyphs.md`](references/phosphor-glyphs.md) | Picking a specific glyph by name/look — find its codepoint, see if it's already defined |

Read the reference that matches the question. They cross-reference each
other where relevant; you don't need to read all four.

## Universal rules

These apply across every reference and every surface:

- All colors come from `SurfaceTokens` via `ClideTheme.of(context).surface`.
  Never hardcode `Color(0xFF...)`.
- Never use `Material*` or `Cupertino*` widgets or color constants — clide
  is `WidgetsApp` only (D-7).
- Use `ClideText` for themed text; never bare `Text` in production widgets.
- Typography sizes: `clideFontMono` for code/paths/IDs, `clideFontCaption` for
  status/section headers, body inherits from `DefaultTextStyle`.
- Font *family* comes from the user-selectable facade, not a const: a
  monospace surface uses `fontFamily: ClideSettings.fonts.monoOf(context)`
  (and `fontFamilyFallback: clideMonoFamilyFallback`); the UI face is inherited
  via the root `DefaultTextStyle`, or `ClideSettings.fonts.uiOf(context)` when a
  widget must set it explicitly. `clideMonoFamily` / `clideUiFamily` are the
  facade's defaults — don't read them directly in new widgets (D-101). Same
  facade exposes `ClideSettings.theme.of(context)` and `.i18n.of(context)`.

## Conversation-panel cards (T-305)

The Claude conversation stream has **three** card categories. They are NOT one
shared wrapper widget — each is its own widget; they only share the spacing
constants in `lib/widgets/src/clide_card_metrics.dart` (`kClideCardGap`,
`kClideCardRadius`, `kClideCardHeaderPadH/V`, `kClideCardCounterSlotWidth`) so
the stream reads as one rhythm. Change spacing there, not per-card.

1. **Dialog cards** — `ConversationCard` with a speaker **side stripe** (you /
   claude / agent). Prose/attribution; not collapsible.
2. **Simple cards** — a single item shown fully open, never collapses (e.g. the
   image card). Standalone display; no chevron, no status chrome.
3. **Collapsibles** — `ClideCollapserCard` (`lib/widgets/`). Every tool use is
   one, over a list of `1..N` inner item cards (a single tool = a 1-item list;
   there is no separate single-card path). Rules:
   - Whole card toggles; chevron hard against the **left** edge, the status tick
     (spinner/check/cross) hard against the **right** edge, the count in a
     fixed-width slot just inboard of it.
   - `color` drives the border + chevron/label tint (per-instance fidelity).
   - Collapsed ticker echoes the run's **last content line** as the title +
     count + aggregate status (computed by the caller, bubbled up from items).
   - Inner item cards are content + their **own** per-item status; they pass
     `margin: EdgeInsets.zero`-ish (a bottom margin matching the canvas) so the
     collapser pads the inner canvas **evenly on all sides** — never let an
     inner card jam under the header or against a frame edge.

Do NOT pull a dialog card's stripe or a simple card's config into the collapser,
and do NOT nest collapsers — inside a run, tools render as the bare inner content
card (`_ConversationTurn(collapseTools: false)`).

## Anti-patterns (cross-cutting)

- Borrowing another surface's token (`sidebarBackground` for hat bar) — give
  each surface its own token even if they share a palette key. See `theme.md`.
- Hardcoded hex colors → use a token. See `surface.md` for which one.
- `fontSize: 14` literal → use `clideFontCaption` or `clideFontMono`.
- `fontFamily: 'JetBrainsMono'` literal → use `clideMonoFamily`.
- Stacking edge padding on a padded parent + a padded child action → see
  `geometry.md` "no double edge padding".
- Eyeballing pixel margins instead of working back from the constraint —
  the math matters; see `geometry.md` "uniform inner spacing".
