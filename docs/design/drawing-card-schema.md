# Drawing-card JSON schema (T-317 / D-91 / D-103) — draft

Status: **draft for build**, SVG-substrate model (D-103), refined from the
T-317 wireframe set, 2026-06-28.

## Model — what this is, and what it is NOT

- **SVG is the substrate.** The card's primitive / scene-graph layer **is SVG**;
  the clide-owned `CustomPaint` **SVG renderer (T-320) is the engine** the rest
  builds on (D-103).
- It is **not** the HTML Canvas 2D API and **not** a third-party package. SVG is
  a document *format* we render ourselves — "own the rendering stack" holds.
  ("HTML `<canvas>`" in D-91 was only a mental model, chosen to reject Obsidian's
  `.canvas` schema; never an API to port.)
- The card is **two layers**:
  1. **SVG content** — painted by the SVG renderer.
  2. A thin **Flutter overlay** — the clide chrome that is *not* content
     (per-object label/description captions, lightbox affordance), anchored to
     SVG elements via `data-*` attributes.
- **Display-only** (D-78); re-rendered from the document. The **graph template
  is the live-widget exception** (below).

## Document envelope

```json
{
  "card":     { "label": "Build pipeline", "description": "…" },  // optional caption (overlay)
  "template": "icon",                                            // optional → template sugar
  "…template fields…": "…",
  "svg":      "<svg viewBox='0 0 480 360'>…</svg>"               // primitive mode = raw SVG
  // or "svgPath": "diagram.svg"
}
```

- **Template mode** — `template` names a component; clide lowers it to SVG
  (+ overlay anchors).
- **Primitive mode** — `svg` (inline) or `svgPath` — arbitrary SVG, the escape
  hatch. One less invented format; external SVG / graphviz / mermaid render free.
- Card size comes from the SVG `viewBox` (or `width`/`height`); the painter scales
  to the pane width.

## Primitive layer = a bounded SVG subset

The renderer supports the subset our templates + d2 / graphviz / mermaid emit —
**not** a full SVG engine:

- shapes: `rect`, `line`, `polyline`, `polygon`, `circle`, `ellipse`, `path`
- `text` (incl. the bundled **Phosphor** font for glyphs)
- `image` (`href` → resolved path; raster)
- `g` + `transform` (translate / scale), basic `fill` / `stroke` /
  `stroke-width` / `opacity`, `rx`/`ry` corners
- **Out of scope** unless a template needs it (decide then): filters,
  animations, rich gradients, `foreignObject`, scripting.

`color` everywhere is an **arbitrary value** (hex / named) — content, not a clide
`SurfaceTokens` token (D-7 governs clide chrome, not rendered content).

## Overlay (clide chrome, layered over the SVG)

Flutter widgets anchored to SVG elements that carry:

- `data-label` → themed caption beneath the element's bounding box
- `data-description` → secondary caption line
- `data-lightbox` (on `<image>`) → click-to-zoom affordance

Templates emit these attributes; raw-SVG authors may add them. The icon
template's `data-label` is also the bridge to the interaction-zone choice list.

## Templates (lower to SVG + overlay)

| template | lowers to | ticket |
|----------|-----------|--------|
| `image`   | `<image href>` + `data-lightbox` + caption attrs | T-316 |
| `icon`    | `<text font=Phosphor>` glyphs at 10,11,12,13,14,15,18,20,24,32,48 + hero 52; per-item `data-label`/`data-description`/color | T-313 |
| `compare` | two+ `<image>` side by side in a `<g>`, per-image `data-lightbox` + captions | T-319 |
| `svg`     | identity — the source *is* the SVG | T-320 |
| `d2`      | compile d2 → SVG → render | T-494 |
| `graph`   | **exception** — hosts the live native graph subsystem widget (D-46 / T-323), not static SVG | T-321 |

## CLI / transport (D-6 parity)

`clide draw --file doc.json` (or inline JSON). **Flutter-free** handler validates,
publishes on a `draw` MessageBus channel; the Claude extension injects the card —
mirroring `image.show`. The shipped `image show` (T-249/T-252) stays as
convenience and migrates onto this card later (D-91). `--stdin` deferred (T-315);
`--file` is the path.

## Error contract

Unknown `template`, unparseable / unsupported SVG, bad `href` / glyph / `color`
→ honest `IpcError` (`userError` / `notFound`), surfaced like `image.show` —
**never a blank card**.

## Build sequence (D-103)

1. **T-320 — the SVG renderer (engine):** parse + paint the bounded SVG subset.
2. **T-318 — envelope + template dispatch + the Flutter overlay** (`data-*` →
   captions / lightbox) on top of the renderer.
3. **Templates:** image / icon (T-316 / T-313) → compare (T-319) → d2 (T-494) →
   graph (T-321, after the graph subsystem T-323).

## Open decisions (resolve before the relevant step)

- **SVG subset boundary (T-320):** now the substrate — bound it to what our
  templates + d2 / graphviz emit; expand deliberately.
- **D2 compiler (T-494):** shell out to a `d2` binary as a pql-style supporter
  tool, vs. vendor.
- **Graph (T-321):** gated on the native graph subsystem (D-46 / T-323).
