/// A single active pane. Pure data — no PTY coupling so this type
/// travels cleanly into the Flutter app (which can't depend on
/// `dart:ffi`-using code for the web build).
///
/// The daemon's [PaneRegistry] keeps a parallel `PtySession` keyed on
/// [id] and mutates [isClosed] when the session exits.
library;

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

class Pane {
  Pane({
    required this.id,
    required this.kind,
    required this.pid,
    required this.argv,
    this.cwd,
    this.title,
    this.isClosed = false,
  });

  final String id;
  final PaneKind kind;
  final int pid;
  final List<String> argv;
  final String? cwd;
  final String? title;

  /// Mutated by the registry when the child exits or the session
  /// closes. Kept mutable so registry state doesn't need to replace
  /// [Pane] instances on transition.
  bool isClosed;

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
