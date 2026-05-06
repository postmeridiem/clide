# Geometry — spacing, alignment, control layout

Principles for placing icons, buttons, and text inside controls.
Apply when building tab strips, list items, buttons with affordances,
or anything where actions sit next to content.

> Numeric values in this doc will move to `ClideSpacing` constants
> (`lib/widgets/src/spacing.dart`) — see T-86. Until then, the
> constants used in the codebase: `12` (text inset), `6` (icon
> breathing), `8` (standard gap), `4` (tight gap), `16` (icon hit
> area), `28` (button / row height).

## Uniform inner spacing rule

Icons inside control surfaces should have **equal margin on every
constrained side**. The "constrained sides" are top, bottom, and the
side opposite to where content flows in.

The remaining side — where the text or other content sits — gets a
larger, content-appropriate breathing room.

Example: tab close button (16×16 inside a 28-tall tab):

```
top    : 6   ┐
bottom : 6   ├─ uniform: (28 − 16) / 2 = 6
right  : 6   ┘
left   : 8   ── content gap (separates from title text)
```

The visual effect: the close button looks like a deliberate
affordance with a calm, consistent border, not a glyph stuffed into
the corner.

## No double-edge padding

When a fixed-size action (icon button, close ×) sits at the edge of
a padded parent, the parent's padding on that edge should **not stack**
with the action's own internal margin. Pick one place to hold the
breathing room.

Wrong:

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12), // tab pad: 12 right
  child: Row(children: [
    Expanded(child: title),
    SizedBox(width: 8),                          // gap: 8
    Container(width: 28, alignment: Center,      // close: 6 internal margin
              child: Icon(close, size: 16)),
  ]),
)
// Visible margin from icon right to outer right = 12 + 6 = 18px → too much
```

Right:

```dart
Container(
  padding: EdgeInsets.only(left: 12, right: 6),  // pad matches icon margin
  child: Row(children: [
    Expanded(child: title),
    SizedBox(width: 8),
    Container(width: 16, height: 16, alignment: Center,  // hit target = icon size
              child: Icon(close, size: 10)),
  ]),
)
// Visible margin = 6 (parent right pad) ≈ 6 (top/bottom auto) → uniform
```

## Two-column control pattern

For tab-shaped or row-shaped controls with a primary content area and
a secondary action:

```dart
Row(children: [
  Expanded(child: <content>),                     // takes remainder
  if (action != null) ...[
    SizedBox(width: 8),                           // standard gap
    <fixed-size action>,                          // shrinks to content
  ],
])
```

- **Left column**: `Expanded`, holds the primary content (title,
  label, description). Aligned to the start of its space by default.
- **Right column**: fixed natural width, holds the action (close,
  status, indicator). Sized to the icon, not to artificial padding.

The parent container's padding sits flush against both columns (see
"no double-edge padding").

## Match perceived mass, not measured pixels

Glyphs vary in visual weight. A bold `+` looks heavier than a thin
`×` at the same point size. When eyeballing alignment, trust the
optical center over the geometric center.

In practice: if two icons measure to the same margin but one *looks*
crowded, give the heavier glyph slightly more breathing room and
trim the lighter one. For clide, this came up with the `×` close
glyph vs the `+` add glyph — both at 14pt, but `+` reads as denser
and is left in its 28-wide button without further padding, while
`×` sits in a 16×16 hit area with 6px symmetric margin.

## Strip / row should fill the parent

Tab strips, status bars, and divider rows should span the full
parent width, not size to their content. Without this, the strip
looks like it floats inside the pane.

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,  // <-- this
  children: [
    _TabStrip(...),
    Expanded(child: _body(...)),
  ],
)
```

Without `stretch`, Column gives loose width constraints and a
`Container(height: tabHeight)` child sizes to its child's natural
width — the strip ends mid-pane.

## Anchor strips with a divider

Add a 1px bottom border (`dividerColor`) to tab strips and any
header strip that sits above content. Without it, the strip looks
disconnected from the body and the perceived alignment slips.

```dart
Container(
  height: 28,
  decoration: BoxDecoration(
    color: tokens.tabBarBackground,
    border: Border(bottom: BorderSide(color: tokens.dividerColor)),
  ),
  child: ...,
)
```

## Anti-patterns

- Centering a glyph inside a "hover background" that's larger than
  the natural icon size, then surrounding the whole thing with a
  padded parent — the icon ends up far inside the visible edge.
- Hardcoded `padding: EdgeInsets.symmetric(horizontal: 12)` on every
  control regardless of whether the right edge has an action — see
  "no double-edge padding".
- Tab strip inside `Column` without `crossAxisAlignment.stretch` —
  the strip ends mid-pane.
- `mainAxisSize.min` on the tab strip's outer Row when you actually
  want it to fill parent width — only use `min` for pill-shaped
  controls that should hug their content.
- Eyeballing alignment without working back from a target margin in
  pixels. The math matters; see "uniform inner spacing".

## Testing alignment

When iterating on a control's spacing:

1. State the target margin (e.g. "6px around the close icon, all
   sides except left").
2. Map every contributing source: parent padding, gap SizedBoxes,
   container alignment offsets, icon-to-container size differences.
3. Sum them. Adjust until they hit the target.
4. Verify visually — perceived mass may justify a 1–2px tweak.
