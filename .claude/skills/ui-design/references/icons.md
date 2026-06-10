# Icons — Phosphor + clide-owned painters

## Phosphor Icons

The app bundles Phosphor Icons (v2.0.8, MIT) as TTF fonts at
`assets/fonts/phosphor/` (regular, bold, fill weights).

**Glyph reference:** [`phosphor-glyphs.md`](phosphor-glyphs.md) — the full
1512-glyph table (codepoint · kebab name · Pascal name). Grep it for the exact
kebab name; **all 1512 are available** — no per-icon wiring (T-314).

### Using an icon

Reference a glyph by its **exact kebab-case name** — no codepoints in feature
code; the label→codepoint table lives only in the generated
`lib/widgets/src/icons/phosphor_glyphs.g.dart`:

```dart
ClideIcon(PhosphorIcons.byName('arrow-clockwise'), size: 13)
```

Or as a `TabContribution` icon field: `icon: PhosphorIcons.byName('lightbulb')`.

- An **unknown name** is a bug — it degrades to the `placeholder` error box so
  the mistake is visible. `phosphor_glyphs_test` asserts every `byName('…')`
  literal in `lib/` resolves, recovering the typo check a const would give.
- For an **intentional blank** that still reserves the icon's box (alignment),
  use `const EmptyIconPainter()` — *not* a missing name.
- Regenerate the map after a font bump: `dart run tool/gen_phosphor_glyphs.dart`.

**Bold weight:** pass `family: 'Phosphor-Bold'` to `PhosphorIconPainter`.
**Fill weight:** `family: 'Phosphor-Fill'`.

**Bold weight:** pass `family: 'Phosphor-Bold'` to `PhosphorIconPainter`.
**Fill weight:** `family: 'Phosphor-Fill'`.

## clide-owned painters

Some shapes are simple enough to paint directly without an icon
font. Hand-rolled `ClideIconPainter` subclasses live under
`lib/widgets/src/icons/`:

- `CheckIcon`, `ChevronIcon`, `CloseIcon` (`x.dart`)
- `DotIcon`, `FolderIcon`, `GearIcon`
- `GitBranchIcon`, `PlugIcon`, `SearchIcon`
- `TerminalIcon`, `WarningIcon`

Use these for tiny, theme-aware glyphs (close ×, dropdown chevrons,
status dots) where pulling in the Phosphor font weight would be
overkill or where the visual needs to match the theme's stroke
weight conventions.

Pattern for a new painter:

```dart
class FoobarIcon extends ClideIconPainter {
  const FoobarIcon();

  @override
  void paint(Canvas canvas, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.10
      ..strokeCap = StrokeCap.round;
    // Coordinates are 0..1 (the painter is given a unit square).
    canvas.drawLine(const Offset(0.2, 0.2), const Offset(0.8, 0.8), p);
  }
}
```

## Sizing

Icon sizes used in clide (subject to consolidation under
`ClideSpacing` — see T-86):

- `10` — micro: close × inside a tab
- `13` — caption-row icons (sidebar, status bar)
- `14` — standard inline icons (icon rail)
- `16` — small icon hit-target outer container
- `18`–`20` — emphatic / standalone icons

Pass `size:` to `ClideIcon`; the painter receives a unit-square
canvas regardless. Color defaults to `globalForeground`; pass
explicit `color:` for muted/active variants.

## Anti-patterns

- Importing all of Phosphor — only declare codepoints we use.
- Hand-painting a glyph that already exists in Phosphor at the right
  weight — use the font.
- Hardcoded `Color` on icons — pass through the surface tokens
  (`globalForeground`, `globalTextMuted`, `panelActiveBorder`, etc.).
