/// Snapshots the kernel's live tabs into [ViewPane]s so `pane list` reflects
/// the panes the user actually sees in the GUI (T-219, D-6 parity / D-83).
///
/// Read-at-request-time: no state is mirrored into the IPC [PaneRegistry], so
/// nothing can drift from the live UI. Lives in the kernel (not `lib/src/panes/`)
/// because it reads Flutter-coupled kernel state; it produces the Flutter-free
/// [ViewPane] the pane command serialises.
library;

import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/registry.dart';
import 'package:clide/src/panes/view_pane.dart';

/// Build a [ViewPane] for every tab in every slot the [panels] registry knows,
/// tagging the active tab per slot and whether its slot is currently visible
/// (read from [arrangement]).
List<ViewPane> snapshotViewPanes(PanelRegistry panels, LayoutArrangement arrangement) {
  final out = <ViewPane>[];
  for (final slot in panels.slots) {
    final activeId = panels.activeTabIn(slot.id);
    final visible = arrangement.isVisible(slot.id);
    for (final tab in panels.tabsFor(slot.id)) {
      out.add(ViewPane(id: tab.id, slot: slot.id.value, title: tab.title, active: tab.id == activeId, visible: visible));
    }
  }
  return out;
}
