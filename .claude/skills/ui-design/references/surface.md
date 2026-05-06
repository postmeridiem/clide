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

## Anti-patterns

- `globalBackground` for panel fill → use `panelBackground`
- `listItemHoverBackground` in sidebar → use `sidebarItemHover`
- Tab active bg = `panelBackground` → use `panelHeader` (elevated chrome)
- Tab active border = `globalFocus` → use `panelActiveBorder`
