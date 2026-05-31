/// Pure helpers for `@`-name completion in the team chat composer (T-180).
///
/// Mirrors the slash_commands.dart API so the composer can use the same
/// LayerLink + OverlayEntry overlay pattern for both typeaheads.
/// Flutter-free — cheap to unit-test.
library;

bool _isWs(String c) => c == ' ' || c == '\t' || c == '\n';

/// An in-progress `@name` query at the cursor — the `@` position and the
/// word typed after it so far.
class AtQuery {
  const AtQuery({required this.start, required this.query});

  /// Index of the `@` in the text.
  final int start;

  /// Text between the `@` and the cursor (no leading `@`, no whitespace).
  final String query;

  @override
  bool operator ==(Object other) => other is AtQuery && other.start == start && other.query == query;

  @override
  int get hashCode => Object.hash(start, query);
}

/// The `@` query at [cursor] in [text], or null when the cursor isn't inside
/// an `@` token. Matches `@name` at the start of the text or right after
/// whitespace; does NOT match mid-word `@` (e.g. an email address).
AtQuery? activeAtQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  var start = cursor;
  while (start > 0 && !_isWs(text[start - 1])) {
    start--;
  }
  if (start >= cursor) return null; // empty run
  if (text[start] != '@') return null; // run doesn't start with @
  return AtQuery(start: start, query: text.substring(start + 1, cursor));
}

/// Member names matching [query] (case-insensitive prefix), de-duplicated,
/// sorted, capped at [limit]. Always includes `team` (broadcast alias) as the
/// first entry when the query is empty or matches.
///
/// [names] should be the broker's member display names (including `user`);
/// pass them all — this helper will NOT filter out `user` because the
/// composer may legitimately let an agent @-reply to the user.
List<String> filterAtNames(String query, Iterable<String> names, {int limit = 8}) {
  const broadcast = 'team';
  final q = query.toLowerCase();
  final seen = <String>{};
  final matches = <String>[];
  // Broadcast alias first.
  if (broadcast.startsWith(q) && seen.add(broadcast)) matches.add(broadcast);
  for (final n in names) {
    if (n.toLowerCase().startsWith(q) && seen.add(n)) matches.add(n);
  }
  matches.sort((a, b) {
    // Keep `team` pinned first when it's present.
    if (a == broadcast) return -1;
    if (b == broadcast) return 1;
    return a.compareTo(b);
  });
  return matches.length > limit ? matches.sublist(0, limit) : matches;
}

/// Replace the `@` token described by [q] in [text] with `@<name> `,
/// returning the new text and the cursor offset just past the inserted space.
({String text, int cursor}) completeAt(String text, AtQuery q, String name) {
  final insert = '@$name ';
  final end = q.start + 1 + q.query.length;
  return (text: text.replaceRange(q.start, end, insert), cursor: q.start + insert.length);
}

/// Parse a leading `@name` tag from the start of [text] (trimmed). Returns
/// the recipient name and the remaining body, or `(null, text)` when there
/// is no tag. `@team` resolves to null (broadcast).
({String? recipient, String body}) parseAtTag(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('@')) return (recipient: null, body: trimmed);
  final ws = trimmed.indexOf(RegExp(r'\s'));
  if (ws < 0) {
    // Entire text is just the tag — no body.
    final tag = trimmed.substring(1);
    return (recipient: tag == 'team' ? null : tag, body: '');
  }
  final tag = trimmed.substring(1, ws);
  final body = trimmed.substring(ws).trimLeft();
  return (recipient: tag == 'team' ? null : tag, body: body);
}
