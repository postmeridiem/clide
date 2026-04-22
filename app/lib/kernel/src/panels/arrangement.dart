import 'package:clide_app/extension/src/contribution.dart';
import 'package:clide_app/kernel/src/panels/registry.dart';
import 'package:clide_app/kernel/src/panels/slot_id.dart';
import 'package:flutter/foundation.dart';

class LayoutArrangement extends ChangeNotifier {
  LayoutArrangement();

  final Map<SlotId, _SlotState> _state = {};

  Map<SlotId, _SlotState>? _focusModeSnapshot;
  SlotId? _focusModeSlot;

  bool _editorOpen = false;
  double _editorRatio = 0.35;

  void applyPreset(LayoutPresetContribution preset) {
    _state.clear();
    _focusModeSnapshot = null;
    _focusModeSlot = null;
    for (final slot in preset.slots) {
      _state[slot.slot] = _SlotState(
        position: slot.position,
        size: slot.defaultSize,
        minSize: slot.minSize,
        maxSize: slot.maxSize,
        visible: slot.visible,
      );
    }
    notifyListeners();
  }

  Iterable<SlotId> get slotsInOrder => _state.keys;

  SlotPosition? positionOf(SlotId id) => _state[id]?.position;
  double? sizeOf(SlotId id) => _state[id]?.size;
  double? minSizeOf(SlotId id) => _state[id]?.minSize;
  double? maxSizeOf(SlotId id) => _state[id]?.maxSize;
  bool isVisible(SlotId id) => _state[id]?.visible ?? false;
  bool isCollapsed(SlotId id) => _state[id]?.collapsed ?? false;
  bool get isInFocusMode => _focusModeSlot != null;
  SlotId? get focusModeSlot => _focusModeSlot;
  bool get editorOpen => _editorOpen;
  double get editorRatio => _editorRatio;

  void setSize(SlotId id, double size) {
    final s = _state[id];
    if (s == null) return;
    final clamped = size.clamp(s.minSize ?? 0, s.maxSize ?? double.infinity).toDouble();
    if (s.size == clamped) return;
    _state[id] = s.copyWith(size: clamped);
    notifyListeners();
  }

  void setVisible(SlotId id, bool visible) {
    final s = _state[id];
    if (s == null || s.visible == visible) return;
    _state[id] = s.copyWith(visible: visible);
    notifyListeners();
  }

  void setCollapsed(SlotId id, bool collapsed) {
    final s = _state[id];
    if (s == null || s.collapsed == collapsed) return;
    _state[id] = s.copyWith(collapsed: collapsed);
    notifyListeners();
  }

  void toggleCollapsed(SlotId id) {
    final s = _state[id];
    if (s == null) return;
    _state[id] = s.copyWith(collapsed: !s.collapsed);
    notifyListeners();
  }

  void enterFocusMode(SlotId slot) {
    if (_focusModeSlot != null) return;
    _focusModeSnapshot = {for (final e in _state.entries) e.key: e.value};
    _focusModeSlot = slot;
    for (final id in _state.keys) {
      if (id == slot) {
        _state[id] = _state[id]!.copyWith(visible: true, collapsed: false);
      } else {
        _state[id] = _state[id]!.copyWith(visible: false);
      }
    }
    notifyListeners();
  }

  void exitFocusMode() {
    final snap = _focusModeSnapshot;
    if (snap == null) return;
    _state.clear();
    _state.addAll(snap);
    _focusModeSnapshot = null;
    _focusModeSlot = null;
    notifyListeners();
  }

  void toggleFocusMode(SlotId slot) {
    if (_focusModeSlot != null) {
      exitFocusMode();
    } else {
      enterFocusMode(slot);
    }
  }

  void openEditor() {
    if (_editorOpen) return;
    _editorOpen = true;
    notifyListeners();
  }

  void closeEditor() {
    if (!_editorOpen) return;
    _editorOpen = false;
    notifyListeners();
  }

  void toggleEditor() {
    _editorOpen = !_editorOpen;
    notifyListeners();
  }

  void setEditorRatio(double ratio) {
    final clamped = ratio.clamp(0.15, 0.70);
    if (_editorRatio == clamped) return;
    _editorRatio = clamped;
    notifyListeners();
  }

  void registerSlotsInto(PanelRegistry registry, LayoutPresetContribution preset) {
    for (final slot in preset.slots) {
      registry.registerSlot(SlotDefinition(
        id: slot.slot,
        position: slot.position,
        defaultSize: slot.defaultSize,
        minSize: slot.minSize,
        maxSize: slot.maxSize,
      ));
    }
  }
}

class _SlotState {
  const _SlotState({
    required this.position,
    this.size,
    this.minSize,
    this.maxSize,
    this.visible = true,
    this.collapsed = false,
  });

  final SlotPosition position;
  final double? size;
  final double? minSize;
  final double? maxSize;
  final bool visible;
  final bool collapsed;

  _SlotState copyWith({
    SlotPosition? position,
    double? size,
    double? minSize,
    double? maxSize,
    bool? visible,
    bool? collapsed,
  }) {
    return _SlotState(
      position: position ?? this.position,
      size: size ?? this.size,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      visible: visible ?? this.visible,
      collapsed: collapsed ?? this.collapsed,
    );
  }
}
