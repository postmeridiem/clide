/// Per-workspace PATH preset (D-106, T-511) — a machine-local, user-scope list
/// of directories prepended to the PATH clide hands to every shell it spawns:
/// the hosted Claude session (so the agent's Bash tool sees it) and terminal
/// PTY panes. The T-439 login-shell probe is a global heuristic with a known
/// hole (interactive-only profile additions like brew shellenv in `~/.bashrc`);
/// the preset is the explicit per-repo layer on top of it.
///
/// Storage is the app (user) settings layer keyed by workspace hash — the
/// account-binding pattern (T-483) — so absolute machine paths never land in a
/// committed file. The hash keys off the REPO identity, not the literal
/// directory: a linked git worktree (its `.git` is a `gitdir:` pointer file,
/// e.g. under an in-repo `.worktrees/` dir) resolves to the main repo root, so
/// every worktree shares its repo's preset.
///
/// Security fence: the preset feeds spawned-shell environments only. Clide's
/// own binary resolution (D-104 pins, bundled pql/git, the toolchain probe)
/// never consults it — see D-106.
///
/// Flutter-free (consumed by the `env path` daemon verbs under `dart test`).
library;

import 'dart:io';

import '../ipc/paths.dart' show canonicalWorkspaceKey, fnv1a64Hex;

/// Prefix of the user-scope settings key; the suffix is the preset-root hash.
const pathPresetKeyPrefix = 'app.env.pathPrepend.';

/// The settings key holding [workspaceRoot]'s preset — app layer, suffixed
/// with the FNV-1a hash (the same one D-70 derives for the socket path) of the
/// [presetRootFor]-resolved repo root, so all worktrees of a repo share one key.
String pathPresetKey(String workspaceRoot, {bool Function(String path)? isFile, String? Function(String path)? readFile, bool Function(String path)? isDir}) =>
    '$pathPresetKeyPrefix${fnv1a64Hex(canonicalWorkspaceKey(presetRootFor(workspaceRoot, isFile: isFile, readFile: readFile, isDir: isDir)))}';

/// The directory whose identity keys the preset: the MAIN repo root when
/// [workspaceRoot] is a linked git worktree, else [workspaceRoot] itself
/// (trailing separators stripped, so `/repo` and `/repo/` map alike).
///
/// A linked worktree's `.git` is a pointer FILE — `gitdir: <main>/.git/worktrees/<name>`
/// (git writes forward slashes on every platform; a relative
/// gitdir is resolved against the worktree root). Anything that doesn't match
/// that shape — a normal repo (`.git` directory), no `.git` at all, a
/// submodule pointer — keys off [workspaceRoot] unchanged.
///
/// The pointer content is REPO-controlled, so the resolved target is
/// validated before it is trusted: the candidate main root must actually
/// hold a `.git` directory (a genuine repo), else the pointer is ignored and
/// the workspace keys off itself. Without that check a crafted `.git` file
/// could alias an arbitrary path's preset key (same-user only — the preset
/// values themselves stay user-authored — but the boundary is cheap to hold).
///
/// [isFile]/[readFile]/[isDir] are injectable for tests; defaults touch the
/// real fs.
String presetRootFor(String workspaceRoot, {bool Function(String path)? isFile, String? Function(String path)? readFile, bool Function(String path)? isDir}) {
  final root = _stripTrailingSep(workspaceRoot);
  final probe = isFile ?? _isFile;
  final read = readFile ?? _readFile;
  final dirProbe = isDir ?? _isDir;
  final gitPointer = '$root/.git';
  if (!probe(gitPointer)) return root;
  final content = read(gitPointer);
  if (content == null) return root;
  final match = RegExp(r'^gitdir:\s*(.+?)\s*$', multiLine: true).firstMatch(content);
  if (match == null) return root;
  final gitdir = match.group(1)!.replaceAll(r'\', '/');
  final resolved = _normalize(_isAbsolute(gitdir) ? gitdir : '${root.replaceAll(r'\', '/')}/$gitdir');
  const marker = '/.git/worktrees/';
  final idx = resolved.indexOf(marker);
  if (idx <= 0) return root;
  final mainRoot = resolved.substring(0, idx);
  if (!dirProbe('$mainRoot/.git')) return root;
  return mainRoot;
}

/// The root to key a spawn-time preset lookup on: [workspaceRoot] when [cwd]
/// is the workspace root or anywhere below it (a pane spawned in a subdir
/// must share the workspace's preset), else [cwd] itself (a spawn in an
/// unrelated directory keys off that directory's own repo).
String presetLookupRoot(String? cwd, String workspaceRoot) {
  final ws = _stripTrailingSep(workspaceRoot);
  if (cwd == null || cwd.isEmpty) return ws;
  final c = _stripTrailingSep(cwd);
  if (c == ws || c.startsWith('$ws/')) return ws;
  return c;
}

/// Read [workspaceRoot]'s preset through an injected settings [read] (key →
/// stored value). Tolerant of a malformed value: anything that isn't a list of
/// non-empty strings is skipped, mirroring `AccountRegistry.accounts`.
List<String> presetDirsFrom(
  Object? Function(String key) read,
  String workspaceRoot, {
  bool Function(String path)? isFile,
  String? Function(String path)? readFile,
  bool Function(String path)? isDir,
}) {
  final raw = read(pathPresetKey(workspaceRoot, isFile: isFile, readFile: readFile, isDir: isDir));
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is String && e.trim().isNotEmpty) e,
  ];
}

/// Pure prepend: [preset] dirs (de-duplicated, order kept) ahead of [base],
/// with base entries that repeat a preset dir dropped so the preset always
/// wins. An empty preset returns [base] unchanged.
///
/// Contract: one directory per entry. An entry containing [sep] is malformed
/// (the CLI/UI reject it at input time; this guards stored values that
/// predate the check) and is skipped — joined verbatim it would smuggle
/// extra tokens into PATH, and a trailing separator yields an EMPTY token,
/// which POSIX shells resolve as CWD.
String applyPathPreset(String base, List<String> preset, {String sep = ':'}) {
  final dirs = <String>[];
  for (final d in preset) {
    final t = d.trim();
    if (t.isNotEmpty && !t.contains(sep) && !dirs.contains(t)) dirs.add(t);
  }
  if (dirs.isEmpty) return base;
  final baseParts = base.isEmpty ? const <String>[] : base.split(sep);
  return [...dirs, ...baseParts.where((p) => !dirs.contains(p))].join(sep);
}

/// Capture-from-login-shell diff (D-106's `env path capture`): the entries the
/// login-shell PATH has that the process PATH lacks — the dirs a desktop
/// launch dropped, i.e. the preset candidates. Empty when the probe failed
/// ([loginPath] null/empty). Order-preserved, de-duplicated.
List<String> missingLoginShellDirs({required String? loginPath, required String processPath, String sep = ':'}) {
  if (loginPath == null || loginPath.isEmpty) return const [];
  final have = processPath.split(sep).toSet();
  final out = <String>[];
  for (final d in loginPath.split(sep)) {
    if (d.isNotEmpty && !have.contains(d) && !out.contains(d)) out.add(d);
  }
  return out;
}

bool _isFile(String path) => FileSystemEntity.typeSync(path) == FileSystemEntityType.file;

bool _isDir(String path) => FileSystemEntity.typeSync(path) == FileSystemEntityType.directory;

String? _readFile(String path) {
  try {
    return File(path).readAsStringSync();
  } catch (_) {
    return null;
  }
}

bool _isAbsolute(String p) => p.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(p);

/// Segment-wise `.`/`..` normalization over forward-slash paths (a gitdir
/// pointer is often relative, e.g. `../../.git/worktrees/x`). No fs access.
String _normalize(String p) {
  final drive = RegExp(r'^[A-Za-z]:').firstMatch(p)?.group(0) ?? '';
  final rest = p.substring(drive.length);
  final out = <String>[];
  for (final seg in rest.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(seg);
  }
  return '$drive/${out.join('/')}';
}

String _stripTrailingSep(String p) {
  var s = p;
  while (s.length > 1 && (s.endsWith('/') || s.endsWith(r'\'))) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
