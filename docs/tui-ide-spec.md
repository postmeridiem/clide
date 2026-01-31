# TUI IDE Specification

A terminal-based IDE built with Textual, designed to wrap Claude Code and integrate project management tooling (Jira/Confluence via CLI).

## Design Principles

- **Claude-centric**: Claude Code is the primary workspace, always visible
- **Contextual panels**: Editor/Diff/Terminal appear only when needed
- **VSCode-familiar**: Keybindings and interaction patterns follow VSCode conventions
- **Responsive**: Works on 13" laptop and widescreen monitors
- **No vim magic**: Standard keyboard navigation, no modal editing

---

## Panel Structure

### Layout Overview

```
┌─────────────────┬─────────────────────────┬──────────────────┐
│ panel-sidebar   │ panel-workspace (60%)   │ panel-context    │
│                 │ [Editor][Diff][Terminal]│                  │
│ [Files][Git]    │ (hidden when inactive)  │ (content area)   │
│ [Tree]          ├─────────────────────────┤                  │
│                 │                         │                  │
│ (content area)  │ panel-claude            │                  │
│                 │ (40% when workspace     │                  │
│                 │  visible, else 100%)    │                  │
├─────────────────┤                         ├──────────────────┤
│ branch-status   │                         │[⚠ 3][✓12][Jira] │
│ ⎇ main ▾       │                         │ context-tabs     │
└─────────────────┴─────────────────────────┴──────────────────┘
```

### Panel Definitions

```python
PANELS = {
    # Left sidebar
    "sidebar": "panel-sidebar",
    "sidebar-files": "panel-sidebar-files",
    "sidebar-git": "panel-sidebar-git", 
    "sidebar-tree": "panel-sidebar-tree",
    "branch-status": "panel-branch-status",
    
    # Center
    "claude": "panel-claude",
    "workspace": "panel-workspace",
    "editor": "panel-editor",
    "diff": "panel-diff",
    "terminal": "panel-terminal",
    
    # Right context
    "context": "panel-context",
    "context-jira": "panel-context-jira",
    "context-problems": "panel-context-problems",
    "context-todos": "panel-context-todos",
}
```

---

## Left Sidebar (`panel-sidebar`)

### Tabs

| Tab | Content | Widget |
|-----|---------|--------|
| Files | Project file tree | `DirectoryTree` |
| Git | Staged/Unstaged changes | `GitChangesView` (custom) |
| Tree | Merge/branch graph | `GitGraphView` (custom) |

### Git Tab Details

Two collapsible sections:
- **Staged**: Files in index, ready to commit
- **Unstaged**: Modified/untracked files

Each file item shows:
- Status icon: `+` added, `~` modified, `-` deleted, `?` untracked, `→` renamed
- File path (relative)

**Interactions:**
- Click file → opens in Editor panel
- Double-click or keybind → stage/unstage file
- Right-click or keybind → show context menu (discard, diff, etc.)

### Tree Tab Details

Renders `git log --graph --oneline --decorate --all` with visual styling.

**Polish item**: Consider custom rendering with box-drawing characters for a cleaner look:
```
●──┬── main: Latest commit message
│  ●── feature: Feature work
●──┴── Merge branch 'feature'
◆───── Tagged release v1.0
```

Use canvas or rich text with:
```python
GRAPH_CHARS = {
    'commit': '●',
    'merge': '◆',
    'line': '│',
    'branch': '├──',
    'join': '┴──',
}
```

### Branch Status Bar

Fixed at bottom of sidebar. Shows current branch with popout toggle.

```
┌─────────────────┐
│ ⎇ main ▾       │  ← Click or keybind to expand
└─────────────────┘
        │
        ▼ (popout overlay)
┌─────────────────┐
│ Recent branches │
│ ○ main         │
│ ○ feature/xyz  │
│ ○ develop      │
├─────────────────┤
│ [Checkout] [New]│
└─────────────────┘
```

---

## Center Column

### Claude Panel (`panel-claude`)

The primary workspace. Displays Claude Code interaction.

**Default state**: 100% height of center column
**With workspace**: 40% height (bottom)

**Content:**
- Streaming markdown responses (use `Markdown` or `RichLog` widget)
- Visual distinction between:
  - Claude's responses
  - Tool calls / file operations
  - User input
- Input area at bottom

### Workspace Panel (`panel-workspace`)

Tabbed container for Editor, Diff, and Terminal. **Hidden by default.**

**Important**: Hiding is not closing. All panels retain state when hidden:
- Editor: Open files, cursor position, scroll position, unsaved changes
- Diff: Current diff content, scroll position
- Terminal: Active session, command history, output buffer

Use `display: none` for visibility, never destroy/recreate widgets.

**Visibility triggers:**

| Trigger | Result |
|---------|--------|
| Click file in sidebar | Show workspace, focus Editor tab |
| Claude proposes changes | Show workspace, focus Diff tab |
| User presses `` Ctrl+` `` | Show workspace, focus Terminal tab |
| User runs command | Show workspace, focus Terminal tab |
| Close all tabs / Escape | Hide workspace, Claude reclaims space |

**Height**: 60% of center column when visible

#### Editor Tab

- `TextArea` widget with syntax highlighting
- Language detection from file extension
- Theme: Follow terminal theme or user preference

#### Diff Tab

- Side-by-side or unified diff view
- Syntax highlighting for changed content
- Accept/Reject buttons for Claude-proposed changes

#### Terminal Tab

- Proper PTY integration for full terminal emulation
- Or simpler command runner with output display (decide based on complexity)
- Working directory tied to project root

---

## Right Sidebar (`panel-context`)

### Content Area

Switches based on selected bottom tab. Shows one of:
- Jira view (default)
- Problems view
- TODOs view

### Bottom Tab Bar (`context-tabs`)

```
┌──────────────────┐
│ [⚠ 3][✓12][Jira]│
└──────────────────┘
```

Tabs show inline counts that update reactively.

| Tab | Icon | Content |
|-----|------|---------|
| Problems | ⚠ | Linter errors, warnings (count badge) |
| TODOs | ✓ | TODO/FIXME comments from codebase (count badge) |
| Jira | Jira | Output from your CLI tool (default) |

### Jira View

Renders markdown output from your CLI tool. Refreshes on:
- Panel focus
- Manual refresh keybind
- Configurable interval

### Problems View

Aggregates from linters (eslint, ruff, etc.). Shows:
- File path
- Line number
- Severity icon
- Message

Click → opens file in Editor at that line.

### TODOs View

Grep results for `TODO`, `FIXME`, `HACK`, `XXX`. Shows:
- File path
- Line number  
- Comment text

Click → opens file in Editor at that line.

---

## Responsiveness

### CSS Breakpoints

```css
/* Widescreen (default) */
#panel-sidebar { width: 20%; min-width: 25; }
#panel-context { width: 25%; min-width: 30; }
#panel-claude { width: 1fr; }

/* Medium terminals */
@media (width < 120) {
    #panel-sidebar { width: 18%; }
    #panel-context { width: 22%; }
}

/* Narrow terminals (laptop, split screen) */
@media (width < 100) {
    #panel-sidebar { display: none; }
    #panel-context { width: 25%; }
}

@media (width < 80) {
    #panel-context { display: none; }
    #panel-claude { width: 100%; }
}
```

### Compact Mode

Toggle with `Ctrl+Shift+C`. Hides both sidebars, maximizes Claude + workspace.

```css
.compact #panel-sidebar { display: none; }
.compact #panel-context { display: none; }
```

### Fullscreen Mode

Any panel can go fullscreen with `F11` (when focused). Press `Escape` to exit.

```css
.fullscreen {
    dock: top;
    width: 100%;
    height: 100%;
    layer: fullscreen;
}
```

---

## Keybindings

Following VSCode conventions where possible.

### Global

| Action | Binding |
|--------|---------|
| Command palette | `Ctrl+Shift+P` |
| Quick open file | `Ctrl+P` |
| Toggle left sidebar | `Ctrl+B` |
| Toggle right sidebar | `Ctrl+Shift+B` |
| Toggle terminal | `` Ctrl+` `` |
| Toggle compact mode | `Ctrl+Shift+C` |
| Fullscreen focused panel | `F11` |
| Exit fullscreen | `Escape` |

### Navigation

| Action | Binding |
|--------|---------|
| Focus Claude panel | `Ctrl+1` |
| Focus Editor | `Ctrl+2` |
| Focus Terminal | `Ctrl+3` |
| Focus sidebar | `Ctrl+0` |
| Next tab (in tabbed panels) | `Ctrl+Tab` |
| Previous tab | `Ctrl+Shift+Tab` |
| Close current tab/editor | `Ctrl+W` |

### Git

| Action | Binding |
|--------|---------|
| Open Git panel | `Ctrl+Shift+G` |
| Stage file | `Ctrl+Enter` (in git view) |
| Unstage file | `Ctrl+Backspace` (in git view) |

### Search & Problems

| Action | Binding |
|--------|---------|
| Find in file | `Ctrl+F` |
| Find in project | `Ctrl+Shift+F` |
| Go to problems | `Ctrl+Shift+M` |
| Next problem | `F8` |
| Previous problem | `Shift+F8` |

### Editor

| Action | Binding |
|--------|---------|
| Save | `Ctrl+S` |
| Undo | `Ctrl+Z` |
| Redo | `Ctrl+Shift+Z` |
| Go to line | `Ctrl+G` |

---

## Panel Communication

Panels should feel connected, like a normal IDE.

### File Navigation

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

### Problems/TODOs Navigation

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
Line highlighted/scrolled into view
```

### Claude Diff Flow

```
Claude proposes file changes
       │
       ▼
Workspace appears
       │
       ▼
Diff tab focused
       │
       ▼
Changes displayed with Accept/Reject
       │
       ├─► Accept: Apply changes, optionally close diff
       │
       └─► Reject: Discard, close diff
```

### Git File Actions

```
Click file in Git tab
       │
       ▼
Workspace appears
       │
       ▼
Diff tab shows unstaged changes
       │
       ▼
Stage/unstage from diff view
```

---

## Implementation Notes

### Recommended Textual Widgets

| Component | Widget |
|-----------|--------|
| File browser | `DirectoryTree` |
| Claude output | `Markdown` or `RichLog` (for streaming) |
| Editor | `TextArea` (syntax highlighting built-in) |
| Tabbed panels | `TabbedContent`, `TabPane` |
| Panel switching | `ContentSwitcher` |
| Problems/TODOs list | `ListView` with `ListItem` |
| Git graph | `RichLog` or custom canvas widget |
| Command palette | `CommandPalette` (built-in) |

### Background Tasks

Use Textual's `@work` decorator for:
- Git status refresh
- Linter execution  
- TODO scanning
- Jira CLI calls

```python
@work(thread=True)
def refresh_git_status(self) -> None:
    result = subprocess.run(["git", "status", "--porcelain"], ...)
    self.call_from_thread(self.update_git_view, result.stdout)
```

### State Management

**Core principle**: Hiding is not closing. All panels persist state when hidden.

```python
class IDEApp(App):
    current_file: reactive[str | None] = reactive(None)
    workspace_visible: reactive[bool] = reactive(False)
    problem_count: reactive[int] = reactive(0)
    todo_count: reactive[int] = reactive(0)
    compact_mode: reactive[bool] = reactive(False)
```

**Panel visibility pattern** — toggle `display`, don't destroy:

```python
def toggle_workspace(self, visible: bool) -> None:
    workspace = self.query_one("#panel-workspace")
    workspace.display = visible  # Retains all child state
    
    # Adjust Claude panel height
    claude = self.query_one("#panel-claude")
    claude.styles.height = "40%" if visible else "100%"
```

**State to preserve per panel:**

| Panel | Preserved State |
|-------|-----------------|
| Editor | Open files, cursor positions, scroll, unsaved changes, undo history |
| Diff | Current diff content, scroll position, accept/reject state |
| Terminal | PTY session, command history, output buffer, working directory |
| Sidebar tabs | Scroll position, expanded/collapsed sections, selection |
| Context tabs | Scroll position, selected item |
| Git views | Expanded sections, selected files |

---

## Future Considerations

- **Session persistence**: Remember open files, panel sizes, last git state
- **Multiple projects**: Workspace switcher
- **Claude history**: Browse past conversations
- **Custom themes**: User-selectable color schemes
- **Plugin system**: User-defined panels/integrations