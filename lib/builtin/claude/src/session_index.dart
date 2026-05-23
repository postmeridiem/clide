/// Enumerates the Claude sessions recorded for a workspace and summarises
/// each by its first and last user message — the labels the /resume picker
/// shows (T-156). Flutter-free so it unit-tests under `dart test`.
///
/// Each session is a `<uuid>.jsonl` transcript in the munged project dir
/// (`~/.claude/projects/<munged-cwd>/`). Bookends are read from a bounded
/// window at each end of the file, so even a multi-MB transcript summarises
/// cheaply.
library;

import 'dart:convert';
import 'dart:io';

/// One session in the workspace, summarised for the picker.
class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.modified,
    this.firstUser,
    this.lastUser,
  });

  /// The session id (the `<uuid>` of `<uuid>.jsonl`).
  final String id;
  final DateTime modified;

  /// First / last *user prompt* text in the session (tool-result-only user
  /// records don't count), or null if none.
  final String? firstUser;
  final String? lastUser;

  /// "first … last" — the picker's primary label. Falls back to the id when
  /// the session carries no user prompt.
  String get label {
    final f = firstUser, l = lastUser;
    if (f == null && l == null) return id;
    if (f == null) return l!;
    if (l == null || l == f) return f;
    return '$f … $l';
  }
}

/// The user-prompt text in a transcript record, or null if [record] isn't a
/// user prompt (e.g. a tool_result-only user record, or a non-user record).
String? userText(Map<String, Object?> record) {
  if (record['type'] != 'user') return null;
  final msg = record['message'];
  if (msg is! Map) return null;
  final content = msg['content'];
  if (content is String) {
    final t = content.trim();
    return t.isEmpty ? null : t;
  }
  if (content is List) {
    final texts = content.whereType<Map>().where((b) => b['type'] == 'text').map((b) => b['text']).whereType<String>();
    final joined = texts.join(' ').trim();
    return joined.isEmpty ? null : joined;
  }
  return null;
}

String? _firstUserText(Iterable<String> lines) {
  for (final line in lines) {
    final t = _userTextOf(line);
    if (t != null) return t;
  }
  return null;
}

String? _lastUserText(Iterable<String> lines) {
  String? last;
  for (final line in lines) {
    final t = _userTextOf(line);
    if (t != null) last = t;
  }
  return last;
}

String? _userTextOf(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;
  try {
    return userText(jsonDecode(trimmed) as Map<String, Object?>);
  } catch (_) {
    return null;
  }
}

/// Sessions in [dir] (the munged project dir), most-recently-modified first,
/// capped at [max]. Each is summarised by bookend user prompts read from a
/// bounded [window] at each end of its transcript.
Future<List<SessionSummary>> listSessions(
  Directory dir, {
  int max = 20,
  int window = 128 * 1024,
}) async {
  if (!await dir.exists()) return const [];
  final files = <File>[];
  await for (final e in dir.list(followLinks: false)) {
    if (e is File && e.path.endsWith('.jsonl')) files.add(e);
  }
  final summaries = <SessionSummary>[];
  for (final f in files) {
    final stat = await f.stat();
    final bookends = await _bookends(f, window);
    summaries.add(SessionSummary(
      id: _sessionId(f.path),
      modified: stat.modified,
      firstUser: bookends.first,
      lastUser: bookends.last,
    ));
  }
  summaries.sort((a, b) => b.modified.compareTo(a.modified));
  return summaries.length > max ? summaries.sublist(0, max) : summaries;
}

String _sessionId(String path) {
  final base = path.split(Platform.pathSeparator).last;
  return base.endsWith('.jsonl') ? base.substring(0, base.length - 6) : base;
}

Future<({String? first, String? last})> _bookends(File f, int window) async {
  final len = await f.length();
  final raf = await f.open();
  try {
    final headLen = len < window ? len : window;
    final head = const LineSplitter().convert(utf8.decode(await raf.read(headLen), allowMalformed: true));
    final first = _firstUserText(head);

    if (len <= window) {
      return (first: first, last: _lastUserText(head));
    }
    await raf.setPosition(len - window);
    var tail = const LineSplitter().convert(utf8.decode(await raf.read(window), allowMalformed: true));
    if (tail.isNotEmpty) tail = tail.sublist(1); // drop the partial first line
    return (first: first, last: _lastUserText(tail));
  } finally {
    await raf.close();
  }
}
