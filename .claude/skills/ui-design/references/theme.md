# Theme — token system, palette, typography

## Token identity rule

Every visual surface gets its own named token. Never borrow a token from
another surface just because they happen to resolve to the same color.

**Wrong:** `sidebarBackground` for the hat bar (the hat isn't a sidebar).
**Right:** Create `chromeBackground` that resolves to the same palette key.

When two surfaces share a color:

1. **Same conceptual surface** (sidebar + context panel are both "side
   panels") → one shared token set is fine.
2. **Different surfaces that happen to match** (hat bar + sidebar +
   status bar are all "chrome frame") → create a shared primitive in the
   palette/semantic layer (e.g. `bgChrome`) and give each surface its
   own token that maps to that primitive. This lets themes diverge them
   later without breaking widgets.

## Palette depth primitives

The palette layer has these depth primitives (defined in each theme YAML):

- `bg` (`#20202C`) — outermost root, behind everything
- `bgSunken` (`#1A1A24`) — chrome frame: sidebar, hat, statusbar
- `surface` (`#242838`) — elevated: pane headers, active tabs
- `surfaceHi` (`#2C3046`) — interactive: hover states, selections

Chrome tokens (`chromeBackground` / `chromeForeground` / `chromeBorder`)
are the shared root for all frame surfaces. They resolve to `bgSunken` /
`textDim` / `border` in the palette. Themes can override them to diverge
hat from sidebar from status bar if desired.

## Typography

Three constants — never hardcode sizes or families:

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

## Extension-owned domain colors

Extensions that need domain-specific color coding (ticket types, decision
types, priority levels) should NOT add tokens to `SurfaceTokens`. Instead:

1. Create a color map class in the extension (e.g. `TicketTypeColors`).
2. Ship dark and light presets, auto-selected via
   `ClideTheme.of(context).dark`.
3. Store user overrides under `ext.<id>.colors` in settings.
4. Reference: `lib/builtin/tickets/src/ticket_colors.dart`.

This keeps the core token surface lean and lets each extension own its
palette. The pattern scales to any extension needing domain colors.

## Where to look in the codebase

- Full token list: `lib/kernel/src/theme/tokens.dart`
- Resolver fallbacks: `lib/kernel/src/theme/resolver.dart`
- Theme YAML example: `lib/kernel/src/theme/themes/clide.yaml`
- Decision: D-43 (handoff), D-44 (four bundled themes), D-45 (syntax tokens)
