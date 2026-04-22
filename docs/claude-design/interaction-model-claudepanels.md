# clide — interaction model (for implementation)

Target: Claude Code. This is the shell spec extracted from wireframe flows v3.
Authoritative source: `Wireframe - Flows v3.html`.

---

## Core principle

**Claude is home.** The prompt bar is pinned to the bottom of the middle column. Every other surface makes room *around* Claude — never *on top of* her, never pushing her prompt off-Y.

---

## Layout — three columns, one bottom line

```
┌──────────────┬──────────────────────────┬──────────────┐
│ LEFT         │ MIDDLE                   │ RIGHT        │
│ overview     │ Claude (+ editor)        │ context      │
│              │                          │              │
│ header       │ transcript (scrolls)     │ header       │
│ body         │ ─────────────            │ body:        │
│              │ prompt (PINNED)          │   viewer     │
│              │                          │   ─────      │
│              │                          │   pql pane   │
├──────────────┼──────────────────────────┼──────────────┤
│ icon rail    │ app strip                │ icon rail    │
└──────────────┴──────────────────────────┴──────────────┘
  ↑ all three bottom strips on the same horizontal line ↑
```

**Hard rules:**
- Prompt bar Y-position is invariant across all states (open, collapsed, focus, editor, viewer).
- The three bottom strips align to one continuous line. Right rail keeps its footprint even when right panel is empty.
- Claude is always the largest surface when present.

---

## Left panel — overview

**Purpose:** where you track what you're working on and browse the codebase.

**Body content (swappable via bottom rail):**
- `◉` **Tickets & decisions** — *default view*. Active ticket stays visible while chatting. Decisions listed below tickets.
- `◆` Decisions (standalone view if desired)
- `▦` Files — tree
- `⌥` Git — staged / unstaged diff list, branch name in header
- `↑` PRs — list

**Bottom rail** = section switcher icons. Sits *under* the panel body when expanded. Keyboard: `⌥1-5`.

**Collapsed state:** 12px spine, vertical label ("tickets"), no icon rail. Edge arrow on outer boundary toggles. Keyboard: `⌘⇧1`.

---

## Middle panel — Claude (+ optional editor)

**Always present.** Structure top-to-bottom:
1. **Transcript** — scrolls
2. **Prompt bar** — pinned, 2px top border, never moves
3. **App strip** — 14px: terminal shell + daemon indicator + branch. Expands on focus.

**Editor mode** (rare, deliberate):
- Invoked via `⌘E` on a file, or `✎` icon in a viewer
- Editor lifts in *above* Claude, occupies 30–40% of vertical space
- Claude keeps the remainder; prompt bar Y unchanged
- Close with `⌘W` — Claude reclaims full height
- `👁`/`✎` toggle in editor header swaps to viewer mode
- Draggable divider between editor and Claude

**No buffer tabs. No breadcrumbs.** Files opened individually; second file closes first (or split on explicit command — deferred).

---

## Right panel — context

**Purpose:** readers. What Claude wants you to look at, or what you pull up to reference.

**Body content:**
- `👁` **Viewer** — rendered md, images, graphs, PR description, diff preview. Read-only.
- `◈` Pql graph view
- `⌘` Links
- `▣` Images

**Pql in/out pane** sits *under* the viewer, collapsed by default. Header shows count: `← 3 in · 5 out →`. Click header to expand.

**Bottom rail** = context-type switcher. Same style as left rail.

**Collapsed state:** 12px spine, vertical label ("context"). Edge arrow toggles. Keyboard: `⌘⇧3`.

### Context auto-behavior

| State | Claude references new content | Behavior |
|---|---|---|
| Right open, empty | — | panel empty, holds footprint |
| Right open, viewer loaded | Claude links `foo.md` | **swap in** — replaces current viewer |
| Right collapsed | Claude links `foo.md` | **badge on spine** ("2") — no layout shift |
| Editor open on `.md` | user edits | viewer auto-opens, **live-syncs** to editor content |
| Editor open on `.dart`, `.yaml`, etc. | — | no auto-viewer (no rendered counterpart) |

---

## Viewer ↔ editor swap (same file)

- Each surface shows a `👁`/`✎` toggle in its header
- Clicking `✎` on a viewer: file *promotes* to editor in the middle column; right panel snaps back to nav
- Clicking `👁` on an editor: file *demotes* to viewer in the right panel; editor closes
- Mutually exclusive for the same file — never two surfaces showing the same file simultaneously
- Different files *can* coexist (editor on `main.dart` + viewer on `README.md`). Rare.

---

## Chrome budget — minimalism rules

Total persistent chrome:
- **2 edge arrows** (left outer boundary, right outer boundary) — collapse toggles
- **1 `⛶` glyph per panel** — hover-only, focus mode
- **0 always-visible buttons** beyond icon rails
- **⌘P overlay** — fuzzy finder, no layout shift

Keyboard is the primary surface. Icons are escape hatches.

### Keyboard map

| Shortcut | Action |
|---|---|
| `⌘P` | Fuzzy find overlay (files, tickets, decisions, symbols) |
| `⌘⇧1` / `⌘⇧3` | Collapse/expand left / right panel |
| `⌘1` / `⌘2` / `⌘3` | Focus left / middle / right panel (move input focus) |
| `⌘.` | Toggle focus mode on currently focused panel |
| `⌥1`–`⌥5` | Left-panel section switch (tickets, decisions, files, git, pr) |
| `⌘E` | Open current file in editor (middle column) |
| `⌘W` | Close editor / dismiss viewer |
| `Esc` | Exit focus mode / close fuzzy finder / dismiss viewer |

---

## Focus mode

- Entered via: double-click panel header, hover-visible `⛶` in header, or `⌘.`
- Active panel takes the whole window; others hidden
- Header shows "Esc" hint
- `Esc` restores exact prior layout (remember collapse state and divider positions)

---

## Collapse behavior — spine

When collapsed, a panel becomes a **12px spine**:
- Vertical rotated label ("tickets" / "context")
- No icon rail on spine
- Background: `paper-2` (slightly darker than main paper)
- Border on inner edge only
- Click anywhere on spine to expand
- If context badge is pending: small filled dot with count at top of spine

---

## What we deleted from classic IDE chrome

- ❌ Left icon rail as a separate column (it's now the left panel's bottom footer)
- ❌ Buffer tabs
- ❌ Breadcrumbs
- ❌ Activity bar (VS Code-style)
- ❌ Separate status bar row (merged into app strip)
- ❌ File tree as the permanent default left view (demoted behind tickets)

---

## Responsive behavior

| Width | Behavior |
|---|---|
| ≥ 1600px | Splits relax toward 30% |
| 1200–1600px | Default: L 200px, R 220px, middle flex |
| < 1200px | Splits snap toward 40%; consider auto-collapse of right |
| < 1000px | Force modal viewer/editor instead of split (deferred) |

---

## State persistence

Remember across sessions:
- Collapse state of left and right panels
- Active left section (tix/dec/files/git/pr)
- Active right context type
- Pql pane expanded/collapsed
- Editor split ratio when open
- Fuzzy find recent picks

---

## Open questions (flag to user, don't assume)

1. **Small screens (< 1000px)** — modal or stacked? (Deferred.)
2. **Two-editor split** — resist until proven needed; feels like tabs creeping back.
3. **Terminal strip as panel** — is it just a shell, or also logs/errors/test output tabs inside the strip? (Probably both, later.)
4. **Branch picker location** — moved out of the bottom status bar; best place is inside the git section header, with a compact indicator in the app strip.
5. **Focus behavior when editor is dirty and user peeks a viewer** — prompt-bar-rule wins: focus stays in Claude.

---

## Visual tokens

Use the four themes already shipped in `tokens/*.yaml`. No new palette. This spec is purely structural.

---

*End of spec. Source wireframe: `Wireframe - Flows v3.html` (anatomy diagram + 6 interaction flows).*
