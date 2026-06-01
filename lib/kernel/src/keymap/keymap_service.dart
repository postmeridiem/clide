/// Kernel service that owns the active [Keymap], scope context, and
/// resolution surface.
///
/// Layering (lowest precedence → highest):
///   1. The active preset (asset under `assets/keymaps/<preset>.yaml`).
///      Selected by the `app.keymap.preset` setting; defaults to
///      `default`.
///   2. A user keymap file at `<appDir>/keybindings.yaml` (per-user
///      power-user overrides).
///   3. A settings-stored JSON overlay at `app.keymap.overrides` —
///      list of `{intent, keys, when?}` maps in the same shape as
///      preset YAML.
///
/// Scope context is a `Map<String, bool>` keyed by named flags (e.g.
/// `palette.open`, `editor.focused`). Producing services call
/// [setScopeFlag] when their state changes; consumers reference the
/// flag name in when-clauses.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, KeyEvent, HardwareKeyboard, rootBundle;
import 'package:flutter/widgets.dart' show Intent;

import '../settings.dart';
import 'intents.dart';
import 'key_chord.dart';
import 'keymap.dart';
import 'when_clause.dart';

/// Setting key for the active preset name.
const String kKeymapPresetSetting = 'app.keymap.preset';

/// Setting key for the JSON overlay list.
const String kKeymapOverridesSetting = 'app.keymap.overrides';

/// Filename for the user keymap file under the app dir.
const String kKeymapUserFile = 'keybindings.yaml';

class KeymapService extends ChangeNotifier {
  KeymapService({
    required SettingsStore settings,
    required Directory appDir,
    AssetBundle? bundle,
  })  : _settings = settings,
        _appDir = appDir,
        _bundle = bundle ?? rootBundle;

  final SettingsStore _settings;
  final Directory _appDir;
  final AssetBundle _bundle;

  Keymap? _active;
  final Map<String, bool> _scope = {};

  // The four layer slots, lowest to highest precedence. Held
  // separately so [registerCommandBinding] can refresh the
  // contributions layer without re-reading the preset / file /
  // settings.
  KeymapLayer? _preset;
  final List<KeymapBinding> _contributions = [];
  KeymapLayer? _userFile;
  KeymapLayer? _settingsOverlay;

  /// The currently effective layered keymap. Null before [load] runs.
  Keymap? get keymap => _active;

  /// Live read-only view of the scope context.
  Map<String, bool> get scope => Map.unmodifiable(_scope);

  /// Read the preset from settings (default `default`), load all
  /// non-contribution layers, and rebuild the active keymap. Safe to
  /// call repeatedly. Contributions registered via
  /// [registerCommandBinding] are preserved across reloads.
  Future<void> load() async {
    final presetName = _settings.get<String>(kKeymapPresetSetting) ?? 'default';

    // Preset (asset).
    try {
      final src = await _bundle.loadString('assets/keymaps/$presetName.yaml');
      _preset = KeymapLayer.fromYaml(src, nameOverride: presetName);
    } catch (_) {
      // A missing preset means we ship without a default. Tests can
      // inject a custom bundle. We don't surface this beyond an empty
      // active map.
      _preset = null;
    }

    // User file overlay.
    final userFile = File('${_appDir.path}/$kKeymapUserFile');
    if (await userFile.exists()) {
      try {
        _userFile = KeymapLayer.fromYaml(await userFile.readAsString(), nameOverride: 'user-file');
      } on FormatException {
        _userFile = null;
      }
    } else {
      _userFile = null;
    }

    // Settings overlay.
    final overlay = _settings.get<List<Object?>>(kKeymapOverridesSetting);
    if (overlay != null && overlay.isNotEmpty) {
      final asYaml = StringBuffer('name: settings-overlay\nbindings:\n');
      for (final entry in overlay) {
        if (entry is! Map) continue;
        asYaml.writeln('  - ${jsonEncode(entry)}');
      }
      try {
        _settingsOverlay = KeymapLayer.fromYaml(asYaml.toString(), nameOverride: 'settings-overlay');
      } on FormatException {
        _settingsOverlay = null;
      }
    } else {
      _settingsOverlay = null;
    }

    _rebuildActive();
  }

  /// Register a programmatic chord → command-id binding (typically
  /// from an extension's `defaultBinding`). Contributions form a
  /// layer between preset and user-file: extensions establish their
  /// defaults, the user can override either via the user file or
  /// settings overlay.
  void registerCommandBinding(String chordSpec, String commandId, {String? when}) {
    _contributions.add(KeymapBinding(
      sequence: KeyChord.parseSequence(chordSpec),
      intent: InvokeCommandIntent(commandId),
      when: WhenExpr.tryParse(when),
    ));
    _rebuildActive();
  }

  /// Remove all extension-contributed bindings for [commandId]. Used
  /// when an extension is disabled or unregistered.
  void unregisterCommandBindings(String commandId) {
    final before = _contributions.length;
    _contributions.removeWhere((b) {
      final i = b.intent;
      return i is InvokeCommandIntent && i.commandId == commandId;
    });
    if (_contributions.length != before) {
      _rebuildActive();
    }
  }

  void _rebuildActive() {
    final layers = <KeymapLayer>[
      if (_preset != null) _preset!,
      KeymapLayer(name: 'contributions', bindings: List.unmodifiable(_contributions)),
      if (_userFile != null) _userFile!,
      if (_settingsOverlay != null) _settingsOverlay!,
    ];
    _active = Keymap(layers);
    notifyListeners();
  }

  /// Resolve a [KeyEvent] against the active keymap and current scope.
  /// Returns null when nothing matches.
  Intent? resolveEvent(KeyEvent event, HardwareKeyboard kb) {
    final km = _active;
    if (km == null) return null;
    final chord = KeyChord.fromKeyEvent(event, kb);
    if (chord == null) return null;
    return km.resolve(chord, _scope);
  }

  /// Set a named scope flag. Producers should call this when their
  /// state changes so when-clauses re-evaluate correctly. Notifies
  /// listeners when the value actually changes.
  void setScopeFlag(String name, bool value) {
    if (_scope[name] == value) return;
    _scope[name] = value;
    notifyListeners();
  }

  /// Clear a named scope flag.
  void clearScopeFlag(String name) {
    if (!_scope.containsKey(name)) return;
    _scope.remove(name);
    notifyListeners();
  }

  /// Switch presets. Persists the new preset name to settings and
  /// re-loads the layered keymap.
  Future<void> setPreset(String name) async {
    await _settings.set<String>(kKeymapPresetSetting, name);
    await load();
  }

  /// All effective bindings, highest-precedence first. Useful for
  /// debug surfaces and keybinding hints in the UI.
  List<KeymapBinding> get effectiveBindings => _active?.effectiveBindings ?? const [];
}
