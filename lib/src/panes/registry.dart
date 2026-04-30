/// [PaneRegistry] — daemon-side state for all live panes.
///
/// Owns the [PtySession] per pane, generates `p_N` ids, and forwards
/// pty output + lifecycle changes as IPC events via a [DaemonEventSink].
/// Pane commands (pane.spawn / list / write / resize / close) resolve
/// against this registry; extension UIs subscribe to the emitted events.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import '../ipc/envelope.dart';
import '../pty/native_pty.dart';
import 'event_sink.dart';
import 'pane.dart';

class PaneRegistry {
  PaneRegistry({required this.events});

  final DaemonEventSink events;
  final Map<String, Pane> _panes = {};
  final Map<String, NativePty> _sessions = {};
  final Map<String, StreamSubscription<Uint8List>> _subs = {};
  int _nextId = 1;

  /// All currently-live panes (not yet closed).
  Iterable<Pane> get panes => _panes.values;

  Pane? get(String id) => _panes[id];

  /// Spawn a child under a PTY and wire its output to events.
  ///
  /// [ptycPath] is plumbed through to [PtySession.spawn]; callers that
  /// have a dev-built `ptyc/bin/ptyc` or a non-PATH install can point
  /// at it explicitly.
  Future<Pane> spawn({
    required PaneKind kind,
    required List<String> argv,
    String? cwd,
    Map<String, String>? env,
    int cols = 80,
    int rows = 24,
    String? title,
  }) async {
    final id = 'p_${_nextId++}';
    final executable = argv.first;
    final arguments = argv.length > 1 ? argv.sublist(1) : const <String>[];

    // Merge the caller's env on top of the process environment +
    // terminal defaults, matching the old ptyc contract.
    final fullEnv = <String, String>{
      ...Platform.environment,
      'TERM': 'xterm-256color',
      'COLORTERM': 'truecolor',
      'LANG': 'en_US.UTF-8',
      'LC_ALL': 'en_US.UTF-8',
      if (env != null) ...env,
    };

    final session = NativePty.start(
      executable: executable,
      arguments: arguments,
      columns: cols,
      rows: rows,
      workingDirectory: cwd,
      environment: fullEnv,
    );
    final pane = Pane(
      id: id,
      kind: kind,
      pid: session.pid,
      argv: argv,
      cwd: cwd,
      title: title,
    );
    _panes[id] = pane;
    _sessions[id] = session;

    _emit('pane.spawned', id, pane.toJson());

    _subs[id] = session.output.listen(
      (bytes) => _emit('pane.output', id, {
        'bytes_b64': base64Encode(bytes),
      }),
      onDone: () => _onExit(pane),
    );

    return pane;
  }

  /// Send bytes to a pane's stdin.
  int write(String id, List<int> bytes) {
    final p = _panes[id];
    final s = _sessions[id];
    if (p == null || p.isClosed || s == null) return 0;
    return s.write(bytes);
  }

  /// Resize a pane + emit `pane.resized`.
  void resize(String id, {required int cols, required int rows}) {
    final p = _panes[id];
    final s = _sessions[id];
    if (p == null || p.isClosed || s == null) return;
    s.resize(cols: cols, rows: rows);
    _emit('pane.resized', id, {'cols': cols, 'rows': rows});
  }

  /// Close a pane + emit `pane.closed`. Idempotent.
  Future<void> close(String id) async {
    final p = _panes[id];
    if (p == null) return;
    final s = _sessions[id];
    if (s != null) await s.close();
    await _subs[id]?.cancel();
    _subs.remove(id);
    _sessions.remove(id);
    _panes.remove(id);
    _emit('pane.closed', id, const {});
  }

  /// Close every pane. Called on daemon shutdown.
  Future<void> shutdown() async {
    for (final id in List<String>.from(_panes.keys)) {
      await close(id);
    }
  }

  // -- internals ----------------------------------------------------------

  void _onExit(Pane p) {
    if (_panes.containsKey(p.id)) {
      p.isClosed = true;
      _emit('pane.exit', p.id, const {});
      // Don't auto-close — keep the pane entry so `list` can show the
      // exited state until the consumer explicitly closes. A future
      // tuning knob (keep-vs-reap policy per kind) can change this.
    }
  }

  void _emit(String kind, String id, Map<String, Object?> data) {
    events.emit(IpcEvent(
      subsystem: 'pane',
      kind: kind,
      timestamp: DateTime.now().toUtc(),
      data: {'id': id, ...data},
    ));
  }
}
