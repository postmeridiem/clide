/// In-memory representation of a layered keymap.
///
/// A [Keymap] is built from one or more [KeymapLayer]s (preset →
/// user-file overlay → settings overlay). Each layer contributes
/// [KeymapBinding]s; later layers replace earlier bindings with the
/// same (chord, when-clause) tuple.
///
/// At resolve time, the [Keymap] walks the layered list once per
/// (chord, scope) and returns the [Intent] bound by the highest-
/// precedence matching layer.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Intent;
import 'package:yaml/yaml.dart';

import 'intents.dart';
import 'key_chord.dart';
import 'when_clause.dart';

/// One row in a layer: a chord, an optional when-clause, and the
/// intent to fire when the chord matches and the when-clause is true.
@immutable
class KeymapBinding {
  const KeymapBinding({
    required this.chord,
    required this.intent,
    this.when,
  });

  final KeyChord chord;
  final Intent intent;
  final WhenExpr? when;

  @override
  String toString() => 'Binding($chord → ${intent.runtimeType}${when == null ? '' : ' when $when'})';
}

/// One source of bindings. Layers are merged in order — later layers
/// take precedence on (chord, when) collisions.
@immutable
class KeymapLayer {
  const KeymapLayer({required this.name, required this.bindings});

  final String name;
  final List<KeymapBinding> bindings;

  /// Parse a YAML document into a layer. Expected shape:
  ///
  /// ```yaml
  /// name: default
  /// bindings:
  ///   - intent: activate
  ///     keys: [enter, space]
  ///     when: focused
  ///   - intent: palette.selectNext
  ///     keys: [down]
  ///     when: palette.open
  /// ```
  ///
  /// `keys:` may be a single chord string or a list. `when:` is
  /// optional. Unknown intent ids cause a [FormatException].
  factory KeymapLayer.fromYaml(String source, {String? nameOverride}) {
    final doc = loadYaml(source);
    if (doc is! YamlMap) {
      throw const FormatException('keymap YAML must be a map at top level');
    }
    final name = nameOverride ?? (doc['name'] as String? ?? 'unnamed');
    final raw = doc['bindings'];
    if (raw is! YamlList) {
      throw const FormatException('keymap YAML must define `bindings:` as a list');
    }
    final out = <KeymapBinding>[];
    for (final entry in raw) {
      if (entry is! YamlMap) {
        throw FormatException('binding entries must be maps; got $entry');
      }
      final intentId = entry['intent'] as String?;
      if (intentId == null) {
        throw FormatException('binding missing `intent:` — $entry');
      }
      final intent = parseIntentId(intentId);
      if (intent == null) {
        throw FormatException('unknown intent id "$intentId" — $entry');
      }
      final keysRaw = entry['keys'];
      final keySpecs = <String>[];
      if (keysRaw is String) {
        keySpecs.add(keysRaw);
      } else if (keysRaw is YamlList) {
        for (final k in keysRaw) {
          if (k is! String) throw FormatException('keys must be strings; got $k in $entry');
          keySpecs.add(k);
        }
      } else {
        throw FormatException('binding missing `keys:` (string or list of strings) — $entry');
      }
      final when = WhenExpr.tryParse(entry['when'] as String?);
      for (final spec in keySpecs) {
        out.add(KeymapBinding(chord: KeyChord.parse(spec), intent: intent, when: when));
      }
    }
    return KeymapLayer(name: name, bindings: out);
  }

  @override
  String toString() => 'KeymapLayer($name, ${bindings.length} binding${bindings.length == 1 ? '' : 's'})';
}

/// A flattened keymap, ready for resolution.
@immutable
class Keymap {
  Keymap(this.layers) : _effective = _flatten(layers);

  final List<KeymapLayer> layers;
  final List<KeymapBinding> _effective;

  /// Resolve a [chord] against the current [context]. Returns the
  /// highest-precedence binding whose chord matches and whose when-
  /// clause (if any) evaluates true. Returns null if no match.
  Intent? resolve(KeyChord chord, Map<String, bool> context) {
    // Effective list is highest-precedence-first; first match wins.
    for (final b in _effective) {
      if (b.chord != chord) continue;
      if (b.when != null && !b.when!.evaluate(context)) continue;
      return b.intent;
    }
    return null;
  }

  /// All resolved bindings in effective-precedence order. Exposed for
  /// debug surfaces (keybindings UI, palette hints).
  List<KeymapBinding> get effectiveBindings => List.unmodifiable(_effective);

  /// Concatenate layers in REVERSE order (last layer first). Later
  /// layers fully shadow earlier (chord, when) collisions: when we walk
  /// the list, the first matching entry wins, so highest-precedence
  /// must come first. We don't dedupe — a no-op match in a later layer
  /// just earns the first slot.
  static List<KeymapBinding> _flatten(List<KeymapLayer> layers) {
    return [
      for (final l in layers.reversed) ...l.bindings,
    ];
  }

  @override
  String toString() => 'Keymap(${layers.map((l) => l.name).join(' < ')})';
}
