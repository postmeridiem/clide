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

Read the reference that matches the question. They cross-reference each
other where relevant; you don't need to read all four.

## Universal rules

These apply across every reference and every surface:

- All colors come from `SurfaceTokens` via `ClideTheme.of(context).surface`.
  Never hardcode `Color(0xFF...)`.
- Never use `Material*` or `Cupertino*` widgets or color constants — clide
  is `WidgetsApp` only (D-7).
- Use `ClideText` for themed text; never bare `Text` in production widgets.
- Typography: `clideFontMono` for code/paths/IDs, `clideFontCaption` for
  status/section headers, body inherits from `DefaultTextStyle`.

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
