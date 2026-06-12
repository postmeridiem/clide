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
/// `/fork` branches the current session into a new pane (T-172). `/model`
/// is interactive in the CLI's TUI only — forwarded it does nothing — so
/// clide owns it as a set_model control request / picker (T-408).
const Set<String> kClideOwnedCommands = {'clear', 'resume', 'fork', 'model'};

/// The clide-owned command in [text] (a single-line leading-slash token in
/// [kClideOwnedCommands]), or null.
String? clideOwnedCommand(String text) {
  final token = slashCommandToken(text);
  return token != null && kClideOwnedCommands.contains(token) ? token : null;
}

/// Where slash input goes (T-411). One source of truth so a TUI-only command
/// neither errors raw from the CLI nor bracket-pastes to the model as text
/// (burning a real turn — observed with /effort on claude 2.1.175).
enum SlashRoute {
  /// clide implements it natively ([kClideOwnedCommands]).
  owned,

  /// The CLI handles it headless — advertised in the `initialize` handshake's
  /// `slash_commands` (skills + the headless builtins: compact, context, …).
  forward,

  /// A known TUI-only builtin: never forwarded; clide shows a local notice
  /// with the clide-native way ([kTuiOnlyCommands]).
  unavailable,
}

/// Claude Code TUI-only builtins (probed against 2.1.175: not advertised in
/// stream-json, and forwarding would either error "isn't available in this
/// environment" or — worse, for un-advertised tokens — bracket-paste to the
/// model as literal text). Value = the clide-native pointer shown in the
/// notice card. Commands clide later implements move to [kClideOwnedCommands].
const Map<String, String> kTuiOnlyCommands = {
  'effort': 'the session effort level is set at spawn time; clide support is tracked in T-412',
  'status': 'session status lives in the Claude sidebar (Activity tab)',
  'cost': 'cost and context usage live in the Claude sidebar (Activity tab)',
  'context': '', // advertised on current CLIs — only routes here on older ones
  'help': 'type / to browse commands; clide owns /clear /resume /fork /model',
  'config': 'open the Claude sidebar Config tab',
  'permissions': 'use the permission-mode control beside the composer',
  'memory': 'open CLAUDE.md in the editor',
  'mcp': 'MCP servers are listed in the Claude sidebar Config tab',
  'agents': 'agents are listed in the Claude sidebar Config tab',
  'hooks': 'hooks are listed in the Claude sidebar Config tab',
  'todos': "Claude's task list docks above the composer",
  'model': '', // owned (T-408) — only routes here if ever removed from owned
  'doctor': 'run `claude doctor` in a terminal',
  'login': 'run `claude` in a terminal and use /login there',
  'logout': 'run `claude` in a terminal and use /logout there',
  'exit': 'close the pane or switch sessions instead',
  'vim': 'clide ships its own editor vim mode',
  'add-dir': '',
  'bashes': '',
  'bug': '',
  'export': '',
  'fast': '',
  'ide': "you're already in one",
  'install-github-app': '',
  'migrate-installer': '',
  'output-style': '',
  'pr-comments': '',
  'privacy-settings': '',
  'release-notes': '',
  'rewind': '',
  'statusline': '',
  'terminal-setup': '',
  'upgrade': '',
};

/// Route [text] (composer input). Null when it isn't slash-command input —
/// send it as a normal message. Precedence: owned > advertised > TUI-only
/// catalog > forward (unknown tokens stay literal text via bracketed paste).
SlashRoute? routeSlashCommand(String text, {required Iterable<String> advertised}) {
  final token = slashCommandToken(text);
  if (token == null) return null;
  if (kClideOwnedCommands.contains(token)) return SlashRoute.owned;
  if (advertised.contains(token)) return SlashRoute.forward;
  if (kTuiOnlyCommands.containsKey(token)) return SlashRoute.unavailable;
  return SlashRoute.forward;
}

/// The notice text for a TUI-only [token] — the CLI's own phrasing plus the
/// clide-native pointer when the catalog has one.
String tuiOnlyNotice(String token) {
  final hint = kTuiOnlyCommands[token] ?? '';
  final base = "/$token is a Claude Code TUI command — it isn't available in clide's conversation pane.";
  return hint.isEmpty ? base : '$base\n→ $hint';
}

/// The argument text after the command token — `"/model sonnet"` → `"sonnet"`
/// — trimmed; empty when there is none (`"/model"`). Null when [text] isn't
/// single-line leading-slash input.
String? slashCommandArg(String text) {
  if (slashCommandToken(text) == null) return null;
  final ws = text.indexOf(RegExp(r'\s'));
  return ws < 0 ? '' : text.substring(ws + 1).trim();
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
