/// Pure-Dart workspace content-grep engine (T-52, per D-79).
///
/// Walks the workspace (ignore-pruned via [walkFiles]), fans the file
/// list across worker isolates ([Isolate.run]) for true parallelism,
/// matches each line with a literal `indexOf` fast-path or a [RegExp],
/// and **streams** match batches back so the UI shows first hits before
/// the whole tree is scanned. Cancellation is checked between chunks.
///
/// No external binary, single-process, cross-platform — the rationale
/// and the ripgrep-accelerator escape hatch are recorded in D-79.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../files/ignore.dart';
import '../files/listing.dart';
import 'match.dart';

/// Cooperative cancellation flag for an in-flight [grepWorkspace].
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Stream match batches for [query] under [root].
///
/// Yields a list per completed file-chunk (in chunk order) so the UI
/// can append incrementally. Stops after [maxResults] total matches
/// (the final batch is trimmed) or when [cancel] fires. [maxPerFile]
/// bounds matches from any single file. Set [useIsolates] false to run
/// in-process (deterministic; used by tests).
///
/// Throws [FormatException] for an invalid regex pattern before any
/// scanning begins.
Stream<List<SearchMatch>> grepWorkspace({
  required Directory root,
  required IgnoreSet ignore,
  required SearchQuery query,
  int maxResults = 5000,
  int maxPerFile = 200,
  int? concurrency,
  CancelToken? cancel,
  bool useIsolates = true,
}) async* {
  if (query.pattern.isEmpty) return;
  // Validate the regex up front so a bad pattern surfaces as an error,
  // not as silent zero results from every isolate.
  if (query.regex) {
    RegExp(query.pattern, caseSensitive: !query.ignoreCase);
  }

  final walk = await walkFiles(root: root, ignore: ignore);
  if (cancel?.isCancelled ?? false) return;

  final includes = [for (final g in query.include) _globToRegExp(g)];
  final excludes = [for (final g in query.exclude) _globToRegExp(g)];
  final candidates = <String>[];
  for (final e in walk.files) {
    if (_acceptGlobs(e.path, includes, excludes)) candidates.add(e.path);
  }
  if (candidates.isEmpty) return;

  final n = (concurrency ?? Platform.numberOfProcessors).clamp(1, 32);
  final chunks = _chunk(candidates, n);
  final rootPath = root.absolute.path;

  // Launch every chunk concurrently; await in chunk order to stream.
  final futures = <Future<List<SearchMatch>>>[for (final c in chunks) _runChunk(rootPath, c, query, maxPerFile, useIsolates)];

  var emitted = 0;
  for (final f in futures) {
    if (cancel?.isCancelled ?? false) {
      _drain(futures);
      return;
    }
    final matches = await f;
    if (cancel?.isCancelled ?? false) {
      _drain(futures);
      return;
    }
    if (matches.isEmpty) continue;
    final remaining = maxResults - emitted;
    final slice = matches.length > remaining ? matches.sublist(0, remaining) : matches;
    emitted += slice.length;
    yield slice;
    if (emitted >= maxResults) {
      _drain(futures);
      return;
    }
  }
}

void _drain(List<Future<List<SearchMatch>>> futures) {
  // Swallow results/errors of any still-running chunks so they don't
  // surface as unhandled async errors after we stop reading.
  for (final f in futures) {
    unawaited(f.then((_) {}, onError: (_) {}));
  }
}

Future<List<SearchMatch>> _runChunk(String rootPath, List<String> paths, SearchQuery query, int maxPerFile, bool useIsolates) {
  if (useIsolates) {
    return Isolate.run(() => grepChunk(rootPath, paths, query, maxPerFile));
  }
  return Future.value(grepChunk(rootPath, paths, query, maxPerFile));
}

/// Split [items] into at most [buckets] contiguous chunks.
List<List<String>> _chunk(List<String> items, int buckets) {
  if (buckets <= 1 || items.length <= 1) return [items];
  final size = (items.length / buckets).ceil();
  final out = <List<String>>[];
  for (var i = 0; i < items.length; i += size) {
    out.add(items.sublist(i, (i + size).clamp(0, items.length)));
  }
  return out;
}

// -- Isolate-side work (top-level, sendable) --------------------------------

/// Grep a chunk of files. Runs in a worker isolate (or in-process for
/// tests). Reads each file, skips binaries, and collects up to
/// [maxPerFile] matches per file.
List<SearchMatch> grepChunk(String rootPath, List<String> relPaths, SearchQuery query, int maxPerFile) {
  final compiled = CompiledQuery(query);
  final out = <SearchMatch>[];
  for (final rel in relPaths) {
    final file = File('$rootPath/$rel');
    String content;
    try {
      final bytes = file.readAsBytesSync();
      // Binary sniff: a NUL in the first 1 KiB → skip.
      final probe = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
      if (probe.contains(0)) continue;
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      continue; // unreadable / vanished — skip
    }
    grepContent(rel, content, compiled, maxPerFile, out);
  }
  return out;
}

/// Match [content]'s lines, appending up to [maxPerFile] hits to [out].
/// Exposed (with a pre-built [compiled]) for unit testing without I/O.
void grepContent(String relPath, String content, CompiledQuery compiled, int maxPerFile, List<SearchMatch> out) {
  var lineNo = 0;
  final added0 = out.length;
  for (final line in const LineSplitter().convert(content)) {
    lineNo++;
    for (final span in compiled.matches(line)) {
      out.add(SearchMatch(path: relPath, line: lineNo, matchStart: span.$1, matchEnd: span.$2, preview: line.length > 500 ? line.substring(0, 500) : line));
      if (out.length - added0 >= maxPerFile) return;
    }
  }
}

/// A compiled query: a [RegExp] when [SearchQuery.regex], else a literal
/// matcher with an optional case-insensitive fast-path.
class CompiledQuery {
  CompiledQuery(SearchQuery q)
    : _regex = q.regex ? RegExp(q.pattern, caseSensitive: !q.ignoreCase) : null,
      _needle = q.regex ? '' : (q.ignoreCase ? q.pattern.toLowerCase() : q.pattern),
      _ignoreCase = q.ignoreCase;

  final RegExp? _regex;
  final String _needle;
  final bool _ignoreCase;

  /// All (start, end) match spans within [line].
  List<(int, int)> matches(String line) {
    final re = _regex;
    if (re != null) {
      return [for (final m in re.allMatches(line)) (m.start, m.end)];
    }
    if (_needle.isEmpty) return const [];
    final hay = _ignoreCase ? line.toLowerCase() : line;
    final spans = <(int, int)>[];
    var from = 0;
    while (true) {
      final i = hay.indexOf(_needle, from);
      if (i < 0) break;
      spans.add((i, i + _needle.length));
      from = i + _needle.length;
    }
    return spans;
  }
}

// -- Glob filtering ----------------------------------------------------------

bool _acceptGlobs(String path, List<RegExp> includes, List<RegExp> excludes) {
  if (includes.isNotEmpty && !includes.any((r) => r.hasMatch(path))) return false;
  if (excludes.any((r) => r.hasMatch(path))) return false;
  return true;
}

/// Compile a gitignore-flavoured glob to a full-path regex. A `/` in
/// the glob anchors it to the workspace root; otherwise it may match at
/// any depth (basename-style). Supports `*`, `**`, `?`.
RegExp _globToRegExp(String glob) {
  final anchored = glob.contains('/');
  final b = StringBuffer('^');
  if (!anchored) b.write(r'(?:.*/)?');
  var i = 0;
  while (i < glob.length) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        b.write('.*');
        i += 2;
        continue;
      }
      b.write('[^/]*');
    } else if (c == '?') {
      b.write('[^/]');
    } else if (r'.^$+(){}[]|\'.contains(c)) {
      b.write('\\$c');
    } else {
      b.write(c);
    }
    i++;
  }
  b.write(r'$');
  return RegExp(b.toString());
}
