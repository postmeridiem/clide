/// Layout-independent representation of a single keystroke.
///
/// The consultant's note (T-110) flagged the old `KeybindingResolver`
/// for keying off `LogicalKeyboardKey.keyLabel`, which is locale-aware
/// (US-QWERTY `Ctrl+/` differs from AZERTY `Ctrl+:`). We key off
/// `LogicalKeyboardKey.keyId` instead — a stable u32 that survives
/// layout changes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One of the four POSIX-style modifier keys. Order is the canonical
/// presentation order in YAML and toString output.
enum KeyModifier {
  ctrl,
  alt,
  shift,
  meta;

  /// Lowercase short form used in YAML (`ctrl`, `alt`, `shift`, `meta`).
  String get yaml => name;

  /// Display string used in palette + tooltip hints.
  String get display => switch (this) {
    KeyModifier.ctrl => 'Ctrl',
    KeyModifier.alt => 'Alt',
    KeyModifier.shift => 'Shift',
    KeyModifier.meta => 'Cmd',
  };
}

/// A modifier-set + a single key, identified by layout-independent
/// `LogicalKeyboardKey.keyId`. Canonicalised on construction
/// (modifiers sorted by enum order) so equality + hashing work for
/// lookup-keying.
@immutable
class KeyChord {
  factory KeyChord({Set<KeyModifier> modifiers = const {}, required LogicalKeyboardKey key}) {
    final sorted = modifiers.toList()..sort((a, b) => a.index.compareTo(b.index));
    return KeyChord._(List.unmodifiable(sorted), key);
  }

  const KeyChord._(this.modifiers, this.key);

  /// A bare modifier press as a chord — no modifier set, the modifier key
  /// itself as the base key. Lets a preset bind `shift` (and a double-tap
  /// as the sequence `shift shift`, e.g. JetBrains "Search Everywhere").
  /// (T-341)
  factory KeyChord.bareModifier(KeyModifier m) => KeyChord(key: _modifierKey[m]!);

  final List<KeyModifier> modifiers;
  final LogicalKeyboardKey key;

  /// The [KeyModifier] a bare modifier-key press maps to (left/right/generic
  /// variants collapse to one), or null if [logical] isn't a modifier key.
  /// Used by the global handler's double-tap detector. (T-341)
  static KeyModifier? modifierForLogicalKey(LogicalKeyboardKey logical) {
    if (logical == LogicalKeyboardKey.control || logical == LogicalKeyboardKey.controlLeft || logical == LogicalKeyboardKey.controlRight) {
      return KeyModifier.ctrl;
    }
    if (logical == LogicalKeyboardKey.alt || logical == LogicalKeyboardKey.altLeft || logical == LogicalKeyboardKey.altRight) {
      return KeyModifier.alt;
    }
    if (logical == LogicalKeyboardKey.shift || logical == LogicalKeyboardKey.shiftLeft || logical == LogicalKeyboardKey.shiftRight) {
      return KeyModifier.shift;
    }
    if (logical == LogicalKeyboardKey.meta || logical == LogicalKeyboardKey.metaLeft || logical == LogicalKeyboardKey.metaRight) {
      return KeyModifier.meta;
    }
    return null;
  }

  /// Build from a Flutter [KeyEvent]. Returns null for non-down events
  /// or events whose logical key has no meaningful id (e.g. a bare
  /// modifier press in isolation).
  static KeyChord? fromKeyEvent(KeyEvent event, HardwareKeyboard kb) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final logical = event.logicalKey;
    // Bare modifier presses don't form a chord on their own.
    if (_isBareModifier(logical)) return null;
    final mods = <KeyModifier>{
      if (kb.isControlPressed) KeyModifier.ctrl,
      if (kb.isAltPressed) KeyModifier.alt,
      if (kb.isShiftPressed) KeyModifier.shift,
      if (kb.isMetaPressed) KeyModifier.meta,
    };
    return KeyChord(modifiers: mods, key: logical);
  }

  /// Parse a YAML chord spec like `ctrl+shift+p`, `cmd+enter`, `escape`.
  /// Whitespace tolerated. Throws [FormatException] on unknown tokens
  /// or empty input.
  static KeyChord parse(String spec) {
    final trimmed = spec.trim();
    if (trimmed.isEmpty) throw const FormatException('empty key chord');
    final parts = trimmed.split('+').map((s) => s.trim()).toList();
    final keyName = parts.removeLast();
    if (keyName.isEmpty) throw FormatException('missing key in chord: "$spec"');
    final mods = <KeyModifier>{};
    for (final m in parts) {
      final mod = _modByName(m);
      if (mod == null) throw FormatException('unknown modifier "$m" in chord: "$spec"');
      mods.add(mod);
    }
    final key = _keyByName(keyName);
    if (key == null) throw FormatException('unknown key "$keyName" in chord: "$spec"');
    return KeyChord(modifiers: mods, key: key);
  }

  /// Parse a sequence spec — one or more chords separated by whitespace,
  /// e.g. `d d`, `g g`, `ctrl+k ctrl+s`. A single chord yields a
  /// one-element list. Whitespace means "then" (D-82); the space *key*
  /// is always spelled `space`, so a literal space never collides.
  /// Throws [FormatException] on empty input or an unknown chord.
  static List<KeyChord> parseSequence(String spec) {
    final parts = spec.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) throw FormatException('empty key sequence: "$spec"');
    return [for (final p in parts) KeyChord.parse(p)];
  }

  /// The digit 0–9 if this is a bare digit key with no modifiers, else
  /// null. Used to capture Vim repeat-count prefixes (`5j`).
  int? get digit {
    if (modifiers.isNotEmpty) return null;
    for (var d = 0; d <= 9; d++) {
      if (key == _digitKeys[d]) return d;
    }
    return null;
  }

  /// Canonical YAML form: `ctrl+shift+p`.
  String get canonical {
    final modPart = modifiers.map((m) => m.yaml).join('+');
    final keyPart = _keyName(key);
    return modPart.isEmpty ? keyPart : '$modPart+$keyPart';
  }

  /// Display form for UI hints: `Ctrl+Shift+P`.
  String get display {
    final modPart = modifiers.map((m) => m.display).join('+');
    final keyPart = _keyName(key).toUpperCase();
    return modPart.isEmpty ? keyPart : '$modPart+$keyPart';
  }

  @override
  bool operator ==(Object other) => other is KeyChord && other.key == key && listEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(modifiers));

  @override
  String toString() => 'KeyChord($canonical)';
}

bool _isBareModifier(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.control ||
    k == LogicalKeyboardKey.controlLeft ||
    k == LogicalKeyboardKey.controlRight ||
    k == LogicalKeyboardKey.alt ||
    k == LogicalKeyboardKey.altLeft ||
    k == LogicalKeyboardKey.altRight ||
    k == LogicalKeyboardKey.shift ||
    k == LogicalKeyboardKey.shiftLeft ||
    k == LogicalKeyboardKey.shiftRight ||
    k == LogicalKeyboardKey.meta ||
    k == LogicalKeyboardKey.metaLeft ||
    k == LogicalKeyboardKey.metaRight ||
    k == LogicalKeyboardKey.fn;

KeyModifier? _modByName(String name) {
  switch (name.toLowerCase()) {
    case 'ctrl':
    case 'control':
      return KeyModifier.ctrl;
    case 'alt':
    case 'option':
      return KeyModifier.alt;
    case 'shift':
      return KeyModifier.shift;
    case 'meta':
    case 'cmd':
    case 'command':
    case 'super':
    case 'win':
      return KeyModifier.meta;
  }
  return null;
}

// -- Key name <-> LogicalKeyboardKey ----------------------------------------
//
// We map YAML names to LogicalKeyboardKey instances. The map covers
// every key a binding can plausibly want; unknown names throw on parse.

const Map<String, LogicalKeyboardKey> _byName = {
  // Letters
  'a': LogicalKeyboardKey.keyA, 'b': LogicalKeyboardKey.keyB, 'c': LogicalKeyboardKey.keyC,
  'd': LogicalKeyboardKey.keyD, 'e': LogicalKeyboardKey.keyE, 'f': LogicalKeyboardKey.keyF,
  'g': LogicalKeyboardKey.keyG, 'h': LogicalKeyboardKey.keyH, 'i': LogicalKeyboardKey.keyI,
  'j': LogicalKeyboardKey.keyJ, 'k': LogicalKeyboardKey.keyK, 'l': LogicalKeyboardKey.keyL,
  'm': LogicalKeyboardKey.keyM, 'n': LogicalKeyboardKey.keyN, 'o': LogicalKeyboardKey.keyO,
  'p': LogicalKeyboardKey.keyP, 'q': LogicalKeyboardKey.keyQ, 'r': LogicalKeyboardKey.keyR,
  's': LogicalKeyboardKey.keyS, 't': LogicalKeyboardKey.keyT, 'u': LogicalKeyboardKey.keyU,
  'v': LogicalKeyboardKey.keyV, 'w': LogicalKeyboardKey.keyW, 'x': LogicalKeyboardKey.keyX,
  'y': LogicalKeyboardKey.keyY, 'z': LogicalKeyboardKey.keyZ,
  // Digits
  '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1, '2': LogicalKeyboardKey.digit2,
  '3': LogicalKeyboardKey.digit3, '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7, '8': LogicalKeyboardKey.digit8,
  '9': LogicalKeyboardKey.digit9,
  // Function keys
  'f1': LogicalKeyboardKey.f1, 'f2': LogicalKeyboardKey.f2, 'f3': LogicalKeyboardKey.f3,
  'f4': LogicalKeyboardKey.f4, 'f5': LogicalKeyboardKey.f5, 'f6': LogicalKeyboardKey.f6,
  'f7': LogicalKeyboardKey.f7, 'f8': LogicalKeyboardKey.f8, 'f9': LogicalKeyboardKey.f9,
  'f10': LogicalKeyboardKey.f10, 'f11': LogicalKeyboardKey.f11, 'f12': LogicalKeyboardKey.f12,
  // Arrows
  'left': LogicalKeyboardKey.arrowLeft,
  'right': LogicalKeyboardKey.arrowRight,
  'up': LogicalKeyboardKey.arrowUp,
  'down': LogicalKeyboardKey.arrowDown,
  // Common control keys
  'enter': LogicalKeyboardKey.enter,
  'return': LogicalKeyboardKey.enter,
  'escape': LogicalKeyboardKey.escape,
  'esc': LogicalKeyboardKey.escape,
  'tab': LogicalKeyboardKey.tab,
  'space': LogicalKeyboardKey.space,
  'backspace': LogicalKeyboardKey.backspace,
  'delete': LogicalKeyboardKey.delete,
  'home': LogicalKeyboardKey.home,
  'end': LogicalKeyboardKey.end,
  'pageup': LogicalKeyboardKey.pageUp,
  'pagedown': LogicalKeyboardKey.pageDown,
  'insert': LogicalKeyboardKey.insert,
  // Punctuation (US-QWERTY positions; preset authors can rely on these names).
  'minus': LogicalKeyboardKey.minus, '-': LogicalKeyboardKey.minus,
  'equal': LogicalKeyboardKey.equal, '=': LogicalKeyboardKey.equal,
  'comma': LogicalKeyboardKey.comma, ',': LogicalKeyboardKey.comma,
  'period': LogicalKeyboardKey.period, '.': LogicalKeyboardKey.period,
  'slash': LogicalKeyboardKey.slash, '/': LogicalKeyboardKey.slash,
  'backslash': LogicalKeyboardKey.backslash, r'\\': LogicalKeyboardKey.backslash,
  'semicolon': LogicalKeyboardKey.semicolon, ';': LogicalKeyboardKey.semicolon,
  'quote': LogicalKeyboardKey.quote, "'": LogicalKeyboardKey.quote,
  'bracketLeft': LogicalKeyboardKey.bracketLeft, '[': LogicalKeyboardKey.bracketLeft,
  'bracketRight': LogicalKeyboardKey.bracketRight, ']': LogicalKeyboardKey.bracketRight,
  'backquote': LogicalKeyboardKey.backquote, '`': LogicalKeyboardKey.backquote,
};

const List<LogicalKeyboardKey> _digitKeys = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

/// Canonical logical key for each bare modifier (left/right variants
/// collapse to the side-agnostic key). Drives [KeyChord.bareModifier] and
/// the `shift` / `ctrl` / `alt` / `meta` base-key names. (T-341)
const Map<KeyModifier, LogicalKeyboardKey> _modifierKey = {
  KeyModifier.ctrl: LogicalKeyboardKey.control,
  KeyModifier.alt: LogicalKeyboardKey.alt,
  KeyModifier.shift: LogicalKeyboardKey.shift,
  KeyModifier.meta: LogicalKeyboardKey.meta,
};

LogicalKeyboardKey? _keyByName(String name) {
  final n = name.toLowerCase();
  // A bare modifier name as the base key (`shift`, `ctrl`, `cmd`, …) — so
  // `parseSequence('shift shift')` yields a double-tap binding. (T-341)
  final mod = _modByName(n);
  if (mod != null) return _modifierKey[mod];
  return _byName[n];
}

String _keyName(LogicalKeyboardKey key) {
  // Bare-modifier keys reverse to their canonical modifier name.
  for (final entry in _modifierKey.entries) {
    if (entry.value == key) return entry.key.yaml;
  }
  // Reverse lookup; prefer the canonical (first) name for each key.
  for (final entry in _byName.entries) {
    if (entry.value == key) return entry.key;
  }
  // Fallback: use the debugName-like representation.
  return key.keyLabel.isNotEmpty ? key.keyLabel.toLowerCase() : 'key(0x${key.keyId.toRadixString(16)})';
}
