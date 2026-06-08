#!/usr/bin/env python3
"""Generate the Phosphor glyph reference page for the ui-design skill.

Mirrors `assets/fonts/phosphor/codepoints.csv` (the full bundled glyph set)
into a readable, greppable markdown table at
`.claude/skills/ui-design/references/phosphor-glyphs.md`, flagging which
glyphs clide already defines in `lib/widgets/src/icons/phosphor.dart`.

Run from the repo root:  python3 .claude/skills/ui-design/scripts/gen-phosphor-glyphs.py
"""
import csv
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[4]
CSV = ROOT / "assets/fonts/phosphor/codepoints.csv"
DART = ROOT / "lib/widgets/src/icons/phosphor.dart"
OUT = ROOT / ".claude/skills/ui-design/references/phosphor-glyphs.md"

# Codepoint -> camelCase accessor already defined in PhosphorIcons.
defined = {}
for m in re.finditer(r"static const (\w+) = PhosphorIconPainter\((0x[0-9a-fA-F]+)\)", DART.read_text()):
    defined[int(m.group(2), 16)] = m.group(1)

rows = list(csv.DictReader(CSV.open()))
n_def = sum(1 for r in rows if int(r["codepoint"], 16) in defined)

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
    "`python3 .claude/skills/ui-design/scripts/gen-phosphor-glyphs.py`.",
    "",
    f"The **In clide** column flags the **{n_def}** glyphs already wired into "
    "`PhosphorIcons` (`lib/widgets/src/icons/phosphor.dart`) — reach for those first. "
    "To use any other glyph, add a one-line `static const` to that class with the "
    "codepoint below, then `ClideIcon(PhosphorIcons.<name>, size: 13)`. Keep additions "
    "to icons we actually use — don't bulk-import.",
    "",
    "| Codepoint | Name (kebab) | Pascal | In clide |",
    "|---|---|---|---|",
]
for r in rows:
    cp = r["codepoint"]
    accessor = defined.get(int(cp, 16))
    in_clide = f"`PhosphorIcons.{accessor}`" if accessor else ""
    lines.append(f"| `{cp}` | {r['name']} | {r['pascal_name']} | {in_clide} |")

OUT.write_text("\n".join(lines) + "\n")
print(f"wrote {OUT.relative_to(ROOT)} — {len(rows)} glyphs, {n_def} already defined")
