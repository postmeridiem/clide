/// Narrow interface through which subsystems emit events.
///
/// The daemon server implements this (broadcasts to every connected
/// IPC client); tests can provide a recording fake. Keeping the
/// emitter behind an interface means subsystems don't depend on the
/// server package, which keeps the dep graph pointing the right way
/// (server depends on subsystems, not the other way round).
library;

import 'dart:async';

import '../ipc/envelope.dart';

abstract class DaemonEventSink {
  void emit(IpcEvent event);
}

/// In-memory recording sink for tests + for composing multi-sink
/// scenarios (e.g. tee to both the wire and an audit log).
class RecordingEventSink implements DaemonEventSink {
  RecordingEventSink();
  final List<IpcEvent> events = [];
  final _controller = StreamController<IpcEvent>.broadcast();

  @override
  void emit(IpcEvent event) {
    events.add(event);
    _controller.add(event);
  }

  /// Live stream of every event emitted into this sink. Tests use
  /// `stream.firstWhere(...)` for event-driven waits instead of
  /// polling the [events] list with `Future.delayed`.
  Stream<IpcEvent> get stream => _controller.stream;

  /// Convenience: filter to a single subsystem (`pane`, `git`, …).
  Iterable<IpcEvent> ofSubsystem(String subsystem) => events.where((e) => e.subsystem == subsystem);

  /// Convenience: filter to a specific `type` (`pane.spawned`, …).
  Iterable<IpcEvent> ofKind(String kind) => events.where((e) => e.kind == kind);
}
