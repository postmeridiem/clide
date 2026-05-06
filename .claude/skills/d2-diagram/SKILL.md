---
name: d2-diagram
description: >
  Generate technical diagrams using d2 (text-to-diagram CLI). Use when the
  user says "create a diagram", "draw architecture", "make a flowchart",
  "diagram this", "render d2", "d2", "data flow diagram", "entity relationship",
  "state machine", "sequence diagram", "UI flow", or invokes /d2-diagram.
  Produces .d2 source files and renders them to PNG. Also use when asked
  to update, re-render, or batch render existing diagrams.
---

# d2 Diagram Generation

Generate technical diagrams from text using d2 (v0.7.1). Pure CLI, no
external dependencies beyond the d2 binary.

**Binary:** `/home/linuxbrew/.linuxbrew/bin/d2`

## Project Defaults

| Setting | Value | Override |
|---------|-------|----------|
| Theme | 200 (Dark Mauve) | `--theme N` |
| Layout | dagre | `--layout elk` |
| Padding | 100px | — |
| Format | PNG | `--svg` |

## Output Convention

```
docs/diagrams/
  architecture/    # System architecture, IPC, component layout
  data-flow/       # Sequence diagrams, data pipelines
  entity/          # ER diagrams, ECS component schemas
  state/           # State machines, behavior trees
  ui/              # UI navigation flow, screen transitions
```

Both `.d2` source and `.png` output are tracked in git.

## Single Diagram Workflow

1. **Determine category** — architecture, data-flow, entity, state, or ui
2. **Read template** — `references/diagram-templates.md` for the matching category
3. **Read syntax** — `references/d2-syntax-guide.md` if unfamiliar with d2 syntax
4. **Write .d2 source** — to `docs/diagrams/{category}/{name}.d2`
5. **Validate** — `.claude/skills/d2-diagram/scripts/d2-render.sh validate {file}`
6. **Render** — `.claude/skills/d2-diagram/scripts/d2-render.sh {file}`
7. **Read SVG** — verify the output, present to user

### Script Usage

```bash
# Render with project defaults
.claude/skills/d2-diagram/scripts/d2-render.sh docs/diagrams/architecture/ipc-bridge.d2

# Validate syntax only
.claude/skills/d2-diagram/scripts/d2-render.sh validate docs/diagrams/architecture/ipc-bridge.d2

# Auto-format source
.claude/skills/d2-diagram/scripts/d2-render.sh fmt docs/diagrams/architecture/ipc-bridge.d2

# Sketch mode (hand-drawn look for drafts)
.claude/skills/d2-diagram/scripts/d2-render.sh docs/diagrams/ui/flow.d2 --sketch

# Light theme (for printable docs)
.claude/skills/d2-diagram/scripts/d2-render.sh docs/diagrams/entity/schema.d2 --theme 0

# SVG output (if specifically needed)
.claude/skills/d2-diagram/scripts/d2-render.sh docs/diagrams/architecture/overview.d2 --svg
```

## Batch Render

Re-render all diagrams after theme or style changes:

```bash
# All diagrams
.claude/skills/d2-diagram/scripts/d2-batch.sh

# One category
.claude/skills/d2-diagram/scripts/d2-batch.sh docs/diagrams/architecture/

# Preview what would render
.claude/skills/d2-diagram/scripts/d2-batch.sh --dry-run

# Force re-render everything
.claude/skills/d2-diagram/scripts/d2-batch.sh --force
```

Batch skips files whose PNG is newer than the `.d2` source unless `--force`.

## Advanced Patterns

### Variables for consistent styling

```d2
vars: {
  color-bg: "#2a3040"
  color-stroke: "#333340"
  color-text: "#c8d0e0"
  color-accent: "#c8d8f0"
}
```

### Multi-board (layers)

```d2
# Base diagram here

layers: {
  detailed: {
    # More detailed view
  }
}
```

### Sequence diagrams

```d2
shape: sequence_diagram
client: Godot Client
server: Rust Server

client -> server: TickRequest(delta)
server -> client: WorldState(entities)
```

### Imports

Split shared definitions into a separate file and import:

```d2
...@shared-defs.d2
```

## Agent Guidance

- **Qatux** — Architecture decision records, system overview diagrams, data
  schemas. Prefer architecture and entity templates.
- **Tyre** — IPC bridge, ECS system flow, chunk loading pipeline, perception
  system data flow. Prefer architecture and data-flow templates.
- **Araminta** — UI navigation flow, screen transitions, component hierarchy.
  Prefer UI flow template.

## References

- `references/d2-syntax-guide.md` — Language quick reference (shapes, edges,
  containers, styling, variables). Read when unfamiliar with d2 syntax.
- `references/diagram-templates.md` — Five category templates with complete
  d2 source examples. Read when starting a new diagram.
