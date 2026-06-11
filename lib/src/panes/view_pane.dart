/// A non-PTY pane the user sees in the GUI — a kernel tab (Claude, Files,
/// Editor, a viewer) surfaced so `pane list` reflects the live workspace,
/// not only PTY-spawned panes (T-219, D-6 parity / D-83).
///
/// The PTY-backed [Pane] can't represent these: a tab has no child process.
/// Rather than mirror state into [PaneRegistry] (and risk it drifting from
/// the live UI), the kernel snapshots its `PanelRegistry` into these value
/// objects at request time — `pane.list` reads them through an injected
/// source. Pure data, Flutter-free, so it serialises on the IPC wire and
/// stays usable from `dart test`.
library;

class ViewPane {
  const ViewPane({required this.id, required this.slot, required this.title, required this.active, required this.visible});

  /// Stable contribution id (e.g. `claude`, `files`, `editor`) — the same id
  /// `pane.focus` would target.
  final String id;

  /// The slot the tab lives in (`sidebar` / `workspace` / `context`).
  final String slot;

  /// Display title the user sees on the tab.
  final String title;

  /// Whether this is the active (front) tab in its slot — the focus state
  /// the acceptance asks for.
  final bool active;

  /// Whether the tab's slot is currently visible (not collapsed/hidden).
  final bool visible;

  Map<String, Object?> toJson() => {'id': id, 'kind': 'view', 'slot': slot, 'title': title, 'active': active, 'visible': visible, 'source': 'ui'};
}
