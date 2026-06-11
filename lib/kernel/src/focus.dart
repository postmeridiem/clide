import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/widgets.dart';

/// Tracks the currently focused contribution (tab id + slot) and
/// hosts a registry of per-slot [FocusScopeNode]s for panel-to-panel
/// focus traversal.
///
/// Backs `clide active` (extensions read activeSlot / activeContributionId)
/// and the `FocusNextPanelIntent` / `FocusPreviousPanelIntent` actions
/// the keymap dispatches on F6 / Shift+F6.
class FocusTracker extends ChangeNotifier {
  SlotId? _slot;
  String? _contributionId;
  Widget? _activeStatusWidget;
  final Map<SlotId, FocusScopeNode> _scopes = {};

  /// Static order panels cycle through. Matches the visual left-to-right
  /// of the three-column layout (sidebar → workspace → context); the
  /// statusbar / toolbar aren't included because they don't host
  /// keyboard-active content.
  static const List<SlotId> traversalOrder = [Slots.sidebar, Slots.workspace, Slots.contextPanel];

  SlotId? get activeSlot => _slot;
  String? get activeContributionId => _contributionId;

  /// The focused pane's status-bar widget (T-150). The status bar renders
  /// this; it's null when the focused contribution has no status, so the
  /// bar clears automatically on focus change.
  Widget? get activeStatusWidget => _activeStatusWidget;

  void setActive({required SlotId slot, required String contributionId}) {
    if (_slot == slot && _contributionId == contributionId) return;
    _slot = slot;
    _contributionId = contributionId;
    // Focus moved — the previous pane's status no longer applies. The
    // newly-focused pane re-conveys its own via [setStatusWidget].
    _activeStatusWidget = null;
    notifyListeners();
  }

  /// Convey [widget] (or null) as the status-bar content for
  /// [contributionId]. Applied only while that contribution is focused —
  /// a background pane's update is ignored, so it keeps its content
  /// locally and re-conveys when it regains focus (T-150).
  void setStatusWidget(String contributionId, Widget? widget) {
    if (contributionId != _contributionId) return;
    if (identical(_activeStatusWidget, widget)) return;
    _activeStatusWidget = widget;
    notifyListeners();
  }

  void clear() {
    if (_slot == null && _contributionId == null && _activeStatusWidget == null) return;
    _slot = null;
    _contributionId = null;
    _activeStatusWidget = null;
    notifyListeners();
  }

  /// SlotHost calls this in initState. Replaces any prior registration
  /// for the same slot (handles hot-reload + slot rebuild).
  void registerSlotScope(SlotId slot, FocusScopeNode scope) {
    _scopes[slot] = scope;
  }

  /// SlotHost calls this in dispose. No-op if a newer scope already
  /// took the slot.
  void unregisterSlotScope(SlotId slot, FocusScopeNode scope) {
    if (identical(_scopes[slot], scope)) {
      _scopes.remove(slot);
    }
  }

  /// Request focus on [slot]'s registered scope. No-op when the slot
  /// has no registered scope (panel not mounted, layout doesn't
  /// include it, etc.).
  void focusSlot(SlotId slot) {
    final scope = _scopes[slot];
    if (scope == null) return;
    scope.requestFocus();
  }

  /// Move focus to the next slot in [traversalOrder], wrapping at the
  /// end. No-op when fewer than two slots are registered.
  void focusNextSlot() => _cycleSlot(1);

  /// Move focus to the previous slot, wrapping at the start.
  void focusPreviousSlot() => _cycleSlot(-1);

  void _cycleSlot(int delta) {
    final registered = traversalOrder.where(_scopes.containsKey).toList();
    if (registered.length < 2) return;
    final from = registered.indexOf(_slot ?? registered.first);
    final start = from < 0 ? 0 : from;
    final next = (start + delta) % registered.length;
    final wrapped = next < 0 ? next + registered.length : next;
    focusSlot(registered[wrapped]);
  }
}
