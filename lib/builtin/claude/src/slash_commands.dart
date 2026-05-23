/// Pure helpers for recognising slash-command input in the Claude composer
/// (T-153). Kept Flutter-free so they're cheap to unit-test.
///
/// Claude's TUI only treats a leading `/` as a command when the input is
/// *typed*, not bracketed-pasted. clide delivers recognised commands typed
/// (so they fire) and everything else bracketed-pasted (so multi-line text
/// and stray leading slashes — e.g. a path like `/tmp/x.log` — arrive as
/// literal text rather than being mis-parsed). Recognition is by the known
/// command set, so unknown `/...` input stays literal; that's intentionally
/// smarter than the CLI, which would reject it.
library;

/// The command token of a single-line slash input — `"/model sonnet"` →
/// `"model"` — or null when [text] isn't single-line leading-slash input.
String? slashCommandToken(String text) {
  if (text.contains('\n') || !text.startsWith('/')) return null;
  final rest = text.substring(1);
  final ws = rest.indexOf(RegExp(r'\s'));
  final token = ws < 0 ? rest : rest.substring(0, ws);
  return token.isEmpty ? null : token;
}

/// Whether [text] is a recognised slash command given the [known] set, so it
/// should be delivered typed (firing the command) rather than bracketed-pasted.
bool isKnownSlashCommand(String text, Iterable<String> known) {
  final token = slashCommandToken(text);
  return token != null && known.contains(token);
}

/// Slash commands clide handles itself instead of forwarding to Claude:
/// Claude Code's own handling forks the session to a new id that clide's
/// transcript reader can't follow, so clide owns the semantics (T-156).
const Set<String> kClideOwnedCommands = {'clear'};

/// The clide-owned command in [text] (a single-line leading-slash token in
/// [kClideOwnedCommands]), or null.
String? clideOwnedCommand(String text) {
  final token = slashCommandToken(text);
  return token != null && kClideOwnedCommands.contains(token) ? token : null;
}

bool _isWs(String c) => c == ' ' || c == '\t' || c == '\n';

/// An in-progress slash query at the cursor — the `/` position and the word
/// typed after it so far — used to drive the composer typeahead (T-152).
class SlashQuery {
  const SlashQuery({required this.start, required this.query});

  /// Index of the `/` in the text.
  final int start;

  /// Text between the `/` and the cursor (no leading slash, no whitespace).
  final String query;

  @override
  bool operator ==(Object other) => other is SlashQuery && other.start == start && other.query == query;

  @override
  int get hashCode => Object.hash(start, query);
}

/// The slash query at [cursor] in [text], or null when the cursor isn't inside
/// a slash token. The token is the run of non-whitespace ending at the cursor;
/// it qualifies only when that run starts with `/` — which, by construction, is
/// at the start of the text or right after whitespace. So `/mod` and `go /mod`
/// both match (inline triggers), but `a/b` (a path) does not, and the query
/// closes once a space follows the command word.
SlashQuery? activeSlashQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  var start = cursor;
  while (start > 0 && !_isWs(text[start - 1])) {
    start--;
  }
  if (start >= cursor) return null; // empty run (cursor at a boundary)
  if (text[start] != '/') return null; // run isn't a slash token
  return SlashQuery(start: start, query: text.substring(start + 1, cursor));
}

/// Commands matching [query] (case-insensitive prefix), de-duplicated, sorted,
/// capped at [limit]. Empty query returns the leading [limit] commands.
List<String> filterSlashCommands(String query, Iterable<String> commands, {int limit = 8}) {
  final q = query.toLowerCase();
  final seen = <String>{};
  final matches = <String>[];
  for (final c in commands) {
    if (c.toLowerCase().startsWith(q) && seen.add(c)) matches.add(c);
  }
  matches.sort();
  return matches.length > limit ? matches.sublist(0, limit) : matches;
}

/// Replace the slash token described by [q] in [text] with `/<command> `,
/// returning the new text and the cursor offset just past the inserted space.
({String text, int cursor}) completeSlash(String text, SlashQuery q, String command) {
  final insert = '/$command ';
  final end = q.start + 1 + q.query.length;
  return (text: text.replaceRange(q.start, end, insert), cursor: q.start + insert.length);
}
