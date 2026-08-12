/// Reading caller-supplied text out of IPC request args.
///
/// Two spellings, because the CLI has to carry content a shell argument
/// can't always hold: `text` for the plain case, `content_b64` for
/// anything with newlines, quotes, or non-UTF-8-safe bytes. Shared so the
/// verbs that accept content (`editor.*`, `files.write`) agree on both —
/// a handler that reads only `text` silently truncates a base64 caller.
///
/// Pure Dart — no Flutter, no I/O — so it runs under `dart test`.
library;

import 'dart:convert';

/// The text a request carries: `text` verbatim, else `content_b64`
/// decoded, else the empty string.
String contentFromArgs(Map<String, Object?> args) {
  final text = args['text'];
  if (text is String) return text;
  final b64 = args['content_b64'];
  if (b64 is String) return utf8.decode(base64Decode(b64));
  return '';
}
