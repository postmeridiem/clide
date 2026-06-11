/// Parsing + the paranoid allowlist for `clide://` deep links (T-56, D-90).
///
/// A clide:// URL is an UNTRUSTED external vector — any webpage can fire one at
/// the OS handler — so the surface is **default-deny**: only the actions in
/// [kDeepLinkSafeActions] are even parseable, and they are read-only /
/// navigation verbs. Execution is additionally gated by a user prompt (see the
/// deeplink extension). Pure (no Flutter): the allowlist + parsing are unit
/// tested in isolation.
library;

/// The ONLY actions a clide:// link may request. Default-deny: anything not in
/// this set is rejected outright. Keep it to side-effect-free navigation —
/// NEVER writes, process control, git, or arbitrary command passthrough.
const Set<String> kDeepLinkSafeActions = {'open'};

/// A validated, allowlisted deep-link action.
class DeepLinkAction {
  const DeepLinkAction({required this.name, required this.path, this.line});

  final String name;
  final String path;
  final int? line;

  /// A human-readable description for the confirmation prompt.
  String get describe => switch (name) {
    'open' => 'Open  $path${line != null ? '  (line $line)' : ''}',
    _ => name,
  };
}

/// Parse [url] into a [DeepLinkAction], or null when it is malformed, not a
/// `clide://` URL, not an allowlisted action, or missing required parameters.
/// Validation only — it never executes anything.
DeepLinkAction? parseDeepLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'clide') return null;
  if (!kDeepLinkSafeActions.contains(uri.host)) return null;
  switch (uri.host) {
    case 'open':
      final path = uri.queryParameters['path'];
      if (path == null || path.isEmpty) return null;
      int? line;
      final lineRaw = uri.queryParameters['line'];
      if (lineRaw != null && lineRaw.isNotEmpty) {
        line = int.tryParse(lineRaw);
        if (line == null || line < 1) return null; // reject junk rather than guess
      }
      return DeepLinkAction(name: 'open', path: path, line: line);
  }
  return null;
}
