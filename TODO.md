# TODO

<!--
  Clide Integration: This file is parsed by Clide's TODO panel.

  Format:
  - Use ## for sections and ### for subsections
  - Use markdown checkboxes: - [ ] for open items, - [x] for completed
  - Items appear in the TODOs panel grouped by section
  - Click an item in Clide to jump to this file at that line

  For AI agents: Add new items under the appropriate section using the
  checkbox format. Mark items as done with [x] when completed.
-->

Long-term open items for Clide development.

## Core Features

### Claude Integration
- [ ] Streaming markdown responses in Claude panel
- [ ] Visual distinction between Claude responses, tool calls, and user input
- [ ] Claude history browser (past conversations)
- [ ] Claude diff flow (propose changes → diff tab → accept/reject)

### Editor
- [ ] Multi-file tab support with state preservation
- [ ] Cursor position and scroll position persistence
- [ ] Undo/redo history preservation when hiding panel
- [ ] Find in file (`Ctrl+F`)
- [ ] Go to line (`Ctrl+G`)

### Diff Panel
- [ ] Side-by-side diff view
- [ ] Unified diff view toggle
- [ ] Accept/Reject buttons for Claude-proposed changes
- [ ] Syntax highlighting in diff content

### Terminal
- [ ] Full PTY integration for terminal emulation
- [ ] Command history preservation
- [ ] Output buffer retention when hiding

### Git Integration
- [ ] Stage/unstage files from Git tab
- [ ] Discard changes context menu
- [ ] Git graph visualization (Tree tab)
- [ ] Branch popout with checkout/new branch actions

## Context Panel (Right Sidebar)

### Problems View
- [ ] Linter integration (ruff, eslint, etc.)
- [ ] Click to navigate to file:line
- [ ] Reactive problem count badge

### TODOs View
- [ ] Scan for TODO/FIXME/HACK/XXX comments
- [ ] Click to navigate to file:line
- [ ] Reactive count badge

### Jira View
- [ ] Render Jira CLI markdown output
- [ ] Auto-refresh on panel focus
- [ ] Configurable refresh interval

## UI/UX

### Responsiveness
- [ ] CSS breakpoints for different terminal widths
- [ ] Auto-hide sidebars on narrow terminals (<100 cols)
- [ ] Compact mode toggle (`Alt+C`)

### Fullscreen Mode
- [ ] Any panel can go fullscreen (`F11`)
- [ ] Exit fullscreen with `Escape`

### Command Palette
- [ ] Implement command palette (`Alt+P`)
- [ ] Quick open file (`Alt+O`)

## State Management

### Session Persistence
- [ ] Remember open files across sessions
- [ ] Persist panel sizes and layout
- [ ] Save last git state
- [ ] Remember expanded/collapsed sections

### Multiple Projects
- [ ] Workspace switcher
- [ ] Recent projects list

## Plugin System

- [ ] User-defined panels via pluggy
- [ ] Custom integrations support
- [ ] Extension API documentation

## Testing

- [ ] Snapshot tests for all panels
- [ ] Integration tests for panel communication
- [ ] Unit tests for controllers
- [ ] Unit tests for services

## Documentation

- [ ] User guide
- [ ] Plugin development guide
- [ ] Architecture documentation updates

## Build & Distribution

- [ ] PyInstaller builds for macOS
- [ ] PyInstaller builds for Linux
- [ ] CI/CD pipeline with Gitea Actions
