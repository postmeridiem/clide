/// Data types for workspace content search (T-52 / T-53, per D-79).
///
/// Flutter-free by construction: shared by the grep engine (which runs
/// in worker isolates), the `search.*` IPC layer, and the search panel
/// UI. Plain data so instances are sendable across isolates.
library;

/// One match produced by the workspace grep. Carries enough to render a
/// result, navigate to the line, and (for replace, T-53) address the
/// matched span within the line.
class SearchMatch {
  const SearchMatch({
    required this.path,
    required this.line,
    required this.matchStart,
    required this.matchEnd,
    required this.preview,
  });

  /// Repo-relative, forward-slashed path of the file.
  final String path;

  /// 1-based line number of the match.
  final int line;

  /// 0-based character offset of the match start within the line.
  final int matchStart;

  /// 0-based character offset of the match end (exclusive) within the line.
  final int matchEnd;

  /// The matched line's text (capped for transport/render).
  final String preview;

  Map<String, Object?> toJson() => {
        'path': path,
        'line': line,
        'matchStart': matchStart,
        'matchEnd': matchEnd,
        'preview': preview,
      };

  factory SearchMatch.fromJson(Map<String, Object?> j) => SearchMatch(
        path: j['path'] as String,
        line: (j['line'] as num).toInt(),
        matchStart: (j['matchStart'] as num).toInt(),
        matchEnd: (j['matchEnd'] as num).toInt(),
        preview: j['preview'] as String,
      );
}

/// Parameters for a workspace search.
class SearchQuery {
  const SearchQuery({
    required this.pattern,
    this.regex = false,
    this.ignoreCase = false,
    this.include = const [],
    this.exclude = const [],
  });

  /// The literal text (when [regex] is false) or regular expression
  /// source (when true) to search for.
  final String pattern;
  final bool regex;
  final bool ignoreCase;

  /// Glob patterns; when non-empty, only matching paths are searched.
  final List<String> include;

  /// Glob patterns; matching paths are skipped (applied after [include]).
  final List<String> exclude;

  Map<String, Object?> toJson() => {
        'pattern': pattern,
        'regex': regex,
        'ignoreCase': ignoreCase,
        'include': include,
        'exclude': exclude,
      };

  factory SearchQuery.fromJson(Map<String, Object?> j) => SearchQuery(
        pattern: (j['pattern'] as String?) ?? '',
        regex: j['regex'] == true,
        ignoreCase: j['ignoreCase'] == true,
        include: _strings(j['include']),
        exclude: _strings(j['exclude']),
      );

  static List<String> _strings(Object? v) => v is List ? [for (final e in v) '$e'] : const [];
}
