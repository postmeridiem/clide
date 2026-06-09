/// `.editorconfig` as an [EditorSettings] source (T-29).
///
/// Reads `.editorconfig` files from the workspace and resolves the properties
/// that apply to a given file into the source-agnostic [EditorSettings] model.
/// This is one *source* feeding `editor_settings_resolver.dart`; it is not the
/// thing the editor obeys directly.
///
/// We parse the INI-ish format and match section globs ourselves (no
/// dependency, per prefer-zero-deps). Resolution walks from the file's
/// directory up to the workspace root, honouring `root = true` to stop the
/// ascent, with nearer files and later sections winning on conflict — the
/// precedence the EditorConfig spec defines.
///
/// Flutter-free by construction: this runs daemon-side under `dart test`
/// alongside [EditorRegistry], so it imports only `dart:io` + the model.
library;

import 'dart:io';

import 'editor_settings.dart';

/// Resolve the EditorConfig-sourced [EditorSettings] for [relPath] (a
/// workspace-relative, `/`-separated path) against the `.editorconfig` files
/// under [workspaceRoot].
///
/// Walks from the file's directory up to (and including) the workspace root,
/// stopping once a file declares `root = true`. Never throws — an unreadable or
/// malformed file is skipped, so a broken `.editorconfig` can't wedge a file
/// open or save.
EditorSettings readEditorConfig(Directory workspaceRoot, String relPath) {
  final rel = relPath.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
  final segs = rel.split('/');
  final dirSegs = segs.sublist(0, segs.length - 1);
  final sep = Platform.pathSeparator;

  // Nearest-first, so we can stop the ascent at root=true.
  final collected = <_ConfigFile>[];
  for (var k = dirSegs.length; k >= 0; k--) {
    final dirSegments = dirSegs.sublist(0, k);
    final filePath = [workspaceRoot.path, ...dirSegments, '.editorconfig'].join(sep);
    final file = File(filePath);
    if (!file.existsSync()) continue;
    _ConfigFile parsed;
    try {
      // The path of the queried file relative to THIS .editorconfig's dir.
      parsed = _parseIni(file.readAsStringSync(), segs.sublist(k).join('/'));
    } catch (_) {
      continue; // unreadable/odd file → skip
    }
    collected.add(parsed);
    if (parsed.isRoot) break;
  }

  // Apply farthest-first so the nearest file's sections win; within a file,
  // later matching sections override earlier ones.
  final props = <String, String>{};
  for (final cfg in collected.reversed) {
    for (final section in cfg.sections) {
      if (_globMatches(section.glob, cfg.relForMatch)) {
        props.addAll(section.props);
      }
    }
  }
  return editorSettingsFromProps(props);
}

/// Build [EditorSettings] from a merged raw EditorConfig property map (keys
/// already lowercased). Applies the spec's `indent_size`/`tab_width`
/// cross-defaulting; a property valued `unset` (or unparseable for its type)
/// resolves to null. Public for direct unit testing of the mapping.
EditorSettings editorSettingsFromProps(Map<String, String> p) {
  String? lc(String k) {
    final v = p[k];
    if (v == null) return null;
    final t = v.trim().toLowerCase();
    return t == 'unset' ? null : t;
  }

  final indentStyle = _oneOf(lc('indent_style'), const {'tab', 'space'});
  int? tabWidth = _posInt(lc('tab_width'));

  final rawIndent = lc('indent_size');
  int? indentSize;
  if (rawIndent == 'tab') {
    indentSize = tabWidth;
  } else {
    indentSize = _posInt(rawIndent);
  }
  // tab_width defaults to indent_size; indent_size (for tabs) defaults to
  // tab_width — the reciprocal defaulting from the spec.
  tabWidth ??= indentSize;
  if (indentStyle == 'tab') indentSize ??= tabWidth;

  final maxRaw = lc('max_line_length');
  final maxLineLength = (maxRaw == 'off') ? null : _posInt(maxRaw);

  return EditorSettings(
    indentStyle: indentStyle,
    indentSize: indentSize,
    tabWidth: tabWidth,
    endOfLine: _oneOf(lc('end_of_line'), const {'lf', 'crlf', 'cr'}),
    maxLineLength: maxLineLength,
    trimTrailingWhitespace: _bool(lc('trim_trailing_whitespace')),
    insertFinalNewline: _bool(lc('insert_final_newline')),
  );
}

String? _oneOf(String? v, Set<String> allowed) => (v != null && allowed.contains(v)) ? v : null;
int? _posInt(String? v) {
  if (v == null) return null;
  final n = int.tryParse(v);
  return (n != null && n > 0) ? n : null;
}

bool? _bool(String? v) => switch (v) {
      'true' => true,
      'false' => false,
      _ => null,
    };

// ---------------------------------------------------------------------------
// INI parsing
// ---------------------------------------------------------------------------

class _ConfigFile {
  _ConfigFile({required this.isRoot, required this.sections, required this.relForMatch});

  final bool isRoot;
  final List<_Section> sections;

  /// Path of the queried file relative to this config file's directory.
  final String relForMatch;
}

class _Section {
  _Section(this.glob) : props = {};
  final String glob;
  final Map<String, String> props;
}

_ConfigFile _parseIni(String text, String relForMatch) {
  var isRoot = false;
  final sections = <_Section>[];
  _Section? current;

  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) continue;

    if (line.startsWith('[') && line.endsWith(']') && line.length >= 2) {
      current = _Section(line.substring(1, line.length - 1));
      sections.add(current);
      continue;
    }

    final eq = line.indexOf('=');
    if (eq < 0) continue;
    final key = line.substring(0, eq).trim().toLowerCase();
    final value = line.substring(eq + 1).trim();
    if (current == null) {
      // Preamble: only `root` is meaningful at the top of the file.
      if (key == 'root') isRoot = value.toLowerCase() == 'true';
    } else {
      current.props[key] = value;
    }
  }
  return _ConfigFile(isRoot: isRoot, sections: sections, relForMatch: relForMatch);
}

// ---------------------------------------------------------------------------
// Glob matching (EditorConfig flavour)
// ---------------------------------------------------------------------------

final Map<String, RegExp> _globCache = {};

/// Whether the EditorConfig section [glob] matches [path] (the file relative to
/// the config file's directory, `/`-separated).
bool _globMatches(String glob, String path) {
  final re = _globCache.putIfAbsent(glob, () => RegExp('^${_globToRegex(glob)}\$'));
  return re.hasMatch(path);
}

/// Translate an EditorConfig glob to a regex body (unanchored).
///
/// Supports `*` (any run of non-separators), `**` (any run, separators
/// included), `?` (one non-separator), `[seq]`/`[!seq]` character classes,
/// `{a,b,c}` alternation, and `{m..n}` numeric ranges. A glob with no `/` may
/// match in any subdirectory; one with a `/` is anchored to the config dir.
String _globToRegex(String glob) {
  // A pattern containing no separator matches the file in any directory.
  // One that does is anchored to the config file's directory; a leading
  // slash is just that anchor and is dropped.
  final hasSlash = glob.contains('/');
  var g = glob;
  if (g.startsWith('/')) g = g.substring(1);
  final prefix = hasSlash ? '' : '(?:.*/)?';
  return prefix + _translate(g);
}

String _translate(String pat) {
  final sb = StringBuffer();
  var i = 0;
  final n = pat.length;
  while (i < n) {
    final c = pat[i];
    if (c == '*') {
      if (i + 1 < n && pat[i + 1] == '*') {
        // `**/` collapses the trailing slash so zero directories also match.
        if (i + 2 < n && pat[i + 2] == '/') {
          sb.write('(?:.*/)?');
          i += 3;
        } else {
          sb.write('.*');
          i += 2;
        }
      } else {
        sb.write('[^/]*');
        i += 1;
      }
    } else if (c == '?') {
      sb.write('[^/]');
      i += 1;
    } else if (c == '[') {
      i = _translateClass(pat, i, sb);
    } else if (c == '{') {
      i = _translateBrace(pat, i, sb);
    } else if (c == '\\' && i + 1 < n) {
      sb.write(RegExp.escape(pat[i + 1]));
      i += 2;
    } else {
      sb.write(RegExp.escape(c));
      i += 1;
    }
  }
  return sb.toString();
}

/// Translate a `[...]` character class starting at [start] (`pat[start] == '['`).
/// Returns the index just past the closing `]`. Falls back to a literal `[`
/// when the class is unterminated.
int _translateClass(String pat, int start, StringBuffer sb) {
  final n = pat.length;
  var j = start + 1;
  var negate = false;
  if (j < n && (pat[j] == '!' || pat[j] == '^')) {
    negate = true;
    j++;
  }
  final body = StringBuffer();
  var closed = false;
  while (j < n) {
    final c = pat[j];
    if (c == ']') {
      closed = true;
      break;
    }
    if (c == '\\' && j + 1 < n) {
      body.write(RegExp.escape(pat[j + 1]));
      j += 2;
      continue;
    }
    // Inside a class only `\` and `]` are special to us; keep ranges (a-z) as is.
    body.write(c == '^' || c == '[' ? '\\$c' : c);
    j++;
  }
  if (!closed) {
    sb.write(RegExp.escape('['));
    return start + 1;
  }
  sb.write('[${negate ? '^' : ''}${body.toString()}]');
  return j + 1; // past ']'
}

/// Translate a `{...}` group starting at [start] (`pat[start] == '{'`).
/// Handles `{a,b,c}` alternation and `{m..n}` numeric ranges; an unterminated
/// or single-item brace is emitted literally. Returns the index past `}`.
int _translateBrace(String pat, int start, StringBuffer sb) {
  final close = _matchingBrace(pat, start);
  if (close < 0) {
    sb.write(RegExp.escape('{'));
    return start + 1;
  }
  final inner = pat.substring(start + 1, close);

  // Numeric range {m..n}.
  final range = RegExp(r'^(-?\d+)\.\.(-?\d+)$').firstMatch(inner);
  if (range != null) {
    final lo = int.parse(range.group(1)!);
    final hi = int.parse(range.group(2)!);
    final from = lo <= hi ? lo : hi;
    final to = lo <= hi ? hi : lo;
    // Cap the expansion; huge ranges fall back to a generic integer match.
    if (to - from <= 4096) {
      final alts = [for (var k = from; k <= to; k++) '$k'].map(RegExp.escape).join('|');
      sb.write('(?:$alts)');
    } else {
      sb.write(r'(?:-?\d+)');
    }
    return close + 1;
  }

  final parts = _splitTopLevel(inner);
  if (parts.length <= 1) {
    // Not a real alternation (`{` with no top-level comma) — literal braces.
    sb.write(RegExp.escape('{'));
    sb.write(_translate(inner));
    sb.write(RegExp.escape('}'));
    return close + 1;
  }
  sb.write('(?:${parts.map(_translate).join('|')})');
  return close + 1;
}

int _matchingBrace(String pat, int open) {
  var depth = 0;
  for (var j = open; j < pat.length; j++) {
    final c = pat[j];
    if (c == '\\') {
      j++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return j;
    }
  }
  return -1;
}

/// Split [s] on commas that are not nested inside `{}` or `[]`.
List<String> _splitTopLevel(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  var brace = 0;
  var bracket = 0;
  for (var j = 0; j < s.length; j++) {
    final c = s[j];
    if (c == '\\' && j + 1 < s.length) {
      buf.write(c);
      buf.write(s[j + 1]);
      j++;
      continue;
    }
    if (c == '{') brace++;
    if (c == '}') brace--;
    if (c == '[') bracket++;
    if (c == ']') bracket--;
    if (c == ',' && brace == 0 && bracket == 0) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}
