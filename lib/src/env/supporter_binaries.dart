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

/// The process-wide resolver, wired at boot via [loadSupporterBinaries]. Tool
/// consumers (e.g. the d2 template, T-494) read it to resolve a binary; null in
/// headless contexts where boot wiring hasn't run.
SupporterBinaries? activeSupporterBinaries;

/// User-scope SettingsStore key (app layer, `~/.clide`, per-machine) holding the
/// explicit override path for tool [name]. One key per tool so the settings
/// panel binds a plain text field to each (T-414 / D-104).
String supporterToolKey(String name) => 'app.tools.$name';

/// Marker key recording that first-run auto-detection has run, so a later launch
/// neither re-probes nor clobbers a path the user cleared on purpose.
const supporterDetectedKey = 'app.tools.detected';

/// The external supporter binaries clide auto-detects (pql/git are bundled per
/// D-58/D-59 and excluded).
const knownSupporterTools = ['claude', 'd2'];

/// Build a [SupporterBinaries] from the per-tool override keys, auto-detecting
/// the as-yet-unconfigured tools ONCE on first run and pinning what it finds
/// (D-104). [read] returns a stored value (or null); [write] persists one.
/// Injected (not the SettingsStore directly) so this stays Flutter-free and
/// `dart test`-able; [detect] is the prober.
Future<SupporterBinaries> loadSupporterBinaries({
  required Object? Function(String key) read,
  required Future<void> Function(String key, Object? value) write,
  List<String> tools = knownSupporterTools,
  SupporterBinaries Function()? detect,
}) async {
  final overrides = _readOverrides(read, tools);
  if (read(supporterDetectedKey) == null) {
    // First run: probe the tools without an explicit path, pin what's found.
    final fresh = (detect?.call() ?? SupporterBinaries()).detect(tools.where((t) => !overrides.containsKey(t)));
    for (final e in fresh.entries) {
      await write(supporterToolKey(e.key), e.value);
      overrides[e.key] = e.value;
    }
    await write(supporterDetectedKey, true);
  }
  return SupporterBinaries(overrides: overrides);
}

/// Re-probe every tool and overwrite its override key (clearing one no longer
/// found), returning a fresh resolver. Backs the "Re-detect" settings action.
Future<SupporterBinaries> redetectSupporterBinaries({
  required Future<void> Function(String key, Object? value) write,
  List<String> tools = knownSupporterTools,
  SupporterBinaries Function()? detect,
}) async {
  final fresh = (detect?.call() ?? SupporterBinaries()).detect(tools);
  for (final t in tools) {
    await write(supporterToolKey(t), fresh[t]);
  }
  await write(supporterDetectedKey, true);
  return SupporterBinaries(overrides: fresh);
}

Map<String, String> _readOverrides(Object? Function(String) read, List<String> tools) {
  final overrides = <String, String>{};
  for (final t in tools) {
    final v = read(supporterToolKey(t));
    if (v is String && v.isNotEmpty) overrides[t] = v;
  }
  return overrides;
}
