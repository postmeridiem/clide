---
name: frame0-wireframe
description: >
  Create and export UI wireframes using Frame0 (local desktop wireframing
  app with HTTP API). Use when the user says "create wireframe", "wireframe
  this", "mock up the UI", "draw a screen", "UI layout", "wireframe the HUD",
  "Frame0", "frame0", "export wireframe", or invokes /frame0-wireframe.
  Wireframes are authored as local JSON files (source of truth) and synced
  to Frame0 for rendering and export. Requires Frame0 to be running locally.
---

# Frame0 Wireframe Generation

Create UI wireframes as JSON files, sync them to Frame0 for rendering, and
export as PNG. Local JSON is the source of truth — Frame0 is the renderer.

**Frame0 is a renderer, not a workspace.** Treat it as disposable output.
Push freely, delete test pages, keep it clean. Never pull from Frame0 unless
the user explicitly says they have made edits in Frame0 and want to import
them. The pull workflow exists for that case only — do not use it proactively.

**Prerequisite:** Frame0 desktop app must be running. If not available,
stop and inform the user. Point to `references/setup-guide.md`.

## Health Check

Always check first:

```bash
.claude/skills/frame0-wireframe/scripts/frame0-cmd.sh health
```

## Core Workflow

1. **Health check** — verify Frame0 is running
2. **Write wireframe JSON** — to `docs/design/wireframes/{category}/{name}.json`
3. **Push to Frame0** — `frame0-sync.py push <file.json>`
4. **Export PNG** — `frame0-sync.py export <file.json> <output.png>`
5. **Clean up** — delete test/scratch pages from Frame0 when done

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/frame0-sync.py` | **Primary.** Push/pull/export wireframes between JSON and Frame0 |
| `scripts/frame0-cmd.sh` | Low-level API wrapper for ad-hoc commands |

## Wireframe JSON Format

```json
{
  "name": "Dialogue Box",
  "shapes": {
    "panel": {
      "type": "Rectangle",
      "left": 170, "top": 500, "width": 800, "height": 260,
      "fillColor": "#1a1e24",
      "strokeColor": "#333340",
      "corners": [8, 8, 8, 8]
    },
    "speaker": {
      "type": "Text",
      "parent": "panel",
      "left": 190, "top": 520,
      "text": "LERA KONSTANTIN",
      "fontColor": "#c8d0e0",
      "fontSize": 16
    },
    "btn-ask": {
      "type": "Rectangle",
      "parent": "panel",
      "left": 190, "top": 670, "width": 370, "height": 30,
      "fillColor": "#2a3040",
      "strokeColor": "#c8d8f0",
      "corners": [4, 4, 4, 4]
    }
  },
  "connectors": {
    "flow-1": {
      "tailId": "panel",
      "headId": "btn-ask",
      "strokeColor": "#c8d8f0"
    }
  }
}
```

### Key rules

- **Shape IDs are stable local IDs** you control (e.g. `"panel"`, `"btn-ask"`)
- **`parent`** references another local shape ID for nesting
- **`type`** uses create-API names: `Rectangle`, `Ellipse`, `Text`, `Line`
- **Colors** can be hex (`#2a3040`) or Frame0 theme tokens (`$slate6`)
- After a pull, Frame0 returns its native vocabulary (`Box` for Rectangle,
  theme tokens for colors). The sync script handles the mapping transparently.
- The `.idmap.json` mapping file (gitignored) tracks local ID ↔ Frame0 ID

### Sync commands

```bash
SYNC=".claude/skills/frame0-wireframe/scripts/frame0-sync.py"

# Push local JSON to Frame0 (clears page, recreates all shapes)
$SYNC push docs/design/wireframes/dialogue/dialogue-box.json

# Pull Frame0 page back to local JSON (preserves local IDs via mapping)
$SYNC pull "Dialogue Box" docs/design/wireframes/dialogue/dialogue-box.json

# Push + export as PNG in one step
$SYNC export docs/design/wireframes/dialogue/dialogue-box.json \
  docs/design/wireframes/dialogue/dialogue-box.png
```

### Batch export

Use this when exporting multiple wireframes. It runs as a single Bash call,
avoiding repeated permission prompts.

```bash
BATCH=".claude/skills/frame0-wireframe/scripts/frame0-export-batch.sh"

# Dry run first — shows full manifest, no Frame0 calls
$BATCH --dry-run

# Export everything (skips PNGs already newer than their JSON)
$BATCH

# Export one category only
$BATCH --category dialogue

# Force re-export of everything
$BATCH --force
```

**Always dry-run first, then get approval before running the live export.**

## Low-Level Commands

For ad-hoc operations or exec calls not covered by sync:

```bash
CMD=".claude/skills/frame0-wireframe/scripts/frame0-cmd.sh"
$CMD health
$CMD list-pages
$CMD current-page
$CMD get-page <page-id>
$CMD create-shape Rectangle '{"name":"btn","left":100,"top":100,"width":120,"height":36}'
$CMD create-connector <tail-id> <head-id>
$CMD move <shape-id> <dx> <dy>
$CMD export --format image/png
$CMD exec "view:fit-to-screen" '{}'
```

If you find yourself using `exec` for the same command repeatedly, flag it as
a candidate for a proper wrapper in `frame0-cmd.sh`.

## Project Styling Defaults

Colors from `docs/design/visual-grammar-v01.md`:

| Role | Hex | Frame0 token |
|------|-----|-------------|
| Background | `#1a1e24` | `$sage3` |
| Stroke | `#333340` | `$slate6` |
| Fill | `#2a3040` | `$slate5` |
| Text | `#c8d0e0` | `$mint12` |
| Accent | `#c8d8f0` | `$blue12` |

Use hex when authoring new wireframes. Frame0 maps them to theme tokens on push.

## Output Convention

```
docs/design/wireframes/
  hud/              # HUD layout wireframes
  menus/            # Menu screen wireframes
  dialogue/         # Dialogue box wireframes
  insert/           # Neural insert wireframes
```

Both `.json` source and `.png` exports are tracked in git.
`.idmap.json` mapping files are gitignored.

## Agent Guidance

- **Araminta** — Primary user. Full wireframe creation, layout iteration,
  visual consistency. Uses all component library patterns.
- **Tyre** — Interface architecture wireframes. System boundary diagrams.
- **Qatux** — Export wireframes for UI decision records and documentation.

## References

- `references/component-library.md` — Pre-built JSON wireframe templates
  (HUD, dialogue, menus, modals, lists, inventory). Copy and adapt.
- `references/api-reference.md` — Frame0 HTTP API command reference and
  type mappings. Read for low-level control.
- `references/setup-guide.md` — Frame0 installation and startup for Fedora.
