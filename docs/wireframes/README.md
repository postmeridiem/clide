# clide wireframes

Canonical layout reference, generated from the actual implementation
via the `frame0-wireframe` skill. Each `.json` is the source of
truth; the `.png` is rendered from it.

These supersede the hi-fi mockups under
[`../claude-design/`](../claude-design/), which are kept for
historical context and design tokens.

## Set

### Welcome
- [`welcome/welcome-screen.json`](welcome/welcome-screen.json) /
  [.png](welcome/welcome-screen.png)
  — first-run landing: logo + wordmark, START / RECENT columns,
  Tips card, status line.

### Main view
- [`main/main-view.json`](main/main-view.json) /
  [.png](main/main-view.png)
  — three-column default: tickets sidebar, Claude pane, empty
  context panel.
- [`main/editor-above-claude.json`](main/editor-above-claude.json) /
  [.png](main/editor-above-claude.png)
  — D-49 editor mode: editor above Claude in the middle column,
  divider between, prompt Y stays fixed.
- [`main/focus-mode.json`](main/focus-mode.json) /
  [.png](main/focus-mode.png)
  — D-52 focus mode: full-window Claude pane, sidebars hidden,
  Esc-to-exit hint in the title bar.
- [`main/sidebar-collapsed.json`](main/sidebar-collapsed.json) /
  [.png](main/sidebar-collapsed.png)
  — D-51 12px spine: sidebar collapsed to a vertical strip with
  rotated label and activity badge.
- [`main/ticket-detail.json`](main/ticket-detail.json) /
  [.png](main/ticket-detail.png)
  — context panel showing a selected ticket with metadata and
  description.

## Updating

1. Edit the `.json` (source of truth).
2. Re-export with the `frame0-wireframe` skill:
   ```
   .claude/skills/frame0-wireframe/scripts/frame0-sync.py \
     export docs/wireframes/<dir>/<name>.json \
            docs/wireframes/<dir>/<name>.png
   ```
3. Commit both files.

Frame0 must be running locally for export. Don't pull from Frame0 —
the JSON is authoritative.
