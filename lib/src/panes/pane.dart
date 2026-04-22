/// A single active pane in the daemon.
///
/// Owns a [PtySession] plus whatever pane-level metadata the UI +
/// CLI need. The `kind:` field distinguishes general-purpose terminal
/// panes from Claude panes (D-041, not yet landed) from whatever
/// future pane-shaped surface Tier 1+ grows.
library;

import '../pty/session.dart';

/// Kind of a pane. Keep this enum small and explicit — each kind
/// typically pairs with a bundled extension that manages its
/// lifecycle (`builtin.terminal`, `builtin.claude`).
enum PaneKind {
  terminal,
  claude;

  String get wire => name;

  static PaneKind parse(String s) {
    return PaneKind.values.firstWhere(
      (v) => v.wire == s,
      orElse: () => throw ArgumentError.value(s, 'kind', 'unknown pane kind'),
    );
  }
}

/// A live pane. Thin wrapper over [PtySession] — the registry is what
/// owns the session lifecycle; consumers of this class read state and
/// call [write] / [resize] via the session.
class Pane {
  Pane({
    required this.id,
    required this.kind,
    required this.session,
    required this.argv,
    this.cwd,
    this.title,
  });

  final String id;
  final PaneKind kind;
  final PtySession session;
  final List<String> argv;
  final String? cwd;
  final String? title;

  int get pid => session.pid;
  bool get isClosed => session.isClosed;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.wire,
        'pid': pid,
        'argv': argv,
        if (cwd != null) 'cwd': cwd,
        if (title != null) 'title': title,
        'closed': isClosed,
      };
}
