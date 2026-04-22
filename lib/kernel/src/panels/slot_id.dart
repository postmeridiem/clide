import 'package:flutter/foundation.dart';

@immutable
class SlotId {
  const SlotId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is SlotId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SlotId($value)';
}

/// Kernel-reserved slot ids. Extensions can declare new slots; these are
/// the ones the default layout presets and the kernel services target.
abstract class Slots {
  static const sidebar = SlotId('sidebar');
  static const workspace = SlotId('workspace');
  static const contextPanel = SlotId('context');
  static const statusbar = SlotId('statusbar');
  static const toolbar = SlotId('toolbar.main');
  static const commandPalette = SlotId('commandPalette');
  static const tray = SlotId('tray');
  static const fullscreen = SlotId('fullscreen');
}

enum SlotPosition { left, right, top, bottom, center, float, popout }
