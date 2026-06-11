/// Workspace search-and-replace engine (T-53, per D-79).
///
/// Builds on the same query semantics as the grep engine: it walks the
/// ignore-pruned workspace, applies the replacement to each matching
/// file, and reports per-file, per-line before/after edits for preview.
/// The authoritative new file content is produced by applying the
/// replacement to the whole file; the per-line edits are derived with
/// the same logic so preview and apply never disagree.
///
/// Regex replacements support capture-group references (`$1`..`$9`,
/// `$&`/`$0` for the whole match, `$$` for a literal `$`).
library;

import 'dart:convert';
import 'dart:io';

import '../files/ignore.dart';
import '../files/listing.dart';
import 'match.dart';

/// One changed line within a file.
class ReplacementEdit {
  const ReplacementEdit({required this.line, required this.before, required this.after});

  final int line; // 1-based
  final String before;
  final String after;

  Map<String, Object?> toJson() => {'line': line, 'before': before, 'after': after};

  factory ReplacementEdit.fromJson(Map<String, Object?> j) =>
      ReplacementEdit(line: (j['line'] as num).toInt(), before: j['before'] as String, after: j['after'] as String);
}

/// The set of edits a replacement would make to one file.
class FileReplacement {
  const FileReplacement({required this.path, required this.count, required this.edits});

  final String path;

  /// Number of individual matches replaced in the file.
  final int count;
  final List<ReplacementEdit> edits;

  Map<String, Object?> toJson() => {
    'path': path,
    'count': count,
    'edits': [for (final e in edits) e.toJson()],
  };

  factory FileReplacement.fromJson(Map<String, Object?> j) => FileReplacement(
    path: j['path'] as String,
    count: (j['count'] as num).toInt(),
    edits: [for (final e in (j['edits'] as List? ?? const []).whereType<Map>()) ReplacementEdit.fromJson(e.cast<String, Object?>())],
  );
}

/// Apply [query]'s pattern to [text], substituting [replacement]. Returns
/// the rewritten text and the number of matches replaced.
({String text, int count}) applyToText(String text, SearchQuery query, String replacement) {
  if (query.pattern.isEmpty) return (text: text, count: 0);
  var count = 0;
  final RegExp re;
  if (query.regex) {
    re = RegExp(query.pattern, caseSensitive: !query.ignoreCase);
  } else {
    re = RegExp(RegExp.escape(query.pattern), caseSensitive: !query.ignoreCase);
  }
  final out = text.replaceAllMapped(re, (m) {
    count++;
    return query.regex ? _expand(replacement, m) : replacement;
  });
  return (text: out, count: count);
}

/// Expand `$n` / `$&` / `$$` references in a regex replacement template.
String _expand(String template, Match m) {
  final b = StringBuffer();
  var i = 0;
  while (i < template.length) {
    final c = template[i];
    if (c == r'$' && i + 1 < template.length) {
      final next = template[i + 1];
      if (next == r'$') {
        b.write(r'$');
        i += 2;
        continue;
      }
      if (next == '&' || next == '0') {
        b.write(m.group(0) ?? '');
        i += 2;
        continue;
      }
      if (_isDigit(next)) {
        // Greedy two-digit group index when valid, else one digit.
        var idx = int.parse(next);
        var consumed = 2;
        if (i + 2 < template.length && _isDigit(template[i + 2])) {
          final two = int.parse('$next${template[i + 2]}');
          if (two <= m.groupCount) {
            idx = two;
            consumed = 3;
          }
        }
        if (idx <= m.groupCount) {
          b.write(m.group(idx) ?? '');
          i += consumed;
          continue;
        }
      }
    }
    b.write(c);
    i++;
  }
  return b.toString();
}

bool _isDigit(String s) => s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39;

/// Compute the replacements [query] → [replacement] would make under
/// [root]. Returns one [FileReplacement] per changed file, with
/// per-line before/after edits for preview. Pure read-only — writing is
/// the caller's job (after the clean-tree safety gate).
Future<List<FileReplacement>> computeReplacements({
  required Directory root,
  required IgnoreSet ignore,
  required SearchQuery query,
  required String replacement,
  int maxFiles = 5000,
}) async {
  if (query.pattern.isEmpty) return const [];
  if (query.regex) RegExp(query.pattern, caseSensitive: !query.ignoreCase); // validate

  final walk = await walkFiles(root: root, ignore: ignore);
  final rootPath = root.absolute.path;
  final out = <FileReplacement>[];
  for (final entry in walk.files) {
    if (out.length >= maxFiles) break;
    final fr = _replaceInFile(rootPath, entry.path, query, replacement);
    if (fr != null) out.add(fr);
  }
  return out;
}

/// Compute the rewritten content for a single file, or null if the file
/// is binary/unreadable/unchanged. Exposed for the apply path + tests.
String? rewriteFileContent(String rootPath, String relPath, SearchQuery query, String replacement) {
  final content = _readText('$rootPath/$relPath');
  if (content == null) return null;
  final r = applyToText(content, query, replacement);
  if (r.count == 0) return null;
  return r.text;
}

FileReplacement? _replaceInFile(String rootPath, String relPath, SearchQuery query, String replacement) {
  final content = _readText('$rootPath/$relPath');
  if (content == null) return null;
  final whole = applyToText(content, query, replacement);
  if (whole.count == 0) return null;
  // Per-line preview edits, using the same apply logic line-by-line.
  final edits = <ReplacementEdit>[];
  var lineNo = 0;
  for (final line in const LineSplitter().convert(content)) {
    lineNo++;
    final r = applyToText(line, query, replacement);
    if (r.count > 0 && r.text != line) {
      edits.add(ReplacementEdit(line: lineNo, before: line, after: r.text));
    }
  }
  return FileReplacement(path: relPath, count: whole.count, edits: edits);
}

String? _readText(String absPath) {
  try {
    final bytes = File(absPath).readAsBytesSync();
    final probe = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    if (probe.contains(0)) return null; // binary
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  }
}
