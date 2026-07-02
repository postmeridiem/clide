#!/usr/bin/env python3
"""Generate the Phosphor glyph reference page for the ui-design skill.

Mirrors `assets/fonts/phosphor/codepoints.csv` (the full bundled glyph set)
into a readable, greppable markdown table at
`.claude/skills/ui-design/references/phosphor-glyphs.md`.

That table is also the source of truth for the `kPhosphorGlyphs` map — after
regenerating it, re-run `dart run tool/gen_phosphor_glyphs.dart` so
`lib/widgets/src/icons/phosphor_glyphs.g.dart` stays in sync.

Run from the repo root:  python3 .claude/skills/ui-design/scripts/gen-phosphor-glyphs.py
"""
import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[4]
CSV = ROOT / "assets/fonts/phosphor/codepoints.csv"
OUT = ROOT / ".claude/skills/ui-design/references/phosphor-glyphs.md"

rows = list(csv.DictReader(CSV.open()))

lines = [
    "---",
    "name: phosphor-glyphs",
    "type: reference",
    "tags: [icons, phosphor, ui-design]",
    "---",
    "",
    "# Phosphor glyphs — full reference (v2.0.8)",
    "",
    f"All **{len(rows)}** glyphs bundled in clide's Phosphor font "
    "(`assets/fonts/phosphor/`, MIT). Generated from "
    "`assets/fonts/phosphor/codepoints.csv` — **do not hand-edit**; regenerate with "
    "`python3 .claude/skills/ui-design/scripts/gen-phosphor-glyphs.py`, then re-run "
    "`dart run tool/gen_phosphor_glyphs.dart` (this table is the source for the "
    "generated `kPhosphorGlyphs` map).",
    "",
    "Every glyph is available in code via `PhosphorIcons.byName('<kebab-name>')` "
    "(T-314) — e.g. `ClideIcon(PhosphorIcons.byName('folder'), size: 13)`. Raw "
    "codepoints never appear in feature code; they live only in the generated map. "
    "An unknown name renders the `placeholder` glyph, and `phosphor_glyphs_test` "
    "asserts every `byName('…')` literal in `lib/` resolves.",
    "",
    "| Codepoint | Name (kebab) | Pascal |",
    "|---|---|---|",
]
for r in rows:
    lines.append(f"| `{r['codepoint']}` | {r['name']} | {r['pascal_name']} |")

OUT.write_text("\n".join(lines) + "\n")
print(f"wrote {OUT.relative_to(ROOT)} — {len(rows)} glyphs")
