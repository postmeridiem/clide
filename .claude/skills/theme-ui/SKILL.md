---
name: theme-ui
description: >-
  Token selection guide for clide UI development. Use when building or
  modifying widgets, panels, pane chrome, status indicators, or any
  visual surface. Ensures correct background, border, text, and hover
  tokens are applied per surface type. Triggers on: new widget code,
  theme-related changes, "which token", "what color", color/background
  questions, visual inconsistency fixes, new panel/pane/view development.
---

# Theme-UI — token selection for clide surfaces

All colors come from `SurfaceTokens` via `ClideTheme.of(context).surface`.
Never hardcode colors. Never use Material/Cupertino color constants.

## Token selection by surface

Pick tokens based on **where** the widget lives, not what it does.

### Chrome (hat bar, status bar, spines)

```
background   → sidebarBackground
border       → dividerColor (1px)
text         → globalTextMuted
active text  → globalForeground
```

### Side panels (sidebar, context panel)

```
background   → sidebarBackground (left) / panelBackground (right)
text         → sidebarForeground
hover        → sidebarItemHover
selected     → sidebarItemSelected
section head → sidebarSectionHeader (muted, used for "START", "FILES", etc.)
```

Padding: 2px on outer edges, 0px on divider edge.

### Center column (workspace, Claude pane, editor)

```
background   → panelBackground
text         → globalForeground
```

No padding — content fills edge to edge.

### Pane headers (`ClidePaneChrome`)

```
background   → panelHeader
text (title) → panelHeaderForeground
text (sub)   → globalTextMuted
```

### List items (decisions, tickets, file rows, backlinks)

```
background   → (none / transparent)
hover bg     → listItemHoverBackground
selected bg  → listItemSelectedBackground
text         → listItemForeground / sidebarForeground (in sidebar)
selected txt → listItemSelectedForeground
```

In sidebar context, use `sidebarItemHover` not `listItemHoverBackground`.

### Buttons

```
normal       → buttonBackground / buttonForeground / buttonBorder
hover        → buttonHoverBackground
active       → buttonActiveBackground
primary      → buttonActiveBackground bg + globalBackground text
subtle       → listItemBackground / listItemHoverBackground (no border)
```

### Dividers and separators

```
line         → dividerColor (always, everywhere)
drag handle  → 8px hit area, 1px visible line, panel bg fill
hover line   → panelActiveBorder
```

### Status indicators

```
success/ok   → statusSuccess (green: done, added, connected)
warning      → statusWarning (amber: question, modified, missing)
error        → statusError (red: deleted, rejected, cancelled)
info         → statusInfo (blue: in_progress, modified)
```

Map semantic states, not visual styles:
- `done` / `added` / `ok` → `statusSuccess`
- `in_progress` / `modified` → `statusInfo`
- `question` / `warning` → `statusWarning`
- `cancelled` / `deleted` / `error` → `statusError`

### Overlays (dialogs, palette, tooltips)

```
dialog bg    → modalSurfaceBackground
dialog border→ modalSurfaceBorder
backdrop     → modalOverlayBackground
tooltip      → tooltipBackground / tooltipForeground / tooltipBorder
dropdown     → dropdownBackground / dropdownForeground / dropdownBorder
```

## Typography

Three constants — never hardcode sizes or families.

```
family UI    → inherited from DefaultTextStyle (JosefinSans Light 300)
family mono  → clideMonoFamily (JetBrainsMono)
body size    → clideFontBody (15)
caption size → clideFontCaption (14) — status bar, section headers, git info
mono size    → clideFontMono (14) — terminal, code, paths, IDs
```

Use `ClideText` for themed text. Set `muted: true` for secondary text
(resolves to `globalTextMuted`). Set `fontFamily: clideMonoFamily` for
code/paths/IDs. Don't set fontFamily for UI text — it inherits.

## Token identity rule

Every visual surface gets its own named token. Never borrow a token from
another surface just because they happen to resolve to the same color.

**Wrong:** `sidebarBackground` for the hat bar (the hat isn't a sidebar).
**Right:** Create `chromeBackground` that resolves to the same palette key.

When two surfaces share a color:
1. **If they're the same conceptual surface** (sidebar + context panel are
   both "side panels") → one shared token set is fine.
2. **If they're different surfaces that happen to match** (hat bar + sidebar
   + status bar are all "chrome frame") → create a shared primitive in the
   palette/semantic layer (e.g. `bgChrome`) and give each surface its own
   token that maps to that primitive. This lets themes diverge them later.

The palette layer has these depth primitives:
- `bg` (`#20202C`) — outermost root, behind everything
- `bgSunken` (`#1A1A24`) — chrome frame: sidebar, hat, statusbar
- `surface` (`#242838`) — elevated: pane headers, active tabs
- `surfaceHi` (`#2C3046`) — interactive: hover states, selections

**Pending:** `chromeBackground`/`chromeForeground`/`chromeBorder` tokens
need to be added to `SurfaceTokens` so hat bar, sidebar, and status bar
share a named root instead of cross-referencing each other's tokens.

## Anti-patterns

- Borrowing another surface's token (`sidebarBackground` for hat bar)
- `globalBackground` for panel fill → use `panelBackground`
- `listItemHoverBackground` in sidebar → use `sidebarItemHover`
- Hardcoded `Color(0xFF...)` → use a token
- `fontSize: 14` → use `clideFontCaption` or `clideFontMono`
- `fontFamily: 'JetBrainsMono'` → use `clideMonoFamily`

## Reference

Full token list: `lib/kernel/src/theme/tokens.dart`
Resolver fallbacks: `lib/kernel/src/theme/resolver.dart`
Theme YAML example: `lib/kernel/src/theme/themes/clide.yaml`
