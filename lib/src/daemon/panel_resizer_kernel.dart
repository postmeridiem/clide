/// Kernel-side [PanelResizer] that drives [LayoutArrangement] for
/// the `panel.resize` IPC verb (T-119).
///
/// Lives in `lib/src/daemon/` next to the other dispatcher wiring,
/// not `lib/kernel/`, because it bridges the Flutter-bound kernel
/// state into the Flutter-free `panel_commands.dart` surface. Same
/// rationale as the `_BusEventSink` in main.dart: the daemon layer
/// owns the adapter, the kernel layer owns the data.
library;

import 'package:clide/kernel/src/panels/arrangement.dart';
import 'package:clide/kernel/src/panels/drag_resize.dart' show bumpedSlotSize;
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:clide/src/daemon/panel_commands.dart';

class ArrangementPanelResizer implements PanelResizer {
  ArrangementPanelResizer(this._a);

  final LayoutArrangement _a;

  @override
  bool setSlotSize(String slot, double size) {
    final id = SlotId(slot);
    if (_a.sizeOf(id) == null) return false;
    _a.setSize(id, size);
    return true;
  }

  @override
  bool bumpSlotSize(String slot, double rawDelta) {
    final id = SlotId(slot);
    final current = _a.sizeOf(id);
    if (current == null) return false;
    _a.setSize(id, bumpedSlotSize(slot: id, current: current, rawDelta: rawDelta));
    return true;
  }

  @override
  void setEditorRatio(double ratio) => _a.setEditorRatio(ratio);

  @override
  void bumpEditorRatio(double delta) => _a.setEditorRatio(_a.editorRatio + delta);

  @override
  double? currentSlotSize(String slot) => _a.sizeOf(SlotId(slot));

  @override
  double get currentEditorRatio => _a.editorRatio;
}
