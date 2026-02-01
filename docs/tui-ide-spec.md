# TUI IDE Specification

Design specification for Clide's terminal user interface. This document describes the layout, interactions, and design decisions.

## Design Principles

- **Claude-centric** — Claude Code is the primary workspace, always visible
- **Contextual panels** — Editor/Diff/Terminal appear only when needed
- **Alt-key shortcuts** — Keybindings use Alt to avoid conflicts with Claude Code input
- **Responsive** — Works on 13" laptops to widescreen monitors
- **State preservation** — Hiding panels preserves all state (never destroy widgets)

---

## Panel Structure

### Layout Overview

```
┌─────────────────┬─────────────────────────┬──────────────────┐
│ panel-sidebar   │ panel-workspace (60%)   │ panel-context    │
│ 20%             │ [Editor][Diff][Terminal]│ 25%              │
│                 │ (hidden when inactive)  │                  │
│ [Files][Git]    ├─────────────────────────┤ [Jira][TODOs]    │
│ [Tree]          │                         │ [Problems]       │
│                 │ panel-claude            │                  │
│ (content area)  │ (40% when workspace     │ (content area)   │
│                 │  visible, else 100%)    │                  │
├─────────────────┤                         ├──────────────────┤
│ branch-status   │                         │                  │
│ ⎇ main ▾       │                         │                  │
│ staged: 2      │                         │                  │
└─────────────────┴─────────────────────────┴──────────────────┘
```

### Panel IDs

```python
PANELS = {
    # Left sidebar
    "sidebar": "panel-sidebar",

    # Center
    "claude": "panel-claude",
    "workspace": "panel-workspace",

    # Right context
    "context": "panel-context",
}
```

---

## Left Sidebar

### Tabs

| Tab | Content | Purpose |
|-----|---------|---------|
| Files | Project file tree | Navigate and open files |
| Git | Staged/Unstaged changes | Review and manage changes |
| Tree | Branch graph | Visualize git history |

### Git Tab

Two collapsible sections showing staged and unstaged changes.

**File status indicators:**
- `+` Added
- `~` Modified
- `-` Deleted
- `?` Untracked
- `→` Renamed

**Action buttons:**
- **Commit** — Delegate to Claude with `/commit` skill
- **Stash** — Delegate to Claude with `/stash` skill
- **Pull** — Delegate to Claude with `/pull` skill
- **Push** — Delegate to Claude with `/push` skill

### Tree Tab

Visual git graph using box-drawing characters:

```
● main: Latest commit message
│
├─● feature: Feature work
│
●─┴ Merge branch 'feature'
◆ Tagged release v1.0
```

**Symbols:**
- `●` Regular commit
- `◆` Merge commit
- `│` Branch line
- `├` Branch point
- `┴` Merge point

### Branch Status Bar

Fixed at bottom of sidebar. Shows current branch and git stats.

```
┌─────────────────────────────────┐
│ ⎇ main ▾    staged: 2 unstaged: 5│
└─────────────────────────────────┘
```

Click to expand branch selector:

```
┌─────────────────┐
│ Recent branches │
│ ● main         │
│ ○ feature/xyz  │
│ ○ develop      │
├─────────────────┤
│[Checkout] [New] │
└─────────────────┘
```

---

## Center Column

### Claude Panel

The primary workspace. Always visible.

**Default state:** 100% height of center column
**With workspace:** 40% height (bottom)

**Content:**
- Full PTY terminal running Claude Code CLI
- Scrollback history (1000 lines)
- Input at bottom

### Workspace Panel

Tabbed container for Editor, Diff, and Terminal. Hidden by default.

**Visibility principle:** Hiding is not closing. All panels retain state:
- Editor: Open file, cursor position, scroll, unsaved changes
- Diff: Current diff content, scroll position
- Terminal: Command history, output buffer

**Visibility triggers:**

| Trigger | Result |
|---------|--------|
| Click file in sidebar | Show workspace, focus Editor |
| Click problem/TODO | Show workspace, focus Editor at line |
| Press `` Alt+` `` | Show workspace, focus Terminal |
| Close all content | Hide workspace, Claude reclaims space |

#### Editor Tab

Code editor with:
- Syntax highlighting (tree-sitter based)
- Line numbers
- Current line highlighting

#### Diff Tab

Side-by-side diff viewer for:
- Git changes (staged and unstaged)
- Claude-proposed edits

#### Terminal Tab

Command execution terminal:
- Working directory tied to project root
- Output preserved when panel hidden

---

## Right Context Panel

### Tabs

| Tab | Badge | Content |
|-----|-------|---------|
| Jira | — | Jira issue display |
| TODOs | Count | TODO/FIXME from code and TODO.md |
| Problems | Count | Linter errors and warnings |

Tab badges update reactively as counts change.

### Jira Tab

Displays Jira issues via CLI integration. Manual refresh button.

### TODOs Tab

Two sub-tabs:

**Project tab:** Items from `TODO.md` (checkbox format)
**Comments tab:** TODO/FIXME/HACK/XXX comments in code

Click any item to jump to source location.

### Problems Tab

Linter output showing:
- File path
- Line number
- Severity (error/warning)
- Message

Click to navigate to source.

---

## Responsiveness

### CSS Strategy

```css
/* Default layout */
#panel-sidebar { width: 20%; min-width: 25; }
#panel-context { width: 25%; min-width: 30; }
#panel-claude { width: 1fr; }
```

### Compact Mode

Toggle with `Alt+C`. Hides both sidebars:

```css
.compact #panel-sidebar { display: none; }
.compact #panel-context { display: none; }
```

All panel state preserved when hidden.

---

## Keybindings

All shortcuts use `Alt` modifier to avoid conflicts with Claude Code input.

### Panel Navigation

| Action | Binding |
|--------|---------|
| Toggle left sidebar | `Alt+B` |
| Toggle right sidebar | `Alt+Shift+B` |
| Toggle terminal | `` Alt+` `` |
| Focus Claude | `Alt+1` |
| Focus Editor | `Alt+2` |
| Focus Terminal | `Alt+3` |
| Toggle compact mode | `Alt+C` |

### Application

| Action | Binding |
|--------|---------|
| Command palette | `Alt+P` |
| Quick open file | `Alt+O` |
| Select theme | `Alt+T` |
| Quit | `Alt+Q` |

### Git

| Action | Binding |
|--------|---------|
| Open Git panel | `Alt+G` |

### Editor

| Action | Binding |
|--------|---------|
| Save | `Alt+S` |
| Go to line | `Alt+L` |
| Go to problems | `Alt+M` |

---

## Panel Communication

### File Navigation Flow

```
Sidebar file click
       │
       ▼
Workspace appears (if hidden)
       │
       ▼
Editor tab focused
       │
       ▼
File loaded in Editor
```

### Problem/TODO Navigation Flow

```
Click problem/todo item
       │
       ▼
Workspace appears (if hidden)
       │
       ▼
Editor tab focused
       │
       ▼
File opened at specific line
       │
       ▼
Line scrolled into view
```

### Git Action Flow

```
Click git action button (Commit, Stash, etc.)
       │
       ▼
Ensure skill installed (async, with notification)
       │
       ▼
Send /command to Claude
       │
       ▼
Claude executes git workflow
```

---

## State Management

### Reactive Properties

```python
class ClideApp(App):
    workspace_visible: reactive[bool] = reactive(False)
    problem_count: reactive[int] = reactive(0)
    todo_count: reactive[int] = reactive(0)
    current_branch: reactive[str] = reactive("main")
    compact_mode: reactive[bool] = reactive(False)
```

### State Preservation

| Panel | Preserved State |
|-------|-----------------|
| Editor | Open file, cursor, scroll, unsaved changes |
| Diff | Current diff, scroll position |
| Terminal | Session, history, output buffer |
| Sidebar tabs | Scroll, expanded sections, selection |
| Context tabs | Scroll, selected item |

---

## Themes

22 built-in themes with custom theme support.

**Default:** summer-night (dark theme)

Theme selection persists in user settings (`~/.clide/settings.json`).

Custom themes can be added to `~/.clide/themes/` as TOML files.
