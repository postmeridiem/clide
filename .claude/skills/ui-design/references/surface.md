# Surface — token selection per surface type

Pick tokens based on **where** the widget lives, not what it does.

## Chrome (hat bar, status bar, sidebar, context panel, spines, drag handles)

```
background   → chromeBackground
text         → chromeForeground
border       → chromeBorder (1px)
active text  → globalForeground
```

## Side panels (sidebar, context panel)

```
background   → chromeBackground (both sides — they're chrome frame)
text         → sidebarForeground
hover        → sidebarItemHover
selected     → sidebarItemSelected
section head → sidebarSectionHeader (muted, used for "START", "FILES", etc.)
```

Padding: 2px on outer edges, 0px on divider edge.

## Center column (workspace, Claude pane, editor)

```
background   → panelBackground
text         → globalForeground
```

No padding — content fills edge to edge.

## Pane headers (`ClidePaneChrome`)

```
background   → panelHeader
text (title) → panelHeaderForeground
text (sub)   → globalTextMuted
```

## Tabs (`MultitabPane`, `ClideTabBar`)

```
strip bg     → tabBarBackground
strip border → bottom: dividerColor (anchors strip to body)
active fg    → tabActiveForeground
inactive fg  → tabInactiveForeground
active bg    → panelHeader (elevated chrome)
inactive bg  → tabBarBackground (blends with strip)
active border→ panelActiveBorder (top accent, 1.5px)
side border  → panelBorder
```

For control geometry inside tabs (close button placement, padding,
two-column title+action layout) see [`geometry.md`](geometry.md).

## List items (decisions, tickets, file rows, backlinks)

```
background   → (none / transparent)
hover bg     → listItemHoverBackground
selected bg  → listItemSelectedBackground
text         → listItemForeground / sidebarForeground (in sidebar)
selected txt → listItemSelectedForeground
```

In sidebar context, use `sidebarItemHover` not `listItemHoverBackground`.

## Buttons

```
normal       → buttonBackground / buttonForeground / buttonBorder
hover        → buttonHoverBackground
active       → buttonActiveBackground
primary      → buttonActiveBackground bg + globalBackground text
subtle       → listItemBackground / listItemHoverBackground (no border)
```

## Dividers and separators

```
line         → dividerColor (always, everywhere)
drag handle  → 8px hit area, 1px visible line, panel bg fill
hover line   → panelActiveBorder
```

## Status indicators

```
success/ok   → statusSuccess (green: done, added, connected)
warning      → statusWarning (amber: question, modified, missing)
error        → statusError   (red:   deleted, rejected, cancelled)
info         → statusInfo    (blue:  in_progress, modified)
```

Map semantic states, not visual styles:

- `done` / `added` / `ok` → `statusSuccess`
- `in_progress` / `modified` → `statusInfo`
- `question` / `warning` → `statusWarning`
- `cancelled` / `deleted` / `error` → `statusError`

## Overlays (dialogs, palette, tooltips)

```
dialog bg    → modalSurfaceBackground
dialog border→ modalSurfaceBorder
backdrop     → modalOverlayBackground
tooltip      → tooltipBackground / tooltipForeground / tooltipBorder
dropdown     → dropdownBackground / dropdownForeground / dropdownBorder
```

## Settings & grouped lists — sectioned cards

Settings surfaces and any long grouped list (e.g. the Claude config lists)
read as **sectioned cards**, not bare rows floating on the panel. Each logical
group gets its own card; the small-caps section label (+ optional count) sits
just **above** the card.

```
panel bg      → panelBackground (#20202C)
card surface  → surface (#242838) fill + dividerColor/border (1px), ~6px corners
section head  → sidebarSectionHeader (small-caps), with the count muted to its right
control inset → inputs INSIDE a card recede to panelBackground, so they still
                read as fields against the elevated card
```

- **One card per group** — a settings table, each config list. The card's
  elevated fill + border do the visual separation; don't rely on spacing alone.
- **Field row inside a card:** label (`globalForeground`) + help
  (`globalTextMuted`) + the control right-aligned, with the per-field scope tag
  in the far-right column.
- **Scroll, don't cram:** when stacked cards exceed the modal/pane viewport, the
  pane scrolls vertically (sticky header, scrolling body) — prefer that over
  shrinking content to fit one screen.
- Pattern reference: the settings wireframes under
  `docs/design/wireframes/settings/` (T-302).

## Anti-patterns

- `globalBackground` for panel fill → use `panelBackground`
- Bare settings rows on the panel where a group of them should be one card →
  see "Settings & grouped lists".
- `listItemHoverBackground` in sidebar → use `sidebarItemHover`
- Tab active bg = `panelBackground` → use `panelHeader` (elevated chrome)
- Tab active border = `globalFocus` → use `panelActiveBorder`
