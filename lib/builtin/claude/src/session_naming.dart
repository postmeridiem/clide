/// Derive deterministic tmux session names for Claude panes (D-041).
///
/// The primary session name encodes the repo path in a human-readable
/// form: `clide-claude-<path-slug>`. For example:
///   ~/projects/clide     → clide-claude-projects-clide
///   /var/mnt/data/myapp  → clide-claude-var-mnt-data-myapp
///
/// Secondary sessions append `-N`.
library;

import 'dart:io' show Platform;

/// Stable session name for the primary Claude pane of [repoRoot].
String primarySessionName(String repoRoot) {
  return 'clide-claude-${_slugify(repoRoot)}';
}

/// Nth secondary session name. [n] starts at 1.
String secondarySessionName(String repoRoot, int n) {
  return '${primarySessionName(repoRoot)}-$n';
}

// tmux session names max out at 256 chars; keep ours well under.
const _maxSlugLen = 80;

String _slugify(String path) {
  final home = Platform.environment['HOME'] ?? '';
  var p = path;
  if (home.isNotEmpty && p.startsWith(home)) {
    p = p.substring(home.length);
  }
  p = p.replaceAll('/', '-').replaceAll('.', '');
  while (p.startsWith('-')) {
    p = p.substring(1);
  }
  while (p.endsWith('-')) {
    p = p.substring(0, p.length - 1);
  }
  if (p.isEmpty) p = 'root';
  if (p.length > _maxSlugLen) return _hash(path);
  return p;
}

String _hash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
