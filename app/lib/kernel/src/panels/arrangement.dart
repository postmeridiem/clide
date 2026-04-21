import 'package:clide_app/extension/src/contribution.dart';
import 'package:clide_app/kernel/src/panels/registry.dart';
import 'package:clide_app/kernel/src/panels/slot_id.dart';
import 'package:flutter/foundation.dart';

/// Current, runtime layout state: which slots are visible, at what size,
/// and in what positions. Persisted through `settings`.
///
/// The registry knows which slots *exist* and which contributions are
/// mounted. The arrangement knows which slots are *currently* shown and
/// how big they are — user-modifiable via drag-resize.
class LayoutArrangement extends ChangeNotifier {
  LayoutArrangement();

  final Map<SlotId, _SlotState> _state = {};

  void applyPreset(LayoutPresetContribution preset) {
    _state.clear();
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

  void setSize(SlotId id, double size) {
    final s = _state[id];
    if (s == null) return;
    final clamped =
        size.clamp(s.minSize ?? 0, s.maxSize ?? double.infinity).toDouble();
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

  /// Convenience for the default-layout extension: register all slots
  /// it provides into a [PanelRegistry] with defaults from this preset.
  void registerSlotsInto(
    PanelRegistry registry,
    LayoutPresetContribution preset,
  ) {
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
  });

  final SlotPosition position;
  final double? size;
  final double? minSize;
  final double? maxSize;
  final bool visible;

  _SlotState copyWith({
    SlotPosition? position,
    double? size,
    double? minSize,
    double? maxSize,
    bool? visible,
  }) {
    return _SlotState(
      position: position ?? this.position,
      size: size ?? this.size,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      visible: visible ?? this.visible,
    );
  }
}
