/// Minimal gitignore-style matcher.
///
/// Implements the common subset: line-per-pattern, `#` comments,
/// anchored-to-root (`/foo`), directory-only (`foo/`), `*` (any except
/// `/`), `**` (any including `/`). Negation (`!foo`) is parsed but
/// applied in list order — the last matching pattern wins.
///
/// Not implemented (deliberate simplification — Tier 1 scope):
///   - Case-insensitive systems (Windows / macOS HFS+).
///   - Nested .gitignore files inside subdirectories. A single ignore
///     file at the root covers the whole tree.
///   - Pattern comments at line ends (`foo # bar`).
///
/// Full D-004 layering (multiple ignore files from `.pql/config.yaml`'s
/// `ignore_files:`, in order) is built on top of this primitive via
/// [IgnoreSet].
library;

/// A single parsed gitignore pattern.
class IgnorePattern {
  IgnorePattern._({
    required this.source,
    required this.negated,
    required this.directoryOnly,
    required this.anchored,
    required this.regex,
  });

  /// The raw line from the file (for diagnostics).
  final String source;
  final bool negated;
  final bool directoryOnly;
  final bool anchored;

  /// Compiled pattern — runs against a repo-relative path (no leading
  /// slash, forward slashes only).
  final RegExp regex;

  /// Parse a single line. Returns `null` on comment / blank.
  static IgnorePattern? parse(String line) {
    var s = line.trimRight();
    if (s.isEmpty || s.startsWith('#')) return null;

    var negated = false;
    if (s.startsWith('!')) {
      negated = true;
      s = s.substring(1);
    }

    var anchored = false;
    if (s.startsWith('/')) {
      anchored = true;
      s = s.substring(1);
    }

    var directoryOnly = false;
    if (s.endsWith('/')) {
      directoryOnly = true;
      s = s.substring(0, s.length - 1);
    }

    return IgnorePattern._(
      source: line,
      negated: negated,
      directoryOnly: directoryOnly,
      anchored: anchored,
      regex: _compile(s, anchored: anchored),
    );
  }

  static RegExp _compile(String glob, {required bool anchored}) {
    final b = StringBuffer('^');
    if (!anchored) {
      // Unanchored: match anywhere in the path (either at root or
      // inside a subdirectory).
      b.write(r'(?:.*/)?');
    }
    var i = 0;
    while (i < glob.length) {
      // Handle the special triples first: `/**/` collapses to either
      // a single `/` (zero dirs between) or `/…/` (any depth).
      if (i + 3 <= glob.length && glob.substring(i, i + 3) == '/**') {
        if (i + 4 <= glob.length && glob[i + 3] == '/') {
          // `/**/` — zero or more directories
          b.write(r'/(?:.*/)?');
          i += 4;
          continue;
        }
        if (i + 3 == glob.length) {
          // Trailing `/**` — everything underneath
          b.write(r'(?:/.*)?');
          i += 3;
          continue;
        }
      }
      final c = glob[i];
      if (c == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          // Bare `**` (not next to `/`): treat as `.*`
          b.write('.*');
          i += 2;
          continue;
        } else {
          // `*` — any except `/`
          b.write('[^/]*');
        }
      } else if (c == '?') {
        b.write('[^/]');
      } else if ('.^\$+(){}[]|\\'.contains(c)) {
        b.write('\\$c');
      } else {
        b.write(c);
      }
      i++;
    }
    b.write(r'(?:/.*)?$'); // match subtree rooted at the glob
    return RegExp(b.toString());
  }

  bool matches(String path, {required bool isDirectory}) {
    if (directoryOnly && !isDirectory) return false;
    return regex.hasMatch(path);
  }
}

/// A layered set of ignore files. Applied in order — later matches
/// win (per D-004). A path is ignored when the last pattern that
/// matches it is non-negated.
class IgnoreSet {
  IgnoreSet(this._patterns);

  final List<IgnorePattern> _patterns;

  /// Build an IgnoreSet from the concatenated contents of multiple
  /// ignore files, in D-004's `ignore_files:` order.
  factory IgnoreSet.parse(Iterable<String> fileContents) {
    final patterns = <IgnorePattern>[];
    for (final content in fileContents) {
      for (final line in content.split('\n')) {
        final p = IgnorePattern.parse(line);
        if (p != null) patterns.add(p);
      }
    }
    return IgnoreSet(patterns);
  }

  /// Apply the layered set to `path`.
  ///
  /// `path` is repo-relative, forward-slashed, no leading slash.
  /// `isDirectory` is load-bearing for patterns that end in `/`.
  bool isIgnored(String path, {required bool isDirectory}) {
    bool ignored = false;
    for (final p in _patterns) {
      if (p.matches(path, isDirectory: isDirectory)) {
        ignored = !p.negated;
      }
    }
    return ignored;
  }

  int get length => _patterns.length;

  /// Exposed for composition: merging multiple IgnoreSets while
  /// preserving the deliberate "later wins" evaluation order.
  List<IgnorePattern> get patterns => List.unmodifiable(_patterns);

  /// Clide-owned dirs that are always hidden regardless of the user's
  /// ignore files. Matches D-004's "walker magic: none except
  /// `.git/`" — but the tree-view UI benefits from hiding `.pql/` and
  /// `.dart_tool/` too since users never edit those by hand.
  static IgnoreSet builtin() => IgnoreSet.parse(const [
        '.git/\n.pql/\n.clide/\n.dart_tool/\nbuild/\nnode_modules/\n',
      ]);
}
