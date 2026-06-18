/// Owns the current Vim editing mode and mirrors it into the keymap as
/// scope flags (T-207).
///
/// The mode is the single source of truth for "is the editor modal right
/// now, and in which mode" — but the *public* interface other subsystems
/// consume is the set of `vim.*` scope flags this service pushes into
/// [KeymapService]. The editor (T-206) decides whether a bare key inserts
/// text or drives a motion by reading `vim.normal` from the keymap scope;
/// the `vim.yaml` preset (T-65) guards its bindings with `when: vim.normal`
/// etc. Nothing reaches into this object across the builtin boundary.
///
/// The whole layer is gated by `enabled`, which the Vim extension ties to
/// the active preset: under a non-Vim preset the flags are cleared so they
/// can never affect another preset's bindings.
library;

import 'package:clide/kernel/src/keymap/keymap_service.dart';
import 'package:flutter/foundation.dart';

/// The three editing modes clide models. Vim's other sub-modes
/// (visual-line, visual-block, replace, command-line) are out of scope
/// for the first pass; `command-line` is surfaced separately as a
/// transient overlay rather than a persistent mode.
enum VimMode {
  normal('vim.normal', 'NORMAL'),
  insert('vim.insert', 'INSERT'),
  visual('vim.visual', 'VISUAL');

  const VimMode(this.scopeFlag, this.label);

  /// The keymap scope flag set true exactly when this mode is active.
  final String scopeFlag;

  /// English status-bar label, shown as `-- NORMAL --`. Used as the i18n
  /// placeholder for `mode.<name>` in the builtin.vim catalog (T-462); the
  /// default keeps Vim's own vocabulary, but a locale may override it.
  final String label;
}

class VimModeService extends ChangeNotifier {
  VimModeService(this._keymap);

  final KeymapService _keymap;

  bool _enabled = false;
  VimMode _mode = VimMode.normal;

  /// Whether the Vim layer is live. False under non-Vim presets.
  bool get enabled => _enabled;

  /// The active mode. Meaningful only while `enabled`; defaults to
  /// [VimMode.normal] and resets to it whenever the layer is enabled.
  VimMode get mode => _mode;

  /// Turn the Vim layer on or off. Enabling resets to normal mode and
  /// publishes the scope flags; disabling clears every `vim.*` flag so a
  /// non-Vim preset's bindings are never shadowed.
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (_enabled) {
      _mode = VimMode.normal;
      _publish();
    } else {
      for (final m in VimMode.values) {
        _keymap.clearScopeFlag(m.scopeFlag);
      }
    }
    notifyListeners();
  }

  void enterNormal() => _setMode(VimMode.normal);
  void enterInsert() => _setMode(VimMode.insert);
  void enterVisual() => _setMode(VimMode.visual);

  void _setMode(VimMode mode) {
    if (!_enabled || _mode == mode) return;
    _mode = mode;
    _publish();
    notifyListeners();
  }

  /// Set exactly one `vim.*` flag (the active mode) true, the rest false.
  void _publish() {
    for (final m in VimMode.values) {
      _keymap.setScopeFlag(m.scopeFlag, m == _mode);
    }
  }
}
