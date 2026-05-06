# Multitab pane — design

Ticket: T-83
Drives: T-24 (secondary Claude pane UI wiring)
Date: 2026-05-06

## Problem

Some panes need to host multiple, dynamically-spawned views of the
same kind. The first concrete case is the Claude pane: per
[D-41](../../decisions/architecture.md#d-41-claude-panes-one-primary-per-repo-tmux-backed),
each repo has exactly one **primary** Claude pane plus zero or more
**secondary** panes spawned at runtime. The user needs a way to:

- See which Claude sessions are open
- Switch between them
- Spawn a new secondary
- Close a secondary (primary has no close affordance)

The kernel's existing `TabContribution` system addresses a different
need — it lets extensions statically declare which widget shows up in
which **panel slot** (sidebar, workspace, context). It does not
support dynamic tab instances *within* a single contribution.

This design fills that gap with a reusable widget, so future panes
that need the same shape (potentially the editor — see D-48 — or
diff/preview surfaces) can adopt it without reinventing tab strips.

## Non-goals

- Replacing `TabContribution`. Slot-host tabs are static-by-design;
  this widget is for inside-a-tab dynamism.
- Window-level tab management (browser-style "tear off into a window").
- Editor multi-buffer tabs. [D-48](../../decisions/architecture.md#d-48-chrome-budget-no-tabs-no-breadcrumbs-keyboard-first)
  rejected those; revisiting is a separate decision.

## API sketch

```dart
class MultitabPane<T> extends StatefulWidget {
  const MultitabPane({
    required this.controller,
    required this.tabBuilder,
    required this.bodyBuilder,
    this.onCloseRequested,
    this.onAddRequested,
    this.allowReorder = true,
  });

  final MultitabController<T> controller;
  final Widget Function(BuildContext, MultitabEntry<T>) tabBuilder;
  final Widget Function(BuildContext, MultitabEntry<T>) bodyBuilder;
  final void Function(MultitabEntry<T> entry)? onCloseRequested;
  final void Function()? onAddRequested;
  final bool allowReorder;
}

class MultitabEntry<T> {
  final String id;          // stable identity (e.g. "claude.primary")
  final String title;       // display label
  final bool closeable;     // primary tabs set this false
  final bool reorderable;   // primary often pinned to position 0
  final T payload;          // domain object the bodyBuilder renders
}

class MultitabController<T> extends ChangeNotifier {
  List<MultitabEntry<T>> get entries;
  MultitabEntry<T>? get active;

  void add(MultitabEntry<T> entry, {bool activate = true});
  void remove(String id);
  void activate(String id);
  void reorder(String id, int newIndex);
}
```

The widget is a thin shell:
- Renders the tab strip via `ClideTabBar` (or a reorderable variant)
- Calls `bodyBuilder(active)` for the visible content
- Routes user gestures to controller methods or callbacks
- Emits `onCloseRequested` / `onAddRequested` so the host decides
  the actual lifecycle (e.g. Claude pane spawns a new tmux session,
  doesn't just append a UI tab)

The host owns the controller and the payload type. The widget never
touches PTY, IPC, or Claude session naming.

## Rendering

The tab strip lives at the top of the pane chrome. Layout:

```
┌──────────────────────────────────────────────────────┐
│ [primary] [secondary 1] [secondary 2] [+]            │
├──────────────────────────────────────────────────────┤
│                                                      │
│             active tab body                          │
│                                                      │
└──────────────────────────────────────────────────────┘
```

- Active tab: filled background, bright text
- Inactive: muted background, muted text
- Close glyph (×) appears on hover for `closeable` tabs
- `+` button at the end if `onAddRequested` is set
- Drag-to-reorder respects `reorderable`; non-reorderable tabs
  (primary) are pinned to position 0 and other tabs cannot be
  dropped before them

## Interaction

- **Click a tab** → activate
- **Click ×** → call `onCloseRequested(entry)`; host decides whether
  to confirm, kill the underlying session, etc.
- **Drag-and-drop** → call `controller.reorder(id, newIndex)` after
  the gesture completes; controller enforces pinned positions
- **Click +** → call `onAddRequested()`; host creates the new entry
  and adds it via `controller.add(...)`
- **Keyboard**: `⌘1`–`⌘9` jump to tab N; `⌘W` close active (skipped
  for non-closeable); `⌘⇧[` / `⌘⇧]` cycle prev/next

## Persistence

Out of scope for the widget. Hosts that want to persist tab order or
which tabs were open across sessions read/write through their own
settings layer and seed the controller on init.

## Claude pane integration (T-24)

```
ClaudePane (host)
└── MultitabPane<ClaudeSessionRef>(
      controller: claudeTabsController,
      tabBuilder: (ctx, e) => Text(e.title),
      bodyBuilder: (ctx, e) => ClaudePaneBody(session: e.payload),
      onAddRequested: () => kernel.claude.spawnSecondary(),
      onCloseRequested: (e) => kernel.claude.closeSecondary(e.payload),
    )
```

`ClaudeSessionRef` carries the tmux session name + isPrimary. The
controller is seeded with `[primary]` on boot; secondaries get
appended as the user clicks `+`. Closing a secondary triggers
`pane.close` IPC and removes the entry; closing the primary is not
exposed (`closeable: false`).

## What ships in this ticket

T-83 delivers:
1. `MultitabPane` widget + `MultitabController` + `MultitabEntry`
   under `lib/widgets/src/`
2. Unit tests for controller invariants (pinned positions, active
   selection survives close, reorder bounds)
3. Widget tests for the strip (selection, close hover, add button,
   drag-reorder)
4. This design doc

T-24 picks up after and wires the Claude pane to it.

## Open questions

- **Q: Where does keyboard handling live?** Host or widget?
  Recommendation: widget owns `⌘W` / `⌘1`–`⌘9` / cycle; host wires
  them via the existing kernel commands surface. Avoids each host
  reinventing the same shortcuts.

  **Nesting caveat:** the widget composes (a Claude tab can host
  its own `MultitabPane<EditorBuffer>` etc.). Shortcut handling
  must be scoped to the focus subtree, not registered globally —
  otherwise the outermost pane consumes `⌘W` even when the user
  is typing in a nested tab. Implementation: wrap shortcuts in a
  `Shortcuts` / `Actions` widget inside the pane's `Focus` scope
  so the innermost focused pane wins via Flutter's normal
  shortcut-resolution chain.

- **Q: Tab overflow** when many secondaries open? Recommendation:
  start with horizontal scroll; revisit if it becomes a problem.

- **Q: Tab-strip visual style** — match `ClideTabBar` exactly, or
  introduce a denser variant for inside-pane use? Recommendation:
  reuse `ClideTabBar` initially; spin off a `ClideTabBar.dense`
  variant only if visual hierarchy issues emerge.
