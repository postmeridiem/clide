/// Resolves external supporter binaries (claude, d2, …) to absolute paths
/// (T-495, D-104).
///
/// Order: an explicit user-scope **override** map is consulted FIRST; then the
/// login-shell / process search PATH ([resolvedToolPath]); then the well-known
/// user/local bin dirs — including **Homebrew-on-Linux** (`/home/linuxbrew/...`),
/// which the standard PATH expansion omits and a login-shell probe misses when
/// `brew shellenv` lives only in `~/.bashrc`. That omission is the gap D-104
/// fixes.
///
/// [detect] probes those locations to seed the override map on first run (or a
/// re-detect), so resolution is **pinned** thereafter — deterministic, not a
/// per-launch heuristic. A pin that no longer points at a file is reported by
/// [isStalePin] so the caller can warn + re-detect rather than silently fail.
///
/// Pure Dart (injected `exists` / `searchPath`), Flutter-free; runs under
/// `dart test`.
library;

import 'dart:io';

import 'shell_env.dart' show resolvedToolPath;

/// Whether [absolutePath] points at an existing file (symlinks followed).
typedef PathExists = bool Function(String absolutePath);

class SupporterBinaries {
  SupporterBinaries({Map<String, String> overrides = const {}, PathExists? exists, String Function()? searchPath, String? home, bool isWindows = false})
    : _overrides = overrides,
      _exists = exists ?? _fileExists,
      _searchPath = searchPath ?? resolvedToolPath,
      _home = home ?? Platform.environment['HOME'],
      _sep = isWindows ? ';' : ':';

  final Map<String, String> _overrides;
  final PathExists _exists;
  final String Function() _searchPath;
  final String? _home;
  final String _sep;

  /// Resolve [name] to an absolute path, or `null`. Order: explicit override (if
  /// it still exists) → search PATH → well-known dirs.
  String? resolve(String name) {
    final pinned = _overrides[name];
    if (pinned != null && pinned.isNotEmpty && _exists(pinned)) return pinned;
    for (final dir in _searchDirs()) {
      final p = '$dir/$name';
      if (_exists(p)) return p;
    }
    return null;
  }

  /// True when [name]'s override is set but no longer points at a file — a stale
  /// pin (the tool moved on an upgrade). The caller warns and can re-detect.
  bool isStalePin(String name) {
    final p = _overrides[name];
    return p != null && p.isNotEmpty && !_exists(p);
  }

  /// Probe for [names], returning name→absolute-path for those found — the seed
  /// for the override map on first run / re-detect.
  Map<String, String> detect(Iterable<String> names) {
    final dirs = _searchDirs().toList();
    final out = <String, String>{};
    for (final name in names) {
      for (final dir in dirs) {
        final p = '$dir/$name';
        if (_exists(p)) {
          out[name] = p;
          break;
        }
      }
    }
    return out;
  }

  Iterable<String> _searchDirs() sync* {
    final seen = <String>{};
    for (final dir in _searchPath().split(_sep)) {
      if (dir.isNotEmpty && seen.add(dir)) yield dir;
    }
    for (final dir in _wellKnownDirs()) {
      if (seen.add(dir)) yield dir;
    }
  }

  List<String> _wellKnownDirs() {
    final h = _home ?? '';
    return [if (h.isNotEmpty) '$h/.local/bin', '/usr/local/bin', '/opt/homebrew/bin', '/opt/homebrew/sbin', '/home/linuxbrew/.linuxbrew/bin'];
  }
}

bool _fileExists(String p) => File(p).existsSync();

/// The user-scope SettingsStore key (app layer, `~/.clide`, per-machine) holding
/// the tool→absolute-path override map.
const supporterToolsKey = 'app.tools';

/// The external supporter binaries clide auto-detects (pql/git are bundled per
/// D-58/D-59 and excluded).
const knownSupporterTools = ['claude', 'd2'];

/// Build a [SupporterBinaries] from persisted overrides, auto-detecting on first
/// run (D-104). [readOverrides] returns the stored map (or null if unset);
/// [writeOverrides] persists a freshly-detected one. Injected (not the
/// SettingsStore directly) so this stays Flutter-free and `dart test`-able;
/// [detect] is the prober (defaults to a real [SupporterBinaries]).
Future<SupporterBinaries> loadSupporterBinaries({
  required Map<dynamic, dynamic>? Function() readOverrides,
  required Future<void> Function(Map<String, String>) writeOverrides,
  List<String> tools = knownSupporterTools,
  SupporterBinaries Function()? detect,
}) async {
  final raw = readOverrides();
  if (raw != null) return SupporterBinaries(overrides: _asStringMap(raw));
  // First run: probe once, persist (pinned), and use the result.
  final detected = (detect?.call() ?? SupporterBinaries()).detect(tools);
  await writeOverrides(detected);
  return SupporterBinaries(overrides: detected);
}

Map<String, String> _asStringMap(Map<dynamic, dynamic> raw) => {
  for (final e in raw.entries)
    if (e.key is String && e.value is String) e.key as String: e.value as String,
};
