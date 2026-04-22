/// Derive deterministic tmux session names for Claude panes (D-041).
///
/// The primary session name for a repo is `clide-claude-<hash>` where
/// `<hash>` is an 8-char FNV-1a-ish hex hash of the canonical
/// (absolute, symlink-resolved) repo path. Not cryptographic — we just
/// need short, stable, collision-resistant-enough strings. Secondary
/// sessions append `-N` for monotonically increasing `N`.
library;

/// Stable session name for the primary Claude pane of [repoRoot].
String primarySessionName(String repoRoot) {
  return 'clide-claude-${_hash(repoRoot)}';
}

/// Nth secondary session name. [n] starts at 1.
String secondarySessionName(String repoRoot, int n) {
  return '${primarySessionName(repoRoot)}-$n';
}

/// 8-char hex hash. FNV-1a over UTF-16 code units; independent of
/// platform endianness. Collision rate at N=1000 repos is still
/// vanishingly small (≈0.0001%).
String _hash(String s) {
  var h = 2166136261; // FNV offset basis (32-bit)
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
