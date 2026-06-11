/// Detect the file a Bash command follows, for the live-tail sub-card (T-325).
///
/// Claude Code runs every Bash tool itself and clide only sees the final
/// `tool_result` block — we never tap the running command's stdout. So instead
/// of mirroring the process, we detect a *file-backed source* the command
/// reads/follows and open our own read-only follower on the same file.
///
/// Deliberately conservative (the ticket's "small, explicit allowlist"): only
/// the read/follow verbs below, only a single file argument, and only paths
/// that resolve INSIDE the workspace. Anything else — a pipe into `tail`, a
/// redirect, two files, a path outside the repo — returns null so the caller
/// shows a "nothing to follow" affordance instead of following the wrong thing.
library;

import 'dart:io';

import 'package:clide/src/files/path_safety.dart';

/// Verbs whose single file argument clide can independently follow read-only.
const Set<String> _followVerbs = {'tail', 'cat', 'less'};

/// The file [command] reads/follows that clide can mirror read-only, as an
/// absolute path inside [workspaceRoot] — or null when there is no single,
/// safe, file-backed source. See the library doc for the policy.
String? detectBashTailSource(String command, {required Directory workspaceRoot}) {
  String? found;
  for (final segment in _commandSegments(command)) {
    final tokens = _tokenize(segment);
    if (tokens.isEmpty || !_followVerbs.contains(tokens.first)) continue;
    final files = _fileArgs(tokens.first, tokens.sublist(1));
    if (files.length != 1) continue; // 0 → reads stdin (a pipe); >1 → ambiguous

    final String resolved;
    try {
      resolved = resolveUnderRoot(workspaceRoot, files.single);
    } on PathOutsideRoot {
      continue; // outside the workspace → don't follow (v1 policy)
    }
    if (found != null && found != resolved) return null; // two distinct sources
    found = resolved;
  }
  return found;
}

/// Whether [command] expresses an intent to FOLLOW a file — used to decide
/// when to surface the live-tail segment at all, so ordinary commands (`ls`,
/// `git status`, a plain `cat`) get no segment, but a `tail …` with no
/// followable file still shows the "nothing to follow" note. v1 triggers on
/// `tail` or a follow flag (`-f`/`-F`/`--follow`); `cat`/`less` are detectable
/// sources but don't trigger the UI on their own (T-325).
bool bashHasTailIntent(String command) {
  for (final segment in _commandSegments(command)) {
    final tokens = _tokenize(segment);
    if (tokens.isEmpty) continue;
    if (tokens.first == 'tail') return true;
    if (tokens.any((t) => t == '-f' || t == '-F' || t == '--follow')) return true;
  }
  return false;
}

/// Split a command line into command/pipeline segments on `|`, `;`, `&`. The
/// doubled forms (`&&`, `||`) fall out as empty middles and are dropped.
Iterable<String> _commandSegments(String command) => command.split(RegExp(r'[|;&]')).where((s) => s.trim().isNotEmpty);

/// Positional (non-flag) file arguments for [verb]. Skips flags, consumes the
/// value of `tail -n N` / `-c N`, honours `--` (end of options), and stops at a
/// redirect (`>` / `<`) — everything after a redirect targets a fd, not the
/// command's input.
List<String> _fileArgs(String verb, List<String> args) {
  final files = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--') {
      files.addAll(args.sublist(i + 1).where((t) => !t.contains('>') && !t.contains('<')));
      break;
    }
    if (a.contains('>') || a.contains('<')) break; // a redirect ends positional args
    if (a.startsWith('-')) {
      if (verb == 'tail' && (a == '-n' || a == '-c') && i + 1 < args.length) i++; // -n N / -c N
      continue;
    }
    files.add(a);
  }
  return files;
}

/// Minimal shell tokeniser: splits on whitespace, honours single/double quotes
/// (no escape or expansion handling — enough to recover file arguments).
List<String> _tokenize(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  String? quote;
  var has = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (quote != null) {
      if (ch == quote) {
        quote = null;
      } else {
        buf.write(ch);
      }
      has = true;
    } else if (ch == '"' || ch == "'") {
      quote = ch;
      has = true;
    } else if (ch == ' ' || ch == '\t') {
      if (has) {
        out.add(buf.toString());
        buf.clear();
        has = false;
      }
    } else {
      buf.write(ch);
      has = true;
    }
  }
  if (has) out.add(buf.toString());
  return out;
}
