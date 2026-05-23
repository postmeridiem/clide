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
