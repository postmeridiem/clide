import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Key combo: modifiers + primary key. Canonicalized on construction
/// (modifiers sorted, lowercased) so equality works for lookup keys.
@immutable
class Keybinding {
  Keybinding({required Set<String> modifiers, required String key})
      : modifiers = _canonModifiers(modifiers),
        key = key.toLowerCase();

  final List<String> modifiers;
  final String key;

  static List<String> _canonModifiers(Set<String> m) {
    final normalized = m.map((s) => s.toLowerCase()).toSet().toList()..sort();
    return List.unmodifiable(normalized);
  }

  /// Parse "ctrl+shift+g", "cmd+k", "alt+f4".
  static Keybinding parse(String spec) {
    if (spec.trim().isEmpty) {
      throw ArgumentError('empty keybinding');
    }
    final parts = spec.split('+').map((s) => s.trim()).toList();
    final key = parts.removeLast();
    if (key.isEmpty) {
      throw ArgumentError('keybinding is missing a key: "$spec"');
    }
    return Keybinding(modifiers: parts.toSet(), key: key);
  }

  String get canonical {
    if (modifiers.isEmpty) return key;
    return '${modifiers.join('+')}+$key';
  }

  @override
  bool operator ==(Object other) => other is Keybinding && other.key == key && listEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(modifiers));

  @override
  String toString() => 'Keybinding($canonical)';
}

class KeybindingResolver {
  final Map<Keybinding, String> _bindings = {};

  void bind(Keybinding b, String commandId) {
    _bindings[b] = commandId;
  }

  void unbind(Keybinding b) {
    _bindings.remove(b);
  }

  String? commandFor(Keybinding b) => _bindings[b];

  Iterable<MapEntry<Keybinding, String>> get entries => _bindings.entries;

  /// Map a Flutter [KeyEvent] to a [Keybinding] suitable for lookup.
  static Keybinding? fromKeyEvent(KeyEvent event, HardwareKeyboard keyboard) {
    if (event is! KeyDownEvent) return null;
    final label = event.logicalKey.keyLabel;
    if (label.isEmpty) return null;
    final mods = <String>{};
    if (keyboard.isControlPressed) mods.add('ctrl');
    if (keyboard.isShiftPressed) mods.add('shift');
    if (keyboard.isAltPressed) mods.add('alt');
    if (keyboard.isMetaPressed) mods.add('cmd');
    return Keybinding(modifiers: mods, key: label);
  }
}
